import IllustrateProviders
import KeychainSwift
import SwiftData
import SwiftUI

#if os(macOS)
private func aspectRatioForDimensions(_ dims: String) -> CGFloat {
    let parts = dims.contains(":") ? dims.split(separator: ":") : dims.split(separator: "x")
    guard parts.count == 2,
          let width = Double(parts[0]),
          let height = Double(parts[1]),
          height > 0
    else { return 1.0 }
    return CGFloat(width / height)
}

struct MenuBarGenerateView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var providerKeysCache = ProviderKeysCache.shared
    @StateObject private var viewModel = MenuBarGenerateViewModel()

    @FocusState private var isPromptFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if providerKeysCache.providerKeys.isEmpty {
                noProvidersView
            } else if let result = viewModel.result {
                resultView(result)
            } else if viewModel.isGenerating {
                generatingView
            } else {
                generateForm
            }
        }
        .frame(width: 320)
        .onAppear {
            providerKeysCache.loadIfNeeded(
                projectId: ProjectManager.shared.currentProjectId,
                modelContext: modelContext
            )
            viewModel.initialize(providerKeys: providerKeysCache.providerKeys)
        }
        .onChange(of: providerKeysCache.providerKeys) { _, _ in
            viewModel.initialize(providerKeys: providerKeysCache.providerKeys)
        }
    }

    private var generateForm: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.prompt)
                    .font(.body)
                    .frame(height: 60)
                    .scrollContentBackground(.hidden)
                    .focused($isPromptFocused)
                    .padding(6)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                isPromptFocused
                                    ? Color.accentColor
                                    : Color(nsColor: .separatorColor),
                                lineWidth: 1
                            )
                    )

                if viewModel.prompt.isEmpty {
                    Text("Describe what you want to generate...")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .allowsHitTesting(false)
                }
            }

            dropdownRow(
                value: viewModel.selectedProvider?.providerName ?? "Provider",
                options: viewModel.supportedProviders.map(\.providerName)
            ) { providerName in
                if let provider = viewModel.supportedProviders.first(where: { $0.providerName == providerName }) {
                    viewModel.selectProvider(provider.providerId.uuidString)
                }
            }

            dropdownRow(
                value: viewModel.selectedModel?.modelName ?? "Model",
                options: viewModel.supportedModels.map(\.modelName)
            ) { modelName in
                if let model = viewModel.supportedModels.first(where: { $0.modelName == modelName }) {
                    viewModel.selectModel(model.modelId.uuidString)
                }
            }

            if !viewModel.supportedDimensions.isEmpty {
                dropdownRow(
                    value: viewModel.dimensions.contains(":")
                        ? viewModel.dimensions
                        : "\(viewModel.dimensions) (\(getAspectRatio(dimension: viewModel.dimensions).ratio))",
                    options: viewModel.supportedDimensions.map { dim in
                        dim.contains(":")
                            ? dim
                            : "\(dim) (\(getAspectRatio(dimension: dim).ratio))"
                    }
                ) { selected in
                    if let dim = viewModel.supportedDimensions.first(where: {
                        let display = $0.contains(":")
                            ? $0
                            : "\($0) (\(getAspectRatio(dimension: $0).ratio))"
                        return display == selected
                    }) {
                        viewModel.dimensions = dim
                    }
                }
            }

            Button {
                viewModel.generate(
                    providerKeys: providerKeysCache.providerKeys,
                    projectId: ProjectManager.shared.currentProjectId,
                    modelContext: modelContext
                )
            } label: {
                Text("Generate")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canGenerate)
        }
        .padding(12)
    }

    private func dropdownRow(
        value: String,
        options: [String],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) {
                    onSelect(option)
                }
            }
        } label: {
            HStack {
                Text(value)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var generatingView: some View {
        VStack(spacing: 8) {
            Spacer()
            GradientSpinner()
            Text("Generating...")
            Spacer()
        }
        .frame(width: 320, height: 200)
    }

    private func resultView(_ result: MenuBarGenerateResult) -> some View {
        VStack(spacing: 12) {
            if result.isSuccessful, let generationId = result.generationId {
                ICloudImageLoader(
                    imageName: ".\(generationId.uuidString)_o50",
                    aspectRatio: aspectRatioForDimensions(viewModel.dimensions),
                    showLoading: true
                ) { image in
                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Color.gray.opacity(0.2)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .frame(maxHeight: 240)
            } else {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundStyle(.orange)
                Text(result.errorMessage ?? "Generation failed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                Spacer()
            }

            HStack(spacing: 8) {
                if result.isSuccessful, let generationId = result.generationId {
                    Button("Copy") {
                        copyImage(generationId: generationId)
                    }
                    .buttonStyle(.bordered)
                }

                Button("Regenerate") {
                    viewModel.regenerate(
                        providerKeys: providerKeysCache.providerKeys,
                        projectId: ProjectManager.shared.currentProjectId,
                        modelContext: modelContext
                    )
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canGenerate)

                Spacer()

                Button("Reset") {
                    viewModel.reset()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
    }

    private func copyImage(generationId: UUID) {
        let imageName = ".\(generationId.uuidString)_o50"
        if let image = loadImageFromiCloud(imageName) ?? loadImageFromiCloud(generationId.uuidString) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
        }
    }

    private var noProvidersView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No providers connected")
                .font(.headline)
            Text("Open Illustrate to connect a provider.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Illustrate") {
                openMainWindow()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
            Spacer()
        }
        .padding(16)
        .frame(width: 320, height: 180)
    }

    private func openMainWindow() {
        if let window = NSApp.windows.first(where: { $0.isVisible && $0.title.isEmpty == false }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

@MainActor
class MenuBarGenerateViewModel: ObservableObject {
    @Published var prompt = ""
    @Published var isGenerating = false
    @Published var result: MenuBarGenerateResult?

    @Published var selectedProviderId = ""
    @Published var selectedModelId = ""
    @Published var dimensions = ""

    private let providerService = ProviderService.shared
    private let queueManager = QueueManager.shared
    private let keychain: KeychainSwift = {
        let kc = KeychainSwift()
        kc.accessGroup = TEAM_KEYCHAIN_AG
        kc.synchronizable = true
        return kc
    }()

    private var currentQueueItem: QueueItem?

    var supportedProviders: [Provider] {
        let keyProviderIds = Set(
            ProviderKeysCache.shared.providerKeys.map(\.providerId)
        )
        let modelProviderIds = Set(
            providerService.models(for: .IMAGE_GENERATE).map(\.providerId)
        )
        return providers.filter {
            keyProviderIds.contains($0.providerId) &&
                modelProviderIds.contains($0.providerId)
        }
    }

    var supportedModels: [ProviderModel] {
        guard !selectedProviderId.isEmpty else { return [] }
        return providerService.models(for: .IMAGE_GENERATE)
            .filter { $0.providerId.uuidString == selectedProviderId && $0.active }
    }

    var supportedDimensions: [String] {
        guard let model = selectedModel else { return [] }
        return model.modelParams.effectiveDimensions
    }

    var selectedProvider: Provider? {
        guard !selectedProviderId.isEmpty else { return nil }
        return getProvider(providerId: UUID(uuidString: selectedProviderId)!)
    }

    var selectedModel: ProviderModel? {
        guard !selectedModelId.isEmpty else { return nil }
        return providerService.model(by: selectedModelId)
    }

    var canGenerate: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !selectedProviderId.isEmpty &&
            !selectedModelId.isEmpty &&
            !dimensions.isEmpty
    }

    func initialize(providerKeys: [ProviderKey]) {
        guard !providerKeys.isEmpty, selectedModelId.isEmpty else { return }

        let available = supportedProviders
        if let savedProviderId = UserDefaults.standard.string(forKey: "menuBar_lastProviderId"),
           available.contains(where: { $0.providerId.uuidString == savedProviderId })
        {
            selectedProviderId = savedProviderId
        } else if let first = available.first {
            selectedProviderId = first.providerId.uuidString
        }

        let models = supportedModels
        if let savedModelId = UserDefaults.standard.string(forKey: "menuBar_lastModelId"),
           models.contains(where: { $0.modelId.uuidString == savedModelId })
        {
            selectedModelId = savedModelId
        } else {
            selectedModelId = models.first?.modelId.uuidString ?? ""
        }

        updateDimensions()
    }

    func selectProvider(_ providerId: String) {
        selectedProviderId = providerId
        UserDefaults.standard.set(providerId, forKey: "menuBar_lastProviderId")
        let models = supportedModels
        selectedModelId = models.first?.modelId.uuidString ?? ""
        updateDimensions()
    }

    func selectModel(_ modelId: String) {
        selectedModelId = modelId
        UserDefaults.standard.set(modelId, forKey: "menuBar_lastModelId")
        updateDimensions()
    }

    private func updateDimensions() {
        if let model = selectedModel {
            dimensions = model.modelParams.effectiveDimensions.first ?? ""
        }
    }

    func generate(
        providerKeys: [ProviderKey],
        projectId: UUID,
        modelContext: ModelContext
    ) {
        guard canGenerate else { return }

        let keychainKey = ProjectManager.keychainKey(
            projectId: projectId,
            providerId: UUID(uuidString: selectedProviderId)!
        )
        guard let providerSecret = keychain.get(keychainKey) else { return }

        guard let providerKey = providerKeys.first(where: {
            $0.providerId.uuidString == selectedProviderId
        }) else { return }

        guard let providerKeyInfo = try? providerKey.toProviderKeyInfo() else { return }

        let request = ImageGenerationRequest(
            modelId: selectedModelId,
            prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
            negativePrompt: nil,
            variant: "",
            quality: "",
            style: "",
            dimensions: dimensions,
            providerKey: providerKeyInfo,
            providerSecret: providerSecret
        )

        isGenerating = true
        result = nil

        let queueItem = queueManager.submitImageGeneration(
            request: request,
            modelContext: modelContext,
            source: .MENU_BAR
        )
        currentQueueItem = queueItem

        Task {
            while queueItem.status == .IN_PROGRESS {
                try? await Task.sleep(for: .milliseconds(300))
            }

            isGenerating = false
            if queueItem.status == .SUCCESSFUL, let setId = queueItem.resultSetId {
                let descriptor = FetchDescriptor<Generation>(
                    predicate: #Predicate { $0.setId == setId }
                )
                let generation = try? modelContext.fetch(descriptor).first
                result = MenuBarGenerateResult(
                    isSuccessful: true,
                    generationId: generation?.id,
                    errorMessage: nil
                )
            } else {
                result = MenuBarGenerateResult(
                    isSuccessful: false,
                    generationId: nil,
                    errorMessage: queueItem.errorMessage ?? "Generation failed"
                )
            }
        }
    }

    func regenerate(
        providerKeys: [ProviderKey],
        projectId: UUID,
        modelContext: ModelContext
    ) {
        guard canGenerate else { return }
        result = nil
        generate(
            providerKeys: providerKeys,
            projectId: projectId,
            modelContext: modelContext
        )
    }

    func reset() {
        prompt = ""
        isGenerating = false
        result = nil
        currentQueueItem = nil
    }
}

struct MenuBarGenerateResult {
    let isSuccessful: Bool
    let generationId: UUID?
    let errorMessage: String?
}
#endif
