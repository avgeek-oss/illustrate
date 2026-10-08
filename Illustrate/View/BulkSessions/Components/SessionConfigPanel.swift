// MARK: - SessionConfigPanel.swift

// Configuration panel for bulk generation sessions.
//
// Provides UI for configuring:
// - Concurrency limit (1-10)
// - Common prompt suffix
// - Provider and model selection
// - Generation parameters (dimensions, quality, etc.)
// - CSV import
// - Estimated cost display
//
// ## CSV Import
// - Uses fileImporter modifier
// - Expects "prompt" header column
// - Max 250 items
// - Replaces existing items on import

import IllustrateProviders
import SwiftData
import SwiftUI

/// Configuration panel for bulk session settings.
struct SessionConfigPanel: View {
    @Environment(\.modelContext) private var modelContext

    let session: BulkSession
    let providerKeys: [ProviderKey]
    let items: [BulkSessionItem]
    let isGenerating: Bool
    let sessionHasStarted: Bool
    let onItemsImported: ([(prompt: String, filename: String?)]) -> Void
    @Binding var showFileImporter: Bool
    let isCompactLayout: Bool

    /// Configuration is locked once generation has started (even if completed/cancelled)
    private var isConfigLocked: Bool {
        sessionHasStarted
    }

    @State private var showSettings = false

    // Local state for configuration
    @State private var selectedProviderId = ""
    @State private var selectedModelId = ""
    @State private var concurrencyLimit = 2
    @State private var commonPrompt = ""
    @State private var dimensions = "1024x1024"
    @State private var quality = "standard"
    @State private var style = ""
    @State private var variant = ""
    @State private var selectedResolution = ""
    @State private var inputFidelity = ""
    @State private var moderation = ""
    @State private var guidanceValue = 3.5
    @State private var seedValue = ""
    @State private var safetyValue: Double = 5
    @State private var growMaskValue: Double = 3
    @State private var modelPromptEnhance = true
    @State private var negativePrompt = ""
    @State private var personGeneration = ""
    @State private var selectedTools: Set<String> = []

    private var supportedProviders: [Provider] {
        providers.filter { provider in
            providerKeys.contains { $0.providerId == provider.providerId } &&
                ProviderService.shared.allModels.contains {
                    $0.providerId == provider.providerId &&
                        $0.modelSetType == .IMAGE_GENERATE &&
                        $0.active
                }
        }
    }

    private var supportedModels: [ProviderModel] {
        guard !selectedProviderId.isEmpty else { return [] }
        return ProviderService.shared.models(for: .IMAGE_GENERATE).filter {
            $0.providerId.uuidString == selectedProviderId
        }
    }

    private var selectedModel: ProviderModel? {
        guard !selectedModelId.isEmpty else { return nil }
        return ProviderService.shared.model(by: selectedModelId)
    }

    var body: some View {
        Group {
            if isCompactLayout {
                compactLayout
            } else {
                desktopLayout
            }
        }
        .sheet(isPresented: compactSettingsBinding) {
            settingsSheet
        }
        .onAppear {
            loadFromSession()
        }
        .onChange(of: session.id) { _, _ in
            loadFromSession()
        }
    }

    private var compactSettingsBinding: Binding<Bool> {
        Binding(
            get: { isCompactLayout && showSettings },
            set: { showSettings = $0 }
        )
    }

    private var desktopLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Provider, Model, Dimensions, Concurrency, and Cost row
            HStack(spacing: 16) {
                // Provider picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Provider")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    providerPicker
                }
                .disabled(isConfigLocked)

