// MARK: - BaseImageViewModel.swift

// Base view model for all image generation views sharing common functionality.
//
// This abstract-style class provides shared state and logic for:
// - ImageGenerateView (text-to-image generation)
// - Image editing views (inpaint, outpaint, etc.)
// - Agent card image configuration
//
// ## Architecture
// The ViewModel follows MVVM pattern with:
// - Published state properties for UI binding
// - Methods for handling user interactions
// - Keychain integration for API key retrieval
// - Queue submission for async generation
//
// ## State Categories
// - **Model Selection**: Provider and model picker state
// - **Prompt State**: Text inputs for generation
// - **Model Parameters**: Dimensions, quality, style, etc.
// - **Image State**: Selected source/reference images
// - **Navigation State**: For result view navigation
//
// ## Model Parameter Handling
// When a user selects a different model, `handleModelChange()` updates
// all parameter states to valid values for the new model based on
// its ModelParams capability descriptor.
//
// ## Queue Integration
// `submitToQueue()` packages current state into an ImageGenerationRequest
// and submits it to QueueManager for async execution.

import Foundation
import IllustrateProviders
import KeychainSwift
import OSLog
import PhotosUI
import SwiftData
import SwiftUI

/// Base ViewModel for image generation views sharing common state and functionality.
///
/// This class encapsulates all the state needed for image generation forms:
/// - Model/provider selection
/// - Prompt and parameter configuration
/// - Source and reference image management
/// - Queue submission
///
/// Views using this ViewModel bind to its @Published properties and call
/// its methods for user interactions. The class handles model capability
/// checking and parameter validation automatically.
@MainActor
class BaseImageViewModel: ObservableObject {
    let providerService: ProviderService
    let keychain: KeychainSwift

    // MARK: - Model Selection State

    @Published var selectedProviderId = ""
    @Published var selectedModelId = ""

    // MARK: - Prompt State

    @Published var prompt = ""
    @Published var negativePrompt = ""
    @Published var searchPrompt = ""

    // MARK: - Model Parameters State

    @Published var dimensions = ""
    @Published var quality = ""
    @Published var style = ""
    @Published var variant = ""
    @Published var background = ""
    @Published var inputFidelity = ""
    @Published var moderation = ""
    @Published var numberOfImages = 1
    @Published var promptEnhanceOpted = false
    @Published var selectedResolution = ""
    @Published var selectedTools: Set<String> = []
    @Published var stepsValue: Double = 28
    @Published var guidanceValue = 3.5
    @Published var seedValue = ""
    @Published var safetyValue: Double = 5
    @Published var growMaskValue: Double = 3
    @Published var modelPromptEnhance = true
    @Published var personGeneration = ""

    // MARK: - Primary Reference Image State

    @Published var isPhotoPickerOpen = false
    @Published var selectedImageItem: PhotosPickerItem?
    @Published var selectedImage: PlatformImage?
    @Published var colorPalette: [String] = []
    @Published var isCropSheetOpen = false
    @Published var cropSessionId = UUID()

    // MARK: - Navigation State

    @Published var isNavigationActive = false
    @Published var selectedSetId: UUID?

    // MARK: - Additional Reference Images State

    @Published var referenceImages: [ReferenceImage] = []
    @Published var selectedReferenceImageItem: PhotosPickerItem?
    @Published var isReferenceImagePickerOpen = false
    @Published var isReferenceImageCropSheetOpen = false
    @Published var referenceImageCropSessionId = UUID()
    @Published var pendingReferenceImage: PlatformImage?
    @Published var pendingReferenceImageType = ""

    // MARK: - Set Type (to be set by subclass or view)

    var setType: EnumSetType = .IMAGE_GENERATE

    // MARK: - Persistence Keys

    private static let lastProviderIdKey = "quickAction.image.lastProviderId"
    private static let lastModelIdKey = "quickAction.image.lastModelId"
    private static let lastDimensionsKey = "quickAction.image.lastDimensions"

    // MARK: - Persistence Methods

    func saveProviderSelection() {
        UserDefaults.standard.set(selectedProviderId, forKey: Self.lastProviderIdKey)
    }

