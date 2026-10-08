// MARK: - GenerationPopoverView.swift

// Popover form for generating from playground canvas.
//
// Presents a compact generation form when:
// - Adding new image/video to canvas
// - Iterating from existing card
// - Combining multiple cards
//
// ## Form Content
// - Model selection (image or video)
// - Prompt input
// - Key parameters
// - Parent image preview (when iterating)
//
// ## Combine Mode
// When multiple parent cards selected, enables combining
// images into video or multi-reference generation.

import IllustrateProviders
import SwiftData
import SwiftUI

private let totalInputBoundedImageModels: Set<EnumProviderModelCode> = [
    .BRIA_FIBO,
    .RUNWAY_GEN_4_IMAGE_TURBO,
    .VERTEX_GEMINI_3_1_FLASH_IMAGE,
    .XAI_GROK_IMAGINE_IMAGE,
    .XAI_GROK_IMAGINE_IMAGE_QUALITY,
]

private func supportsPlaygroundParentInputs(_ model: ProviderModel, count: Int) -> Bool {
    guard count > 0 else { return true }
    let params = model.modelParams
    let supportsAsSource = params.supportsSourceImage && count == 1
    let supportsAsReferences = params.supportsReferenceImages && params.maxReferenceImages >= count

    if totalInputBoundedImageModels.contains(model.modelCode) {
        let supportsSourcePlusReferences = params.supportsSourceImage &&
            params.supportsReferenceImages &&
            params.maxReferenceImages >= count
        return supportsAsSource || supportsAsReferences || supportsSourcePlusReferences
    }

    let supportsSourcePlusReferences = params.supportsSourceImage &&
        params.supportsReferenceImages &&
        params.maxReferenceImages >= (count - 1)
    return supportsAsSource || supportsAsReferences || supportsSourcePlusReferences
}

/// Compact generation form for playground canvas.
struct GenerationPopoverView: View {
    @Binding var isPresented: Bool
    let generationType: PlaygroundCardType
    let position: CGPoint
    let parentCard: PlaygroundCard?
    let parentCards: [PlaygroundCard]
    let isCombineToVideo: Bool
    let providerKeys: [ProviderKey]
    let onGenerate: (PlaygroundCardType, CGPoint, Any) -> Void

    @StateObject private var imageViewModel = AgentCardViewModel()
    @StateObject private var videoViewModel = AgentVideoCardViewModel()

    @State private var parentImage: PlatformImage?
    @State private var parentImages: [UUID: PlatformImage] = [:]
    @State private var isLoadingParentImage = false

    private var selectedImageModel: ProviderModel? {
        imageViewModel.getSelectedModel()
    }

    private var selectedVideoModel: ProviderModel? {
        videoViewModel.getSelectedModel()
    }

    /// All reference cards (combining single parentCard with parentCards array)
    private var allReferenceCards: [PlaygroundCard] {
        if let single = parentCard {
            return [single] + parentCards
        }
        return parentCards
    }

    /// When editing from parent images, filter to models that support source/reference images
    private var requiresSourceImageSupport: Bool {
        !allReferenceCards.isEmpty
    }

    /// Number of reference images from parent cards
    private var referenceImageCount: Int {
        allReferenceCards.count
    }

    /// Whether the user can add more reference images beyond the parent cards
    private var canAddMoreReferenceImages: Bool {
        additionalReferenceSlots > 0
    }

    /// How many additional reference images can be added
    private var additionalReferenceSlots: Int {
        guard let model = selectedImageModel else { return 0 }
        let maxRefs = model.modelParams.maxReferenceImages
        if totalInputBoundedImageModels.contains(model.modelCode) {
            return max(0, maxRefs - referenceImageCount)
        }
        let usedAsSource = model.modelParams.supportsSourceImage && referenceImageCount > 0 ? 1 : 0
        let refsFromParents = referenceImageCount - usedAsSource
        return max(0, maxRefs - refsFromParents)
    }

    // MARK: - Filtered Providers (with source/reference image support filtering)

