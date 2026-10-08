// MARK: - BaseVideoViewModel.swift

// Base view model for all video generation views sharing common functionality.
//
// This abstract-style class provides shared state and logic for:
// - VideoGenerateView (text/image-to-video generation)
// - VideoExtendView (extend existing videos)
// - Agent card video configuration
//
// ## Architecture
// Similar to BaseImageViewModel but with video-specific handling:
// - Video file selection and processing
// - Duration and resolution parameters
// - Audio generation options
// - Frame extraction for thumbnails
//
// ## Video-Specific State
// - **Source Image**: Starting frame for image-to-video
// - **Last Frame**: End frame for video generation
// - **Source Video**: For video extension workflows
// - **Previous Generation**: For extending provider-native videos
//
// ## Model Parameter Handling
// Video models have additional parameters:
// - Duration options (4s, 8s, etc.)
// - Resolution tiers (720p, 1080p)
// - FPS options
// - Audio generation support
// - Motion/stickyness controls
//
// ## Video Extension Support
// Some models require extending their own videos using provider-specific metadata.
// The `requires*GeneratedVideo()` helpers check for these constraints.

import AVFoundation
import Foundation
import IllustrateProviders
import KeychainSwift
import OSLog
import PhotosUI
import SwiftData
import SwiftUI

/// Base ViewModel for video generation views sharing common state and functionality.
///
/// This class encapsulates all state needed for video generation forms:
/// - Model/provider selection
/// - Prompt and video-specific parameters
/// - Source image, video, and frame management
/// - Queue submission for async generation
///
/// Video generation has unique requirements like duration selection,
/// audio generation, and video file handling that this class manages.
@MainActor
class BaseVideoViewModel: ObservableObject {
    let providerService: ProviderService
    let keychain: KeychainSwift

    // MARK: - Model Selection State

    @Published var selectedProviderId = ""
    @Published var selectedModelId = ""

    // MARK: - Prompt State

    @Published var prompt = ""
    @Published var searchPrompt = ""
    @Published var negativePrompt = ""

    // MARK: - Model Parameters State

    @Published var dimensions = ""
    @Published var quality = ""
    @Published var style = ""
    @Published var variant = ""
    @Published var inputFidelity = ""
    @Published var moderation = ""
    @Published var selectedResolution = ""
    @Published var selectedFPS = 24
    @Published var selectedTools: Set<String> = []
    @Published var durationSeconds = 8 {
        didSet {
            if getSelectedModel()?.modelCode == .XAI_GROK_IMAGINE_VIDEO,
               !referenceImages.isEmpty,
               durationSeconds > 10
            {
                durationSeconds = 10
            }
        }
    }

    @Published var generateAudio = true
    @Published var numberOfVideos = 1
    @Published var motion: Double = 135
    @Published var stickyness = 2.0
    @Published var guidanceValue = 3.5
    @Published var safetyValue: Double = 5
    @Published var seedValue = ""
    @Published var modelPromptEnhance = true

    // MARK: - Primary Reference Image State

    @Published var selectedImageItem: PhotosPickerItem?
    @Published var selectedImage: PlatformImage?
    @Published var colorPalette: [String] = []
    @Published var isPhotoPickerOpen = false
    @Published var isCropSheetOpen = false
    @Published var cropSessionId = UUID()

    // MARK: - Last Frame State

    @Published var selectedLastFrameItem: PhotosPickerItem?
    @Published var selectedLastFrame: PlatformImage?
    @Published var isLastFramePickerOpen = false
    @Published var isLastFrameCropSheetOpen = false
    @Published var lastFrameCropSessionId = UUID()

    // MARK: - Video Selection State

    @Published var selectedVideoItem: PhotosPickerItem?
    @Published var selectedVideoData: Data?
    @Published var selectedVideoThumbnail: PlatformImage?
    @Published var selectedVideoURL: URL?
    @Published var isVideoPickerOpen = false
    @Published var isProcessingVideo = false