    func saveModelSelection() {
        UserDefaults.standard.set(selectedModelId, forKey: Self.lastModelIdKey)
    }

    func saveDimensionsSelection() {
        UserDefaults.standard.set(dimensions, forKey: Self.lastDimensionsKey)
    }

    // MARK: - Initialization

    init(
        providerService: ProviderService = ProviderService.shared,
        keychain: KeychainSwift = KeychainSwift()
    ) {
        self.providerService = providerService
        self.keychain = keychain

        self.keychain.accessGroup = TEAM_KEYCHAIN_AG
        self.keychain.synchronizable = true
    }

    // MARK: - Model Selection Functions

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

    // MARK: - Additional Reference Images Support

    func supportsReferenceImages() -> Bool {
        guard let modelParams = getSelectedModel()?.modelParams else { return false }
        return modelParams.supportsReferenceImages
    }

    func maxReferenceImages() -> Int {
        guard let model = getSelectedModel() else { return 0 }
        let configuredMaximum = model.modelParams.maxReferenceImages
        if selectedImage != nil,
           let maximumInputs = maximumCombinedImageInputs(for: model.modelCode)
        {
            return min(configuredMaximum, max(0, maximumInputs - 1))
        }
        return configuredMaximum
    }

    func supportedReferenceTypes() -> [String] {
        getSelectedModel()?.modelParams.supportedReferenceTypes ?? []
    }

    func supportsFlexibleReferenceDimensions() -> Bool {
        getSelectedModel()?.modelParams.supportsFlexibleReferenceDimensions ?? true
    }

    func supportedTools() -> [String] {
        getSelectedModel()?.modelParams.supportedTools ?? []
    }

    func canAddMoreReferenceImages() -> Bool {
        supportsReferenceImages() && referenceImages.count < maxReferenceImages()
    }

    func addReferenceImage(image: PlatformImage, referenceType: String) {
        guard canAddMoreReferenceImages() else { return }
        let refImage = ReferenceImage(image: image, referenceType: referenceType)
        referenceImages.append(refImage)
    }

    func removeReferenceImage(id: UUID) {
        referenceImages.removeAll { $0.id == id }
    }

    func updateReferenceImageType(id: UUID, newType: String) {
        if let index = referenceImages.firstIndex(where: { $0.id == id }) {
            referenceImages[index].referenceType = newType
        }
    }

    func processSelectedReferenceImage(image: PlatformImage) {
        pendingReferenceImage = image
        pendingReferenceImageType = supportedReferenceTypes().first ?? ""
        referenceImageCropSessionId = UUID()
        isReferenceImageCropSheetOpen = true
    }

    func handleReferenceImageCropConfirm(image: PlatformImage) {
        addReferenceImage(image: image, referenceType: pendingReferenceImageType)

        pendingReferenceImage = nil
        pendingReferenceImageType = ""
        isReferenceImageCropSheetOpen = false
    }

    func cancelReferenceImageCropping() {
        pendingReferenceImage = nil
        pendingReferenceImageType = ""
        isReferenceImageCropSheetOpen = false
    }

    func clearReferenceImages() {
        referenceImages = []
    }

    // MARK: - Setup

    func initialize(providerKeys: [ProviderKey]) {
        guard !providerKeys.isEmpty, selectedModelId.isEmpty else { return }

        let supportedProviders = getSupportedProviders(providerKeys: providerKeys)

        // Try to restore saved provider selection
        if let savedProviderId = UserDefaults.standard.string(forKey: Self.lastProviderIdKey),
           supportedProviders.contains(where: { $0.providerId.uuidString == savedProviderId })
        {
            selectedProviderId = savedProviderId

            // Try to restore saved model selection
            let supportedModels = getSupportedModels()
            if let savedModelId = UserDefaults.standard.string(forKey: Self.lastModelIdKey),
               supportedModels.contains(where: { $0.modelId.uuidString == savedModelId })
            {
                selectedModelId = savedModelId
            } else {
                selectedModelId = supportedModels.first?.modelId.uuidString ?? ""
            }
        } else if let firstSupportedProvider = supportedProviders.first,
                  let key = providerKeys.first(where: { $0.providerId == firstSupportedProvider.providerId })
        {
            // Fall back to first available provider/model
            selectedProviderId = key.providerId.uuidString
            selectedModelId = getSupportedModels().first?.modelId.uuidString ?? ""
        }

        if !selectedProviderId.isEmpty, !selectedModelId.isEmpty,
           let modelParams = getSelectedModel()?.modelParams
        {
            initializeModelParams(modelParams: modelParams)

            // Try to restore saved dimensions if supported by current model
            if let savedDimensions = UserDefaults.standard.string(forKey: Self.lastDimensionsKey),
               modelParams.effectiveDimensions.contains(savedDimensions)
            {
                dimensions = savedDimensions
            }
        }
    }

