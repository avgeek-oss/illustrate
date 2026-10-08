// MARK: - StudioPromptBar.swift

// Prompt bar for creative studio asset generation.
//
// StudioPromptBar provides the main input interface for creative studios:
// - Asset type dropdown (Poster, Invitation, etc.)
// - Provider/model selection (filtered to models supporting reference images)
// - Text input for prompts
// - Attachments for custom reference images
// - Brand assets toggle for logos and assets
// - Settings popover for advanced options
//
// ## Layout
// The bar is designed to be in the header area of creative studios:
// - Primary: Asset type dropdown + Model selection + Attachments + Brand Assets row
// - Secondary: Prompt text field with send button
//
// ## Brand Context Injection
// When submitting, the bar automatically builds a full prompt that includes
// brand context (name, about, personality, colors, font) from the BrandKit.

import SwiftData
import SwiftUI

/// Brand asset selection options for reference images
struct BrandAssetSelection {
    var includeLightLogo = true
    var includeDarkLogo = true
    /// Set of selected model asset UUIDs (default empty)
    var selectedModelAssetIds: Set<UUID> = []
}

/// Prompt bar for submitting creative studio generation requests.
struct StudioPromptBar: View {
    let studio: CreativeStudio
    let providerKeys: [ProviderKey]
    let brandKit: BrandKit?
    let onSend: (String, String, CreativeAssetType, ImageGenerationConfiguration, [PlatformImage], BrandAssetSelection)
        -> Void
    @Binding var attachedImages: [PlatformImage]

    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = StudioPromptBarViewModel()

    @State private var promptText = ""
    @State private var showSettings = false
    @State private var showAttachments = false
    @State private var showBrandAssets = false
    @State private var selectedAssetType: CreativeAssetType = .generalPurpose

    // Persisted brand asset selections
    @AppStorage("brandAsset.includeLightLogo") private var includeLightLogo = true
    @AppStorage("brandAsset.includeDarkLogo") private var includeDarkLogo = true
    /// Model assets stored as JSON-encoded Set<UUID>
    @AppStorage("brandAsset.selectedModelAssets") private var selectedModelAssetsData = Data()

