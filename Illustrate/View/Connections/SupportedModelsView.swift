// MARK: - SupportedModelsView.swift

// Displays a comprehensive catalog of all supported AI models.
//
// This view is accessible from the macOS Help menu under "Supported Models".
// It provides users with a reference guide to understand what each model can do.
//
// ## Structure
// - Models listed with provider logo
// - Grouped by type (Image Generate, Video Generate, Video Extend)
// - Simple capability tags for key features

import IllustrateProviders
import SwiftUI

#if os(macOS)

// MARK: - Menu Commands

/// Commands for the Help menu to access Supported Models.
struct SupportedModelsCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("Supported Models") {
                openWindow(id: "supported-models")
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])

            Button("Erase & Reset Application") {
                openWindow(id: "erase-reset")
            }

            Divider()

            Link("Illustrate Help", destination: URL(string: "https://illustrate.so")!)
        }
    }
}

// MARK: - Main View

/// A comprehensive view showing all supported models and their capabilities.
struct SupportedModelsView: View {
    @Environment(\.providerService) private var providerService
    @State private var searchText = ""

    private var allModels: [ProviderModel] {
        providerService.activeModels
    }

    private var filteredModels: [ProviderModel] {
        if searchText.isEmpty {
            return allModels
        }
        return allModels.filter { model in
            model.modelName.localizedCaseInsensitiveContains(searchText) ||
                model.modelDescription.localizedCaseInsensitiveContains(searchText) ||
                providerName(for: model).localizedCaseInsensitiveContains(searchText)
        }
    }

    private var imageModels: [ProviderModel] {
        filteredModels.filter { $0.modelSetType == .IMAGE_GENERATE }
    }

    private var videoModels: [ProviderModel] {
        filteredModels.filter { $0.modelSetType == .VIDEO_GENERATE }
    }

    private var videoExtendModels: [ProviderModel] {
        filteredModels.filter { $0.modelSetType == .VIDEO_EXTEND }
    }

    var body: some View {
        List {
            if !imageModels.isEmpty {
                Section("Image Generation") {
                    ForEach(imageModels, id: \.modelId) { model in
                        ModelRow(model: model)
                    }
                }
            }

            if !videoModels.isEmpty {
                Section("Video Generation") {
                    ForEach(videoModels, id: \.modelId) { model in
                        ModelRow(model: model)
                    }
                }
            }

            if !videoExtendModels.isEmpty {
                Section("Video Extension") {
                    ForEach(videoExtendModels, id: \.modelId) { model in
                        ModelRow(model: model)
                    }
                }
            }

            if filteredModels.isEmpty {
                ContentUnavailableView(
                    "No Models Found",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term")
                )
            }
        }
        .searchable(text: $searchText, prompt: "Search models...")
        .frame(minWidth: 600, minHeight: 400)
    }

    private func providerName(for model: ProviderModel) -> String {
        providers.first { $0.providerId == model.providerId }?.providerName ?? ""
    }
}

// MARK: - Model Row

/// Individual model row showing provider logo, name, description, and capabilities.
private struct ModelRow: View {
    let model: ProviderModel

    private var provider: Provider? {
        providers.first { $0.providerId == model.providerId }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let provider {
                Image(providerArtworkName(code: provider.providerCode, variant: .square))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(model.modelName)
                    .font(.body.bold())

                CapabilitiesView(params: model.modelParams)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Capabilities View

/// Displays selected model capabilities as tags.
private struct CapabilitiesView: View {
    let params: ModelParams

    var body: some View {
        HStack(spacing: 4) {
            if params.active {
                CapabilityTag(text: "Active", color: .green)
            } else {
                CapabilityTag(text: "Deprecated", color: .red)
            }

            if params.supportsReferenceImages || params.supportsSourceImage {
                CapabilityTag(text: "Supports Image Inputs", color: .gray)
            }

            if params.supportsMask {
                CapabilityTag(text: "Supports Mask Inputs", color: .gray)
            }

            if params.supportsSeed {
                CapabilityTag(text: "Supports Seed", color: .gray)
            }
        }
    }
}

// MARK: - Capability Tag

/// Individual capability tag.
private struct CapabilityTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .cornerRadius(4)
    }
}

#endif