    func initializeModelParams(modelParams: ModelParams) {
        dimensions = modelParams.effectiveDimensions.first ?? ""
        variant = modelParams.supportedVariants.first ?? ""
        style = modelParams.supportedStyles.first ?? ""
        quality = modelParams.supportedImageQualities.first ?? ""
        background = modelParams.supportedBackgrounds.first ?? ""
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

    // MARK: - Model Change Handler

    @discardableResult
    func handleModelChange() -> Bool {
        guard let modelParams = getSelectedModel()?.modelParams else { return false }

        let effectiveDimensions = modelParams.effectiveDimensions
        let previousDimensions = dimensions
        var dimensionsChanged = false

        if dimensions.isEmpty {
            dimensions = effectiveDimensions.first ?? ""
            dimensionsChanged = dimensions != previousDimensions
        } else if !effectiveDimensions.contains(dimensions) {
            dimensions = effectiveDimensions.first ?? ""
            dimensionsChanged = true
        }

        // Reset options when model changes
        quality = modelParams.supportedImageQualities.first ?? ""
        variant = modelParams.supportedVariants.first ?? ""
        style = modelParams.supportedStyles.first ?? ""
        background = modelParams.supportedBackgrounds.first ?? ""
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
            referenceImages = []
        }

        return dimensionsChanged
    }

    // MARK: - Provider Change Handler

    func handleProviderChange() {
        selectedModelId = getSupportedModels().first?.modelId.uuidString ?? ""
    }

    // MARK: - Dimension Change Handler

    func handleDimensionChange() {
        selectedImage = nil
        colorPalette = []
    }

    // MARK: - Image Selection Functions

    func processSelectedImage(image: PlatformImage) {
        selectedImage = image
        cropSessionId = UUID()
        isCropSheetOpen = true
        Task.detached(priority: .userInitiated) {
            let palette = dominantColorsFromImage(image, clusterCount: 6)
            await MainActor.run { [weak self] in self?.colorPalette = palette }
        }
    }

    func handleCropConfirm(image: PlatformImage) {
        selectedImage = image
        isCropSheetOpen = false
        Task.detached(priority: .userInitiated) {
            let palette = dominantColorsFromImage(image, clusterCount: 6)
            await MainActor.run { [weak self] in self?.colorPalette = palette }
        }
    }

    func handleCropCancel() {
        selectedImage = nil
        colorPalette = []
        isCropSheetOpen = false
    }

    // MARK: - Queue Submission

