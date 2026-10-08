// MARK: - BrandKitManager.swift

// Singleton manager for brand kit operations including colors and logos.
//
// BrandKitManager handles all brand asset operations:
// - Loading/creating brand kits for projects
// - Managing brand colors (add, update, remove)
// - Handling brand image uploads with thumbnail generation
// - iCloud storage integration for brand assets
//
// ## Image Storage
// Brand images are stored in iCloud Documents with thumbnails:
// - Full image: `brand_image_{variant}_{kitId}.png`
// - Small thumbnail: `...thumb.png` (96px max dimension)
// - Large thumbnail: `..._thumb_large.png` (320px max dimension)
//
// ## Project Scoping
// Each project has its own BrandKit. When switching projects,
// call `loadBrandKit` or `ensureBrandKitExists` to update context.

import Foundation
import IllustrateProviders
import OSLog
import SwiftData
import SwiftUI

/// Singleton manager for brand kit operations.
///
/// Handles all brand asset CRUD operations including:
/// - Color palette management
/// - Logo image storage with auto-generated thumbnails
/// - Project-scoped brand kit loading
class BrandKitManager: ObservableObject {
    /// Shared singleton instance
    static let shared = BrandKitManager()

    /// Currently loaded brand kit (for active project)
    @Published var currentBrandKit: BrandKit?

    /// Project ID context for brand operations
    @Published var currentProjectId: UUID = Project.defaultProjectId

    private init() {}