    // MARK: - Previous Generation Video Selection State

    @Published var selectedPreviousGeneration: Generation?
    @Published var isPreviousGenerationVideoPickerOpen = false
    @Published var sourceMetadata: [String: String] = [:]

    // MARK: - Additional Reference Images State

    @Published var referenceImages: [ReferenceImage] = []
    @Published var selectedReferenceImageItem: PhotosPickerItem?
    @Published var isReferenceImagePickerOpen = false
    @Published var isReferenceImageCropSheetOpen = false
    @Published var referenceImageCropSessionId = UUID()
    @Published var pendingReferenceImage: PlatformImage?
    @Published var pendingReferenceImageType = ""

    // MARK: - Luma Multi-Keyframe State

    @Published var lumaKeyframes: [VideoKeyframeImage] = []
    @Published var lumaHDR = false
    @Published var lumaEXRExport = false
    @Published var lumaLoop = false

    // MARK: - Navigation State

    @Published var isNavigationActive = false
    @Published var selectedSetId: UUID? = nil

    // MARK: - Set Type (to be set by subclass or view)

    var setType: EnumSetType = .VIDEO_GENERATE

    // MARK: - Persistence Keys

    private static let lastProviderIdKey = "quickAction.video.lastProviderId"
    private static let lastModelIdKey = "quickAction.video.lastModelId"
    private static let lastDimensionsKey = "quickAction.video.lastDimensions"

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

    func supportsLastFrame() -> Bool {
        guard let modelParams = getSelectedModel()?.modelParams else { return false }
        return modelParams.supportsLastFrame
    }

    func requiresVeoGeneratedVideo() -> Bool {
        guard let modelParams = getSelectedModel()?.modelParams else { return false }
        return modelParams.requiredMetadata.contains("veoGeneratedUri")
    }

    func requiresSoraGeneratedVideo() -> Bool {
        guard let modelParams = getSelectedModel()?.modelParams else { return false }
        return modelParams.requiredMetadata.contains("soraVideoId")
    }

    func requiresGeminiInteractionVideo() -> Bool {
        guard let modelParams = getSelectedModel()?.modelParams else { return false }
        return modelParams.requiredMetadata.contains(GeminiInteractionMetadataKey.interactionId)
    }

    func requiresLumaGeneratedVideo() -> Bool {
        guard let modelParams = getSelectedModel()?.modelParams else { return false }
        return modelParams.requiredMetadata.contains("lumaGenerationId")
    }

    func usesLumaVideoEdit() -> Bool {
        getSelectedModel()?.modelCode == .LUMA_RAY_3_2_EDIT
    }

    func usesLumaVideoReframe() -> Bool {
        getSelectedModel()?.modelCode == .LUMA_RAY_3_2_REFRAME
    }

    func usesLumaMultiKeyframes() -> Bool {
        getSelectedModel()?.modelCode == .LUMA_RAY_3_2_KEYFRAMES
    }

    func supportsLumaHDR() -> Bool {
        guard let modelCode = getSelectedModel()?.modelCode else { return false }
        return [
            .LUMA_RAY_3_2,
            .LUMA_RAY_3_2_KEYFRAMES,
            .LUMA_RAY_3_2_EDIT,
        ].contains(modelCode)
    }

    func supportsLumaLoop() -> Bool {
        getSelectedModel()?.modelCode == .LUMA_RAY_3_2
    }

    func getRequiredMetadataKeys() -> [String] {
        getSelectedModel()?.modelParams.requiredMetadata ?? []
    }

    func supportsVideoUpload() -> Bool {
        guard let modelParams = getSelectedModel()?.modelParams else { return false }
        return modelParams.supportsVideoUpload
    }

    func supportsSourceImage() -> Bool {
        guard let model = getSelectedModel() else { return false }
        if model.modelCode == .XAI_GROK_IMAGINE_VIDEO, !referenceImages.isEmpty {
            return false
        }
        return model.modelParams.supportsSourceImage
    }