    private var selectedModelAssetIds: Set<UUID> {
        get {
            guard !selectedModelAssetsData.isEmpty else { return [] }
            return (try? JSONDecoder().decode(Set<UUID>.self, from: selectedModelAssetsData)) ?? []
        }
        set {
            selectedModelAssetsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    private var brandAssetSelection: BrandAssetSelection {
        BrandAssetSelection(
            includeLightLogo: includeLightLogo,
            includeDarkLogo: includeDarkLogo,
            selectedModelAssetIds: selectedModelAssetIds
        )
    }

    private var brandAssetSelectionBinding: Binding<BrandAssetSelection> {
        Binding(
            get: { brandAssetSelection },
            set: { newValue in
                includeLightLogo = newValue.includeLightLogo
                includeDarkLogo = newValue.includeDarkLogo
                selectedModelAssetsData = (try? JSONEncoder().encode(newValue.selectedModelAssetIds)) ?? Data()
            }
        )
    }

    private let inputHeight: CGFloat = 44

    private var canSend: Bool {
        !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !viewModel.selectedProviderId.isEmpty &&
            !viewModel.selectedModelId.isEmpty
    }

    var body: some View {
        VStack(spacing: 12) {
            // Asset type + Model selection row
            HStack(spacing: 12) {
                assetTypePicker
                providerPicker
                modelPicker

                Spacer()

                brandAssetsButton
                attachmentsButton
                settingsButton
            }

            // Prompt input row
            HStack(spacing: 12) {
                promptTextField
                sendButton
            }
        }
        .onAppear {
            viewModel.initialize(studio: studio, providerKeys: providerKeys, modelContext: modelContext)
        }
        .onChange(of: studio.id) { _, _ in
            viewModel.initialize(studio: studio, providerKeys: providerKeys, modelContext: modelContext)
        }
        .sheet(isPresented: $showAttachments) {
            AttachmentsSheetView(
                attachedImages: $attachedImages,
                isPresented: $showAttachments
            )
        }
    }

    // MARK: - Asset Type Picker

    private var assetTypePicker: some View {
        Menu {
            ForEach(CreativeAssetType.allCases) { type in
                Button {
                    selectedAssetType = type
                } label: {
                    Label(type.displayName, systemImage: type.icon)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selectedAssetType.icon)
                    .font(.caption)
                Text(selectedAssetType.displayName)
                    .font(.callout)
                    .lineLimit(1)
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

    // MARK: - Provider Picker

    private var providerPicker: some View {
        Menu {
            ForEach(viewModel.supportedProviders, id: \.providerId) { provider in
                Button(provider.providerName) {
                    viewModel.selectedProviderId = provider.providerId.uuidString
                    viewModel.handleProviderChange()
                    viewModel.saveToStudio()
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
                    viewModel.saveToStudio()
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

    // MARK: - Prompt TextField

    private var promptTextField: some View {
        TextField("Describe what you want to generate...", text: $promptText, axis: .vertical)
            .textFieldStyle(.plain)
            .lineLimit(1 ... 3)
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
        .disabled(!canSend)
        .accessibilityLabel("Send")
        .accessibilityHint(canSend ? "Generates with the current prompt" : "Enter a prompt first")
    }

    // MARK: - Attachments Button

    private var attachmentsButton: some View {
        Button {
            showAttachments.toggle()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "paperclip")
                    .font(.system(size: 14))
                    .frame(width: 32, height: 32)
                    .background(secondarySystemFill)
                    .cornerRadius(8)

                BadgeView(count: attachedImages.count)
                    .offset(x: 6, y: -6)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: attachedImages.count)
        }
        .buttonStyle(.plain)
        .help("Add custom reference images")
        .accessibilityLabel("Attachments")
        .accessibilityHint(attachedImages
            .isEmpty ? "No attachments" : "\(attachedImages.count) attachment\(attachedImages.count == 1 ? "" : "s")")
    }

    // MARK: - Brand Assets Button

    private var brandAssetsButton: some View {
        Button {
            showBrandAssets.toggle()
        } label: {
            Image(systemName: "briefcase")
                .font(.system(size: 14))
                .foregroundStyle(hasBrandAssetsSelected ? Color.accentColor : .secondary)
                .frame(width: 32, height: 32)
                .background(secondarySystemFill)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showBrandAssets) {
            brandAssetsPopover
        }
        .help("Select brand assets to include as references")
        .accessibilityLabel("Brand assets")
        .accessibilityHint(hasBrandAssetsSelected ? "Brand assets selected" : "Select brand assets as references")
    }

    private var hasBrandAssetsSelected: Bool {
        (brandAssetSelection.includeLightLogo && brandKit?.imageFileName(for: .lightLogo) != nil) ||
            (brandAssetSelection.includeDarkLogo && brandKit?.imageFileName(for: .darkLogo) != nil) ||
            !brandAssetSelection.selectedModelAssetIds.isEmpty
    }

    // MARK: - Brand Assets Popover

    private var brandAssetsPopover: some View {
        BrandAssetsPopoverContent(
            brandKit: brandKit,
            selection: brandAssetSelectionBinding
        )
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
        .popover(isPresented: $showSettings) {
            settingsPopover
        }
    }

    // MARK: - Settings Popover

    private var settingsPopover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Additional Settings")
                    .font(.headline)

                if let modelParams = viewModel.selectedModel?.modelParams {
                    // Dimensions
                    if !modelParams.effectiveDimensions.isEmpty {
                        CardStringDropdown(
                            label: "Dimensions",
                            selection: $viewModel.dimensions,
                            options: modelParams.effectiveDimensions,
                            capitalize: false,
                            onChange: { viewModel.saveToStudio() }
                        )
                    }

                    // Quality
                    if !modelParams.supportedImageQualities.isEmpty {
                        CardSegmentedPicker(
                            label: "Quality",
                            selection: $viewModel.quality,
                            options: modelParams.supportedImageQualities
                        )
                        .onChange(of: viewModel.quality) { _, _ in viewModel.saveToStudio() }
                    }

                    // Style
                    if modelParams.supportsStyles, !modelParams.supportedStyles.isEmpty {
                        CardStringDropdown(
                            label: "Style",
                            selection: $viewModel.style,
                            options: modelParams.supportedStyles,
                            onChange: { viewModel.saveToStudio() }
                        )
                    }

                    // Variant
                    if modelParams.supportsVariants, !modelParams.supportedVariants.isEmpty {
                        CardStringDropdown(
                            label: "Variant",
                            selection: $viewModel.variant,
                            options: modelParams.supportedVariants,
                            onChange: { viewModel.saveToStudio() }
                        )
                    }

                    // Resolution
                    if modelParams.supportsImageResolution, !modelParams.supportedImageResolutions.isEmpty {
                        CardStringDropdown(
                            label: "Resolution",
                            selection: $viewModel.selectedResolution,
                            options: modelParams.supportedImageResolutions,
                            capitalize: false,
                            onChange: { viewModel.saveToStudio() }
                        )
                    }

                    // Input Fidelity
                    if modelParams.supportsInputFidelity, !modelParams.supportedInputFidelities.isEmpty {
                        CardStringDropdown(
                            label: "Input Fidelity",
                            selection: $viewModel.inputFidelity,
                            options: modelParams.supportedInputFidelities,
                            onChange: { viewModel.saveToStudio() }
                        )
                    }

                    // Moderation
                    if modelParams.supportsModeration, !modelParams.supportedModerations.isEmpty {
                        CardStringDropdown(
                            label: "Moderation",
                            selection: $viewModel.moderation,
                            options: modelParams.supportedModerations,
                            onChange: { viewModel.saveToStudio() }
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
                        .onChange(of: viewModel.stepsValue) { _, _ in viewModel.saveToStudio() }
                    }

                    // Guidance
                    if let guidanceRange = modelParams.supportedGuidanceRange {
                        CardSlider(
                            label: "Guidance Scale",
                            value: $viewModel.guidanceValue,
                            range: guidanceRange.min ... guidanceRange.max,
                            step: 0.1,
                            valueFormatter: { String(format: "%.1f", $0) }
                        )
                        .onChange(of: viewModel.guidanceValue) { _, _ in viewModel.saveToStudio() }
                    }

                    // Safety
                    if let safetyRange = modelParams.supportedSafetyRange {
                        CardSlider(
                            label: "Safety Tolerance",
                            value: $viewModel.safetyValue,
                            range: Double(safetyRange.min) ... Double(safetyRange.max)
                        )
                        .onChange(of: viewModel.safetyValue) { _, _ in viewModel.saveToStudio() }
                    }

                    // Seed
                    if modelParams.supportsSeed {
                        CardSeedField(label: "Seed", value: $viewModel.seedValue)
                            .onChange(of: viewModel.seedValue) { _, _ in viewModel.saveToStudio() }
                    }

                    // Grow Mask
                    if let growMaskRange = modelParams.supportedGrowMaskRange {
                        CardSlider(
                            label: "Grow Mask",
                            value: $viewModel.growMaskValue,
                            range: Double(growMaskRange.min) ... Double(growMaskRange.max)
                        )
                        .onChange(of: viewModel.growMaskValue) { _, _ in viewModel.saveToStudio() }
                    }

                    // Prompt enhance
                    if modelParams.supportsPromptEnhance {
                        CardToggle(label: "Enhance Prompt", isOn: $viewModel.modelPromptEnhance)
                            .onChange(of: viewModel.modelPromptEnhance) { _, _ in viewModel.saveToStudio() }
                    }

                    // Person Generation
                    if modelParams.supportsPersonGeneration, !modelParams.supportedPersonGenerationOptions.isEmpty {
                        CardStringDropdown(
                            label: "Person Generation",
                            selection: $viewModel.personGeneration,
                            options: modelParams.supportedPersonGenerationOptions,
                            onChange: { viewModel.saveToStudio() }
                        )
                    }

                    // Tools
                    if modelParams.supportsTools, !modelParams.supportedTools.isEmpty {
                        CardToolsPicker(
                            label: "Available Tools",
                            selection: $viewModel.selectedTools,
                            tools: modelParams.supportedTools
                        )
                        .onChange(of: viewModel.selectedTools) { _, _ in viewModel.saveToStudio() }
                    }

                    Divider()

                    // Negative prompt
                    if modelParams.supportsNegativePrompt {
                        CardPromptField(
                            label: "Negative Prompt",
                            text: $viewModel.negativePrompt,
                            minHeight: 40,
                            maxHeight: 60
                        )
                        .onChange(of: viewModel.negativePrompt) { _, _ in viewModel.saveToStudio() }
                    }
                } else {
                    Text("Select a model to configure settings")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .frame(width: 340, height: 450)
    }

    // MARK: - Actions

    private func submitPrompt() {
        let trimmedPrompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        // Build full prompt with brand context
        let fullPrompt = buildBrandContextPrompt(userPrompt: trimmedPrompt)

        // Build configuration
        let config = viewModel.buildConfiguration(prompt: fullPrompt)

        onSend(trimmedPrompt, fullPrompt, selectedAssetType, config, attachedImages, brandAssetSelection)
        promptText = ""
        attachedImages = []
    }

    // MARK: - Brand Context Prompt Builder

    private func buildBrandContextPrompt(userPrompt: String) -> String {
        guard let kit = brandKit else {
            return userPrompt
        }

        var promptParts: [String] = []

        // Asset type header
        promptParts
            .append(
                "Generate a \(selectedAssetType.promptDescription) for \(kit.brandName.isEmpty ? "the brand" : kit.brandName)."
            )

        // Brand context section
        var brandContext: [String] = []

        if !kit.brandAbout.isEmpty {
            brandContext.append("About: \(kit.brandAbout)")
        }

        if !kit.brandPersonality.isEmpty {
            brandContext.append("Personality: \(kit.brandPersonality)")
        }

        // Colors
        var colorDescriptions: [String] = []
        let primaryColor = kit.color(for: .primary)
        let secondaryColor = kit.color(for: .secondary)
        let accentColor = kit.color(for: .accent)

        if primaryColor != BrandColorType.primary.defaultColor {
            colorDescriptions.append("Primary (\(primaryColor))")
        }
        if secondaryColor != BrandColorType.secondary.defaultColor {
            colorDescriptions.append("Secondary (\(secondaryColor))")
        }
        if accentColor != BrandColorType.accent.defaultColor {
            colorDescriptions.append("Accent (\(accentColor))")
        }

        if !kit.additionalColors.isEmpty {
            let additionalColorStr = kit.additionalColors.prefix(3).joined(separator: ", ")
            colorDescriptions.append("Additional (\(additionalColorStr))")
        }

        if !colorDescriptions.isEmpty {
            brandContext.append("Brand Colors: \(colorDescriptions.joined(separator: ", "))")
        }

        // Font
        if let fontFace = kit.fontFace, !fontFace.isEmpty {
            brandContext.append("Font: \(fontFace)")
        }

        if !brandContext.isEmpty {
            promptParts.append("\nBrand Context:")
            for item in brandContext {
                promptParts.append("- \(item)")
            }
        }

        // User request
        promptParts.append("\nUser Request:")
        promptParts.append(userPrompt)

        return promptParts.joined(separator: "\n")
    }
}

// MARK: - View Model

@MainActor
class StudioPromptBarViewModel: ObservableObject {
    private let providerService = ProviderService.shared

    private weak var studio: CreativeStudio?
    private var modelContext: ModelContext?

    @Published var selectedProviderId = ""
    @Published var selectedModelId = ""
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
                        $0.active &&
                        $0.modelParams.supportsReferenceImages
                }
        }
    }

    var supportedModels: [ProviderModel] {
        guard !selectedProviderId.isEmpty else { return [] }
        // Only show models that support reference images for creative studios
        return providerService.models(for: .IMAGE_GENERATE).filter {
            $0.providerId.uuidString == selectedProviderId &&
                $0.modelParams.supportsReferenceImages
        }
    }

    var selectedModel: ProviderModel? {
        guard !selectedModelId.isEmpty else { return nil }
        return providerService.model(by: selectedModelId)
    }

    func initialize(studio: CreativeStudio, providerKeys: [ProviderKey], modelContext: ModelContext) {
        self.studio = studio
        self.providerKeys = providerKeys
        self.modelContext = modelContext

        // Restore from studio if available
        if !studio.selectedProviderId.isEmpty {
            selectedProviderId = studio.selectedProviderId
            selectedModelId = studio.selectedModelId

            // Load saved configuration
            let config = studio.savedConfiguration
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

    func saveToStudio() {
        guard let studio else { return }

        studio.selectedProviderId = selectedProviderId
        studio.selectedModelId = selectedModelId

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

        studio.savedConfiguration = config

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

// MARK: - Brand Assets Popover Content

/// Popover content for selecting brand assets as reference images.
struct BrandAssetsPopoverContent: View {
    let brandKit: BrandKit?
    @Binding var selection: BrandAssetSelection

    @State private var lightLogoImage: PlatformImage?
    @State private var darkLogoImage: PlatformImage?
    @State private var modelAssetImages: [UUID: PlatformImage] = [:]

    private let imageSize: CGFloat = 48

    private var hasAnyAssets: Bool {
        let hasLightLogo = brandKit?.imageFileName(for: .lightLogo) != nil
        let hasDarkLogo = brandKit?.imageFileName(for: .darkLogo) != nil
        let hasModelAssets = brandKit?.modelAssets.isEmpty == false
        return hasLightLogo || hasDarkLogo || hasModelAssets
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Brand Assets")
                    .font(.headline)

                Text("Brand information is included by default. Select which brand assets to include as references.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if hasAnyAssets {
                // Light Logo
                if brandKit?.imageFileName(for: .lightLogo) != nil {
                    logoAssetRow(
                        label: "Light Logo",
                        image: lightLogoImage,
                        isSelected: $selection.includeLightLogo,
                        hasAsset: true
                    )
                }

                // Dark Logo
                if brandKit?.imageFileName(for: .darkLogo) != nil {
                    logoAssetRow(
                        label: "Dark Logo",
                        image: darkLogoImage,
                        isSelected: $selection.includeDarkLogo,
                        hasAsset: true
                    )
                }

                if let kit = brandKit, !kit.modelAssets.isEmpty {
                    Divider()

                    Text("Model Assets")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(kit.modelAssets) { asset in
                        modelAssetRow(
                            asset: asset,
                            image: modelAssetImages[asset.id]
                        )
                    }
                }
            } else {
                Text("No assets to attach")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
        .padding(16)
        .frame(width: 260)
        .onAppear {
            loadImages()
        }
    }

    private func logoAssetRow(
        label: String,
        image: PlatformImage?,
        isSelected: Binding<Bool>,
        hasAsset: Bool
    ) -> some View {
        HStack(spacing: 12) {
            // Image preview or placeholder
            if let img = image {
                #if os(macOS)
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                #else
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                #endif
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(secondarySystemFill)
                    .frame(width: imageSize, height: imageSize)
                    .overlay {
                        if hasAsset {
                            GradientSpinner()
                        } else {
                            Image(systemName: "photo")
                                .foregroundStyle(.tertiary)
                        }
                    }
            }

            Text(label)
                .font(.callout)

            Spacer()

            if hasAsset {
                Toggle("", isOn: isSelected)
                    #if os(macOS)
                    .toggleStyle(.checkbox)
                    #endif
                    .labelsHidden()
            } else {
                Text("Not set")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(hasAsset ? 1 : 0.5)
    }

    @ViewBuilder
    private func modelAssetRow(asset: ModelAsset, image: PlatformImage?) -> some View {
        let isSelected = Binding(
            get: { selection.selectedModelAssetIds.contains(asset.id) },
            set: { newValue in
                if newValue {
                    selection.selectedModelAssetIds.insert(asset.id)
                } else {
                    selection.selectedModelAssetIds.remove(asset.id)
                }
            }
        )

        HStack(spacing: 12) {
            // Image preview or placeholder
            if let img = image {
                #if os(macOS)
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                #else
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                #endif
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(secondarySystemFill)
                    .frame(width: imageSize, height: imageSize)
                    .overlay {
                        GradientSpinner()
                    }
            }

            Text("Model Asset")
                .font(.callout)

            Spacer()

            Toggle("", isOn: isSelected)
                #if os(macOS)
                .toggleStyle(.checkbox)
                #endif
                .labelsHidden()
        }
    }

    private func loadImages() {
        guard let kit = brandKit else { return }

        // Load light logo
        if let fileName = kit.thumbFileName(for: .lightLogo) ?? kit.imageFileName(for: .lightLogo) {
            loadImage(fileName: fileName) { image in
                lightLogoImage = image
            }
        }

        // Load dark logo
        if let fileName = kit.thumbFileName(for: .darkLogo) ?? kit.imageFileName(for: .darkLogo) {
            loadImage(fileName: fileName) { image in
                darkLogoImage = image
            }
        }

        // Load model asset images
        for asset in kit.modelAssets {
            loadImage(fileName: asset.thumbFileName) { image in
                modelAssetImages[asset.id] = image
            }
        }
    }

    private func loadImage(fileName: String, completion: @escaping (PlatformImage?) -> Void) {
        // Check cache first
        if let cached = ImageCache.shared.get(forKey: fileName) {
            completion(cached)
            return
        }

        // Load from iCloud
        DispatchQueue.global(qos: .userInitiated).async {
            let image = loadImageFromiCloud(fileName)
            DispatchQueue.main.async {
                if let img = image {
                    ImageCache.shared.set(img, forKey: fileName)
                }
                completion(image)
            }
        }
    }
}