    /// Ensures a brand kit exists for the specified project, creates one if not.
    /// Uses a deferred Task to avoid blocking the initial view render.
    func ensureBrandKitExists(modelContext: ModelContext, projectId: UUID) {
        currentProjectId = projectId

        Task { @MainActor in
            do {
                let descriptor = FetchDescriptor<BrandKit>(
                    predicate: #Predicate { $0.projectId == projectId }
                )
                let projectKit = try modelContext.fetch(descriptor).first

                if let kit = projectKit {
                    self.currentBrandKit = kit
                } else {
                    let newKit = BrandKit(projectId: projectId)
                    modelContext.insert(newKit)
                    try? modelContext.save()
                    self.currentBrandKit = newKit
                }
            } catch {
                AppLogger.data.error("Error ensuring brand kit exists: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Loads the brand kit for the specified project from the database.
    /// Uses a deferred Task to avoid blocking the initial view render.
    func loadBrandKit(modelContext: ModelContext, projectId: UUID) {
        currentProjectId = projectId

        Task { @MainActor in
            do {
                let descriptor = FetchDescriptor<BrandKit>(
                    predicate: #Predicate { $0.projectId == projectId }
                )
                let projectKit = try modelContext.fetch(descriptor).first
                self.currentBrandKit = projectKit
            } catch {
                AppLogger.data.error("Error loading brand kit: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Brand Details

    func updateBrandName(_ name: String, modelContext: ModelContext) {
        guard let kit = currentBrandKit else { return }
        kit.brandName = name
        save(modelContext: modelContext)
    }

    func updateBrandAbout(_ about: String, modelContext: ModelContext) {
        guard let kit = currentBrandKit else { return }
        // Enforce 500 character limit
        kit.brandAbout = String(about.prefix(500))
        save(modelContext: modelContext)
    }

    func updateBrandPersonality(_ personality: String, modelContext: ModelContext) {
        guard let kit = currentBrandKit else { return }
        // Enforce 160 character limit
        kit.brandPersonality = String(personality.prefix(160))
        save(modelContext: modelContext)
    }

    // MARK: - Brand Colors

    func updateBrandColor(_ hexColor: String, for type: BrandColorType, modelContext: ModelContext) {
        guard let kit = currentBrandKit else { return }
        kit.setColor(normalizeHexColor(hexColor), for: type)
        save(modelContext: modelContext)
    }

    func getBrandColor(for type: BrandColorType) -> String {
        currentBrandKit?.color(for: type) ?? type.defaultColor
    }

    // MARK: - Additional Colors

    func addAdditionalColor(_ hexColor: String, modelContext: ModelContext) {
        guard let kit = currentBrandKit else { return }

        let normalizedColor = normalizeHexColor(hexColor)
        kit.additionalColors.append(normalizedColor)
        save(modelContext: modelContext)
    }

    func updateAdditionalColor(at index: Int, with hexColor: String, modelContext: ModelContext) {
        guard let kit = currentBrandKit, index >= 0, index < kit.additionalColors.count else { return }

        kit.additionalColors[index] = normalizeHexColor(hexColor)
        save(modelContext: modelContext)
    }

    func removeAdditionalColor(at index: Int, modelContext: ModelContext) {
        guard let kit = currentBrandKit, index >= 0, index < kit.additionalColors.count else { return }

        kit.additionalColors.remove(at: index)
        save(modelContext: modelContext)
    }

    // MARK: - Typeface

    func updateFontFace(_ fontName: String?, modelContext: ModelContext) {
        guard let kit = currentBrandKit else { return }
        kit.fontFace = fontName
        save(modelContext: modelContext)
    }

    // MARK: - Prefill from Extraction

    /// Applies extracted brand information from Firecrawl Agent.
    ///
    /// Replaces existing values with extracted data.
    ///
    /// - Parameters:
    ///   - extraction: The extracted brand information
    ///   - modelContext: SwiftData model context for persistence
    func applyExtraction(_ extraction: BrandKitExtraction, modelContext: ModelContext) {
        guard let kit = currentBrandKit else { return }

        // Apply extracted values (replace existing)
        if let name = extraction.brandName, !name.isEmpty {
            kit.brandName = name
        }

        if let about = extraction.brandAbout, !about.isEmpty {
            kit.brandAbout = String(about.prefix(500))
        }

        if let personality = extraction.brandPersonality, !personality.isEmpty {
            kit.brandPersonality = String(personality.prefix(160))
        }

        // Apply fontFace if provided and found in system
        if let fontFace = extraction.fontFace, !fontFace.isEmpty {
            if let systemFont = findSystemFont(fontFace) {
                kit.fontFace = systemFont
            }
        }

        // Apply colors (replace existing)
        if let primaryColor = extraction.primaryColor {
            kit.setColor(normalizeHexColor(primaryColor), for: .primary)
        }

        if let secondaryColor = extraction.secondaryColor {
            kit.setColor(normalizeHexColor(secondaryColor), for: .secondary)
        }

        if let accentColor = extraction.accentColor {
            kit.setColor(normalizeHexColor(accentColor), for: .accent)
        }

        if let backgroundColor = extraction.backgroundColor {
            kit.setColor(normalizeHexColor(backgroundColor), for: .background)
        }

        // Replace additional colors
        if let additionalColors = extraction.additionalColors, !additionalColors.isEmpty {
            kit.additionalColors = additionalColors.prefix(4).map { normalizeHexColor($0) }
        }

        save(modelContext: modelContext)

        // Trigger UI update
        objectWillChange.send()
    }

    /// Saves a brand image and its thumbnails, then updates the brand kit
    func saveBrandImage(_ image: PlatformImage, variant: BrandImageVariant, modelContext: ModelContext) {
        guard let kit = currentBrandKit else { return }

        let fileName = "brand_image_\(variant.rawValue)_\(kit.id.uuidString)"
        let thumbFileName = fileName + "_thumb"
        let largeThumbFileName = fileName + "_thumb_large"

        image.saveToiCloud(fileName: fileName)

        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height

        let smallMaxDimension: CGFloat = 96
        let smallThumbnailSize = if aspectRatio > 1 {
            CGSize(width: smallMaxDimension, height: smallMaxDimension / aspectRatio)
        } else {
            CGSize(width: smallMaxDimension * aspectRatio, height: smallMaxDimension)
        }
        if let smallThumbnail = image.resizeImage(targetSize: smallThumbnailSize) {
            smallThumbnail.saveToiCloud(fileName: thumbFileName)
        }

        let largeMaxDimension: CGFloat = 320
        let largeThumbnailSize = if aspectRatio > 1 {
            CGSize(width: largeMaxDimension, height: largeMaxDimension / aspectRatio)
        } else {
            CGSize(width: largeMaxDimension * aspectRatio, height: largeMaxDimension)
        }
        if let largeThumbnail = image.resizeImage(targetSize: largeThumbnailSize) {
            largeThumbnail.saveToiCloud(fileName: largeThumbFileName)
        }

        kit.setImageFileName(fileName, for: variant)
        save(modelContext: modelContext)

        // Trigger UI update
        objectWillChange.send()
    }

    /// Removes a brand image from the brand kit
    func removeBrandImage(variant: BrandImageVariant, modelContext: ModelContext) {
        guard let kit = currentBrandKit else { return }

        let fileName = kit.imageFileName(for: variant)
        let thumbFileName = kit.thumbFileName(for: variant)
        let largeThumbFileName = kit.largeThumbFileName(for: variant)

        kit.setImageFileName(nil, for: variant)

        if let fileName {
            deleteBrandImageFromiCloud(fileName: fileName)
        }
        if let thumbFileName {
            deleteBrandImageFromiCloud(fileName: thumbFileName)
        }
        if let largeThumbFileName {
            deleteBrandImageFromiCloud(fileName: largeThumbFileName)
        }

        save(modelContext: modelContext)

        // Trigger UI update
        objectWillChange.send()
    }

    func thumbnailFileName(for variant: BrandImageVariant) -> String? {
        currentBrandKit?.thumbFileName(for: variant)
    }

    func largeThumbnailFileName(for variant: BrandImageVariant) -> String? {
        currentBrandKit?.largeThumbFileName(for: variant)
    }

    func imageFileName(for variant: BrandImageVariant) -> String? {
        currentBrandKit?.imageFileName(for: variant)
    }

    func hasImage(for variant: BrandImageVariant) -> Bool {
        imageFileName(for: variant) != nil
    }

    // MARK: - Model Assets

    /// Adds a new model asset from an image
    /// - Returns: The created ModelAsset
    @discardableResult
    func addModelAsset(_ image: PlatformImage, modelContext: ModelContext) -> ModelAsset? {
        guard let kit = currentBrandKit else { return nil }

        let assetId = UUID()
        let fileName = "model_asset_\(assetId.uuidString)_\(kit.id.uuidString)"

        // Save image and thumbnails
        image.saveToiCloud(fileName: fileName)

        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height

        let smallMaxDimension: CGFloat = 96
        let smallThumbnailSize = if aspectRatio > 1 {
            CGSize(width: smallMaxDimension, height: smallMaxDimension / aspectRatio)
        } else {
            CGSize(width: smallMaxDimension * aspectRatio, height: smallMaxDimension)
        }
        if let smallThumbnail = image.resizeImage(targetSize: smallThumbnailSize) {
            smallThumbnail.saveToiCloud(fileName: fileName + "_thumb")
        }

        let largeMaxDimension: CGFloat = 320
        let largeThumbnailSize = if aspectRatio > 1 {
            CGSize(width: largeMaxDimension, height: largeMaxDimension / aspectRatio)
        } else {
            CGSize(width: largeMaxDimension * aspectRatio, height: largeMaxDimension)
        }
        if let largeThumbnail = image.resizeImage(targetSize: largeThumbnailSize) {
            largeThumbnail.saveToiCloud(fileName: fileName + "_thumb_large")
        }

        let asset = ModelAsset(id: assetId, fileName: fileName)
        var assets = kit.modelAssets
        assets.append(asset)
        kit.modelAssets = assets

        save(modelContext: modelContext)
        objectWillChange.send()

        return asset
    }

    /// Removes a model asset by ID
    func removeModelAsset(id: UUID, modelContext: ModelContext) {
        guard let kit = currentBrandKit else { return }

        var assets = kit.modelAssets
        guard let index = assets.firstIndex(where: { $0.id == id }) else { return }

        let asset = assets[index]

        // Delete files from iCloud
        deleteBrandImageFromiCloud(fileName: asset.fileName)
        deleteBrandImageFromiCloud(fileName: asset.thumbFileName)
        deleteBrandImageFromiCloud(fileName: asset.largeThumbFileName)

        assets.remove(at: index)
        kit.modelAssets = assets

        // Clean up AppStorage selection for this asset
        cleanupModelAssetSelection(assetId: id)

        save(modelContext: modelContext)
        objectWillChange.send()
    }

    /// Gets all model assets for the current brand kit
    var modelAssets: [ModelAsset] {
        currentBrandKit?.modelAssets ?? []
    }

    /// Cleans up AppStorage selection when a model asset is removed
    private func cleanupModelAssetSelection(assetId: UUID) {
        let key = "brandAsset.selectedModelAssets"
        let defaults = UserDefaults.standard

        guard let data = defaults.data(forKey: key),
              var selectedIds = try? JSONDecoder().decode(Set<UUID>.self, from: data)
        else { return }

        if selectedIds.remove(assetId) != nil {
            if let encoded = try? JSONEncoder().encode(selectedIds) {
                defaults.set(encoded, forKey: key)
            }
        }
    }

    // MARK: - Private Helpers

    private func save(modelContext: ModelContext) {
        do {
            try modelContext.save()
        } catch {
            AppLogger.data.error("Error saving brand kit: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func normalizeHexColor(_ hex: String) -> String {
        var color = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !color.hasPrefix("#") {
            color = "#" + color
        }
        return color
    }

    /// Checks if a font family is available in the system.
    private func isSystemFontAvailable(_ fontName: String) -> Bool {
        #if os(macOS)
        let availableFonts = NSFontManager.shared.availableFontFamilies
        #else
        let availableFonts = UIFont.familyNames
        #endif

        // Check for exact match first
        if availableFonts.contains(fontName) {
            return true
        }

        // Check for case-insensitive match
        let lowercasedName = fontName.lowercased()
        return availableFonts.contains { $0.lowercased() == lowercasedName }
    }

    /// Finds the correct system font name (case-sensitive) for a given font name.
    func findSystemFont(_ fontName: String) -> String? {
        #if os(macOS)
        let availableFonts = NSFontManager.shared.availableFontFamilies
        #else
        let availableFonts = UIFont.familyNames
        #endif

        // Check for exact match first
        if availableFonts.contains(fontName) {
            return fontName
        }

        // Check for case-insensitive match and return the correct casing
        let lowercasedName = fontName.lowercased()
        return availableFonts.first { $0.lowercased() == lowercasedName }
    }

    private func deleteBrandImageFromiCloud(fileName: String) {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
        else {
            return
        }

        let fileURL = containerURL.appendingPathComponent("\(fileName).png")

        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                AppLogger.storage.debug("Deleted brand image: \(fileName, privacy: .public)")
            }
        } catch {
            AppLogger.storage.error("Error deleting brand image: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Brand Image Variant Enum

/// Variants for logo images only. Model assets are stored separately.
enum BrandImageVariant: String, CaseIterable {
    case lightLogo
    case darkLogo

    var displayName: String {
        switch self {
        case .lightLogo: "Light Logo"
        case .darkLogo: "Dark Logo"
        }
    }

    /// Whether this variant is a logo type
    var isLogo: Bool {
        true
    }

    /// Logo variants only
    static var logoVariants: [BrandImageVariant] {
        [.lightLogo, .darkLogo]
    }
}

// MARK: - Environment Key

struct BrandKitManagerKey: EnvironmentKey {
    static let defaultValue = BrandKitManager.shared
}

extension EnvironmentValues {
    var brandKitManager: BrandKitManager {
        get { self[BrandKitManagerKey.self] }
        set { self[BrandKitManagerKey.self] = newValue }
    }
}