    private var filteredImageProviders: [Provider] {
        let baseProviders = imageViewModel.getSupportedProviders(providerKeys: providerKeys)
        guard requiresSourceImageSupport else { return baseProviders }

        let imageModels = ProviderService.shared.models(for: .IMAGE_GENERATE)
        return baseProviders.filter { provider in
            imageModels.contains { model in
                guard model.providerId == provider.providerId else { return false }
                return supportsPlaygroundParentInputs(model, count: referenceImageCount)
            }
        }
    }

    private var filteredVideoProviders: [Provider] {
        let baseProviders = videoViewModel.getSupportedProviders(providerKeys: providerKeys)
        guard requiresSourceImageSupport else { return baseProviders }

        let videoModels = ProviderService.shared.models(for: .VIDEO_GENERATE)
        if isCombineToVideo {
            return baseProviders.filter { provider in
                videoModels.contains { model in
                    model.providerId == provider.providerId &&
                        model.modelParams.supportsSourceImage &&
                        model.modelParams.supportsLastFrame
                }
            }
        }

        return baseProviders.filter { provider in
            videoModels.contains { model in
                model.providerId == provider.providerId &&
                    model.modelParams.supportsSourceImage
            }
        }
    }

    // MARK: - Filtered Models (with source image support filtering)

    private var filteredImageModels: [ProviderModel] {
        let baseModels = imageViewModel.getSupportedModels()
        guard requiresSourceImageSupport else { return baseModels }

        // Filter to models that can handle our reference image count
        return baseModels.filter { supportsPlaygroundParentInputs($0, count: referenceImageCount) }
    }

    private var filteredVideoModels: [ProviderModel] {
        let baseModels = videoViewModel.getSupportedModels()
        guard requiresSourceImageSupport else { return baseModels }

        // For "Combine to Video", filter to models that support both source image and last frame
        if isCombineToVideo {
            return baseModels.filter { $0.modelParams.supportsSourceImage && $0.modelParams.supportsLastFrame }
        }

        return baseModels.filter(\.modelParams.supportsSourceImage)
    }