    func submitToQueue(
        providerKeys: [ProviderKey],
        projectId: UUID,
        queueManager: QueueManager,
        modelContext: ModelContext,
        additionalRequestParams: ((inout ImageGenerationRequest) -> Void)? = nil
    ) {
        guard let selectedModel = getSelectedModel() else {
            showToast(.error("No model selected"))
            return
        }

        let keychainKey = ProjectManager.keychainKey(projectId: projectId, providerId: selectedModel.providerId)
        guard let providerSecret = keychain.get(keychainKey) else {
            showToast(.error("Keychain record not found"))
            return
        }

        guard let providerKey = providerKeys.first(where: { $0.providerId == selectedModel.providerId }) else {
            showToast(.error("Provider key not found"))
            return
        }

        let modelParams = selectedModel.modelParams

        let clientReferenceImages: [ReferenceImageData]? = referenceImages.isEmpty ? nil : referenceImages
            .map { refImage in
                ReferenceImageData(
                    base64Image: refImage.image.toBase64PNG() ?? "",
                    referenceType: refImage.referenceType
                )
            }

        guard let providerKeyInfo = try? providerKey.toProviderKeyInfo() else {
            showToast(.error("Provider not found"))
            return
        }

        var request = ImageGenerationRequest(
            modelId: selectedModel.modelId.uuidString,
            prompt: prompt,
            searchPrompt: searchPrompt.isEmpty ? nil : searchPrompt,
            negativePrompt: negativePrompt.isEmpty ? nil : negativePrompt,
            variant: variant,
            quality: quality,
            style: style,
            dimensions: dimensions,
            clientImage: selectedImage?.toBase64(
                maxPixels: modelParams.maxImagePixels,
                maxSizeBytes: modelParams.maxImageSizeBytes
            ),
            clientReferenceImages: clientReferenceImages,
            providerKey: providerKeyInfo,
            providerSecret: providerSecret,
            resolution: modelParams.supportsImageResolution ? selectedResolution : nil,
            steps: modelParams.supportsStepsRange ? Int(stepsValue) : nil,
            guidance: modelParams.supportsGuidanceRange ? guidanceValue : nil,
            seed: modelParams.supportsSeed && !seedValue.isEmpty ? Int(seedValue) : nil,
            safetyTolerance: modelParams.supportsSafetyRange ? Int(safetyValue) : nil,
            promptEnhance: modelParams.supportsPromptEnhance ? modelPromptEnhance : nil,
            background: modelParams.supportsBackgrounds && !background.isEmpty ? background : nil,
            inputFidelity: modelParams.supportsInputFidelity && !inputFidelity.isEmpty ? inputFidelity : nil,
            moderation: modelParams.supportsModeration && !moderation.isEmpty ? moderation : nil,
            growMask: modelParams.supportsGrowMaskRange ? Int(growMaskValue) : nil,
            selectedTools: modelParams.supportsTools && !selectedTools.isEmpty ? Array(selectedTools) : nil,
            personGeneration: modelParams.supportsPersonGeneration && !personGeneration.isEmpty ? personGeneration : nil
        )

        additionalRequestParams?(&request)

        _ = queueManager.submitImageGeneration(
            request: request,
            modelContext: modelContext,
            source: .IMAGE_GENERATE
        )
    }

    // MARK: - Computed Properties

    var canGenerate: Bool {
        let selectedModel = getSelectedModel()
        let selectedModelParams = selectedModel?.modelParams

        // If the model supports prompts, require a non-empty prompt.
        if selectedModelParams?.supportsPrompt ?? true {
            if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }
        } else {
            // Promptless models typically require an input image (e.g., background removal, sketch-to-image).
            return selectedImage != nil
        }

        if let selectedModel,
           let maximumInputs = maximumCombinedImageInputs(for: selectedModel.modelCode),
           (selectedImage == nil ? 0 : 1) + referenceImages.count > maximumInputs
        {
            return false
        }

        // Image editing operations require an image
        switch setType {
        case .IMAGE_GENERATE:
            return true
        default:
            return selectedImage != nil
        }
    }

    var hasSupportedModel: Bool {
        !selectedModelId.isEmpty
    }

    // MARK: - Navigation

    func resetNavigation() {
        isNavigationActive = false
        selectedSetId = nil
    }

    // MARK: - Preload Data

    func applyPreload(_ preload: GenerateImagePreload, providerKeys: [ProviderKey]) {
        selectedImage = preload.image
        colorPalette = preload.colorPalette

        if let modelParams = getSelectedModel()?.modelParams,
           modelParams.effectiveDimensions.contains(preload.dimensions)
        {
            dimensions = preload.dimensions
        }

        if let prompt = preload.prompt {
            self.prompt = prompt
        }
        if let negativePrompt = preload.negativePrompt {
            self.negativePrompt = negativePrompt
        }
    }
}
