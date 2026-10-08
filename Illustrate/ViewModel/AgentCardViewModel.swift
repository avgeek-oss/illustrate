// MARK: - AgentCardViewModel.swift

// View model for image generation agent cards on the infinite canvas.
//
// This ViewModel manages the state for image generation cards in agent workflows.
// It handles configuration persistence, model selection, and parameter management
// for the card-based generation system.
//
// ## Binding Pattern
// Unlike standalone view models, AgentCardViewModel binds to an AgentCard entity:
// 1. Call `bind(to:providerKeys:)` with the card to configure
// 2. ViewModel loads existing configuration or initializes defaults
// 3. All state changes auto-save to the card's configuration
//
// ## Auto-Save Behavior
// Each @Published property has a `didSet` that triggers `saveConfiguration()`
// when `hasInitialized` is true. This ensures changes persist immediately.
// The `hasInitialized` flag prevents saves during initial loading.
//
// ## Reference Image Storage
// Reference images for agent cards are stored in the local Documents directory
// (not iCloud) with naming pattern: `imggen_ref_{cardId}_{imageId}.png`
// This keeps card configurations self-contained and portable.

import Foundation
import IllustrateProviders
import KeychainSwift
import OSLog
import SwiftUI

/// ViewModel for image generation agent cards.
///
/// This class manages the complete state for configuring an image generation
/// card in an agent workflow. It binds to an AgentCard and automatically
/// persists all configuration changes.
///
/// ## Usage
/// ```swift
/// @StateObject var viewModel = AgentCardViewModel()
/// viewModel.bind(to: card, providerKeys: keys)
/// // Changes to viewModel properties auto-save to card
/// ```
@MainActor
class AgentCardViewModel: ObservableObject {
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