    private var canGenerate: Bool {
        if generationType == .IMAGE {
            guard !imageViewModel.selectedProviderId.isEmpty,
                  !imageViewModel.selectedModelId.isEmpty,
                  !imageViewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let model = selectedImageModel,
                  supportsPlaygroundParentInputs(model, count: referenceImageCount)
            else {
                return false
            }

            if totalInputBoundedImageModels.contains(model.modelCode) {
                return referenceImageCount + imageViewModel.referenceImages.count <=
                    model.modelParams.maxReferenceImages
            }
            return imageViewModel.referenceImages.count <= additionalReferenceSlots
        } else {
            return !videoViewModel.selectedProviderId.isEmpty &&
                !videoViewModel.selectedModelId.isEmpty &&
                !videoViewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var popoverTitle: String {
        if generationType == .VIDEO {
            if isCombineToVideo, allReferenceCards.count == 2 {
                return "Combine to Video"
            }
            if !allReferenceCards.isEmpty {
                return "Create Video from Image"
            }
            return "Generate Video"
        }

        // Image generation
        if allReferenceCards.count > 1 {
            return "Fuse Images"
        }
        if !allReferenceCards.isEmpty {
            return "Edit Image"
        }
        return "Generate Image"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if generationType == .IMAGE {
                        imageGenerationForm
                    } else {
                        videoGenerationForm
                    }
                }
                .padding(20)
            }
            .frame(maxHeight: 500)
            .navigationTitle(popoverTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        submitGeneration()
                    }
                    .disabled(!canGenerate)
                }
            }
        }
        .frame(width: 420)
        .onAppear {
            initializeViewModels()
            loadParentImageIfNeeded()
        }
        .imageSelection(
            id: "playgroundGenPopover",
            isPickerOpen: $imageViewModel.isImagePickerOpen,
            onImageSelected: { imageViewModel.addReferenceImage(image: $0) }
        )
    }

    // MARK: - Image Generation Form

    @ViewBuilder
    private var imageGenerationForm: some View {
        // Provider selection
        CardDropdownPicker(
            label: "Provider",
            selection: $imageViewModel.selectedProviderId,
            options: filteredImageProviders.map(\.providerId.uuidString),
            displayName: { id in
                UUID(uuidString: id).flatMap { providersById[$0]?.providerName } ?? "Select Provider"
            },
            iconName: { id in
                guard let provider = UUID(uuidString: id).flatMap({ providersById[$0] }) else { return "" }
                return providerArtworkName(code: provider.providerCode, variant: .square)
            },
            placeholder: "Select Provider",
            emptyOption: "",
            onChange: { handleImageProviderChange() }
        )

        // Model selection
        if !imageViewModel.selectedProviderId.isEmpty {
            CardDropdownPicker(
                label: "Model",
                selection: $imageViewModel.selectedModelId,
                options: filteredImageModels.map(\.modelId.uuidString),
                displayName: { id in
                    filteredImageModels.first { $0.modelId.uuidString == id }?.modelName ?? "Select Model"
                },
                placeholder: "Select Model",
                emptyOption: "",
                onChange: { imageViewModel.handleModelChange() }
            )
        }

        // Prompt
        CardPromptField(
            label: "Prompt",
            text: $imageViewModel.prompt
        )

        // Search prompt
        if selectedImageModel?.modelParams.supportsSearchPrompt == true {
            CardPromptField(
                label: "Search Prompt",
                text: $imageViewModel.searchPrompt,
                minHeight: 40,
                maxHeight: 60
            )
        }

        // Negative prompt
        if selectedImageModel?.modelParams.supportsNegativePrompt == true {
            CardPromptField(
                label: "Negative Prompt",
                text: $imageViewModel.negativePrompt,
                minHeight: 40,
                maxHeight: 60
            )
        }

        // Reference images from parent cards
        if !allReferenceCards.isEmpty {
            parentReferenceImagesSection

            // Additional reference images picker (if model supports more)
            if canAddMoreReferenceImages {
                additionalReferenceImagesSection
            }
        }
        // Reference images for new generation (no parent cards)
        else if imageViewModel.supportsReferenceImages() {
            referenceImagesSection
        }

        // Tools section
        if selectedImageModel?.modelParams.supportsTools == true {
            let tools = imageViewModel.supportedTools()
            if !tools.isEmpty {
                CardToolsPicker(
                    label: "Available Tools",
                    selection: $imageViewModel.selectedTools,
                    tools: tools
                )
            }
        }

        // Dimensions
        if let dimensions = selectedImageModel?.modelParams.effectiveDimensions, !dimensions.isEmpty {
            CardStringDropdown(
                label: "Dimensions",
                selection: $imageViewModel.dimensions,
                options: dimensions,
                capitalize: false
            )
        }

        // Quality
        if let qualities = selectedImageModel?.modelParams.supportedImageQualities, !qualities.isEmpty {
            CardSegmentedPicker(label: "Quality", selection: $imageViewModel.quality, options: qualities)
        }

        // Input Fidelity
        if selectedImageModel?.modelParams.supportsInputFidelity == true {
            let fidelities = selectedImageModel?.modelParams.supportedInputFidelities ?? []
            if !fidelities.isEmpty {
                CardStringDropdown(
                    label: "Input Fidelity",
                    selection: $imageViewModel.inputFidelity,
                    options: fidelities
                )
            }
        }

        // Moderation
        if selectedImageModel?.modelParams.supportsModeration == true {
            let moderations = selectedImageModel?.modelParams.supportedModerations ?? []
            if !moderations.isEmpty {
                CardStringDropdown(label: "Moderation", selection: $imageViewModel.moderation, options: moderations)
            }
        }

        // Resolution
        if selectedImageModel?.modelParams.supportsImageResolution == true {
            let resolutions = selectedImageModel?.modelParams.supportedImageResolutions ?? []
            if !resolutions.isEmpty {
                CardStringDropdown(
                    label: "Resolution",
                    selection: $imageViewModel.selectedResolution,
                    options: resolutions,
                    capitalize: false
                )
            }
        }

        // Steps
        if let stepsRange = selectedImageModel?.modelParams.supportedStepsRange {
            CardSlider(
                label: "Steps",
                value: $imageViewModel.stepsValue,
                range: Double(stepsRange.min) ... Double(stepsRange.max),
                step: 1
            )
        }

        // Guidance scale
        if let guidanceRange = selectedImageModel?.modelParams.supportedGuidanceRange {
            CardSlider(
                label: "Guidance Scale",
                value: $imageViewModel.guidanceValue,
                range: guidanceRange.min ... guidanceRange.max,
                step: 0.1,
                valueFormatter: { String(format: "%.1f", $0) }
            )
        }

        // Safety Tolerance
        if let safetyRange = selectedImageModel?.modelParams.supportedSafetyRange {
            CardSlider(
                label: "Safety Tolerance",
                value: $imageViewModel.safetyValue,
                range: Double(safetyRange.min) ... Double(safetyRange.max)
            )
        }

        // Grow Mask
        if let growMaskRange = selectedImageModel?.modelParams.supportedGrowMaskRange {
            CardSlider(
                label: "Grow Mask",
                value: $imageViewModel.growMaskValue,
                range: Double(growMaskRange.min) ... Double(growMaskRange.max)
            )
        }

        // Seed
        if selectedImageModel?.modelParams.supportsSeed == true {
            CardSeedField(label: "Seed", value: $imageViewModel.seedValue)
        }

        // Prompt enhance
        if selectedImageModel?.modelParams.supportsPromptEnhance == true {
            CardToggle(label: "Enhance Prompt", isOn: $imageViewModel.modelPromptEnhance)
        }

        // Person Generation
        if selectedImageModel?.modelParams.supportsPersonGeneration == true {
            let options = selectedImageModel?.modelParams.supportedPersonGenerationOptions ?? []
            if !options.isEmpty {
                CardStringDropdown(
                    label: "Person Generation",
                    selection: $imageViewModel.personGeneration,
                    options: options
                )
            }
        }

        // Style
        if let styles = selectedImageModel?.modelParams.supportedStyles, !styles.isEmpty {
            CardStringDropdown(label: "Style", selection: $imageViewModel.style, options: styles)
        }

        // Variant
        if let variants = selectedImageModel?.modelParams.supportedVariants, !variants.isEmpty {
            CardStringDropdown(label: "Variant", selection: $imageViewModel.variant, options: variants)
        }
    }

    // MARK: - Video Generation Form

    @ViewBuilder
    private var videoGenerationForm: some View {
        // Provider selection
        CardDropdownPicker(
            label: "Provider",
            selection: $videoViewModel.selectedProviderId,
            options: filteredVideoProviders.map(\.providerId.uuidString),
            displayName: { id in
                UUID(uuidString: id).flatMap { providersById[$0]?.providerName } ?? "Select Provider"
            },
            iconName: { id in
                guard let provider = UUID(uuidString: id).flatMap({ providersById[$0] }) else { return "" }
                return providerArtworkName(code: provider.providerCode, variant: .square)
            },
            placeholder: "Select Provider",
            emptyOption: "",
            onChange: { handleVideoProviderChange() }
        )

        // Model selection
        if !videoViewModel.selectedProviderId.isEmpty {
            CardDropdownPicker(
                label: "Model",
                selection: $videoViewModel.selectedModelId,
                options: filteredVideoModels.map(\.modelId.uuidString),
                displayName: { id in
                    filteredVideoModels.first { $0.modelId.uuidString == id }?.modelName ?? "Select Model"
                },
                placeholder: "Select Model",
                emptyOption: "",
                onChange: { videoViewModel.handleModelChange() }
            )
        }

        // Prompt
        CardPromptField(
            label: "Prompt",
            text: $videoViewModel.prompt
        )

        // Negative prompt
        if selectedVideoModel?.modelParams.supportsNegativePrompt == true {
            CardPromptField(
                label: "Negative Prompt",
                text: $videoViewModel.negativePrompt,
                minHeight: 40,
                maxHeight: 60
            )
        }

        // Combine to video (first and last frame)
        if isCombineToVideo, allReferenceCards.count == 2 {
            combineToVideoSection
        }
        // Single parent image as source (for image-to-video flow)
        else if !allReferenceCards.isEmpty, videoViewModel.supportsSourceImage() {
            videoSourceImageSection
        }

        // Tools section
        if selectedVideoModel?.modelParams.supportsTools == true {
            let tools = videoViewModel.supportedTools()
            if !tools.isEmpty {
                CardToolsPicker(
                    label: "Available Tools",
                    selection: $videoViewModel.selectedTools,
                    tools: tools
                )
            }
        }

        // Dimensions
        if let dimensions = selectedVideoModel?.modelParams.effectiveDimensions, !dimensions.isEmpty {
            CardStringDropdown(
                label: "Dimensions",
                selection: $videoViewModel.dimensions,
                options: dimensions,
                capitalize: false
            )
        }

        // Duration
        let durations = videoViewModel.supportedVideoDurations()
        if !durations.isEmpty {
            CardIntDropdown(
                label: "Duration (seconds)",
                selection: $videoViewModel.durationSeconds,
                options: durations
            )
        }

        // Resolution
        let resolutions = videoViewModel.supportedVideoResolutions()
        if !resolutions.isEmpty {
            CardStringDropdown(
                label: "Resolution",
                selection: $videoViewModel.selectedResolution,
                options: resolutions,
                capitalize: false
            )
        }

        // FPS
        let fpsOptions = videoViewModel.supportedVideoFPS()
        if !fpsOptions.isEmpty {
            CardIntDropdown(
                label: "FPS",
                selection: $videoViewModel.selectedFPS,
                options: fpsOptions
            )
        }

        // Audio
        if videoViewModel.supportsAudio() {
            CardToggle(label: "Generate Audio", isOn: $videoViewModel.generateAudio)
        }

        // Guidance scale
        if let guidanceRange = selectedVideoModel?.modelParams.supportedGuidanceRange {
            CardSlider(
                label: "Guidance Scale",
                value: $videoViewModel.guidanceValue,
                range: guidanceRange.min ... guidanceRange.max,
                step: 0.1,
                valueFormatter: { String(format: "%.1f", $0) }
            )
        }

        // Safety Tolerance
        if let safetyRange = selectedVideoModel?.modelParams.supportedSafetyRange {
            CardSlider(
                label: "Safety Tolerance",
                value: $videoViewModel.safetyValue,
                range: Double(safetyRange.min) ... Double(safetyRange.max)
            )
        }

        // Seed
        if selectedVideoModel?.modelParams.supportsSeed == true {
            CardSeedField(label: "Seed", value: $videoViewModel.seedValue)
        }

        // Prompt enhance
        if selectedVideoModel?.modelParams.supportsPromptEnhance == true {
            CardToggle(label: "Enhance Prompt", isOn: $videoViewModel.modelPromptEnhance)
        }
    }

    // MARK: - Parent Reference Images Section

    private var parentReferenceImagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CardSectionLabel(text: "Reference Images")
                Spacer()
                Text("\(referenceImageCount) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isLoadingParentImage {
                HStack(spacing: 8) {
                    GradientSpinner()
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allReferenceCards, id: \.id) { card in
                            if let image = parentImages[card.id] ?? (card.id == parentCard?.id ? parentImage : nil) {
                                #if os(macOS)
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                #else
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                #endif
                            }
                        }
                    }
                }

                // Explain how images will be used
                if let model = selectedImageModel {
                    let usesSource = model.modelParams.supportsSourceImage
                    let usesRefs = model.modelParams.supportsReferenceImages

                    if usesSource, usesRefs, referenceImageCount > 1 {
                        Text("First image as source, rest as style references")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if usesSource {
                        Text("Will be used as source image for editing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if usesRefs {
                        Text("Will be used as style references")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Additional Reference Images Section

    private var additionalReferenceImagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CardSectionLabel(text: "Additional References")
                Spacer()
                Text("\(imageViewModel.referenceImages.count)/\(additionalReferenceSlots) slots")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            CardReferenceImagesGrid(
                images: imageViewModel.referenceImages,
                getImage: { $0.image },
                getReferenceType: { $0.referenceType },
                supportedTypes: imageViewModel.supportedReferenceTypes(),
                onTypeChange: { id, type in imageViewModel.updateReferenceImageType(id: id, newType: type) },
                onDelete: { imageViewModel.removeReferenceImage(id: $0) },
                canAddMore: imageViewModel.referenceImages.count < additionalReferenceSlots,
                onAdd: { imageViewModel.isImagePickerOpen = true },
                onImageDropped: { imageViewModel.addReferenceImage(image: $0) }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Video Source Image Section

    private var videoSourceImageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardSectionLabel(text: "First Frame")

            if isLoadingParentImage {
                HStack(spacing: 8) {
                    GradientSpinner()
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let firstCard = allReferenceCards.first,
                      let image = parentImages[firstCard.id] ?? parentImage
            {
                HStack(spacing: 8) {
                    #if os(macOS)
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    #else
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    #endif

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Source Image")
                            .font(.callout)
                            .fontWeight(.medium)
                        Text("Will be used as the first frame")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Combine to Video Section

    private var combineToVideoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardSectionLabel(text: "Source Images")

            if isLoadingParentImage {
                HStack(spacing: 8) {
                    GradientSpinner()
                    Text("Loading images...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 12) {
                    // First frame
                    if let firstCard = allReferenceCards.first,
                       let firstImage = parentImages[firstCard.id] ?? parentImage
                    {
                        VStack(spacing: 4) {
                            #if os(macOS)
                            Image(nsImage: firstImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            #else
                            Image(uiImage: firstImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            #endif
                            Text("First Frame")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Image(systemName: "arrow.right")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    // Last frame
                    if allReferenceCards.count > 1,
                       let lastCard = allReferenceCards.last,
                       let lastImage = parentImages[lastCard.id]
                    {
                        VStack(spacing: 4) {
                            #if os(macOS)
                            Image(nsImage: lastImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            #else
                            Image(uiImage: lastImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            #endif
                            Text("Last Frame")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Text("Video will be generated transitioning from the first image to the second.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Reference Images Section (for new generation without parent cards)

    private var referenceImagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CardSectionLabel(text: "Reference Images")
                Spacer()
                if imageViewModel.maxReferenceImages() > 1 {
                    Text("\(imageViewModel.referenceImages.count)/\(imageViewModel.maxReferenceImages())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            CardReferenceImagesGrid(
                images: imageViewModel.referenceImages,
                getImage: { $0.image },
                getReferenceType: { $0.referenceType },
                supportedTypes: imageViewModel.supportedReferenceTypes(),
                onTypeChange: { id, type in imageViewModel.updateReferenceImageType(id: id, newType: type) },
                onDelete: { imageViewModel.removeReferenceImage(id: $0) },
                canAddMore: imageViewModel.canAddMoreReferenceImages(),
                onAdd: { imageViewModel.isImagePickerOpen = true },
                onImageDropped: { imageViewModel.addReferenceImage(image: $0) }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func initializeViewModels() {
        if generationType == .IMAGE {
            if let firstProvider = filteredImageProviders.first {
                imageViewModel.selectedProviderId = firstProvider.providerId.uuidString
                handleImageProviderChange()
            }
        } else {
            if let firstProvider = filteredVideoProviders.first {
                videoViewModel.selectedProviderId = firstProvider.providerId.uuidString
                handleVideoProviderChange()
            }
        }

        // Enable source image usage if editing with single parent
        if parentCard != nil, parentCards.isEmpty {
            if generationType == .IMAGE {
                imageViewModel.usePreviousImageAsSourceImage = true
            } else {
                videoViewModel.usePreviousImageAsSourceImage = true
            }
        }

        // For combine to video, enable source image
        if isCombineToVideo {
            videoViewModel.usePreviousImageAsSourceImage = true
        }
    }

    private func handleImageProviderChange() {
        // Select first model that supports source image if we're editing, otherwise first model
        imageViewModel.handleProviderChange()

        if requiresSourceImageSupport {
            imageViewModel.selectedModelId = filteredImageModels.first?.modelId.uuidString ?? ""
            imageViewModel.handleModelChange()
        }
    }

    private func handleVideoProviderChange() {
        // Select first model that supports source image if we're editing, otherwise first model
        videoViewModel.handleProviderChange()

        if requiresSourceImageSupport {
            videoViewModel.selectedModelId = filteredVideoModels.first?.modelId.uuidString ?? ""
            videoViewModel.handleModelChange()
        }
    }

    private func loadParentImageIfNeeded() {
        guard !allReferenceCards.isEmpty else { return }

        isLoadingParentImage = true

        // Capture reference cards on main actor before entering detached task
        let cards = allReferenceCards

        Task.detached(priority: .userInitiated) {
            var loadedImagesDict: [UUID: PlatformImage] = [:]
            var firstImage: PlatformImage? = nil

            for card in cards {
                if let genId = card.generationId,
                   let image = loadImageFromDocumentsDirectory(withName: genId.uuidString)
                {
                    loadedImagesDict[card.id] = image
                    if firstImage == nil {
                        firstImage = image
                    }
                }
            }

            let finalSingleImage = firstImage
            let finalLoadedImages = loadedImagesDict

            await MainActor.run {
                parentImage = finalSingleImage
                parentImages = finalLoadedImages
                isLoadingParentImage = false
            }
        }
    }

    private func submitGeneration() {
        if generationType == .IMAGE {
            var config = ImageGenerationConfiguration()
            config.selectedProviderId = imageViewModel.selectedProviderId
            config.selectedModelId = imageViewModel.selectedModelId
            config.prompt = imageViewModel.prompt
            config.negativePrompt = imageViewModel.negativePrompt
            config.searchPrompt = imageViewModel.searchPrompt
            config.selectedDimensions = imageViewModel.dimensions
            config.selectedQuality = imageViewModel.quality
            config.selectedStyle = imageViewModel.style
            config.selectedVariant = imageViewModel.variant
            config.selectedInputFidelity = imageViewModel.inputFidelity
            config.selectedModeration = imageViewModel.moderation
            config.selectedResolution = imageViewModel.selectedResolution
            config.stepsValue = imageViewModel.stepsValue
            config.guidanceValue = imageViewModel.guidanceValue
            config.seedValue = imageViewModel.seedValue
            config.safetyValue = imageViewModel.safetyValue
            config.growMaskValue = imageViewModel.growMaskValue
            config.modelPromptEnhance = imageViewModel.modelPromptEnhance
            config.personGeneration = imageViewModel.personGeneration
            config.selectedTools = Array(imageViewModel.selectedTools)
            config.usePreviousImageAsReference = imageViewModel.usePreviousImageAsReference
            config.usePreviousImageAsSourceImage = imageViewModel.usePreviousImageAsSourceImage
            config.referenceImages = imageViewModel.referenceImages.map { refImage in
                ReferenceImageConfig(id: refImage.id, imagePath: "", referenceType: refImage.referenceType)
            }

            onGenerate(.IMAGE, position, config)
        } else {
            var config = VideoGenerationConfiguration()
            config.selectedProviderId = videoViewModel.selectedProviderId
            config.selectedModelId = videoViewModel.selectedModelId
            config.prompt = videoViewModel.prompt
            config.negativePrompt = videoViewModel.negativePrompt
            config.selectedDimensions = videoViewModel.dimensions
            config.selectedResolution = videoViewModel.selectedResolution
            config.durationSeconds = videoViewModel.durationSeconds
            config.selectedFPS = videoViewModel.selectedFPS
            config.generateAudio = videoViewModel.generateAudio
            config.guidanceValue = videoViewModel.guidanceValue
            config.seedValue = videoViewModel.seedValue
            config.safetyValue = videoViewModel.safetyValue
            config.modelPromptEnhance = videoViewModel.modelPromptEnhance
            config.selectedTools = Array(videoViewModel.selectedTools)
            config.usePreviousImageAsSourceImage = videoViewModel.usePreviousImageAsSourceImage

            onGenerate(.VIDEO, position, config)
        }

        isPresented = false
    }
}
