// MARK: - BrandKit.swift

// Defines the BrandKit model for storing brand assets and colors.
//
// BrandKit allows users to maintain consistent branding across their
// generated content by storing:
// - Brand details (name, personality)
// - Brand colors (primary, secondary, accent, background, text + additional)
// - Logo images (light and dark variants)
// - Reference images (dynamic array for ad generation reference)
// - Typeface selection
//
// ## Brand Details
// - Brand name: Company/product name
// - Brand about: Description of the brand (max 500 chars)
// - Brand personality: Brand voice/tone traits (max 160 chars)
//
// ## Brand Colors
// Static color types with editable values:
// - Primary, Secondary, Accent, Background, Text
// - Additional custom colors array
//
// ## Brand Images
// Multiple image variants are supported:
// - Light Logo / Dark Logo (stored in imageFileNames dictionary)
// - Reference Images (stored in modelAssets array, unlimited)
// Each variant has associated thumbnails for performance.
//
// ## Typeface
// System font selection with guidance for proprietary fonts.
//
// ## Image Storage
// Images are stored in iCloud Documents with naming convention:
// - Full image: `{uuid}.png`
// - Thumbnail: `{uuid}_thumb.png`
// - Large thumbnail: `{uuid}_thumb_large.png`

import Foundation
import SwiftData

// MARK: - Brand Color Type

/// Predefined brand color types for consistent branding
enum BrandColorType: String, CaseIterable, Codable {
    case primary
    case secondary
    case accent
    case background
    case text

    var displayName: String {
        switch self {
        case .primary: "Primary"
        case .secondary: "Secondary"
        case .accent: "Accent"
        case .background: "Background"
        case .text: "Text/Label"
        }
    }

    var defaultColor: String {
        switch self {
        case .primary: "#007AFF"
        case .secondary: "#5856D6"
        case .accent: "#FF9500"
        case .background: "#FFFFFF"
        case .text: "#000000"
        }
    }
}

// MARK: - Model Asset

/// Represents a single model/style asset with unique ID and file reference
struct ModelAsset: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    /// Base file name (without extension) stored in iCloud
    var fileName: String

    init(id: UUID = UUID(), fileName: String) {
        self.id = id
        self.fileName = fileName
    }

    /// Thumbnail file name
    var thumbFileName: String {
        fileName + "_thumb"
    }

    /// Large thumbnail file name
    var largeThumbFileName: String {
        fileName + "_thumb_large"
    }
}

// MARK: - BrandKit Model

/// SwiftData model storing brand assets for a project.
///
/// Each project can have one BrandKit containing:
/// - Brand details (name, personality)
/// - Color palette with predefined types + custom colors
/// - Logo images (light/dark variants)
/// - Reference images for ad generation
/// - Typeface selection
///
/// ## Color Storage
/// Colors are stored in two ways:
/// - `brandColors`: Dictionary mapping BrandColorType to hex strings
/// - `additionalColors`: Array for custom hex color strings
///
/// ## Image Variants
/// The `imageFileNames` dictionary maps variant types to file names.
/// Each image has associated thumbnails generated on upload.
///
/// ## File Naming
/// Image files use UUID-based names stored in iCloud:
/// - Original: `{filename}.png`
/// - Small thumb: `{filename}_thumb.png`
/// - Large thumb: `{filename}_thumb_large.png`
@Model
final class BrandKit: Codable, Identifiable {
    #Index<BrandKit>([\.projectId])

    enum CodingKeys: CodingKey {
        case id
        case projectId
        case brandName
        case brandAbout
        case brandPersonality
        case brandColors
        case additionalColors
        case fontFace
        case imageFileNames
        case modelAssetsData
    }

    var id = UUID()

    var projectId: UUID = Project.defaultProjectId

    var project: Project?

    /// Brand name (company/product name)
    var brandName = ""

    /// Brand about description (max 500 characters)
    var brandAbout = ""

    /// Brand personality traits (max 160 characters)
    var brandPersonality = ""

    /// Maps brand color types to hex color strings
    var brandColors: [String: String] = [:]

    /// Additional custom hex color strings
    var additionalColors: [String] = []

    /// Selected system font face name
    var fontFace: String?

    /// Maps image variant types to file names (for logos only)
    var imageFileNames: [String: String] = [:]

    var modelAssetsData = Data()

    /// Computed property to access model assets
    var modelAssets: [ModelAsset] {
        get {
            guard !modelAssetsData.isEmpty else { return [] }
            do {
                return try JSONDecoder().decode([ModelAsset].self, from: modelAssetsData)
            } catch {
                AppLogger.data.error("Failed to decode modelAssets: \(error, privacy: .public)")
                return []
            }
        }
        set {
            do {
                modelAssetsData = try JSONEncoder().encode(newValue)
            } catch {
                modelAssetsData = Data()
                AppLogger.data.error("Failed to encode modelAssets: \(error, privacy: .public)")
                modelAssetsData = Data()
            }
        }
    }

