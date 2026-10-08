// MARK: - AgentVideoCardViewModel.swift

// View model for video generation agent cards on the infinite canvas.
//
// Similar to AgentCardViewModel but for video generation cards. Manages
// video-specific parameters like duration, FPS, audio generation, and
// resolution settings.
//
// ## Binding Pattern
// Same as AgentCardViewModel - binds to an AgentCard and auto-saves:
// 1. Call `bind(to:providerKeys:)` with the video generation card
// 2. ViewModel loads existing configuration or initializes defaults
// 3. All state changes auto-save to the card's videoGenerationConfiguration
//
// ## Video-Specific Parameters
// In addition to standard generation parameters, manages:
// - `durationSeconds`: Video length
// - `selectedFPS`: Frame rate
// - `generateAudio`: Whether to generate audio track
// - `selectedResolution`: Video resolution tier
//
// ## Source Image Support
// The `usePreviousImageAsSourceImage` flag enables using the output
// from a connected upstream card as the starting frame for video generation.

import Foundation
import IllustrateProviders
import KeychainSwift
import OSLog
import SwiftUI

/// ViewModel for video generation agent cards.
///
/// This class manages the complete state for configuring a video generation
/// card in an agent workflow. It binds to an AgentCard and automatically
/// persists all configuration changes to the card's videoGenerationConfiguration.
@MainActor
class AgentVideoCardViewModel: ObservableObject {
    let providerService: ProviderService

    private weak var card: AgentCard?
    private var hasInitialized = false

