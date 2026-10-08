// MARK: - GenerationImageView.swift

// Detail view for a single image generation.
//
// Shows comprehensive details and actions for a generated image:
// - Full image display with zoom/expand
// - Generation metadata (prompt, model, dimensions, cost)
// - Source/mask image comparison (if applicable)
// - Dominant colors extracted from image
// - Actions: copy, save, share, edit, compare, delete
//
// ## Platform Differences
// - macOS: Save to file, copy to clipboard
// - iOS: Share sheet, save to Photos
//
// ## Edit Actions
// - "Edit" opens ImageGenerateView with preload data
// - "Generate Video" creates video from this image
// - "Extend Video" (for video generations) extends the video

import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import Photos
import UIKit

/// iOS share sheet wrapper for UIActivityViewController.
struct ImageShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]?

    func makeUIViewController(context _: UIViewControllerRepresentableContext<ImageShareSheet>)
        -> UIActivityViewController
    {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(
        _: UIActivityViewController,
        context _: UIViewControllerRepresentableContext<ImageShareSheet>
    ) {}
}
#endif

struct MaskView: View {
    var maskImage: PlatformImage

    var body: some View {
        #if os(macOS)
        Image(nsImage: maskImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxHeight: 400)
            .frame(maxWidth: .infinity)
            .opacity(0.4)
        #else
        Image(uiImage: maskImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(0.4)
        #endif
    }
}

private func formatMetadataKey(_ key: String) -> String {
    var result = key
        .replacingOccurrences(of: "_", with: " ")
        .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)

    result = result.split(separator: " ").map { word in
        word.prefix(1).uppercased() + word.dropFirst().lowercased()
    }.joined(separator: " ")

    return result
}

struct GenerationImageView: View {
    @Environment(\.openURL) var openURL
    @Environment(\.modelContext) private var modelContext
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var navigationManager: NavigationManager

    #if os(macOS)
    /// Indicates if this view is displayed in a standalone preview window
    @Environment(\.isPreviewWindow) private var isPreviewWindow
    #endif

    let setId: UUID
    @State private var imageSet: ImageSet? = nil
    @State private var generations: [Generation] = []
    @State private var generationIndex = 0

    @State private var showDeleteConfirmation = false
    @State private var showAddToPromptGallery = false
    @State private var showEditConfirmation = false
    @State private var exportImage: IdentifiableImage?
    @State private var showSaveSuccess = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    @State private var expandedGenerationId: UUID?
    @State private var compareGenerationId: UUID?

    private var selectedGeneration: Generation? {
        guard generationIndex >= 0, generationIndex < generations.count else { return nil }
        return generations[generationIndex]
    }

    func getSelectedGeneration() -> Generation? {
        selectedGeneration
    }

    func deleteImageSet() async {
        for generation in generations {
            deleteICloudDocuments(containingSubstring: generation.id.uuidString)
        }
        modelContext.delete(imageSet!)
        try? modelContext.save()

        DispatchQueue.main.async {
            presentationMode.wrappedValue.dismiss()
        }
    }

