// MARK: - StoryboardCreateSheet.swift

// Sheet for creating a new storyboard with configuration options.
//
// StoryboardCreateSheet guides users through setting up a new storyboard:
// 1. Name the storyboard
// 2. Choose a mode (auto-extend or frame-based)
// 3. Select a compatible model
// 4. Configure video parameters (dimensions, duration, resolution)
//
// ## Model Filtering
// Models are filtered based on the selected mode:
// - Auto-extend: Models that support video extension (Veo, Sora)
// - Frame-based: Models that support first/last frame (Seedance, etc.)

import OSLog
import SwiftData
import SwiftUI

/// Sheet for creating a new storyboard with full configuration.
struct StoryboardCreateSheet: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var projectManager: ProjectManager
    @ObservedObject private var providerKeysCache = ProviderKeysCache.shared

    @Binding var isPresented: Bool
    let onCreate: (Storyboard) -> Void

    // Form state
    @State private var name = ""
    @State private var mode: StoryboardMode = .FRAME_BASED
    @State private var selectedProviderId = ""
    @State private var selectedModelId = ""
    @State private var selectedDimensions = ""
    @State private var selectedDuration = 8
    @State private var selectedResolution = ""

    private let providerService = ProviderService.shared

    private var providerKeys: [ProviderKey] {
        providerKeysCache.providerKeys
    }

    // MARK: - Computed Properties

    /// Models filtered by the selected mode
    private var supportedModels: [ProviderModel] {
        let videoGenerateModels = providerService.models(for: .VIDEO_GENERATE)
        let videoExtendModels = providerService.models(for: .VIDEO_EXTEND)

        switch mode {
        case .AUTO_EXTEND:
            // For auto-extend, we need models that support video extension
            return videoExtendModels.filter { model in
                providerKeys.contains { $0.providerId == model.providerId }
            }
        case .FRAME_BASED:
            // For frame-based, we need models that support source image (first frame)
            return videoGenerateModels.filter { model in
                model.modelParams.supportsSourceImage &&
                    providerKeys.contains { $0.providerId == model.providerId }
            }
        }
    }

    /// Unique providers from supported models
    private var supportedProviders: [Provider] {
        let providerIds = Set(supportedModels.map(\.providerId))
        return providers.filter { providerIds.contains($0.providerId) }
    }

    /// Models for the selected provider
    private var modelsForSelectedProvider: [ProviderModel] {
        guard !selectedProviderId.isEmpty else { return [] }
        return supportedModels.filter { $0.providerId.uuidString == selectedProviderId }
    }

    /// The currently selected model
    private var selectedModel: ProviderModel? {
        guard !selectedModelId.isEmpty else { return nil }
        return providerService.model(by: selectedModelId)
    }

    /// Available dimensions for the selected model
    private var availableDimensions: [String] {
        selectedModel?.modelParams.effectiveDimensions ?? []
    }

    /// Available durations for the selected model
    private var availableDurations: [Int] {
        selectedModel?.modelParams.supportedVideoDurations ?? []
    }

    /// Available resolutions for the selected model
    private var availableResolutions: [String] {
        selectedModel?.modelParams.supportedVideoResolutions ?? []
    }

    /// Whether the form can be submitted
    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !selectedModelId.isEmpty &&
            !selectedDimensions.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Storyboard Name") {
                    TextField("Enter Storyboard Name", text: $name)
                }

                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(StoryboardMode.allCases) { mode in
                            Label(mode.displayName, systemImage: mode.icon)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Generation Mode")
                }

                Section("Model Selection") {
                    if supportedProviders.isEmpty {
                        noModelsAvailableView
                    } else {
                        Picker("Provider", selection: $selectedProviderId) {
                            Text("Select Provider").tag("")
                            ForEach(supportedProviders, id: \.providerId) { provider in
                                Text(provider.providerName).tag(provider.providerId.uuidString)
                            }
                        }
                        .onChange(of: selectedProviderId) { _, _ in
                            handleProviderChange()
                        }

                        if !selectedProviderId.isEmpty {
                            Picker("Model", selection: $selectedModelId) {
                                Text("Select Model").tag("")
                                ForEach(modelsForSelectedProvider, id: \.modelId) { model in
                                    Text(model.modelName).tag(model.modelId.uuidString)
                                }
                            }
                            .onChange(of: selectedModelId) { _, _ in
                                handleModelChange()
                            }
                        }
                    }
                }

                if selectedModel != nil {
                    Section("Video Parameters") {
                        if !availableDimensions.isEmpty {
                            Picker("Dimensions", selection: $selectedDimensions) {
                                ForEach(availableDimensions, id: \.self) { dim in
                                    Text(dim).tag(dim)
                                }
                            }
                        }

                        if !availableDurations.isEmpty {
                            Picker("Scene Duration", selection: $selectedDuration) {
                                ForEach(availableDurations, id: \.self) { duration in
                                    Text("\(duration) seconds").tag(duration)
                                }
                            }
                        }

                        if !availableResolutions.isEmpty {
                            Picker("Resolution", selection: $selectedResolution) {
                                ForEach(availableResolutions, id: \.self) { res in
                                    Text(res).tag(res)
                                }
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Create Storyboard")
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
                    Button("Create") {
                        createStoryboard()
                    }
                    .disabled(!canCreate)
                }
            }
        }
        #if os(macOS)
        .frame(width: 480, height: 520)
        #endif
        .onAppear {
            providerKeysCache.loadIfNeeded(projectId: projectManager.currentProjectId, modelContext: modelContext)
            initializeDefaults()
        }
        .onChange(of: mode) { _, _ in
            selectedProviderId = ""
            selectedModelId = ""
            selectedDimensions = ""
            selectedDuration = 8
            selectedResolution = ""

            if let firstProvider = supportedProviders.first {
                selectedProviderId = firstProvider.providerId.uuidString
                handleProviderChange()
            }
        }
    }

    // MARK: - Subviews

    private var noModelsAvailableView: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.orange)

            Text("No compatible models available")
                .font(.subheadline)
                .fontWeight(.medium)

            Text(
                mode == .AUTO_EXTEND
                    ? "Configure a provider with video extend models (Veo, Sora)"
                    : "Configure a provider with frame-based video models"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Actions

    private func initializeDefaults() {
        // Auto-select first provider if available
        if let firstProvider = supportedProviders.first {
            selectedProviderId = firstProvider.providerId.uuidString
            handleProviderChange()
        }
    }

    private func handleProviderChange() {
        // Reset model selection
        selectedModelId = ""

        // Auto-select first model for this provider
        if let firstModel = modelsForSelectedProvider.first {
            selectedModelId = firstModel.modelId.uuidString
            handleModelChange()
        }
    }

    private func handleModelChange() {
        guard let model = selectedModel else { return }

        // Set default dimensions
        if let firstDim = model.modelParams.effectiveDimensions.first {
            selectedDimensions = firstDim
        }

        // Set default duration
        if let firstDuration = model.modelParams.supportedVideoDurations.first {
            selectedDuration = firstDuration
        } else {
            selectedDuration = 8
        }

        // Set default resolution
        if let firstRes = model.modelParams.supportedVideoResolutions.first {
            selectedResolution = firstRes
        }
    }

    private func createStoryboard() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let storyboard = Storyboard(
            name: trimmedName,
            projectId: projectManager.currentProjectId,
            mode: mode,
            modelId: selectedModelId,
            providerId: selectedProviderId,
            dimensions: selectedDimensions,
            sceneDuration: Double(selectedDuration),
            resolution: selectedResolution
        )

        modelContext.insert(storyboard)

        do {
            try modelContext.save()
            onCreate(storyboard)
            isPresented = false
        } catch {
            AppLogger.ui.error("Failed to create storyboard: \(error.localizedDescription, privacy: .public)")
        }
    }
}