    @Published var selectedProviderId = "" {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var selectedModelId = "" {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var prompt = "" {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var negativePrompt = "" {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var dimensions = "1280x720" {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var selectedResolution = "" {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var durationSeconds = 5 {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var selectedFPS = 24 {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var generateAudio = false {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var guidanceValue = 3.5 {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var seedValue = "" {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var safetyValue: Double = 5 {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var modelPromptEnhance = true {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var selectedTools: Set<String> = [] {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var usePreviousImageAsSourceImage = false {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    var setType: EnumSetType = .VIDEO_GENERATE

    init(providerService: ProviderService = ProviderService.shared) {
        self.providerService = providerService
    }

    func bind(to card: AgentCard, providerKeys: [ProviderKey]) {
        self.card = card
        loadConfiguration(providerKeys: providerKeys)
        hasInitialized = true
    }

    func getSupportedModels() -> [ProviderModel] {
        guard !selectedProviderId.isEmpty else { return [] }
        return providerService.models(for: setType).filter {
            $0.providerId.uuidString == selectedProviderId
        }
    }

    func getSelectedModel() -> ProviderModel? {
        guard !selectedModelId.isEmpty else { return nil }
        return providerService.model(by: selectedModelId)
    }

    func getSupportedProviders(providerKeys: [ProviderKey]) -> [Provider] {
        let keyProviderIds = Set(providerKeys.map(\.providerId))
        let modelsForType = providerService.models(for: setType)
        let modelProviderIds = Set(modelsForType.map(\.providerId))
        return providers.filter { keyProviderIds.contains($0.providerId) && modelProviderIds.contains($0.providerId) }
    }

    func supportsSourceImage() -> Bool {
        getSelectedModel()?.modelParams.supportsSourceImage ?? false
    }

    func supportedTools() -> [String] {
        getSelectedModel()?.modelParams.supportedTools ?? []
    }

    func supportedVideoDurations() -> [Int] {
        getSelectedModel()?.modelParams.supportedVideoDurations ?? []
    }

    func supportedVideoFPS() -> [Int] {
        getSelectedModel()?.modelParams.supportedVideoFPS ?? []
    }

    func supportedVideoResolutions() -> [String] {
        getSelectedModel()?.modelParams.supportedVideoResolutions ?? []
    }

    func supportsAudio() -> Bool {
        getSelectedModel()?.modelParams.supportsAudio ?? false
    }

    func handleProviderChange() {
        selectedModelId = getSupportedModels().first?.modelId.uuidString ?? ""
        handleModelChange()
    }

    func handleModelChange() {
        guard let modelParams = getSelectedModel()?.modelParams else { return }

        let effectiveDimensions = modelParams.effectiveDimensions
        if !effectiveDimensions.contains(dimensions) {
            dimensions = effectiveDimensions.first ?? "1280x720"
        }

        if modelParams.supportsImageResolution {
            selectedResolution = modelParams.supportedImageResolutions.first ?? ""
        }

        let supportedDurations = modelParams.supportedVideoDurations
        if !supportedDurations.isEmpty, !supportedDurations.contains(durationSeconds) {
            durationSeconds = supportedDurations.first ?? 5
        }

        let supportedFPS = modelParams.supportedVideoFPS
        if !supportedFPS.isEmpty, !supportedFPS.contains(selectedFPS) {
            selectedFPS = supportedFPS.first ?? 24
        }

        if let guidanceRange = modelParams.supportedGuidanceRange {
            guidanceValue = (guidanceRange.min + guidanceRange.max) / 2
        }
        if let safetyRange = modelParams.supportedSafetyRange {
            safetyValue = Double(safetyRange.min + safetyRange.max) / 2.0
        }

        seedValue = ""
        selectedTools = []
        modelPromptEnhance = true
        generateAudio = false
    }

    var hasContent: Bool {
        if getSelectedModel()?.modelCode == .XAI_GROK_IMAGINE_VIDEO_1_5 {
            return usePreviousImageAsSourceImage
        }
        return !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            usePreviousImageAsSourceImage
    }

    var hasSupportedModel: Bool {
        !selectedModelId.isEmpty
    }

    var selectedProviderName: String {
        if selectedProviderId.isEmpty {
            return "Select Provider"
        }
        return providers.first { $0.providerId.uuidString == selectedProviderId }?.providerName ?? "Select Provider"
    }

    var selectedModelName: String {
        if selectedModelId.isEmpty {
            return "Select Model"
        }
        return getSelectedModel()?.modelName ?? "Select Model"
    }

    private func loadConfiguration(providerKeys: [ProviderKey]) {
        guard let card else { return }

        let config = card.videoGenerationConfiguration
        let hasSavedConfig = !config.selectedProviderId.isEmpty || !config.prompt.isEmpty

        if hasSavedConfig {
            selectedProviderId = config.selectedProviderId
            selectedModelId = config.selectedModelId
            prompt = config.prompt
            negativePrompt = config.negativePrompt
            dimensions = config.selectedDimensions
            selectedResolution = config.selectedResolution
            durationSeconds = config.durationSeconds
            selectedFPS = config.selectedFPS
            generateAudio = config.generateAudio
            guidanceValue = config.guidanceValue
            seedValue = config.seedValue
            safetyValue = config.safetyValue
            modelPromptEnhance = config.modelPromptEnhance
            selectedTools = Set(config.selectedTools)
            usePreviousImageAsSourceImage = config.usePreviousImageAsSourceImage
        } else {
            initializeDefaults(providerKeys: providerKeys)
        }
    }

    private func initializeDefaults(providerKeys: [ProviderKey]) {
        let supportedProviders = getSupportedProviders(providerKeys: providerKeys)

        if let firstProvider = supportedProviders.first {
            selectedProviderId = firstProvider.providerId.uuidString

            if let firstModel = getSupportedModels().first {
                selectedModelId = firstModel.modelId.uuidString

                if let modelParams = getSelectedModel()?.modelParams {
                    initializeModelParams(modelParams: modelParams)
                }
            }
        }
    }

    private func initializeModelParams(modelParams: ModelParams) {
        dimensions = modelParams.effectiveDimensions.first ?? "1280x720"

        if modelParams.supportsImageResolution {
            selectedResolution = modelParams.supportedImageResolutions.first ?? ""
        }

        if !modelParams.supportedVideoDurations.isEmpty {
            durationSeconds = modelParams.supportedVideoDurations.first ?? 5
        }

        if !modelParams.supportedVideoFPS.isEmpty {
            selectedFPS = modelParams.supportedVideoFPS.first ?? 24
        }

        if let guidanceRange = modelParams.supportedGuidanceRange {
            guidanceValue = (guidanceRange.min + guidanceRange.max) / 2
        }
        if let safetyRange = modelParams.supportedSafetyRange {
            safetyValue = Double(safetyRange.min + safetyRange.max) / 2.0
        }
    }

    private func saveConfiguration() {
        guard let card, hasInitialized else { return }

        var config = VideoGenerationConfiguration()
        config.selectedProviderId = selectedProviderId
        config.selectedModelId = selectedModelId
        config.prompt = prompt
        config.negativePrompt = negativePrompt
        config.selectedDimensions = dimensions
        config.selectedResolution = selectedResolution
        config.durationSeconds = durationSeconds
        config.selectedFPS = selectedFPS
        config.generateAudio = generateAudio
        config.guidanceValue = guidanceValue
        config.seedValue = seedValue
        config.safetyValue = safetyValue
        config.modelPromptEnhance = modelPromptEnhance
        config.selectedTools = Array(selectedTools)
        config.usePreviousImageAsSourceImage = usePreviousImageAsSourceImage

        card.videoGenerationConfiguration = config
    }
}
