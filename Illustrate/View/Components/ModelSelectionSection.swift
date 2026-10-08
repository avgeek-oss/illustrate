// MARK: - ModelSelectionSection.swift

// Reusable component for provider and model selection.
//
// Provides a consistent UI for selecting AI provider and model
// across all generation views. Automatically filters providers
// and models based on:
// - Connected provider keys
// - Set type (image generate, video generate, etc.)
// - Active status
// - Optional custom filter
//
// ## Components
// - ProviderPicker: Dropdown for provider selection
// - ModelPicker: Dropdown for model selection
//
// ## Filtering Logic
// 1. Providers: Must have API key configured and have active models for set type
// 2. Models: Must be active, match set type, and pass custom filter (if any)

import IllustrateProviders
import SwiftUI

// MARK: - Model Selection Section

/// Reusable section for selecting provider and model with filtering.
struct ModelSelectionSection: View {
    @Binding var selectedProviderId: String
    @Binding var selectedModelId: String

    let providerKeys: [ProviderKey]
    let setType: EnumSetType

    var onProviderChange: (() -> Void)?
    var onModelChange: (() -> Void)?

    var customModelFilter: ((ProviderModel) -> Bool)?

    var body: some View {
        Section(header: Text("Select Model")) {
            ProviderPicker(
                selection: $selectedProviderId,
                providers: supportedProviders,
                onChange: onProviderChange
            )

            ModelPicker(
                selection: $selectedModelId,
                models: supportedModels,
                onChange: onModelChange
            )
        }
    }

    private var supportedProviders: [Provider] {
        providers.filter { provider in
            providerKeys.contains { $0.providerId == provider.providerId } &&
                ProviderService.shared.allModels.contains {
                    $0.providerId == provider.providerId &&
                        $0.modelSetType == setType &&
                        $0.active
                }
        }
    }

    private var supportedModels: [ProviderModel] {
        guard !selectedProviderId.isEmpty else { return [] }

        if let customFilter = customModelFilter {
            return ProviderService.shared.allModels.filter { model in
                model.providerId.uuidString == selectedProviderId &&
                    model.active &&
                    customFilter(model)
            }
        }

        return ProviderService.shared.models(for: setType).filter {
            $0.providerId.uuidString == selectedProviderId
        }
    }
}

// MARK: - Model Selection Section with Custom Provider Filter

/// A more flexible model selection section that allows custom provider and model filtering.
struct CustomModelSelectionSection: View {
    @Binding var selectedProviderId: String
    @Binding var selectedModelId: String

    let supportedProviders: [Provider]
    let supportedModels: [ProviderModel]

    var onProviderChange: (() -> Void)?
    var onModelChange: (() -> Void)?

    var body: some View {
        Section(header: Text("Select Model")) {
            ProviderPicker(
                selection: $selectedProviderId,
                providers: supportedProviders,
                onChange: onProviderChange
            )

            ModelPicker(
                selection: $selectedModelId,
                models: supportedModels,
                onChange: onModelChange
            )
        }
    }
}

// MARK: - Provider Keys Helper

/// Helper to get filtered provider keys for the current project.
/// Can be used as a computed property pattern replacement.
struct ProviderKeysHelper {
    let allProviderKeys: [ProviderKey]
    let currentProjectId: UUID

    var filteredKeys: [ProviderKey] {
        allProviderKeys.filter { $0.projectId == currentProjectId }
    }

    func supportedProviders(for setType: EnumSetType) -> [Provider] {
        providers.filter { provider in
            filteredKeys.contains { $0.providerId == provider.providerId } &&
                ProviderService.shared.allModels.contains {
                    $0.providerId == provider.providerId &&
                        $0.modelSetType == setType &&
                        $0.active
                }
        }
    }

    func supportedModels(for setType: EnumSetType, providerId: String) -> [ProviderModel] {
        guard !providerId.isEmpty else { return [] }

        return ProviderService.shared.models(for: setType).filter {
            $0.providerId.uuidString == providerId
        }
    }

    func firstProvider(for setType: EnumSetType) -> Provider? {
        supportedProviders(for: setType).first
    }

    func firstModel(for setType: EnumSetType, providerId: String) -> ProviderModel? {
        supportedModels(for: setType, providerId: providerId).first
    }
}
