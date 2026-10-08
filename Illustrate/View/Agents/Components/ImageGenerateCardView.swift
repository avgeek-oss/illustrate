// MARK: - ImageGenerateCardView.swift

// Card view for image generation workflow steps.
//
// Displays configuration and output for image generation cards:
// - Model selection (provider and model)
// - Prompt input with {{input}} template support
// - Parameter controls (dimension, quality, style)
// - Reference/source image options
// - Output image preview when complete
//
// ## ViewModel
// Uses AgentCardViewModel to manage card configuration
// with auto-save to AgentCard.imageGenerationConfiguration.
//
// ## Previous Card Input
// Receives PreviousCardInput with image/prompt from upstream card.
// Used for {{input}} replacement and reference images.

import SwiftData
import SwiftUI

/// Card view for image generation workflow configuration.
struct ImageGenerateCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var card: AgentCard
    var isHovered = false
    var isRunning = false
    var isErrored = false
    var errorMessage: String?
    var previousInput = PreviousCardInput()
    var isLocked = false

    @EnvironmentObject private var projectManager: ProjectManager
    @ObservedObject private var providerKeysCache = ProviderKeysCache.shared
    @StateObject private var viewModel = AgentCardViewModel()
    @State private var inputImageThumbnail: PlatformImage?
    @State private var sourceImageThumbnail: PlatformImage?
    @State private var isOutputExpanded = false
    @State private var outputImage: PlatformImage?
    @State private var isLoadingOutputImage = false
    @State private var outputGeneration: Generation?

    private var providerKeys: [ProviderKey] {
        providerKeysCache.providerKeys
    }

    private func fetchOutputGeneration() {
        guard let genId = card.generationId else {
            outputGeneration = nil
            return
        }
        let descriptor = FetchDescriptor<Generation>(predicate: #Predicate { $0.id == genId })
        outputGeneration = try? modelContext.fetch(descriptor).first
    }

    private var selectedModel: ProviderModel? {
        viewModel.getSelectedModel()
    }

    private func seedInputTemplatePromptIfNeeded() {
        guard previousInput.hasText,
              viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return
        }

        viewModel.prompt = "{{input}}"
    }

    private var inputImageIdentifier: ObjectIdentifier? {
        guard let image = previousInput.image else { return nil }
        return ObjectIdentifier(image)
    }

    var body: some View {
        CardContainerView(
            isHovered: isHovered,
            isRunning: isRunning,
            isErrored: isErrored,
            errorMessage: errorMessage
        ) {
            CardHeaderView(
                title: "Image Generation",
                icon: "photo.fill",
                iconColor: label,
                hasGenerationId: card.generationId != nil
            )
        } content: {
            VStack(alignment: .leading, spacing: 16) {
                modelSelectionSection
                sourceImageSection
                promptSection
                referenceImageSection
                toolsSection
                parametersSection
            }
            .disabled(isLocked)
        } footer: {
            outputFooterView
        }
        .onAppear {
            viewModel.bind(to: card, providerKeys: providerKeys)
            seedInputTemplatePromptIfNeeded()
            if viewModel.usePreviousImageAsReference { generateInputThumbnail() }
            if viewModel.usePreviousImageAsSourceImage { generateSourceThumbnail() }
            fetchOutputGeneration()
            loadOutputImageIfNeeded()
        }
        .onChange(of: previousInput.text) { _, _ in
            seedInputTemplatePromptIfNeeded()
        }
        .onChange(of: card.generationId) { _, _ in
            fetchOutputGeneration()
            loadOutputImageIfNeeded()
        }
        .onChange(of: inputImageIdentifier) { _, _ in
            if viewModel.usePreviousImageAsReference {
                inputImageThumbnail = nil
                generateInputThumbnail()
            }
            if viewModel.usePreviousImageAsSourceImage {
                sourceImageThumbnail = nil
                generateSourceThumbnail()
            }
        }
        .imageSelection(
            id: "imageGenCardRefImage",
            isPickerOpen: $viewModel.isImagePickerOpen,
            onImageSelected: { viewModel.addReferenceImage(image: $0) }
        )
    }

    private var modelSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardDropdownPicker(
                label: "Provider",
                selection: $viewModel.selectedProviderId,
                options: viewModel.getSupportedProviders(providerKeys: providerKeys).map(\.providerId.uuidString),
                displayName: { id in
                    UUID(uuidString: id).flatMap { providersById[$0]?.providerName } ?? "Select Provider"
                },
                iconName: { id in
                    guard let provider = UUID(uuidString: id).flatMap({ providersById[$0] }) else { return "" }
                    return providerArtworkName(code: provider.providerCode, variant: .square)
                },
                placeholder: "Select Provider",
                emptyOption: "",
                onChange: { viewModel.handleProviderChange() }
            )

            if !viewModel.selectedProviderId.isEmpty {
                CardDropdownPicker(
                    label: "Model",
                    selection: $viewModel.selectedModelId,
                    options: viewModel.getSupportedModels().map(\.modelId.uuidString),
                    displayName: { id in
                        viewModel.getSupportedModels().first { $0.modelId.uuidString == id }?
                            .modelName ?? "Select Model"
                    },
                    placeholder: "Select Model",
                    emptyOption: "",
                    onChange: { viewModel.handleModelChange() }
                )
            }
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardPromptField(
                label: "Prompt",
                text: $viewModel.prompt,
                hint: "Use {{input}} for previous card input"
            )

            if selectedModel?.modelParams.supportsSearchPrompt == true {
                CardPromptField(
                    label: "Search Prompt",
                    text: $viewModel.searchPrompt,
                    minHeight: 40,
                    maxHeight: 60
                )
            }

            if selectedModel?.modelParams.supportsNegativePrompt == true {
                CardPromptField(
                    label: "Negative Prompt",
                    text: $viewModel.negativePrompt,
                    minHeight: 40,
                    maxHeight: 60
                )
            }
        }
    }

    @ViewBuilder
    private var sourceImageSection: some View {
        if viewModel.supportsSourceImage(), previousInput.canProvideImage {
            VStack(alignment: .leading, spacing: 12) {
                CardSectionLabel(text: "Source Image")

                Toggle(isOn: $viewModel.usePreviousImageAsSourceImage) {
                    Text("Use Input as Source Image").font(.callout)
                }
                #if os(macOS)
                .toggleStyle(.checkbox)
                #endif
                .onChange(of: viewModel.usePreviousImageAsSourceImage) { _, isOn in
                    if isOn { generateSourceThumbnail() }
                }

                if viewModel.usePreviousImageAsSourceImage {
                    HStack(spacing: 8) {
                        if previousInput.isImagePlaceholder {
                            CardInputPlaceholderCell(isLocked: isLocked)
                        } else if let thumbnail = sourceImageThumbnail {
                            CardInputImageCell(image: thumbnail, isLocked: isLocked)
                        } else if let image = previousInput.image {
                            CardInputImageCell(image: image, isLocked: isLocked)
                        }

                        Text("The input image will be used as the source for image editing/generation.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var referenceImageSection: some View {
        if viewModel.supportsReferenceImages() {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    CardSectionLabel(text: "Reference Images")
                    Spacer()
                    if viewModel.maxReferenceImages() > 1 {
                        let effectiveCount = viewModel.referenceImages
                            .count + (viewModel.usePreviousImageAsReference && previousInput.canProvideImage ? 1 : 0)
                        Text("\(effectiveCount)/\(viewModel.maxReferenceImages())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if previousInput.canProvideImage {
                    Toggle(isOn: $viewModel.usePreviousImageAsReference) {
                        Text("Use Input Image as Reference").font(.callout)
                    }
                    #if os(macOS)
                    .toggleStyle(.checkbox)
                    #endif
                    .onChange(of: viewModel.usePreviousImageAsReference) { _, isOn in
                        if isOn { generateInputThumbnail() }
                    }
                }

                CardReferenceImagesGrid(
                    images: viewModel.referenceImages,
                    getImage: { $0.image },
                    getReferenceType: { $0.referenceType },
                    supportedTypes: viewModel.supportedReferenceTypes(),
                    onTypeChange: { id, type in viewModel.updateReferenceImageType(id: id, newType: type) },
                    onDelete: { viewModel.removeReferenceImage(id: $0) },
                    canAddMore: viewModel.canAddMoreReferenceImages(),
                    onAdd: { viewModel.isImagePickerOpen = true },
                    inputImage: viewModel
                        .usePreviousImageAsReference ?
                        (previousInput.isImagePlaceholder ? previousInput.image : inputImageThumbnail) : nil,
                    isInputImagePlaceholder: viewModel.usePreviousImageAsReference && previousInput.isImagePlaceholder,
                    isLocked: isLocked,
                    onImageDropped: { viewModel.addReferenceImage(image: $0) }
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var toolsSection: some View {
        if selectedModel?.modelParams.supportsTools == true {
            let tools = viewModel.supportedTools()
            if !tools.isEmpty {
                CardToolsPicker(
                    label: "Available Tools",
                    selection: $viewModel.selectedTools,
                    tools: tools
                )
            }
        }
    }

    private var parametersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let dimensions = selectedModel?.modelParams.effectiveDimensions, !dimensions.isEmpty {
                CardStringDropdown(
                    label: "Dimensions",
                    selection: $viewModel.dimensions,
                    options: dimensions,
                    capitalize: false
                )
            }

            if let qualities = selectedModel?.modelParams.supportedImageQualities, !qualities.isEmpty {
                CardSegmentedPicker(label: "Quality", selection: $viewModel.quality, options: qualities)
            }

            if selectedModel?.modelParams.supportsInputFidelity == true {
                let fidelities = selectedModel?.modelParams.supportedInputFidelities ?? []
                if !fidelities.isEmpty {
                    CardStringDropdown(
                        label: "Input Fidelity",
                        selection: $viewModel.inputFidelity,
                        options: fidelities
                    )
                }
            }

            if selectedModel?.modelParams.supportsModeration == true {
                let moderations = selectedModel?.modelParams.supportedModerations ?? []
                if !moderations.isEmpty {
                    CardStringDropdown(label: "Moderation", selection: $viewModel.moderation, options: moderations)
                }
            }

            if selectedModel?.modelParams.supportsImageResolution == true {
                let resolutions = selectedModel?.modelParams.supportedImageResolutions ?? []
                if !resolutions.isEmpty {
                    CardStringDropdown(
                        label: "Resolution",
                        selection: $viewModel.selectedResolution,
                        options: resolutions,
                        capitalize: false
                    )
                }
            }

            if let stepsRange = selectedModel?.modelParams.supportedStepsRange {
                CardSlider(
                    label: "Steps",
                    value: $viewModel.stepsValue,
                    range: Double(stepsRange.min) ... Double(stepsRange.max),
                    step: 1
                )
            }

            if let guidanceRange = selectedModel?.modelParams.supportedGuidanceRange {
                CardSlider(
                    label: "Guidance Scale",
                    value: $viewModel.guidanceValue,
                    range: guidanceRange.min ... guidanceRange.max,
                    step: 0.1,
                    valueFormatter: { String(format: "%.1f", $0) }
                )
            }

            if let safetyRange = selectedModel?.modelParams.supportedSafetyRange {
                CardSlider(
                    label: "Safety Tolerance",
                    value: $viewModel.safetyValue,
                    range: Double(safetyRange.min) ... Double(safetyRange.max)
                )
            }

            if let growMaskRange = selectedModel?.modelParams.supportedGrowMaskRange {
                CardSlider(
                    label: "Grow Mask",
                    value: $viewModel.growMaskValue,
                    range: Double(growMaskRange.min) ... Double(growMaskRange.max)
                )
            }

            if selectedModel?.modelParams.supportsSeed == true {
                CardSeedField(label: "Seed", value: $viewModel.seedValue)
            }

            if selectedModel?.modelParams.supportsPromptEnhance == true {
                CardToggle(label: "Enhance Prompt", isOn: $viewModel.modelPromptEnhance)
            }

            if selectedModel?.modelParams.supportsPersonGeneration == true {
                let options = selectedModel?.modelParams.supportedPersonGenerationOptions ?? []
                if !options.isEmpty {
                    CardStringDropdown(
                        label: "Person Generation",
                        selection: $viewModel.personGeneration,
                        options: options
                    )
                }
            }

            if let styles = selectedModel?.modelParams.supportedStyles, !styles.isEmpty {
                CardStringDropdown(label: "Style", selection: $viewModel.style, options: styles)
            }

            if let variants = selectedModel?.modelParams.supportedVariants, !variants.isEmpty {
                CardStringDropdown(label: "Variant", selection: $viewModel.variant, options: variants)
            }
        }
    }

    private func generateInputThumbnail() {
        guard let inputImage = previousInput.image else { return }
        Task.detached(priority: .userInitiated) {
            let thumbnail = inputImage.resizedToFit(maxPixels: 96 * 96)
            await MainActor.run {
                inputImageThumbnail = thumbnail
            }
        }
    }

    private func generateSourceThumbnail() {
        guard let inputImage = previousInput.image else { return }
        Task.detached(priority: .userInitiated) {
            let thumbnail = inputImage.resizedToFit(maxPixels: 96 * 96)
            await MainActor.run {
                sourceImageThumbnail = thumbnail
            }
        }
    }

    private func loadOutputImageIfNeeded() {
        guard let generation = outputGeneration else {
            outputImage = nil
            return
        }

        guard outputImage == nil else { return }

        isLoadingOutputImage = true
        let genId = generation.id.uuidString

        Task.detached(priority: .background) {
            let image = loadImageFromDocumentsDirectory(withName: genId)
            await MainActor.run {
                outputImage = image
                isLoadingOutputImage = false
            }
        }
    }

    private func formatLastRun(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "<1 min"
        }
        return date.formatted(.relative(presentation: .named))
    }

    private var outputFooterView: some View {
        VStack(spacing: 0) {
            Button {
                if outputGeneration != nil {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isOutputExpanded.toggle()
                    }
                }
            } label: {
                HStack {
                    if outputGeneration != nil {
                        Image(systemName: isOutputExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                        Text("Output")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let date = outputGeneration?.createdAt {
                        Text(formatLastRun(date))
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("Not run yet")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(outputGeneration == nil)

            if isOutputExpanded, outputGeneration != nil {
                outputPreviewSection
                    .padding(.top, 10)
            }
        }
    }

    private var outputPreviewSection: some View {
        VStack(spacing: 10) {
            if isLoadingOutputImage {
                HStack {
                    Spacer()
                    GradientSpinner()
                    Spacer()
                }
                .frame(height: 150)
                .background(secondarySystemFill)
                .cornerRadius(8)
            } else if let image = outputImage {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 200)
                    .cornerRadius(8)
                #else
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 200)
                    .cornerRadius(8)
                #endif
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundStyle(.tertiary)
                        Text("Image not found")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .frame(height: 80)
                .background(secondarySystemFill)
                .cornerRadius(8)
            }
        }
    }
}