    /// Creates a new brand kit.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided)
    ///   - projectId: Parent project
    ///   - brandName: Brand name
    ///   - brandAbout: Brand about description
    ///   - brandPersonality: Brand personality traits
    ///   - brandColors: Predefined brand colors
    ///   - additionalColors: Custom color palette
    ///   - fontFace: Selected font face
    ///   - imageFileNames: Initial image mappings (for logos)
    ///   - modelAssets: Reference images array
    init(
        id: UUID = UUID(),
        projectId: UUID = Project.defaultProjectId,
        brandName: String = "",
        brandAbout: String = "",
        brandPersonality: String = "",
        brandColors: [String: String] = [:],
        additionalColors: [String] = [],
        fontFace: String? = nil,
        imageFileNames: [String: String] = [:],
        modelAssets: [ModelAsset] = []
    ) {
        self.id = id
        self.projectId = projectId
        self.brandName = brandName
        self.brandAbout = brandAbout
        self.brandPersonality = brandPersonality
        self.brandColors = brandColors
        self.additionalColors = additionalColors
        self.fontFace = fontFace
        self.imageFileNames = imageFileNames
        modelAssetsData = (try? JSONEncoder().encode(modelAssets)) ?? Data()
    }

    // MARK: - Brand Color Helpers

    /// Gets the hex color for a brand color type
    func color(for type: BrandColorType) -> String {
        brandColors[type.rawValue] ?? type.defaultColor
    }

    /// Sets the hex color for a brand color type
    func setColor(_ hex: String, for type: BrandColorType) {
        brandColors[type.rawValue] = hex
    }

    // MARK: - Image File Name Helpers

    /// Gets the file name for a brand image variant.
    ///
    /// - Parameter variant: The image variant to look up
    /// - Returns: File name if set, nil otherwise
    func imageFileName(for variant: BrandImageVariant) -> String? {
        imageFileNames[variant.rawValue]
    }

    /// Gets the thumbnail file name for a brand image variant.
    /// Thumbnails are used in lists and previews for performance.
    ///
    /// - Parameter variant: The image variant
    /// - Returns: Thumbnail file name (original + "_thumb")
    func thumbFileName(for variant: BrandImageVariant) -> String? {
        guard let base = imageFileNames[variant.rawValue] else { return nil }
        return base + "_thumb"
    }

    /// Gets the large thumbnail file name for a brand image variant.
    /// Large thumbnails are used in medium-sized previews.
    ///
    /// - Parameter variant: The image variant
    /// - Returns: Large thumbnail file name (original + "_thumb_large")
    func largeThumbFileName(for variant: BrandImageVariant) -> String? {
        guard let base = imageFileNames[variant.rawValue] else { return nil }
        return base + "_thumb_large"
    }

    /// Sets or removes the file name for a brand image variant.
    ///
    /// - Parameters:
    ///   - fileName: New file name (nil to remove)
    ///   - variant: The image variant to update
    func setImageFileName(_ fileName: String?, for variant: BrandImageVariant) {
        if let fileName {
            imageFileNames[variant.rawValue] = fileName
        } else {
            imageFileNames.removeValue(forKey: variant.rawValue)
        }
    }

    // MARK: - Codable Implementation

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(brandName, forKey: .brandName)
        try container.encode(brandAbout, forKey: .brandAbout)
        try container.encode(brandPersonality, forKey: .brandPersonality)
        try container.encode(brandColors, forKey: .brandColors)
        try container.encode(additionalColors, forKey: .additionalColors)
        try container.encodeIfPresent(fontFace, forKey: .fontFace)
        try container.encode(imageFileNames, forKey: .imageFileNames)
        try container.encode(modelAssetsData, forKey: .modelAssetsData)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId) ?? Project.defaultProjectId
        brandName = try container.decodeIfPresent(String.self, forKey: .brandName) ?? ""
        brandAbout = try container.decodeIfPresent(String.self, forKey: .brandAbout) ?? ""
        brandPersonality = try container.decodeIfPresent(String.self, forKey: .brandPersonality) ?? ""
        brandColors = try container.decodeIfPresent([String: String].self, forKey: .brandColors) ?? [:]
        fontFace = try container.decodeIfPresent(String.self, forKey: .fontFace)
        imageFileNames = try container.decodeIfPresent([String: String].self, forKey: .imageFileNames) ?? [:]
        modelAssetsData = try container.decodeIfPresent(Data.self, forKey: .modelAssetsData) ?? Data()
        additionalColors = try container.decodeIfPresent([String].self, forKey: .additionalColors) ?? []
    }
}
