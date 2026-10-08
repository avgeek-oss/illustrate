// MARK: - PhotoshootCreateSheet.swift

// Sheet for creating a new product photoshoot with configuration options.
//
// PhotoshootCreateSheet guides users through setting up a new photoshoot:
// 1. Name the photoshoot
// 2. Select a compatible model (must support reference images)
// 3. Choose image dimensions (filtered by model capabilities)
//
// ## Model Filtering
// Models are filtered to only show those that:
// - Support reference images (maxReferenceImages > 0)
// - Support at least one of the allowed dimensions (9:16, 16:9, 3:4, 4:3)

import OSLog
import SwiftData
import SwiftUI

/// Sheet for creating a new product photoshoot with full configuration.
struct PhotoshootCreateSheet: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var projectManager: ProjectManager
    @ObservedObject private var providerKeysCache = ProviderKeysCache.shared

    @Binding var isPresented: Bool
    let onCreate: (ProductPhotoshoot) -> Void

    // Form state
    @State private var name = ""
    @State private var selectedProviderId = ""
    @State private var selectedModelId = ""
    @State private var selectedDimensions: PhotoshootDimension = .portrait9x16

    private let providerService = ProviderService.shared

    private var providerKeys: [ProviderKey] {
        providerKeysCache.providerKeys
    }

    // MARK: - Computed Properties

    /// Check if a model supports at least one of our allowed dimensions
    private func modelSupportsPhotoshootDimensions(_ model: ProviderModel) -> Bool {
        let modelDimensions = model.modelParams.effectiveDimensions
        // Check if any of our photoshoot dimensions are supported (by pixel or aspect ratio)
        return PhotoshootDimension.allCases.contains { dimension in
            modelDimensions.contains(dimension.pixelDimensions) ||
                modelDimensions.contains(dimension.rawValue)
        }
    }

    /// Models filtered to only show those supporting reference images AND at least one allowed dimension
    private var supportedModels: [ProviderModel] {
        let imageGenerateModels = providerService.models(for: .IMAGE_GENERATE)

        return imageGenerateModels.filter { model in
            model.modelParams.supportsReferenceImages &&
                modelSupportsPhotoshootDimensions(model) &&
                providerKeys.contains { $0.providerId == model.providerId }
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

    /// Available dimensions filtered by the selected model's capabilities
    private var availableDimensions: [PhotoshootDimension] {
        guard let model = selectedModel else { return PhotoshootDimension.allCases }
        let modelDimensions = model.modelParams.effectiveDimensions
        return PhotoshootDimension.allCases.filter { dimension in
            modelDimensions.contains(dimension.pixelDimensions) ||
                modelDimensions.contains(dimension.rawValue)
        }
    }

    /// Whether the form can be submitted
    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !selectedModelId.isEmpty &&
            availableDimensions.contains(selectedDimensions)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Photoshoot Name") {
                    TextField("Enter Product Name", text: $name)
                        .textFieldStyle(.roundedBorder)
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

                if !selectedModelId.isEmpty, !availableDimensions.isEmpty {
                    Section {
                        Picker("Aspect Ratio", selection: $selectedDimensions) {
                            ForEach(availableDimensions) { dimension in
                                Text(dimension.displayName).tag(dimension)
                            }
                        }
                    } header: {
                        Text("Image Dimensions")
                    } footer: {
                        Text(
                            "Select the aspect ratio for your product photographs. This determines which backdrop options are available."
                        )
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Create Photoshoot")
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
                        createPhotoshoot()
                    }
                    .disabled(!canCreate)
                }
            }
        }
        #if os(macOS)
        .frame(width: 480, height: 420)
        #endif
        .onAppear {
            providerKeysCache.loadIfNeeded(projectId: projectManager.currentProjectId, modelContext: modelContext)
            initializeDefaults()
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
                "Configure a provider with models that support reference images and standard aspect ratios."
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
        // If current dimension is not supported by new model, select first available
        if !availableDimensions.contains(selectedDimensions),
           let firstDimension = availableDimensions.first
        {
            selectedDimensions = firstDimension
        }
    }

    private func createPhotoshoot() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let photoshoot = ProductPhotoshoot(
            name: trimmedName,
            projectId: projectManager.currentProjectId,
            modelId: selectedModelId,
            providerId: selectedProviderId,
            dimensions: selectedDimensions,
            productDescription: ""
        )

        modelContext.insert(photoshoot)

        do {
            try modelContext.save()
            onCreate(photoshoot)
            isPresented = false
        } catch {
            AppLogger.ui.error("Failed to create photoshoot: \(error.localizedDescription, privacy: .public)")
        }
    }
}
