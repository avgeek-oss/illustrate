// MARK: - ChatPromptBar.swift

// Bottom sticky prompt bar for chat threads.
//
// ChatPromptBar provides the main input interface for chat threads:
// - Text input for prompts
// - Provider/model selection
// - Settings popover for advanced options
//
// ## Layout
// The bar is designed to be sticky at the bottom of the chat area:
// - Primary: Prompt text field with send button
// - Secondary: Compact provider/model pickers
// - Gear button: Opens settings popover
//
// ## Settings Popover
// Contains model-specific parameters that are persisted to the thread.

import SwiftData
import SwiftUI

/// Bottom sticky prompt bar for submitting generation requests.
struct ChatPromptBar: View {
    let thread: ChatThread
    let providerKeys: [ProviderKey]
    let hasMessages: Bool
    let onSend: (String, ImageGenerationConfiguration, [PlatformImage]) -> Void
    @Binding var attachedImages: [PlatformImage]

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ChatPromptBarViewModel()

    @FocusState private var isPromptFocused: Bool
    @State private var promptText = ""
    @State private var showSettings = false
    @State private var showReferenceWarning = false
    @State private var showAttachments = false

    private let inputHeight: CGFloat = 44

    private var shouldUseCompactMobileLayout: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    private var modelSupportsReferences: Bool {
        viewModel.selectedModel?.modelParams.supportsReferenceImages ?? false
    }

    private var modelSupportsSourceImage: Bool {
        viewModel.selectedModel?.modelParams.supportsSourceImage ?? false
    }

    private var needsReferenceSupport: Bool {
        hasMessages && !modelSupportsReferences && !modelSupportsSourceImage
    }

    private var canSend: Bool {
        !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !viewModel.selectedProviderId.isEmpty &&
            !viewModel.selectedModelId.isEmpty &&
            !needsReferenceSupport
    }

    private var canAttemptSend: Bool {
        !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !viewModel.selectedProviderId.isEmpty &&
            !viewModel.selectedModelId.isEmpty
    }

    private var referenceWarningMessage: String {
        "Selected model doesn't support iterating on images. Choose a model that supports image editing or references to continue this thread."
    }

    var body: some View {
        VStack(spacing: 12) {
            // Prompt input row
            HStack(spacing: 12) {
                promptTextField
                sendButton
            }
            .padding(.horizontal, shouldUseCompactMobileLayout ? 16 : 0)

            // Provider/Model row
            if shouldUseCompactMobileLayout {
                ScrollView(.horizontal, showsIndicators: false) {
                    promptControls
                        .padding(.horizontal, 16)
                }
            } else {
                HStack(spacing: 12) {
                    promptControls
                    Spacer()
                }
            }
        }
        .padding(.horizontal, shouldUseCompactMobileLayout ? 0 : 16)
        .padding(.vertical, 16)
        .background(shouldUseCompactMobileLayout ? systemBackground : tertiarySystemFill)
        .onAppear {
            viewModel.initialize(thread: thread, providerKeys: providerKeys, modelContext: modelContext)
        }
        .onChange(of: thread.id) { _, _ in
            viewModel.initialize(thread: thread, providerKeys: providerKeys, modelContext: modelContext)
        }
        .onChange(of: thread.imagesPerIteration) { _, newValue in
            viewModel.imageCount = newValue
        }
    }

    private var promptControls: some View {
        HStack(spacing: 12) {
            providerPicker
            modelPicker
            if !hasMessages {
                countPicker
            }
            attachmentsButton
            settingsButton
        }
    }

    // MARK: - Prompt TextField

    private var promptTextField: some View {
        TextField("Enter your prompt...", text: $promptText, axis: .vertical)
            .textFieldStyle(.plain)
            .focused($isPromptFocused)
            .lineLimit(1 ... 4)
            .padding(12)
            .frame(minHeight: inputHeight)
            .background(secondarySystemFill)
            .cornerRadius(12)
            .onSubmit {
                if canSend {
                    submitPrompt()
                }
            }
    }