    @Published var searchPrompt = "" {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var dimensions = "1024x1024" {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var quality = "standard" {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var style = "" {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var variant = "" {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var inputFidelity = "" {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var moderation = "" {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var selectedResolution = "" {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var stepsValue: Double = 28 {
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

    @Published var growMaskValue: Double = 3 {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var modelPromptEnhance = true {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var personGeneration = "" {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var selectedTools: Set<String> = [] {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var usePreviousImageAsReference = false {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var usePreviousImageAsSourceImage = false {
        didSet { if hasInitialized { saveConfiguration() } }
    }

    @Published var referenceImages: [ReferenceImage] = []
    @Published var isImagePickerOpen = false

    var setType: EnumSetType = .IMAGE_GENERATE

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

    func supportsReferenceImages() -> Bool {
        guard let modelParams = getSelectedModel()?.modelParams else { return false }
        return modelParams.supportsReferenceImages
    }

    func maxReferenceImages() -> Int {
        guard let model = getSelectedModel() else { return 0 }
        let configuredMaximum = model.modelParams.maxReferenceImages
        guard let maximumInputs = maximumCombinedImageInputs(for: model.modelCode) else {
            return configuredMaximum
        }

        let reservedInputs = (usePreviousImageAsSourceImage ? 1 : 0)
            + (usePreviousImageAsReference ? 1 : 0)
        return min(configuredMaximum, max(0, maximumInputs - reservedInputs))
    }

    func supportedReferenceTypes() -> [String] {
        getSelectedModel()?.modelParams.supportedReferenceTypes ?? []
    }

    func supportedTools() -> [String] {
        getSelectedModel()?.modelParams.supportedTools ?? []
    }

    func supportsSourceImage() -> Bool {
        getSelectedModel()?.modelParams.supportsSourceImage ?? false
    }

    func canAddMoreReferenceImages() -> Bool {
        supportsReferenceImages() && referenceImages.count < maxReferenceImages()
    }

    func addReferenceImage(image: PlatformImage) {
        guard canAddMoreReferenceImages() else { return }
        let defaultType = supportedReferenceTypes().first ?? ""
        let refImage = ReferenceImage(image: image, referenceType: defaultType)
        referenceImages.append(refImage)
        saveReferenceImage(refImage)
        saveConfiguration()
    }

    func removeReferenceImage(id: UUID) {
        deleteReferenceImageFromDocuments(id: id)
        referenceImages.removeAll { $0.id == id }
        saveConfiguration()
    }

    func updateReferenceImageType(id: UUID, newType: String) {
        if let index = referenceImages.firstIndex(where: { $0.id == id }) {
            referenceImages[index].referenceType = newType
            saveConfiguration()
        }
    }

    func handleProviderChange() {
        selectedModelId = getSupportedModels().first?.modelId.uuidString ?? ""
        handleModelChange()
    }

    func handleModelChange() {
        guard let modelParams = getSelectedModel()?.modelParams else { return }

        let effectiveDimensions = modelParams.effectiveDimensions
        if !effectiveDimensions.contains(dimensions) {
            dimensions = effectiveDimensions.first ?? "1024x1024"
        }

        quality = modelParams.supportedImageQualities.first ?? ""
        variant = modelParams.supportedVariants.first ?? ""
        style = modelParams.supportedStyles.first ?? ""
        inputFidelity = modelParams.supportedInputFidelities.first ?? ""
        moderation = modelParams.supportedModerations.first ?? ""

        if modelParams.supportsImageResolution {
            selectedResolution = modelParams.supportedImageResolutions.first ?? ""
        }
        if let stepsRange = modelParams.supportedStepsRange {
            stepsValue = Double(stepsRange.min + stepsRange.max) / 2.0
        }
        if let guidanceRange = modelParams.supportedGuidanceRange {
            guidanceValue = (guidanceRange.min + guidanceRange.max) / 2
        }
        if let safetyRange = modelParams.supportedSafetyRange {
            safetyValue = Double(safetyRange.min + safetyRange.max) / 2.0
        }
        if let growMaskRange = modelParams.supportedGrowMaskRange {
            growMaskValue = Double(growMaskRange.min + growMaskRange.max) / 2.0
        }
        seedValue = ""
        selectedTools = []
        modelPromptEnhance = true
        personGeneration = modelParams.supportedPersonGenerationOptions.first ?? ""

        if !modelParams.supportsReferenceImages {
            for refImage in referenceImages {
                deleteReferenceImageFromDocuments(id: refImage.id)
            }
            referenceImages = []
        }
    }

    var hasContent: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            usePreviousImageAsReference ||
            !referenceImages.isEmpty
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

        let config = card.imageGenerationConfiguration
        let hasSavedConfig = !config.selectedProviderId.isEmpty || !config.prompt.isEmpty

        if hasSavedConfig {
            selectedProviderId = config.selectedProviderId
            selectedModelId = config.selectedModelId
            prompt = config.prompt
            negativePrompt = config.negativePrompt
            searchPrompt = config.searchPrompt
            dimensions = config.selectedDimensions
            quality = config.selectedQuality
            style = config.selectedStyle
            variant = config.selectedVariant
            inputFidelity = config.selectedInputFidelity
            moderation = config.selectedModeration
            selectedResolution = config.selectedResolution
            stepsValue = config.stepsValue
            guidanceValue = config.guidanceValue
            seedValue = config.seedValue
            safetyValue = config.safetyValue
            growMaskValue = config.growMaskValue
            modelPromptEnhance = config.modelPromptEnhance
            personGeneration = config.personGeneration
            selectedTools = Set(config.selectedTools)
            usePreviousImageAsReference = config.usePreviousImageAsReference
            usePreviousImageAsSourceImage = config.usePreviousImageAsSourceImage

            loadReferenceImages(from: config.referenceImages)
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
        dimensions = modelParams.effectiveDimensions.first ?? "1024x1024"
        quality = modelParams.supportedImageQualities.first ?? "standard"
        style = modelParams.supportedStyles.first ?? ""
        variant = modelParams.supportedVariants.first ?? ""
        inputFidelity = modelParams.supportedInputFidelities.first ?? ""
        moderation = modelParams.supportedModerations.first ?? ""

        if modelParams.supportsImageResolution {
            selectedResolution = modelParams.supportedImageResolutions.first ?? ""
        }
        if let stepsRange = modelParams.supportedStepsRange {
            stepsValue = Double(stepsRange.min + stepsRange.max) / 2.0
        }
        if let guidanceRange = modelParams.supportedGuidanceRange {
            guidanceValue = (guidanceRange.min + guidanceRange.max) / 2
        }
        if let safetyRange = modelParams.supportedSafetyRange {
            safetyValue = Double(safetyRange.min + safetyRange.max) / 2.0
        }
        if let growMaskRange = modelParams.supportedGrowMaskRange {
            growMaskValue = Double(growMaskRange.min + growMaskRange.max) / 2.0
        }
        if modelParams.supportsPersonGeneration {
            personGeneration = modelParams.supportedPersonGenerationOptions.first ?? ""
        }
    }

    private func loadReferenceImages(from configs: [ReferenceImageConfig]) {
        guard let card else { return }

        referenceImages = configs.compactMap { config in
            let imageName = "imggen_ref_\(card.id.uuidString)_\(config.id.uuidString)"
            guard let image = loadImageFromDocumentsDirectory(withName: imageName) else { return nil }
            return ReferenceImage(id: config.id, image: image, referenceType: config.referenceType)
        }
    }

    private func saveConfiguration() {
        guard let card, hasInitialized else { return }

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
        config.selectedInputFidelity = inputFidelity
        config.selectedModeration = moderation
        config.selectedResolution = selectedResolution
        config.stepsValue = stepsValue
        config.guidanceValue = guidanceValue
        config.seedValue = seedValue
        config.safetyValue = safetyValue
        config.growMaskValue = growMaskValue
        config.modelPromptEnhance = modelPromptEnhance
        config.personGeneration = personGeneration
        config.selectedTools = Array(selectedTools)
        config.usePreviousImageAsReference = usePreviousImageAsReference
        config.usePreviousImageAsSourceImage = usePreviousImageAsSourceImage
        config.referenceImages = referenceImages.map { refImage in
            ReferenceImageConfig(id: refImage.id, imagePath: "", referenceType: refImage.referenceType)
        }

        card.imageGenerationConfiguration = config
    }

    private func saveReferenceImage(_ refImage: ReferenceImage) {
        guard let card else { return }
        let imageName = "imggen_ref_\(card.id.uuidString)_\(refImage.id.uuidString)"

        #if os(macOS)
        if let tiffData = refImage.image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:])
        {
            _ = saveImageToDocumentsDirectory(imageData: pngData, withName: imageName)
        }
        #else
        if let pngData = refImage.image.pngData() {
            _ = saveImageToDocumentsDirectory(imageData: pngData, withName: imageName)
        }
        #endif
    }

    private func deleteReferenceImageFromDocuments(id: UUID) {
        guard let card else { return }
        let imageName = "imggen_ref_\(card.id.uuidString)_\(id.uuidString)"
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let imageFileURL = documentsURL.appendingPathComponent("\(imageName).png")
        try? fileManager.removeItem(at: imageFileURL)
    }
}