    // MARK: - Additional Reference Images Support

    func supportsReferenceImages() -> Bool {
        guard let model = getSelectedModel() else { return false }
        if model.modelCode == .XAI_GROK_IMAGINE_VIDEO, selectedImage != nil {
            return false
        }
        return model.modelParams.supportsReferenceImages
    }

    func maxReferenceImages() -> Int {
        getSelectedModel()?.modelParams.maxReferenceImages ?? 0
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
        if getSelectedModel()?.modelCode == .XAI_GROK_IMAGINE_VIDEO, durationSeconds > 10 {
            durationSeconds = 10
        }
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
        if supportsFlexibleReferenceDimensions() {
            addReferenceImage(image: image, referenceType: pendingReferenceImageType)
        } else {
            let targetSize = computeTargetSize()
            if let resizedImage = image.resizeImage(targetSize: targetSize) {
                addReferenceImage(image: resizedImage, referenceType: pendingReferenceImageType)
            }
        }

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

    func canAddMoreLumaKeyframes() -> Bool {
        usesLumaMultiKeyframes() && lumaKeyframes.count < 64
    }

    func processSelectedLumaKeyframeImage(image: PlatformImage) {
        pendingReferenceImage = image
        pendingReferenceImageType = ""
        referenceImageCropSessionId = UUID()
        isReferenceImageCropSheetOpen = true
    }

    func handleLumaKeyframeCropConfirm(image: PlatformImage) {
        addLumaKeyframe(image: image)
        pendingReferenceImage = nil
        pendingReferenceImageType = ""
        isReferenceImageCropSheetOpen = false
    }

    func addLumaKeyframe(image: PlatformImage) {
        guard canAddMoreLumaKeyframes() else { return }
        lumaKeyframes.append(VideoKeyframeImage(
            image: image,
            frameIndex: nextLumaKeyframeIndex()
        ))
        sortLumaKeyframes()
    }

    func removeLumaKeyframe(id: UUID) {
        lumaKeyframes.removeAll { $0.id == id }
    }

    func updateLumaKeyframeFrameIndex(id: UUID, frameIndex: Int) {
        guard let index = lumaKeyframes.firstIndex(where: { $0.id == id }) else { return }
        lumaKeyframes[index].frameIndex = max(0, min(frameIndex, lumaKeyframeMaxFrameIndex))
        sortLumaKeyframes()
    }

    var lumaKeyframeMaxFrameIndex: Int {
        let duration = [5, 10].contains(durationSeconds) ? durationSeconds : 5
        return duration * 24
    }

    func lumaKeyframeValidationMessage() -> String? {
        guard usesLumaMultiKeyframes() else { return nil }

        if lumaKeyframes.isEmpty {
            return "Add at least one keyframe image."
        }

        let indexes = lumaKeyframes.map(\.frameIndex)
        if Set(indexes).count != indexes.count {
            return "Keyframe frame positions must be unique."
        }

        if indexes.contains(where: { $0 < 0 || $0 > lumaKeyframeMaxFrameIndex }) {
            return "Keyframe frames must be between 0 and \(lumaKeyframeMaxFrameIndex)."
        }

        return nil
    }

    private func nextLumaKeyframeIndex() -> Int {
        let usedIndexes = Set(lumaKeyframes.map(\.frameIndex))
        let preferredIndexes = [0, lumaKeyframeMaxFrameIndex]
        if let index = preferredIndexes.first(where: { !usedIndexes.contains($0) }) {
            return index
        }

        let step = max(1, lumaKeyframeMaxFrameIndex / 4)
        for index in stride(from: step, through: lumaKeyframeMaxFrameIndex, by: step)
            where !usedIndexes.contains(index)
        {
            return index
        }

        return (0 ... lumaKeyframeMaxFrameIndex).first { !usedIndexes.contains($0) } ?? lumaKeyframeMaxFrameIndex
    }

    private func sortLumaKeyframes() {
        lumaKeyframes.sort { lhs, rhs in lhs.frameIndex < rhs.frameIndex }
    }

    func clampLumaKeyframesToCurrentDuration() {
        guard usesLumaMultiKeyframes() else { return }
        for index in lumaKeyframes.indices {
            lumaKeyframes[index].frameIndex = max(0, min(lumaKeyframes[index].frameIndex, lumaKeyframeMaxFrameIndex))
        }
        sortLumaKeyframes()
    }

    func enforceLumaOutputConstraints() {
        if !supportsLumaHDR() {
            lumaHDR = false
            lumaEXRExport = false
        }

        if !supportsLumaLoop() {
            lumaLoop = false
        }

        if lumaEXRExport {
            lumaHDR = true
        }

        if lumaLoop, lumaHDR {
            lumaHDR = false
            lumaEXRExport = false
        }

        if lumaHDR, selectedResolution == "360p" || selectedResolution == "540p" {
            selectedResolution = "720p"
        }

        if lumaHDR || lumaLoop, usesLumaGenerationOutputOptions(), durationSeconds == 10, !hasLumaAnchorFrame {
            durationSeconds = 5
        }
    }

    func lumaOutputControlsValidationMessage() -> String? {
        guard supportsLumaHDR() || supportsLumaLoop() else { return nil }

        if lumaEXRExport, !lumaHDR {
            return "EXR export requires HDR."
        }

        if lumaHDR, selectedResolution == "360p" || selectedResolution == "540p" {
            return "HDR requires 720p or 1080p."
        }

        if lumaHDR, usesLumaGenerationOutputOptions(), lumaEffectiveGenerationDuration == 10 {
            return "HDR generation supports 5s clips."
        }

        if lumaLoop {
            if !supportsLumaLoop() {
                return "Loop is only available for Ray 3.2 generation."
            }
            if lumaEffectiveGenerationDuration == 10 {
                return "Loop generation supports 5s clips."
            }
            if selectedLastFrame != nil {
                return "Loop cannot be combined with a last frame."
            }
            if lumaHDR {
                return "Loop cannot be combined with HDR."
            }
        }

        return nil
    }

    private func usesLumaGenerationOutputOptions() -> Bool {
        guard let modelCode = getSelectedModel()?.modelCode else { return false }
        return modelCode == .LUMA_RAY_3_2 || modelCode == .LUMA_RAY_3_2_KEYFRAMES
    }

    private var hasLumaAnchorFrame: Bool {
        selectedImage != nil || selectedLastFrame != nil
    }

    private var lumaEffectiveGenerationDuration: Int {
        hasLumaAnchorFrame ? 5 : durationSeconds
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
        inputFidelity = modelParams.supportedInputFidelities.first ?? ""
        moderation = modelParams.supportedModerations.first ?? ""
        selectedResolution = modelParams.supportedVideoResolutions.last ?? ""

        if modelParams.supportsFPS {
            selectedFPS = modelParams.supportedVideoFPS.first ?? 24
        }

        if modelParams.supportsVideoDurations {
            durationSeconds = modelParams.supportedVideoDurations.last ?? 4
        }

        enforceLumaReframeResolutionConstraint()
        clampLumaKeyframesToCurrentDuration()
        enforceLumaOutputConstraints()

        if let guidanceRange = modelParams.supportedGuidanceRange {
            guidanceValue = (guidanceRange.min + guidanceRange.max) / 2
        }
        if let safetyRange = modelParams.supportedSafetyRange {
            safetyValue = Double(safetyRange.min + safetyRange.max) / 2.0
        }
    }

    // MARK: - Validation

    func handleModelChange() {
        guard let modelParams = getSelectedModel()?.modelParams else { return }

        if modelParams.supportsDimensions {
            if dimensions.isEmpty {
                dimensions = modelParams.effectiveDimensions.first ?? ""
            } else if !modelParams.effectiveDimensions.contains(dimensions) {
                dimensions = modelParams.effectiveDimensions.first ?? ""
            }
        }

        if modelParams.supportsVideoResolutions {
            if selectedResolution.isEmpty {
                selectedResolution = modelParams.supportedVideoResolutions.last ?? ""
            } else if !modelParams.supportedVideoResolutions.contains(selectedResolution) {
                selectedResolution = modelParams.supportedVideoResolutions.last ?? ""
            }
        }

        if modelParams.supportsVideoDurations {
            if !modelParams.supportedVideoDurations.contains(durationSeconds) {
                durationSeconds = modelParams.supportedVideoDurations.last ?? durationSeconds
            }
        }

        enforceLumaReframeResolutionConstraint()
        clampLumaKeyframesToCurrentDuration()
        enforceLumaOutputConstraints()

        if !modelParams.supportsLastFrame {
            selectedLastFrame = nil
            selectedLastFrameItem = nil
        }

        if !modelParams.supportsSourceImage {
            selectedImage = nil
            selectedImageItem = nil
        }

        if !modelParams.supportsReferenceImages {
            referenceImages = []
        }

        if !usesLumaMultiKeyframes() {
            lumaKeyframes = []
        }

        if selectedPreviousGeneration != nil {
            let requiredKeys = modelParams.requiredMetadata
            let hasRequiredMetadata = requiredKeys.isEmpty ||
                metadataSatisfies(requiredKeys, metadata: selectedGenerationMetadata)

            if !hasRequiredMetadata {
                clearGeneratedVideoSelection()
            }
        }

        quality = modelParams.supportedImageQualities.first ?? ""
        variant = modelParams.supportedVariants.first ?? ""
        style = modelParams.supportedStyles.first ?? ""
        inputFidelity = modelParams.supportedInputFidelities.first ?? ""
        moderation = modelParams.supportedModerations.first ?? ""

        if let guidanceRange = modelParams.supportedGuidanceRange {
            guidanceValue = (guidanceRange.min + guidanceRange.max) / 2
        }
        if let safetyRange = modelParams.supportedSafetyRange {
            safetyValue = Double(safetyRange.min + safetyRange.max) / 2.0
        }

        seedValue = ""
        selectedTools = []
        modelPromptEnhance = true
    }

    // MARK: - Provider Change Handler

    func handleProviderChange() {
        selectedModelId = getSupportedModels().first?.modelId.uuidString ?? ""
    }

    // MARK: - Computed Properties

    var canGenerate: Bool {
        if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }

        if lumaOutputControlsValidationMessage() != nil {
            return false
        }

        switch setType {
        case .VIDEO_GENERATE:
            let selectedModelCode = getSelectedModel()?.modelCode
            if selectedModelCode == .XAI_GROK_IMAGINE_VIDEO_1_5,
               selectedImage == nil
            {
                return false
            }
            if selectedModelCode == .XAI_GROK_IMAGINE_VIDEO,
               selectedImage != nil,
               !referenceImages.isEmpty
            {
                return false
            }
            if selectedModelCode == .XAI_GROK_IMAGINE_VIDEO,
               !referenceImages.isEmpty,
               durationSeconds > 10
            {
                return false
            }
            if usesLumaMultiKeyframes() {
                return lumaKeyframeValidationMessage() == nil
            }
            return true
        case .VIDEO_EXTEND:
            let requiredKeys = getRequiredMetadataKeys()
            if !requiredKeys.isEmpty {
                return selectedPreviousGeneration != nil &&
                    metadataSatisfies(requiredKeys, metadata: selectedGenerationMetadata)
            }
            return selectedVideoURL != nil
        default:
            return false
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

    // MARK: - Dimension Change

    func updateDimensions(dimension: String) {
        guard dimensions != dimension else { return }

        dimensions = dimension
        selectedImage = nil
        selectedLastFrame = nil
        colorPalette = []
        enforceLumaReframeResolutionConstraint()
        clampLumaKeyframesToCurrentDuration()
        enforceLumaOutputConstraints()
    }

    // MARK: - Image Processing

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
        let targetSize = computeTargetSize()
        selectedImage = image.resizeImage(targetSize: targetSize)

        if let selectedImage {
            let image = selectedImage
            Task.detached(priority: .userInitiated) {
                let palette = dominantColorsFromImage(image, clusterCount: 6)
                await MainActor.run { [weak self] in self?.colorPalette = palette }
            }
        }

        isCropSheetOpen = false
    }

    func handleCropCancel() {
        selectedImage = nil
        colorPalette = []
        isCropSheetOpen = false
    }

    // MARK: - Last Frame Processing

    func processSelectedLastFrame(image: PlatformImage) {
        selectedLastFrame = image
        lastFrameCropSessionId = UUID()
        isLastFrameCropSheetOpen = true
    }

    func handleLastFrameCropping(image: PlatformImage) {
        let targetSize = computeTargetSize()
        selectedLastFrame = image.resizeImage(targetSize: targetSize)
        isLastFrameCropSheetOpen = false
    }

    func cancelLastFrameCropping() {
        selectedLastFrame = nil
        isLastFrameCropSheetOpen = false
    }

    private func computeTargetSize() -> CGSize {
        if dimensions.contains(":") {
            let dims = getVideoDimensions(resolution: selectedResolution, aspectRatio: dimensions)
            return CGSize(width: dims.width, height: dims.height)
        } else {
            return CGSize(
                width: getAspectRatio(dimension: dimensions).actualWidth,
                height: getAspectRatio(dimension: dimensions).actualHeight
            )
        }
    }

    // MARK: - Video Processing

    func processSelectedVideo() async {
        guard let videoItem = selectedVideoItem else { return }

        isProcessingVideo = true

        do {
            if let movie = try await videoItem.loadTransferable(type: VideoTransferable.self) {
                selectedVideoData = movie.data
                selectedVideoThumbnail = await generateThumbnail(from: movie.data)
            }
        } catch {
            showToast(.error("Failed to load video", subtitle: error.localizedDescription))
        }

        isProcessingVideo = false
    }

    private func generateThumbnail(from videoData: Data) async -> PlatformImage? {
        if let oldURL = selectedVideoURL {
            try? FileManager.default.removeItem(at: oldURL)
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")

        do {
            try videoData.write(to: tempURL)
            selectedVideoURL = tempURL

            let asset = AVURLAsset(url: tempURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true

            let time = CMTime(seconds: 0.1, preferredTimescale: 600)
            let cgImage = try await imageGenerator.image(at: time).image

            #if os(macOS)
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            #else
            return UIImage(cgImage: cgImage)
            #endif
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            selectedVideoURL = nil
            return nil
        }
    }

    func clearVideo() {
        if let url = selectedVideoURL {
            try? FileManager.default.removeItem(at: url)
        }
        selectedVideoItem = nil
        selectedVideoData = nil
        selectedVideoThumbnail = nil
        selectedVideoURL = nil
        selectedPreviousGeneration = nil
        sourceMetadata = [:]
    }

    func selectGeneratedVideo(_ generation: Generation) {
        selectedPreviousGeneration = generation
        sourceMetadata = sourceMetadata(for: generation)
        applySelectedSourceDurationIfNeeded()

        selectedVideoData = nil
        selectedVideoThumbnail = loadImageFromiCloud(generation.id.uuidString)

        if let videoURL = loadVideoFromiCloud(generation.id.uuidString) {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
            do {
                try FileManager.default.copyItem(at: videoURL, to: tempURL)
                selectedVideoURL = tempURL
            } catch {
                selectedVideoURL = nil
            }
        }
    }

    func selectVeoGeneration(_ generation: Generation) {
        selectGeneratedVideo(generation)
    }

    func clearGeneratedVideoSelection() {
        selectedPreviousGeneration = nil
        sourceMetadata = [:]
        clearVideo()
    }

    func clearVeoSelection() {
        clearGeneratedVideoSelection()
    }

    private func sourceMetadata(for generation: Generation) -> [String: String] {
        var metadata = generation.metadata
        metadata["source_generation_id"] = generation.id.uuidString
        metadata["source_generation_set_id"] = generation.setId.uuidString
        if let model = providerService.model(by: generation.modelId) {
            metadata["source_model_code"] = model.modelCode.rawValue
        }
        return metadata
    }

    private func applySelectedSourceDurationIfNeeded() {
        guard usesLumaVideoReframe(),
              let duration = sourceDurationSeconds(from: sourceMetadata)
        else {
            return
        }
        durationSeconds = duration
    }

    private func sourceDurationSeconds(from metadata: [String: String]) -> Int? {
        guard let value = metadata["duration_seconds"],
              let duration = Int(value),
              duration > 0
        else {
            return nil
        }
        return min(duration, 30)
    }

    private func enforceLumaReframeResolutionConstraint() {
        guard usesLumaVideoReframe(),
              selectedResolution == "1080p",
              isVerticalAspectRatio(dimensions)
        else {
            return
        }
        selectedResolution = "720p"
    }

    private func isVerticalAspectRatio(_ dimensions: String) -> Bool {
        if dimensions.contains(":") {
            let parts = dimensions.split(separator: ":")
            guard parts.count == 2,
                  let width = Double(parts[0]),
                  let height = Double(parts[1]),
                  height > 0
            else {
                return false
            }
            return width / height < 1
        }

        let parts = dimensions.split(separator: "x")
        guard parts.count == 2,
              let width = Double(parts[0]),
              let height = Double(parts[1]),
              height > 0
        else {
            return false
        }
        return width / height < 1
    }

    // MARK: - Queue Submission

    func submitToQueue(
        providerKeys: [ProviderKey],
        projectId: UUID,
        queueManager: QueueManager,
        modelContext: ModelContext
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

        guard let providerKeyInfo = try? providerKey.toProviderKeyInfo() else {
            showToast(.error("Provider not found"))
            return
        }

        let modelParams = selectedModel.modelParams

        let clientReferenceImages: [ReferenceImageData]? = {
            if usesLumaMultiKeyframes() {
                let keyframes = lumaKeyframes.map { keyframe in
                    ReferenceImageData(
                        base64Image: keyframe.image.toBase64PNG() ?? "",
                        referenceType: "keyframe",
                        frameIndex: keyframe.frameIndex
                    )
                }
                return keyframes.isEmpty ? nil : keyframes
            }

            return referenceImages.isEmpty ? nil : referenceImages
                .map { refImage in
                    ReferenceImageData(
                        base64Image: refImage.image.toBase64PNG() ?? "",
                        referenceType: refImage.referenceType
                    )
                }
        }()

        let clientVideo: String? = {
            if let data = selectedVideoData {
                return data.base64EncodedString()
            }
            guard let url = selectedVideoURL else { return nil }
            return (try? Data(contentsOf: url))?.base64EncodedString()
        }()

        let request = VideoGenerationRequest(
            modelId: selectedModel.modelId.uuidString,
            prompt: prompt,
            negativePrompt: negativePrompt.isEmpty ? nil : negativePrompt,
            dimensions: dimensions,
            clientImage: selectedImage != nil ? selectedImage!.toBase64PNG() : nil,
            clientLastFrame: selectedLastFrame != nil ? selectedLastFrame!.toBase64PNG() : nil,
            clientVideo: clientVideo,
            clientReferenceImages: clientReferenceImages,
            providerKey: providerKeyInfo,
            providerSecret: providerSecret,
            numberOfVideos: numberOfVideos,
            motion: modelParams.supportsMotion ? Int(motion) : nil,
            stickyness: modelParams.supportsStickyness ? Int(stickyness) : nil,
            durationSeconds: durationSeconds,
            resolution: selectedResolution,
            fps: modelParams.supportsFPS ? selectedFPS : nil,
            generateAudio: modelParams.supportsAudio ? generateAudio : nil,
            seed: modelParams.supportsSeed && !seedValue.isEmpty ? Int(seedValue) : nil,
            safetyTolerance: modelParams.supportsSafetyRange ? Int(safetyValue) : nil,
            promptEnhance: modelParams.supportsPromptEnhance ? modelPromptEnhance : nil,
            moderation: modelParams.supportsModeration && !moderation.isEmpty ? moderation : nil,
            sourceMetadata: sourceMetadata.isEmpty ? nil : sourceMetadata,
            lumaHDR: supportsLumaHDR() && lumaHDR ? true : nil,
            lumaEXRExport: supportsLumaHDR() && lumaEXRExport ? true : nil,
            lumaLoop: supportsLumaLoop() && lumaLoop ? true : nil
        )

        _ = queueManager.submitVideoGeneration(
            request: request,
            modelContext: modelContext,
            source: .VIDEO_GENERATE
        )
    }

    // MARK: - Preload Data

    func applyPreload(_ preload: GenerateVideoPreload, providerKeys: [ProviderKey]) async {
        colorPalette = preload.colorPalette

        selectedVideoData = nil
        if let videoURL = loadVideoFromiCloud(preload.videoId) {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
            do {
                try FileManager.default.copyItem(at: videoURL, to: tempURL)
                selectedVideoURL = tempURL
            } catch {
                selectedVideoURL = nil
            }
        }

        selectedVideoThumbnail = loadImageFromiCloud(preload.videoId)

        if let modelParams = getSelectedModel()?.modelParams,
           modelParams.effectiveDimensions.contains(preload.dimensions)
        {
            dimensions = preload.dimensions
        }

        if let extendPreload = preload as? ExtendVideoPreload,
           let generation = extendPreload.generation
        {
            selectGeneratedVideo(generation)
            selectCompatibleExtendModel(for: generation, providerKeys: providerKeys)
        }
    }

    private func selectCompatibleExtendModel(for generation: Generation, providerKeys: [ProviderKey]) {
        let availableProviderIds = Set(providerKeys.map(\.providerId))
        guard let model = providerService.models(for: .VIDEO_EXTEND).first(where: { model in
            availableProviderIds.contains(model.providerId) &&
                metadataSatisfies(model.modelParams.requiredMetadata, metadata: generation.metadata)
        }) else {
            return
        }

        selectedProviderId = model.providerId.uuidString
        selectedModelId = model.modelId.uuidString
        initializeModelParams(modelParams: model.modelParams)
    }

    private func metadataSatisfies(_ requiredKeys: [String], metadata: [String: String]) -> Bool {
        guard !requiredKeys.isEmpty else { return false }
        return requiredKeys.allSatisfy { key in
            metadata[key]?.isEmpty == false
        }
    }

    private var selectedGenerationMetadata: [String: String] {
        if !sourceMetadata.isEmpty {
            return sourceMetadata
        }
        return selectedPreviousGeneration?.metadata ?? [:]
    }
}

// MARK: - Video Transferable

struct VideoTransferable: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .movie) { data in
            VideoTransferable(data: data)
        }
    }
}

// MARK: - Reference Image Model

struct ReferenceImage: Identifiable {
    var id: UUID
    var image: PlatformImage
    var referenceType: String

    init(id: UUID = UUID(), image: PlatformImage, referenceType: String) {
        self.id = id
        self.image = image
        self.referenceType = referenceType
    }
}

struct VideoKeyframeImage: Identifiable {
    var id: UUID
    var image: PlatformImage
    var frameIndex: Int

    init(id: UUID = UUID(), image: PlatformImage, frameIndex: Int) {
        self.id = id
        self.image = image
        self.frameIndex = frameIndex
    }
}