    // MARK: - Send Button

    private var sendButton: some View {
        Button {
            if needsReferenceSupport {
                showReferenceWarning = true
                return
            }

            submitPrompt()
        } label: {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: inputHeight, height: inputHeight)
                .background(canSend ? Color.accentColor : Color.secondary)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(!canAttemptSend)
        .accessibilityLabel("Send")
        .accessibilityHint(canSend ? "Sends the message" : "Enter a prompt first")
        #if os(iOS)
        .alert("Model Incompatible", isPresented: $showReferenceWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(referenceWarningMessage)
        }
        #else
        .onHover { hovering in
            if needsReferenceSupport {
                showReferenceWarning = hovering
            }
        }
        .popover(isPresented: $showReferenceWarning, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Model Incompatible", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text(referenceWarningMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(width: 280)
        }
        #endif
    }

    // MARK: - Provider Picker

    private var providerPicker: some View {
        Menu {
            ForEach(viewModel.supportedProviders, id: \.providerId) { provider in
                Button(provider.providerName) {
                    viewModel.selectedProviderId = provider.providerId.uuidString
                    viewModel.handleProviderChange()
                    viewModel.saveToThread()
                }
            }
        } label: {
            HStack(spacing: 6) {
                if !viewModel.selectedProviderId.isEmpty,
                   let provider = UUID(uuidString: viewModel.selectedProviderId).flatMap({ providersById[$0] })
                {
                    Image(providerArtworkName(code: provider.providerCode, variant: .square))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                    Text(provider.providerName)
                        .font(.callout)
                        .lineLimit(1)
                } else {
                    Text("Provider")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(secondarySystemFill)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Model Picker

    private var modelPicker: some View {
        Menu {
            ForEach(viewModel.supportedModels, id: \.modelId) { model in
                Button(model.modelName) {
                    viewModel.selectedModelId = model.modelId.uuidString
                    viewModel.handleModelChange()
                    viewModel.saveToThread()
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let model = viewModel.selectedModel {
                    Text(model.modelName)
                        .font(.callout)
                        .lineLimit(1)
                } else {
                    Text("Model")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(secondarySystemFill)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.selectedProviderId.isEmpty)
    }

    // MARK: - Count Picker

    /// Only shown before the first message is sent
    private var countPicker: some View {
        Menu {
            ForEach(1 ... 4, id: \.self) { count in
                Button("\(count) image\(count > 1 ? "s" : "")") {
                    viewModel.imageCount = count
                    thread.imagesPerIteration = count
                    try? modelContext.save()
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "photo")
                    .font(.caption)
                Text("\(viewModel.imageCount)")
                    .font(.callout)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(secondarySystemFill)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .help("Number of images per prompt")
    }

    // MARK: - Attachments Button

    private var attachmentsButton: some View {
        Button {
            showAttachments.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "paperclip")
                    .font(.system(size: 14))
                if !attachedImages.isEmpty {
                    Text("\(attachedImages.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .foregroundStyle(attachedImages.isEmpty ? .secondary : Color.accentColor)
            .frame(height: 32)
            .padding(.horizontal, attachedImages.isEmpty ? 10 : 8)
            .background(secondarySystemFill)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Attachments")
        .accessibilityHint(attachedImages
            .isEmpty ? "No attachments" : "\(attachedImages.count) attachment\(attachedImages.count == 1 ? "" : "s")")
        .sheet(isPresented: $showAttachments) {
            AttachmentsSheetView(
                attachedImages: $attachedImages,
                isPresented: $showAttachments
            )
        }
    }

    // MARK: - Settings Button

    private var settingsButton: some View {
        Button {
            showSettings.toggle()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(secondarySystemFill)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Additional settings")
        .accessibilityHint("Adjusts generation parameters")
        #if os(iOS)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                settingsPopover
                    .navigationTitle("Additional Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showSettings = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        #else
        .popover(isPresented: $showSettings) {
            settingsPopover
        }
        #endif
    }

    // MARK: - Settings Popover

    private var settingsPopover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                #if os(macOS)
                Text("Additional Settings")
                    .font(.headline)
                #endif

                if let modelParams = viewModel.selectedModel?.modelParams {
                    // Dimensions
                    if !modelParams.effectiveDimensions.isEmpty {
                        CardStringDropdown(
                            label: "Dimensions",
                            selection: $viewModel.dimensions,
                            options: modelParams.effectiveDimensions,
                            capitalize: false,
                            onChange: { viewModel.saveToThread() }
                        )
                    }

                    // Quality
                    if !modelParams.supportedImageQualities.isEmpty {
                        CardSegmentedPicker(
                            label: "Quality",
                            selection: $viewModel.quality,
                            options: modelParams.supportedImageQualities
                        )
                        .onChange(of: viewModel.quality) { _, _ in viewModel.saveToThread() }
                    }

                    // Style
                    if !modelParams.supportedStyles.isEmpty {
                        CardStringDropdown(
                            label: "Style",
                            selection: $viewModel.style,
                            options: modelParams.supportedStyles,
                            onChange: { viewModel.saveToThread() }
                        )
                    }

                    // Variant
                    if !modelParams.supportedVariants.isEmpty {
                        CardStringDropdown(
                            label: "Variant",
                            selection: $viewModel.variant,
                            options: modelParams.supportedVariants,
                            onChange: { viewModel.saveToThread() }
                        )
                    }

                    // Resolution
                    if modelParams.supportsImageResolution,
                       !modelParams.supportedImageResolutions.isEmpty
                    {
                        CardStringDropdown(
                            label: "Resolution",
                            selection: $viewModel.selectedResolution,
                            options: modelParams.supportedImageResolutions,
                            capitalize: false,
                            onChange: { viewModel.saveToThread() }
                        )
                    }

                    // Input Fidelity
                    if modelParams.supportsInputFidelity,
                       !modelParams.supportedInputFidelities.isEmpty
                    {
                        CardStringDropdown(
                            label: "Input Fidelity",
                            selection: $viewModel.inputFidelity,
                            options: modelParams.supportedInputFidelities,
                            onChange: { viewModel.saveToThread() }
                        )
                    }

                    // Moderation
                    if modelParams.supportsModeration,
                       !modelParams.supportedModerations.isEmpty
                    {
                        CardStringDropdown(
                            label: "Moderation",
                            selection: $viewModel.moderation,
                            options: modelParams.supportedModerations,
                            onChange: { viewModel.saveToThread() }
                        )
                    }

                    // Steps
                    if let stepsRange = modelParams.supportedStepsRange {
                        CardSlider(
                            label: "Steps",
                            value: $viewModel.stepsValue,
                            range: Double(stepsRange.min) ... Double(stepsRange.max),
                            step: 1
                        )
                        .onChange(of: viewModel.stepsValue) { _, _ in viewModel.saveToThread() }
                    }

                    // Guidance scale
                    if let guidanceRange = modelParams.supportedGuidanceRange {
                        CardSlider(
                            label: "Guidance Scale",
                            value: $viewModel.guidanceValue,
                            range: guidanceRange.min ... guidanceRange.max,
                            step: 0.1,
                            valueFormatter: { String(format: "%.1f", $0) }
                        )
                        .onChange(of: viewModel.guidanceValue) { _, _ in viewModel.saveToThread() }
                    }

                    // Safety Tolerance
                    if let safetyRange = modelParams.supportedSafetyRange {
                        CardSlider(
                            label: "Safety Tolerance",
                            value: $viewModel.safetyValue,
                            range: Double(safetyRange.min) ... Double(safetyRange.max)
                        )
                        .onChange(of: viewModel.safetyValue) { _, _ in viewModel.saveToThread() }
                    }

                    // Grow Mask
                    if let growMaskRange = modelParams.supportedGrowMaskRange {
                        CardSlider(
                            label: "Grow Mask",
                            value: $viewModel.growMaskValue,
                            range: Double(growMaskRange.min) ... Double(growMaskRange.max)
                        )
                        .onChange(of: viewModel.growMaskValue) { _, _ in viewModel.saveToThread() }
                    }

                    // Seed
                    if modelParams.supportsSeed {
                        CardSeedField(label: "Seed", value: $viewModel.seedValue)
                            .onChange(of: viewModel.seedValue) { _, _ in viewModel.saveToThread() }
                    }

                    // Prompt enhance
                    if modelParams.supportsPromptEnhance {
                        CardToggle(label: "Enhance Prompt", isOn: $viewModel.modelPromptEnhance)
                            .onChange(of: viewModel.modelPromptEnhance) { _, _ in viewModel.saveToThread() }
                    }

                    // Person Generation
                    if modelParams.supportsPersonGeneration,
                       !modelParams.supportedPersonGenerationOptions.isEmpty
                    {
                        CardStringDropdown(
                            label: "Person Generation",
                            selection: $viewModel.personGeneration,
                            options: modelParams.supportedPersonGenerationOptions,
                            onChange: { viewModel.saveToThread() }
                        )
                    }

                    // Tools
                    if modelParams.supportsTools,
                       !modelParams.supportedTools.isEmpty
                    {
                        CardToolsPicker(
                            label: "Available Tools",
                            selection: $viewModel.selectedTools,
                            tools: modelParams.supportedTools
                        )
                        .onChange(of: viewModel.selectedTools) { _, _ in viewModel.saveToThread() }
                    }

                    Divider()

                    // Search prompt
                    if modelParams.supportsSearchPrompt {
                        CardPromptField(
                            label: "Search Prompt",
                            text: $viewModel.searchPrompt,
                            minHeight: 40,
                            maxHeight: 60
                        )
                        .onChange(of: viewModel.searchPrompt) { _, _ in viewModel.saveToThread() }
                    }

                    // Negative prompt
                    if modelParams.supportsNegativePrompt {
                        CardPromptField(
                            label: "Negative Prompt",
                            text: $viewModel.negativePrompt,
                            minHeight: 40,
                            maxHeight: 60
                        )
                        .onChange(of: viewModel.negativePrompt) { _, _ in viewModel.saveToThread() }
                    }
                } else {
                    Text("Select a model to configure settings")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        #if os(macOS)
        .frame(width: 340, height: 500)
        #endif
    }

    // MARK: - Actions

    private func submitPrompt() {
        let trimmedPrompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        let config = viewModel.buildConfiguration(prompt: trimmedPrompt)
        let imagesToSend = attachedImages
        onSend(trimmedPrompt, config, imagesToSend)
        promptText = ""
        attachedImages = []
        isPromptFocused = false
    }
}

// MARK: - View Model

@MainActor
class ChatPromptBarViewModel: ObservableObject {
    private let providerService = ProviderService.shared

    private weak var thread: ChatThread?
    private var modelContext: ModelContext?

    @Published var selectedProviderId = ""
    @Published var selectedModelId = ""
    @Published var imageCount = 4
    @Published var dimensions = "1024x1024"
    @Published var quality = "standard"
    @Published var style = ""
    @Published var variant = ""
    @Published var selectedResolution = ""
    @Published var inputFidelity = ""
    @Published var moderation = ""
    @Published var stepsValue: Double = 28
    @Published var guidanceValue = 3.5
    @Published var seedValue = ""
    @Published var safetyValue: Double = 5
    @Published var growMaskValue: Double = 3
    @Published var modelPromptEnhance = true
    @Published var negativePrompt = ""
    @Published var searchPrompt = ""
    @Published var personGeneration = ""
    @Published var selectedTools: Set<String> = []

    private var providerKeys: [ProviderKey] = []

    var supportedProviders: [Provider] {
        providers.filter { provider in
            providerKeys.contains { $0.providerId == provider.providerId } &&
                providerService.allModels.contains {
                    $0.providerId == provider.providerId &&
                        $0.modelSetType == .IMAGE_GENERATE &&
                        $0.active
                }
        }
    }

    var supportedModels: [ProviderModel] {
        guard !selectedProviderId.isEmpty else { return [] }
        return providerService.models(for: .IMAGE_GENERATE).filter {
            $0.providerId.uuidString == selectedProviderId
        }
    }

    var selectedModel: ProviderModel? {
        guard !selectedModelId.isEmpty else { return nil }
        return providerService.model(by: selectedModelId)
    }

    func initialize(thread: ChatThread, providerKeys: [ProviderKey], modelContext: ModelContext) {
        self.thread = thread
        self.providerKeys = providerKeys
        self.modelContext = modelContext

        // Load image count from thread
        imageCount = thread.imagesPerIteration

        // Restore from thread if available
        if !thread.selectedProviderId.isEmpty {
            selectedProviderId = thread.selectedProviderId
            selectedModelId = thread.selectedModelId

            // Load saved configuration
            let config = thread.savedConfiguration
            loadConfiguration(config)
        } else if let firstProvider = supportedProviders.first {
            // Initialize with first available provider
            selectedProviderId = firstProvider.providerId.uuidString
            handleProviderChange()
        }
    }

    private func loadConfiguration(_ config: ImageGenerationConfiguration) {
        dimensions = config.selectedDimensions.isEmpty ? "1024x1024" : config.selectedDimensions
        quality = config.selectedQuality
        style = config.selectedStyle
        variant = config.selectedVariant
        selectedResolution = config.selectedResolution
        inputFidelity = config.selectedInputFidelity
        moderation = config.selectedModeration
        stepsValue = config.stepsValue
        guidanceValue = config.guidanceValue
        seedValue = config.seedValue
        safetyValue = config.safetyValue
        growMaskValue = config.growMaskValue
        modelPromptEnhance = config.modelPromptEnhance
        negativePrompt = config.negativePrompt
        searchPrompt = config.searchPrompt
        personGeneration = config.personGeneration
        selectedTools = Set(config.selectedTools)
    }

    func handleProviderChange() {
        selectedModelId = supportedModels.first?.modelId.uuidString ?? ""
        handleModelChange()
    }

    func handleModelChange() {
        guard let modelParams = selectedModel?.modelParams else { return }

        // Initialize to supported defaults if current values aren't supported
        if !modelParams.effectiveDimensions.contains(dimensions) {
            dimensions = modelParams.effectiveDimensions.first ?? "1024x1024"
        }

        if !modelParams.supportedImageQualities.contains(quality) {
            quality = modelParams.supportedImageQualities.first ?? ""
        }

        if !modelParams.supportedStyles.contains(style) {
            style = modelParams.supportedStyles.first ?? ""
        }

        if !modelParams.supportedVariants.contains(variant) {
            variant = modelParams.supportedVariants.first ?? ""
        }

        if modelParams.supportsImageResolution {
            if !modelParams.supportedImageResolutions.contains(selectedResolution) {
                selectedResolution = modelParams.supportedImageResolutions.first ?? ""
            }
        }

        if modelParams.supportsInputFidelity {
            if !modelParams.supportedInputFidelities.contains(inputFidelity) {
                inputFidelity = modelParams.supportedInputFidelities.first ?? ""
            }
        }

        if modelParams.supportsModeration {
            if !modelParams.supportedModerations.contains(moderation) {
                moderation = modelParams.supportedModerations.first ?? ""
            }
        }

        if modelParams.supportsPersonGeneration {
            if !modelParams.supportedPersonGenerationOptions.contains(personGeneration) {
                personGeneration = modelParams.supportedPersonGenerationOptions.first ?? ""
            }
        }
    }

    func saveToThread() {
        guard let thread else { return }

        thread.selectedProviderId = selectedProviderId
        thread.selectedModelId = selectedModelId

        var config = ImageGenerationConfiguration()
        config.selectedProviderId = selectedProviderId
        config.selectedModelId = selectedModelId
        config.selectedDimensions = dimensions
        config.selectedQuality = quality
        config.selectedStyle = style
        config.selectedVariant = variant
        config.selectedResolution = selectedResolution
        config.selectedInputFidelity = inputFidelity
        config.selectedModeration = moderation
        config.stepsValue = stepsValue
        config.guidanceValue = guidanceValue
        config.seedValue = seedValue
        config.safetyValue = safetyValue
        config.growMaskValue = growMaskValue
        config.modelPromptEnhance = modelPromptEnhance
        config.negativePrompt = negativePrompt
        config.searchPrompt = searchPrompt
        config.personGeneration = personGeneration
        config.selectedTools = Array(selectedTools)

        thread.savedConfiguration = config

        try? modelContext?.save()
    }

    func buildConfiguration(prompt: String) -> ImageGenerationConfiguration {
        var config = ImageGenerationConfiguration()
        config.selectedProviderId = selectedProviderId
        config.selectedModelId = selectedModelId
        config.prompt = prompt
        config.negativePrompt = negativePrompt
        config.searchPrompt = searchPrompt
        config.selectedDimensions = dimensions
        config.selectedQuality = quality
        config.selectedStyle = style
        config.selectedVariant = variant
        config.selectedResolution = selectedResolution
        config.selectedInputFidelity = inputFidelity
        config.selectedModeration = moderation
        config.stepsValue = stepsValue
        config.guidanceValue = guidanceValue
        config.seedValue = seedValue
        config.safetyValue = safetyValue
        config.growMaskValue = growMaskValue
        config.modelPromptEnhance = modelPromptEnhance
        config.personGeneration = personGeneration
        config.selectedTools = Array(selectedTools)
        return config
    }
}

// MARK: - Attachments Sheet View

/// Separate view for attachments sheet with its own image selection modifier.
struct AttachmentsSheetView: View {
    @Binding var attachedImages: [PlatformImage]
    @Binding var isPresented: Bool

    @State private var isImagePickerOpen = false
    @State private var isAddCardDropTargeted = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(Array(attachedImages.enumerated()), id: \.offset) { index, image in
                        attachmentThumbnail(image: image, index: index)
                    }
                    addPlaceholderCard
                }
                .padding()
            }
            .navigationTitle("Reference Images")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        isImagePickerOpen = true
                    } label: {
                        Label("Add Image", systemImage: "plus")
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 350)
        #endif
        .imageSelection(
            id: "attachmentsSheetImagePicker",
            isPickerOpen: $isImagePickerOpen,
            onImageSelected: { image in
                attachedImages.append(image)
            }
        )
    }

    private var addPlaceholderCard: some View {
        Button {
            isImagePickerOpen = true
        } label: {
            VStack(spacing: 6) {
                Image(systemName: isAddCardDropTargeted ? "arrow.down.circle.fill" : "plus")
                    .font(.system(size: 24, weight: .medium))
                Text(isAddCardDropTargeted ? "Drop" : "Add")
                    .font(.caption)
            }
            .foregroundStyle(isAddCardDropTargeted ? Color.accentColor : .secondary)
            .frame(width: 120, height: 120)
            .background(isAddCardDropTargeted ? Color.accentColor.opacity(0.2) : secondarySystemFill)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isAddCardDropTargeted ? Color.accentColor : Color.secondary,
                        style: isAddCardDropTargeted
                            ? StrokeStyle(lineWidth: 2)
                            : StrokeStyle(lineWidth: 1, dash: [5])
                    )
            )
        }
        .buttonStyle(.plain)
        .imageDropTarget(isTargeted: $isAddCardDropTargeted) { image in
            attachedImages.append(image)
        } onMultipleImagesDropped: { images in
            attachedImages.append(contentsOf: images)
        }
    }

    @ViewBuilder
    private func attachmentThumbnail(image: PlatformImage, index: Int) -> some View {
        #if os(macOS)
        Image(nsImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topTrailing) {
                Button {
                    attachedImages.remove(at: index)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white, .black.opacity(0.6))
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
            }
        #else
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topTrailing) {
                Button {
                    attachedImages.remove(at: index)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white, .black.opacity(0.6))
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
            }
        #endif
    }
}