    var body: some View {
        Form {
            if let generation = selectedGeneration {
                Section {
                    GenerationImageSection(
                        generation: generation,
                        showDeleteConfirmation: $showDeleteConfirmation,
                        expandedGenerationId: $expandedGenerationId,
                        compareGenerationId: $compareGenerationId
                    )

                    if generations.count > 1 {
                        Picker("\(generations.count) Images", selection: $generationIndex) {
                            ForEach(0 ..< generations.count, id: \.self) { index in
                                Text("\(index + 1)")
                                    .monospaced()
                                    .tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()
                    }

                    #if os(macOS)
                    HStack(spacing: 12) {
                        KeyboardShortcutView(
                            keys: ["⌘", "C"],
                            description: "Copy",
                            keyEquivalent: "c"
                        ) {
                            if let currentGeneration = getSelectedGeneration(),
                               let image = loadImageFromiCloud(currentGeneration.id.uuidString)
                            {
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.writeObjects([image])
                                showToast(.success("Copied to clipboard"))
                            }
                        }

                        KeyboardShortcutView(
                            keys: ["⌘", "J"],
                            description: "Download",
                            keyEquivalent: "j"
                        ) {
                            if let currentGeneration = getSelectedGeneration(),
                               let image = loadImageFromiCloud(currentGeneration.id.uuidString)
                            {
                                image.saveImageToDownloads(fileName: currentGeneration.id.uuidString)
                            }
                        }

                        // Hide Edit shortcut in standalone preview windows
                        if !isPreviewWindow {
                            KeyboardShortcutView(
                                keys: ["⌘", "⌥", "E"],
                                description: "Edit",
                                keyEquivalent: "e",
                                modifiers: [.command, .option]
                            ) {
                                showEditConfirmation = true
                            }
                        }

                        if generationIndex > 0 {
                            KeyboardShortcutView(
                                keys: ["←"],
                                description: "Previous",
                                keyEquivalent: .leftArrow,
                                modifiers: []
                            ) {
                                generationIndex -= 1
                            }
                        }

                        if generationIndex < generations.count - 1 {
                            KeyboardShortcutView(
                                keys: ["→"],
                                description: "Next",
                                keyEquivalent: .rightArrow,
                                modifiers: []
                            ) {
                                generationIndex += 1
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    #endif
                }

                ImageReferenceMediaSection(generation: generation)

                if !generation.prompt.isEmpty {
                    Section("User Prompts") {
                        SectionKeyValueView(
                            icon: "text.quote",
                            key: "Requested Prompt",
                            value: generation.prompt,
                            multilineValue: true
                        )
                        if let negativePrompt = generation.negativePrompt, !negativePrompt.isEmpty {
                            SectionKeyValueView(
                                icon: "text.badge.minus",
                                key: "Negative Prompt",
                                value: negativePrompt,
                                multilineValue: true
                            )
                        }
                        if let searchPrompt = generation.searchPrompt, !searchPrompt.isEmpty {
                            SectionKeyValueView(
                                icon: "rectangle.and.text.magnifyingglass",
                                key: "Search Prompt",
                                value: searchPrompt,
                                multilineValue: true
                            )
                        }
                        Button {
                            showAddToPromptGallery = true
                        } label: {
                            Text("Add Prompt to Prompt Gallery")
                        }
                    }
                }

                Section("Model Response") {
                    if let provider = getProvider(modelId: generation.modelId) {
                        SectionKeyValueView(
                            icon: "link",
                            key: "Provider",
                            value: "",
                            customValueView: ProviderLabel(provider: provider)
                        )
                    }
                    if let model = ProviderService.shared.model(by: generation.modelId) {
                        SectionKeyValueView(
                            icon: "network",
                            key: "Model",
                            value: "",
                            customValueView: ModelLabel(model: model)
                        )
                    }
                    SectionKeyValueView(
                        icon: "wand.and.sparkles",
                        key: "Auto-enhance opted",
                        value: generation.promptEnhanceOpted ? "Yes" : "No"
                    )
                    if generation.promptEnhanceOpted, !generation.promptAfterEnhance.isEmpty {
                        SectionKeyValueView(
                            icon: "text.quote",
                            key: "Enhanced Prompt",
                            value: generation.promptAfterEnhance,
                            multilineValue: true
                        )
                    }
                    if let modelRevisedPrompt = generation.modelRevisedPrompt, !modelRevisedPrompt.isEmpty {
                        SectionKeyValueView(
                            icon: "text.quote",
                            key: "Response Prompt",
                            value: modelRevisedPrompt,
                            multilineValue: true
                        )
                    }
                    SectionKeyValueView(
                        icon: "dollarsign",
                        key: "Est. Incurred Cost",
                        value: "\(String(format: "%.3f", generation.creditUsed).replacingOccurrences(of: ".000", with: "")) \(getProvider(modelId: generation.modelId)?.creditCurrency.rawValue ?? "Credits")"
                    )
                }

                Section("Image Metadata") {
                    SectionKeyValueView(
                        icon: "aspectratio.fill",
                        key: "Image Dimensions",
                        value: generation.dimensions.replacingOccurrences(of: "x", with: " x "),
                        monospaced: true
                    )
                    if let requestedDimensions = generation.metadata["requested_dimensions"],
                       !requestedDimensions.isEmpty
                    {
                        SectionKeyValueView(
                            icon: "rectangle.dashed",
                            key: "Requested Dimensions",
                            value: requestedDimensions.replacingOccurrences(of: "x", with: " x "),
                            monospaced: true
                        )
                    }
                    SectionKeyValueView(
                        icon: "internaldrive.fill",
                        key: "Image Size",
                        value: String(format: "%.2f MB", Double(generation.size) / 1_000_000.0),
                        monospaced: true
                    )
                    if let resolution = generation.metadata["resolution"], !resolution.isEmpty {
                        SectionKeyValueView(
                            icon: "arrow.up.right.and.arrow.down.left.rectangle",
                            key: "Resolution",
                            value: resolution,
                            monospaced: true
                        )
                    }
                    if !generation.style.isEmpty {
                        SectionKeyValueView(icon: "paintpalette.fill", key: "Color Style", value: generation.style)
                    }
                    if !generation.variant.isEmpty {
                        SectionKeyValueView(icon: "paintbrush.fill", key: "Variant", value: generation.variant)
                    }
                    if !generation.quality.isEmpty {
                        SectionKeyValueView(
                            icon: "photo",
                            key: "Image Quality",
                            value: generation.quality,
                            monospaced: true
                        )
                    }
                    if let background = generation.metadata["background"], !background.isEmpty {
                        SectionKeyValueView(
                            icon: "square.on.square",
                            key: "Background",
                            value: background
                        )
                    }
                }

                ImageGenerationSettingsSection(generation: generation)

                Section("System Information") {
                    SectionKeyValueView(icon: "calendar", key: "Created", value: generation.createdAt.formatted(
                        date: .abbreviated,
                        time: .shortened
                    ))
                    SectionKeyValueView(
                        icon: "doc.text",
                        key: "Content Type",
                        value: generation.contentType.rawValue.replacingOccurrences(of: "_", with: " ")
                    )
                    SectionKeyValueView(
                        icon: "number",
                        key: "Generation ID",
                        value: generation.id.uuidString,
                        monospaced: true
                    )
                }

                ImageAdditionalMetadataSection(metadata: generation.metadata)
                Section("Notice something wrong?") {
                    HStack {
                        Text("Send an email")
                        Spacer()
                        Link("Submit Feedback", destination: getFeedbackLink())
                    }
                }
            } else if imageSet == nil {
                Section("Image Details") {
                    Text("Loading...")
                }
                .onAppear {
                    loadData()
                }
            }
        }
        .formStyle(.grouped)
        .toolbar {
            if let generation = selectedGeneration {
                ToolbarItem(placement: .automatic) {
                    Button("Download", systemImage: "arrow.down") {
                        let image = loadImageFromiCloud("\(generation.id.uuidString)")
                        if let image {
                            #if os(macOS)
                            image.saveImageToDownloads(fileName: generation.id.uuidString)
                            #else
                            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                                DispatchQueue.main.async {
                                    if status == .authorized || status == .limited {
                                        PHPhotoLibrary.shared().performChanges({
                                            PHAssetChangeRequest.creationRequestForAsset(from: image)
                                        }) { success, error in
                                            DispatchQueue.main.async {
                                                if success {
                                                    showSaveSuccess = true
                                                } else {
                                                    saveErrorMessage = error?
                                                        .localizedDescription ?? "Failed to save image"
                                                    showSaveError = true
                                                }
                                            }
                                        }
                                    } else {
                                        saveErrorMessage =
                                            "Photo library access denied. Please enable access in Settings."
                                        showSaveError = true
                                    }
                                }
                            }
                            #endif
                        }
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button("Share", systemImage: "square.and.arrow.up") {
                        let image = loadImageFromiCloud("\(generation.id.uuidString)")
                        if let image {
                            #if os(macOS)
                            image.shareImage()
                            #else
                            exportImage = IdentifiableImage(image: image)
                            #endif
                        }
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }
            }
        }
        #if !os(macOS)
        .sheet(item: $exportImage) { item in
            ImageShareSheet(activityItems: [item.image])
        }
        .alert("Saved to Photos", isPresented: $showSaveSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Image has been saved to your photo library.")
        }
        .alert("Save Failed", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
        #endif
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Confirm Deletion"),
                message: Text("Are you sure you want to delete this image set?"),
                primaryButton: .destructive(Text("Delete")) {
                    Task {
                        await deleteImageSet()
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .navigationTitle(labelForItem(.generationImage(setId: setId)))
        #if os(macOS)
        .sheet(item: $expandedGenerationId) { genId in
            ExpandedImageView(
                imageName: genId.uuidString,
                isPresented: Binding(
                    get: { expandedGenerationId != nil },
                    set: { if !$0 { expandedGenerationId = nil } }
                )
            )
        }
        .sheet(item: $compareGenerationId) { genId in
            CompareImagesView(
                leftImageName: ".\(genId.uuidString)_client",
                rightImageName: genId.uuidString,
                leftLabel: "Request Image",
                rightLabel: "Generated Image",
                maskImageName: ".\(genId.uuidString)_mask",
                isPresented: Binding(
                    get: { compareGenerationId != nil },
                    set: { if !$0 { compareGenerationId = nil } }
                )
            )
        }
        .alert("Edit Image", isPresented: $showEditConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Continue") {
                if let currentGeneration = getSelectedGeneration(),
                   let image = loadImageFromiCloud(currentGeneration.id.uuidString)
                {
                    let preload = GenerateImagePreload(
                        image: image,
                        colorPalette: currentGeneration.colorPalette,
                        dimensions: currentGeneration.dimensions,
                        prompt: currentGeneration.prompt.isEmpty ? nil : currentGeneration.prompt,
                        negativePrompt: currentGeneration.negativePrompt
                    )
                    navigationManager.navigateToGenerateImage(with: preload)
                }
            }
        } message: {
            Text(
                "The image will be added as a reference image for a new image generation. You can update the prompt and model supported configs in the upcoming window."
            )
        }
        #else
        .fullScreenCover(item: $expandedGenerationId) { genId in
            ExpandedImageView(
                imageName: genId.uuidString,
                isPresented: Binding(
                    get: { expandedGenerationId != nil },
                    set: { if !$0 { expandedGenerationId = nil } }
                )
            )
        }
        #endif
        .sheet(isPresented: $showAddToPromptGallery) {
            if let generation = selectedGeneration {
                PromptGalleryEditSheet(
                    mode: .create,
                    onSave: { title, prompt, tags in
                        let item = PromptGalleryItem(
                            projectId: generation.projectId,
                            title: title,
                            prompt: prompt,
                            tags: tags
                        )
                        modelContext.insert(item)
                    },
                    prefillPrompt: generation.prompt,
                    prefillTags: autoTags(for: generation)
                )
            }
        }
    }

    private func autoTags(for generation: Generation) -> [String] {
        var tags: [String] = []
        if let model = ProviderService.shared.model(by: generation.modelId) {
            tags.append(model.modelName.lowercased())
        }
        if let provider = getProvider(modelId: generation.modelId) {
            tags.append(provider.providerCode.rawValue.lowercased())
        }
        tags.append(generation.contentType == .VIDEO ? "video" : "image")
        if generation.promptEnhanceOpted {
            tags.append("enhanced")
        }
        return tags
    }

    private func loadData() {
        // Try cache first for faster lookup
        let cache = GalleryCache.shared
        if cache.isLoaded {
            if let cachedSet = cache.imageSets.first(where: { $0.id == setId }) {
                imageSet = cachedSet
                generations = cache.imageGenerations.filter { $0.setId == setId }
                    .sorted { $0.createdAt > $1.createdAt }
                if !generations.isEmpty {
                    return
                }
            }
        }

        // Fallback to database fetch
        let imageSetDescriptor = FetchDescriptor<ImageSet>(predicate: #Predicate { $0.id == setId })
        let generationsDescriptor = FetchDescriptor<Generation>(
            predicate: #Predicate { $0.setId == setId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            imageSet = try modelContext.fetch(imageSetDescriptor).first
            generations = try modelContext.fetch(generationsDescriptor)
        } catch {
            AppLogger.data.error("Error fetching data: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private struct GenerationImageSection: View {
    let generation: Generation
    @Binding var showDeleteConfirmation: Bool
    @Binding var expandedGenerationId: UUID?
    @Binding var compareGenerationId: UUID?

    private var imageId: String {
        generation.id.uuidString
    }

    private var displayImageName: String {
        imageId
    }

    private var generationAspectRatio: CGFloat {
        let trimmed = generation.dimensions.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard parts.count == 2,
                  let w = Double(parts[0]),
                  let h = Double(parts[1]),
                  w > 0, h > 0
            else {
                return 1.0
            }
            return CGFloat(w / h)
        }

        let parts = trimmed
            .lowercased()
            .split(separator: "x")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        guard parts.count == 2,
              let w = Double(parts[0]),
              let h = Double(parts[1]),
              w > 0, h > 0
        else {
            return 1.0
        }
        return CGFloat(w / h)
    }

    #if os(macOS)
    private let maxPreviewHeight: CGFloat = 400
    #endif

    var body: some View {
        ZStack {
            SmoothAnimatedGradientView(colors: generation.colorPalette.compactMap { hex in
                Color(getUniversalColorFromHex(hexString: hex))
            })

            generatedImageView
                .padding(.vertical, 8)
        }
    }

    #if os(macOS)
    /// Whether we have a client image (source image)
    private var hasClientImage: Bool {
        generation.hasClientImage
    }
    #endif

    @ViewBuilder
    private var generatedImageView: some View {
        ZStack {
            ICloudImageLoader(imageName: displayImageName) { image in
                if let image {
                    VStack(spacing: 16) {
                        #if os(macOS)
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.4), radius: 8)
                            .overlay(alignment: .topTrailing) {
                                imageOverlayButtons
                            }
                            .frame(maxWidth: .infinity)
                            .onCopyCommand {
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.writeObjects([image])
                                showToast(.success("Copied to clipboard"))
                                return [NSItemProvider(object: image)]
                            }
                            .contextMenu {
                                Button("View image", systemImage: "eye") {
                                    expandedGenerationId = generation.id
                                }
                                if hasClientImage {
                                    Button("Compare", systemImage: "rectangle.split.2x1") {
                                        compareGenerationId = generation.id
                                    }
                                }
                                Divider()
                                Button("Copy image", systemImage: "doc.on.doc") {
                                    let pasteboard = NSPasteboard.general
                                    pasteboard.clearContents()
                                    pasteboard.writeObjects([image])
                                    showToast(.success("Copied to clipboard"))
                                }
                                Button("Download image", systemImage: "arrow.down") {
                                    image.saveImageToDownloads(fileName: imageId)
                                }
                                Button("Share image", systemImage: "square.and.arrow.up") {
                                    image.shareImage()
                                }
                                Divider()
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    showDeleteConfirmation = true
                                }
                            }
                        #else
                        Image(uiImage: image)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(alignment: .topTrailing) {
                                expandButton
                            }
                        #endif
                    }
                } else if !ImageCache.shared.isFailedAttempt(forKey: displayImageName) {
                    EmptyView()
                } else {
                    Text("Failed to load")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .id("image_\(imageId)")
        }
        .frame(maxWidth: .infinity)
        #if os(macOS)
        .frame(maxHeight: maxPreviewHeight)
        #endif
    }

    #if os(macOS)
    private var imageOverlayButtons: some View {
        HStack(spacing: 6) {
            if hasClientImage {
                Button {
                    compareGenerationId = generation.id
                } label: {
                    Image(systemName: "rectangle.split.2x1")
                        .font(.callout)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.5))
                        )
                }
                .buttonStyle(.plain)
            }

            Button {
                expandedGenerationId = generation.id
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.5))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(8)
    }
    #endif

    private var expandButton: some View {
        Button {
            expandedGenerationId = generation.id
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.callout)
                .foregroundStyle(.white)
                .padding(8)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.5))
                )
        }
        .buttonStyle(.plain)
        .padding(8)
    }
}

// MARK: - Additional Settings Section

private struct ImageGenerationSettingsSection: View {
    let generation: Generation

    private var hasGenerationSettings: Bool {
        let metadata = generation.metadata
        return metadata["seed"] != nil ||
            metadata["steps"] != nil ||
            metadata["guidance"] != nil ||
            metadata["safety_tolerance"] != nil ||
            metadata["prompt_enhance"] != nil ||
            metadata["input_fidelity"] != nil ||
            metadata["moderation"] != nil ||
            metadata["grow_mask"] != nil ||
            metadata["selected_tools"] != nil
    }

    var body: some View {
        if hasGenerationSettings {
            Section("Additional Settings") {
                if let seed = generation.metadata["seed"], !seed.isEmpty {
                    SectionKeyValueView(
                        icon: "dice.fill",
                        key: "Seed",
                        value: seed,
                        monospaced: true
                    )
                }
                if let steps = generation.metadata["steps"], let stepsValue = Int(steps) {
                    SectionKeyValueView(
                        icon: "stairs",
                        key: "Steps",
                        value: "\(stepsValue)",
                        monospaced: true
                    )
                }
                if let guidance = generation.metadata["guidance"], !guidance.isEmpty {
                    SectionKeyValueView(
                        icon: "slider.horizontal.3",
                        key: "Guidance Scale",
                        value: guidance,
                        monospaced: true
                    )
                }
                if let safetyTolerance = generation.metadata["safety_tolerance"],
                   let toleranceValue = Int(safetyTolerance)
                {
                    SectionKeyValueView(
                        icon: "shield.fill",
                        key: "Safety Tolerance",
                        value: "\(toleranceValue)",
                        monospaced: true
                    )
                }
                if let promptEnhance = generation.metadata["prompt_enhance"], !promptEnhance.isEmpty {
                    SectionKeyValueView(
                        icon: "wand.and.rays.inverse",
                        key: "Prompt Enhancement",
                        value: promptEnhance
                    )
                }
                if let inputFidelity = generation.metadata["input_fidelity"], !inputFidelity.isEmpty {
                    SectionKeyValueView(
                        icon: "target",
                        key: "Input Fidelity",
                        value: inputFidelity
                    )
                }
                if let moderation = generation.metadata["moderation"], !moderation.isEmpty {
                    SectionKeyValueView(
                        icon: "eye.fill",
                        key: "Moderation Level",
                        value: moderation
                    )
                }
                if let growMask = generation.metadata["grow_mask"], let growMaskValue = Int(growMask) {
                    SectionKeyValueView(
                        icon: "square.dashed",
                        key: "Mask Growth",
                        value: "\(growMaskValue) px",
                        monospaced: true
                    )
                }
                if let selectedTools = generation.metadata["selected_tools"], !selectedTools.isEmpty {
                    SectionKeyValueView(
                        icon: "wrench.and.screwdriver.fill",
                        key: "Tools Used",
                        value: selectedTools
                    )
                }
            }
        }
    }
}

// MARK: - Image Additional Metadata Section

private struct ImageAdditionalMetadataSection: View {
    let metadata: [String: String]

    private let displayedKeys: Set = [
        "resolution",
        "background",
        "requested_dimensions",
        "seed",
        "steps",
        "guidance",
        "safety_tolerance",
        "prompt_enhance",
        "input_fidelity",
        "moderation",
        "grow_mask",
        "selected_tools",
    ]

    private var additionalMetadata: [(key: String, value: String)] {
        metadata
            .filter { !displayedKeys.contains($0.key) && !$0.value.isEmpty }
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        if !additionalMetadata.isEmpty {
            Section("Additional Metadata") {
                ForEach(additionalMetadata, id: \.key) { key, value in
                    SectionKeyValueView(
                        icon: iconForMetadataKey(key),
                        key: formatMetadataKey(key),
                        value: value,
                        monospaced: shouldBeMonospaced(key)
                    )
                }
            }
        }
    }

    private func iconForMetadataKey(_ key: String) -> String {
        let lowercased = key.lowercased()
        if lowercased.contains("id") || lowercased.contains("uri") {
            return "link"
        } else if lowercased.contains("image") {
            return "photo.fill"
        } else if lowercased.contains("resolution") || lowercased.contains("dimension") {
            return "aspectratio.fill"
        } else {
            return "tag"
        }
    }

    private func shouldBeMonospaced(_ key: String) -> Bool {
        let lowercased = key.lowercased()
        return lowercased.contains("id") ||
            lowercased.contains("uri") ||
            lowercased.contains("seed") ||
            lowercased.contains("step")
    }
}

// MARK: - Image Reference Media Section

struct ImageReferenceMediaSection: View {
    let generation: Generation

    private var generationId: UUID {
        generation.id
    }

    private var clientImageName: String {
        ".\(generationId.uuidString)_client"
    }

    private var maskImageName: String {
        ".\(generationId.uuidString)_mask"
    }

    var body: some View {
        ICloudImageLoader(imageName: clientImageName, showLoading: false) { clientImage in
            ImageReferenceImagesLoader(generationId: generationId) { referenceImages in
                ImageReferenceMediaInnerContent(
                    generation: generation,
                    clientImage: clientImage,
                    referenceImages: referenceImages,
                    maskImageName: maskImageName
                )
            }
        }
    }
}

private struct ImageReferenceMediaInnerContent: View {
    let generation: Generation
    let clientImage: PlatformImage?
    let referenceImages: [PlatformImage]
    let maskImageName: String

    @State private var maskImage: PlatformImage? = nil
    @State private var hasMaskLoaded = false
    @State private var showMask = false

    private var hasAnyMedia: Bool {
        clientImage != nil || !referenceImages.isEmpty
    }

    var body: some View {
        if hasAnyMedia {
            Section("Reference Media") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        if let clientImage {
                            ImageReferenceMediaItem(
                                image: clientImage,
                                label: "Source Image",
                                maskImage: showMask ? maskImage : nil,
                                hasMask: maskImage != nil,
                                showMask: $showMask
                            )
                            .onAppear {
                                if generation.hasClientMask, !hasMaskLoaded {
                                    hasMaskLoaded = true
                                    DispatchQueue.global(qos: .background).async {
                                        let loaded = loadImageFromiCloud(maskImageName)
                                        DispatchQueue.main.async {
                                            maskImage = loaded
                                        }
                                    }
                                }
                            }
                        }

                        ForEach(Array(referenceImages.enumerated()), id: \.offset) { index, image in
                            ImageReferenceMediaItem(
                                image: image,
                                label: referenceImages.count == 1 ? "Reference Image" : "Reference \(index + 1)",
                                maskImage: nil,
                                hasMask: false,
                                showMask: .constant(false)
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

private struct ImageReferenceImagesLoader<Content: View>: View {
    let generationId: UUID
    let content: ([PlatformImage]) -> Content

    @State private var referenceImages: [PlatformImage] = []
    @State private var hasLoaded = false

    var body: some View {
        content(referenceImages)
            .task(id: generationId) {
                await loadReferenceImages()
            }
    }

    private func loadReferenceImages() async {
        let images = await Task.detached {
            var refs: [PlatformImage] = []
            for i in 0 ..< 10 {
                if let refImage = loadImageFromiCloud(".\(generationId.uuidString)_ref\(i)") {
                    refs.append(refImage)
                } else {
                    break
                }
            }
            return refs
        }.value
        await MainActor.run {
            referenceImages = images
            hasLoaded = true
        }
    }
}

private struct ImageReferenceMediaItem: View {
    let image: PlatformImage
    let label: String
    let maskImage: PlatformImage?
    let hasMask: Bool
    @Binding var showMask: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.2), radius: 4)

                if let maskImage {
                    Image(nsImage: maskImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 200, maxHeight: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .opacity(0.5)
                }
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.2), radius: 4)

                if let maskImage {
                    Image(uiImage: maskImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 200, maxHeight: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .opacity(0.5)
                }
                #endif
            }

            HStack(spacing: 8) {
                Text(label)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if hasMask {
                    Button {
                        showMask.toggle()
                    } label: {
                        Label(showMask ? "Hide Mask" : "Show Mask", systemImage: showMask ? "eye.slash" : "eye")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}