                // Model picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Model")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    modelPicker
                }
                .disabled(isConfigLocked)

                // Dimensions picker
                if let modelParams = selectedModel?.modelParams,
                   !modelParams.effectiveDimensions.isEmpty
                {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dimensions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Menu {
                            ForEach(modelParams.effectiveDimensions, id: \.self) { dim in
                                Button {
                                    dimensions = dim
                                    saveToSession()
                                } label: {
                                    let ratio = getAspectRatio(dimension: dim)
                                    Text(
                                        dim.contains(":")
                                            ? dim
                                            : "\(dim) (\(ratio.ratio))"
                                    )
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                let ratio = getAspectRatio(dimension: dimensions)
                                Text(
                                    dimensions.contains(":")
                                        ? dimensions
                                        : "\(dimensions) (\(ratio.ratio))"
                                )
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
                    .disabled(isConfigLocked)
                }

                // Concurrency picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Concurrency")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    concurrencyPicker
                }
                .disabled(isConfigLocked)

                Spacer()

                // Settings button
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
                .help("Additional settings")
                .popover(isPresented: $showSettings) {
                    settingsPopover
                }
                .disabled(isConfigLocked)
            }

            // Common prompt field
            VStack(alignment: .leading, spacing: 4) {
                TextAreaField(
                    label: "Common Prompt (applied as suffix)",
                    text: $commonPrompt,
                    placeholder: "e.g., high quality, 85mm lens, professional photography",
                    lineRange: 2 ... 5
                )
                .onChange(of: commonPrompt) { _, _ in
                    saveToSession()
                }
            }
        }
        .padding(16)
        .background(systemBackground)
    }

    private var compactLayout: some View {
        Form {
            Section {
                Picker("Provider", selection: $selectedProviderId) {
                    Text("Select Provider").tag("")
                    ForEach(supportedProviders, id: \.providerId) { provider in
                        Text(provider.providerName)
                            .tag(provider.providerId.uuidString)
                    }
                }
                .disabled(isConfigLocked)
                .onChange(of: selectedProviderId) { _, _ in
                    handleProviderChange()
                    saveToSession()
                }

                Picker("Model", selection: $selectedModelId) {
                    Text("Select Model").tag("")
                    ForEach(supportedModels, id: \.modelId) { model in
                        Text(model.modelName)
                            .tag(model.modelId.uuidString)
                    }
                }
                .disabled(isConfigLocked || selectedProviderId.isEmpty)
                .onChange(of: selectedModelId) { _, _ in
                    handleModelChange()
                    saveToSession()
                }

                if let modelParams = selectedModel?.modelParams,
                   !modelParams.effectiveDimensions.isEmpty
                {
                    Picker("Dimensions", selection: $dimensions) {
                        ForEach(modelParams.effectiveDimensions, id: \.self) { dim in
                            Text(compactDimensionLabel(for: dim))
                                .tag(dim)
                        }
                    }
                    .disabled(isConfigLocked)
                    .onChange(of: dimensions) { _, _ in saveToSession() }
                }

                Picker("Concurrency", selection: $concurrencyLimit) {
                    ForEach(1 ... 10, id: \.self) { count in
                        Text("\(count)")
                            .tag(count)
                    }
                }
                .disabled(isConfigLocked)
                .onChange(of: concurrencyLimit) { _, _ in saveToSession() }
            }

            Section("Prompt Settings") {
                TextField(
                    "Common Prompt",
                    text: $commonPrompt,
                    axis: .vertical
                )
                .lineLimit(3 ... 8)
                .disabled(isConfigLocked)
                .onChange(of: commonPrompt) { _, _ in saveToSession() }

                if selectedModel?.modelParams.supportsNegativePrompt == true {
                    TextField(
                        "Negative Prompt",
                        text: $negativePrompt,
                        axis: .vertical
                    )
                    .lineLimit(3 ... 8)
                    .disabled(isConfigLocked)
                    .onChange(of: negativePrompt) { _, _ in saveToSession() }
                }
            }

            compactAdvancedFormSections
        }
        .formStyle(.grouped)
    }

    // MARK: - Provider Picker

    private var providerPicker: some View {
        Menu {
            ForEach(supportedProviders, id: \.providerId) { provider in
                Button(provider.providerName) {
                    selectedProviderId = provider.providerId.uuidString
                    handleProviderChange()
                    saveToSession()
                }
            }
        } label: {
            HStack(spacing: 6) {
                if !selectedProviderId.isEmpty,
                   let provider = UUID(uuidString: selectedProviderId).flatMap({ providersById[$0] })
                {
                    Image(providerArtworkName(code: provider.providerCode, variant: .square))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                    Text(provider.providerName)
                        .font(.callout)
                        .lineLimit(1)
                } else {
                    Text("Select Provider")
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
            ForEach(supportedModels, id: \.modelId) { model in
                Button(model.modelName) {
                    selectedModelId = model.modelId.uuidString
                    handleModelChange()
                    saveToSession()
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let model = selectedModel {
                    Text(model.modelName)
                        .font(.callout)
                        .lineLimit(1)
                } else {
                    Text("Select Model")
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
        .disabled(selectedProviderId.isEmpty)
    }

    // MARK: - Concurrency Picker

    private var concurrencyPicker: some View {
        Menu {
            ForEach(1 ... 10, id: \.self) { count in
                Button("\(count) \(count == 1 ? "request" : "requests")") {
                    concurrencyLimit = count
                    saveToSession()
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text("\(concurrencyLimit) \(concurrencyLimit == 1 ? "request" : "requests")")
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
    }

    private var dimensionsPicker: some View {
        Menu {
            if let modelParams = selectedModel?.modelParams {
                ForEach(modelParams.effectiveDimensions, id: \.self) { dim in
                    Button {
                        dimensions = dim
                        saveToSession()
                    } label: {
                        let ratio = getAspectRatio(dimension: dim)
                        Text(dim.contains(":") ? dim : "\(dim) (\(ratio.ratio))")
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                let ratio = getAspectRatio(dimension: dimensions)
                Text(dimensions.contains(":") ? dimensions : "\(dimensions) (\(ratio.ratio))")
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

    // MARK: - Settings Popover

    private var settingsPopover: some View {
        settingsContent
            .frame(width: 340, height: 450)
    }

    private var settingsContent: some View {
        ScrollView {
            compactAdvancedSettings
                .padding(20)
        }
    }

    private var compactAdvancedSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let modelParams = selectedModel?.modelParams {
                if !modelParams.supportedImageQualities.isEmpty {
                    CardSegmentedPicker(
                        label: "Quality",
                        selection: $quality,
                        options: modelParams.supportedImageQualities
                    )
                    .onChange(of: quality) { _, _ in saveToSession() }
                }

                if !modelParams.supportedStyles.isEmpty {
                    CardStringDropdown(
                        label: "Style",
                        selection: $style,
                        options: modelParams.supportedStyles,
                        onChange: { saveToSession() }
                    )
                }

                if !modelParams.supportedVariants.isEmpty {
                    CardStringDropdown(
                        label: "Variant",
                        selection: $variant,
                        options: modelParams.supportedVariants,
                        onChange: { saveToSession() }
                    )
                }

                if modelParams.supportsImageResolution,
                   !modelParams.supportedImageResolutions.isEmpty
                {
                    CardStringDropdown(
                        label: "Resolution",
                        selection: $selectedResolution,
                        options: modelParams.supportedImageResolutions,
                        capitalize: false,
                        onChange: { saveToSession() }
                    )
                }

                if modelParams.supportsInputFidelity,
                   !modelParams.supportedInputFidelities.isEmpty
                {
                    CardStringDropdown(
                        label: "Input Fidelity",
                        selection: $inputFidelity,
                        options: modelParams.supportedInputFidelities,
                        onChange: { saveToSession() }
                    )
                }

                if modelParams.supportsModeration,
                   !modelParams.supportedModerations.isEmpty
                {
                    CardStringDropdown(
                        label: "Moderation",
                        selection: $moderation,
                        options: modelParams.supportedModerations,
                        onChange: { saveToSession() }
                    )
                }

                if let guidanceRange = modelParams.supportedGuidanceRange {
                    CardSlider(
                        label: "Guidance Scale",
                        value: $guidanceValue,
                        range: guidanceRange.min ... guidanceRange.max,
                        step: 0.1,
                        valueFormatter: { String(format: "%.1f", $0) }
                    )
                    .onChange(of: guidanceValue) { _, _ in saveToSession() }
                }

                if let safetyRange = modelParams.supportedSafetyRange {
                    CardSlider(
                        label: "Safety Tolerance",
                        value: $safetyValue,
                        range: Double(safetyRange.min) ... Double(safetyRange.max)
                    )
                    .onChange(of: safetyValue) { _, _ in saveToSession() }
                }

                if let growMaskRange = modelParams.supportedGrowMaskRange {
                    CardSlider(
                        label: "Grow Mask",
                        value: $growMaskValue,
                        range: Double(growMaskRange.min) ... Double(growMaskRange.max)
                    )
                    .onChange(of: growMaskValue) { _, _ in saveToSession() }
                }

                if modelParams.supportsSeed {
                    CardSeedField(label: "Seed", value: $seedValue)
                        .onChange(of: seedValue) { _, _ in saveToSession() }
                }

                if modelParams.supportsPromptEnhance {
                    CardToggle(label: "Enhance Prompt", isOn: $modelPromptEnhance)
                        .onChange(of: modelPromptEnhance) { _, _ in saveToSession() }
                }

                if modelParams.supportsPersonGeneration,
                   !modelParams.supportedPersonGenerationOptions.isEmpty
                {
                    CardStringDropdown(
                        label: "Person Generation",
                        selection: $personGeneration,
                        options: modelParams.supportedPersonGenerationOptions,
                        onChange: { saveToSession() }
                    )
                }

                if modelParams.supportsTools,
                   !modelParams.supportedTools.isEmpty
                {
                    CardToolsPicker(
                        label: "Available Tools",
                        selection: $selectedTools,
                        tools: modelParams.supportedTools
                    )
                    .onChange(of: selectedTools) { _, _ in saveToSession() }
                }

                if modelParams.supportsNegativePrompt {
                    Divider()

                    CardPromptField(
                        label: "Negative Prompt",
                        text: $negativePrompt,
                        minHeight: 40,
                        maxHeight: 60
                    )
                    .onChange(of: negativePrompt) { _, _ in saveToSession() }
                }
            } else {
                Text("Select a model to configure settings")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var settingsSheet: some View {
        NavigationStack {
            settingsContent
                .navigationTitle("Additional Settings")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showSettings = false
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var compactAdvancedFormSections: some View {
        if let modelParams = selectedModel?.modelParams {
            if !modelParams.supportedImageQualities.isEmpty ||
                !modelParams.supportedStyles.isEmpty ||
                !modelParams.supportedVariants.isEmpty ||
                (modelParams.supportsImageResolution && !modelParams.supportedImageResolutions.isEmpty) ||
                (modelParams.supportsInputFidelity && !modelParams.supportedInputFidelities.isEmpty) ||
                (modelParams.supportsModeration && !modelParams.supportedModerations.isEmpty) ||
                (modelParams.supportsPersonGeneration && !modelParams.supportedPersonGenerationOptions.isEmpty)
            {
                Section("Image Settings") {
                    if !modelParams.supportedImageQualities.isEmpty {
                        Picker("Quality", selection: $quality) {
                            ForEach(modelParams.supportedImageQualities, id: \.self) { option in
                                Text(option.capitalized)
                                    .tag(option)
                            }
                        }
                        .disabled(isConfigLocked)
                        .onChange(of: quality) { _, _ in saveToSession() }
                    }

                    if !modelParams.supportedStyles.isEmpty {
                        Picker("Style", selection: $style) {
                            ForEach(modelParams.supportedStyles, id: \.self) { option in
                                Text(option.capitalized)
                                    .tag(option)
                            }
                        }
                        .disabled(isConfigLocked)
                        .onChange(of: style) { _, _ in saveToSession() }
                    }

                    if !modelParams.supportedVariants.isEmpty {
                        Picker("Variant", selection: $variant) {
                            ForEach(modelParams.supportedVariants, id: \.self) { option in
                                Text(option.capitalized)
                                    .tag(option)
                            }
                        }
                        .disabled(isConfigLocked)
                        .onChange(of: variant) { _, _ in saveToSession() }
                    }

                    if modelParams.supportsImageResolution,
                       !modelParams.supportedImageResolutions.isEmpty
                    {
                        Picker("Resolution", selection: $selectedResolution) {
                            ForEach(modelParams.supportedImageResolutions, id: \.self) { option in
                                Text(option)
                                    .tag(option)
                            }
                        }
                        .disabled(isConfigLocked)
                        .onChange(of: selectedResolution) { _, _ in saveToSession() }
                    }

                    if modelParams.supportsInputFidelity,
                       !modelParams.supportedInputFidelities.isEmpty
                    {
                        Picker("Input Fidelity", selection: $inputFidelity) {
                            ForEach(modelParams.supportedInputFidelities, id: \.self) { option in
                                Text(option.capitalized)
                                    .tag(option)
                            }
                        }
                        .disabled(isConfigLocked)
                        .onChange(of: inputFidelity) { _, _ in saveToSession() }
                    }

                    if modelParams.supportsModeration,
                       !modelParams.supportedModerations.isEmpty
                    {
                        Picker("Moderation", selection: $moderation) {
                            ForEach(modelParams.supportedModerations, id: \.self) { option in
                                Text(option.capitalized)
                                    .tag(option)
                            }
                        }
                        .disabled(isConfigLocked)
                        .onChange(of: moderation) { _, _ in saveToSession() }
                    }

                    if modelParams.supportsPersonGeneration,
                       !modelParams.supportedPersonGenerationOptions.isEmpty
                    {
                        Picker("Person Generation", selection: $personGeneration) {
                            ForEach(modelParams.supportedPersonGenerationOptions, id: \.self) { option in
                                Text(option.capitalized)
                                    .tag(option)
                            }
                        }
                        .disabled(isConfigLocked)
                        .onChange(of: personGeneration) { _, _ in saveToSession() }
                    }
                }
            }

            if modelParams.supportedGuidanceRange != nil ||
                modelParams.supportedSafetyRange != nil ||
                modelParams.supportedGrowMaskRange != nil
            {
                Section("Controls") {
                    if let guidanceRange = modelParams.supportedGuidanceRange {
                        VStack(alignment: .leading, spacing: 8) {
                            LabeledContent("Guidance Scale", value: String(format: "%.1f", guidanceValue))
                            Slider(value: $guidanceValue, in: guidanceRange.min ... guidanceRange.max, step: 0.1)
                                .disabled(isConfigLocked)
                        }
                        .onChange(of: guidanceValue) { _, _ in saveToSession() }
                    }

                    if let safetyRange = modelParams.supportedSafetyRange {
                        VStack(alignment: .leading, spacing: 8) {
                            LabeledContent("Safety Tolerance", value: String(format: "%.0f", safetyValue))
                            Slider(
                                value: $safetyValue,
                                in: Double(safetyRange.min) ... Double(safetyRange.max),
                                step: 1
                            )
                            .disabled(isConfigLocked)
                        }
                        .onChange(of: safetyValue) { _, _ in saveToSession() }
                    }

                    if let growMaskRange = modelParams.supportedGrowMaskRange {
                        VStack(alignment: .leading, spacing: 8) {
                            LabeledContent("Grow Mask", value: String(format: "%.0f", growMaskValue))
                            Slider(
                                value: $growMaskValue,
                                in: Double(growMaskRange.min) ... Double(growMaskRange.max),
                                step: 1
                            )
                            .disabled(isConfigLocked)
                        }
                        .onChange(of: growMaskValue) { _, _ in saveToSession() }
                    }
                }
            }

            if modelParams.supportsSeed || modelParams.supportsPromptEnhance {
                Section("Options") {
                    if modelParams.supportsSeed {
                        TextField("Seed", text: $seedValue, prompt: Text("Leave empty for random"))
                            .disabled(isConfigLocked)
                            .onChange(of: seedValue) { _, _ in saveToSession() }
                    }

                    if modelParams.supportsPromptEnhance {
                        Toggle("Enhance Prompt", isOn: $modelPromptEnhance)
                            .disabled(isConfigLocked)
                            .onChange(of: modelPromptEnhance) { _, _ in saveToSession() }
                    }
                }
            }

            if modelParams.supportsTools,
               !modelParams.supportedTools.isEmpty
            {
                Section("Tools") {
                    ForEach(modelParams.supportedTools, id: \.self) { tool in
                        Toggle(tool, isOn: toolBinding(for: tool))
                            .disabled(isConfigLocked)
                    }
                }
            }
        } else {
            Section {
                Text("Select a model to configure settings")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func compactDimensionLabel(for dimension: String) -> String {
        let ratio = getAspectRatio(dimension: dimension)
        return dimension.contains(":") ? dimension : "\(dimension) (\(ratio.ratio))"
    }

    private func toolBinding(for tool: String) -> Binding<Bool> {
        Binding(
            get: { selectedTools.contains(tool) },
            set: { isSelected in
                if isSelected {
                    selectedTools.insert(tool)
                } else {
                    selectedTools.remove(tool)
                }
                saveToSession()
            }
        )
    }

    // MARK: - Actions

    private func loadFromSession() {
        selectedProviderId = session.selectedProviderId
        selectedModelId = session.selectedModelId
        concurrencyLimit = session.concurrencyLimit
        commonPrompt = session.commonPrompt

        let config = session.savedConfiguration
        dimensions = config.selectedDimensions.isEmpty ? "1024x1024" : config.selectedDimensions
        quality = config.selectedQuality
        style = config.selectedStyle
        variant = config.selectedVariant
        selectedResolution = config.selectedResolution
        inputFidelity = config.selectedInputFidelity
        moderation = config.selectedModeration
        guidanceValue = config.guidanceValue
        seedValue = config.seedValue
        safetyValue = config.safetyValue
        growMaskValue = config.growMaskValue
        modelPromptEnhance = config.modelPromptEnhance
        negativePrompt = config.negativePrompt
        personGeneration = config.personGeneration
        selectedTools = Set(config.selectedTools)

        // Initialize provider/model if not set
        if selectedProviderId.isEmpty, let firstProvider = supportedProviders.first {
            selectedProviderId = firstProvider.providerId.uuidString
            handleProviderChange()
        }
    }

    private func saveToSession() {
        session.selectedProviderId = selectedProviderId
        session.selectedModelId = selectedModelId
        session.concurrencyLimit = concurrencyLimit
        session.commonPrompt = commonPrompt

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
        config.guidanceValue = guidanceValue
        config.seedValue = seedValue
        config.safetyValue = safetyValue
        config.growMaskValue = growMaskValue
        config.modelPromptEnhance = modelPromptEnhance
        config.negativePrompt = negativePrompt
        config.personGeneration = personGeneration
        config.selectedTools = Array(selectedTools)

        session.savedConfiguration = config

        try? modelContext.save()
    }

    private func handleProviderChange() {
        selectedModelId = supportedModels.first?.modelId.uuidString ?? ""
        handleModelChange()
    }

    private func handleModelChange() {
        guard let modelParams = selectedModel?.modelParams else { return }

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

        if modelParams.supportsPersonGeneration {
            if !modelParams.supportedPersonGenerationOptions.contains(personGeneration) {
                personGeneration = modelParams.supportedPersonGenerationOptions.first ?? ""
            }
        }
    }
}
