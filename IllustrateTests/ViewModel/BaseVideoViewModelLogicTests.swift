// MARK: - BaseVideoViewModelLogicTests.swift

// Extended logic tests for BaseVideoViewModel computed properties and state management.
//
// BaseViewModelTests covers: init defaults (5), canGenerate empty/valid/extend (4),
// hasSupportedModel (2), resetNavigation (1), updateDimensions (2),
// clearVideo (1), clearVeoSelection (1), clearReferenceImages (1),
// cancelReferenceImageCropping (1), cancelLastFrameCropping (1), handleCropCancel (1).
//
// This file adds: canGenerate whitespace variants (newline, tab, mixed),
// canGenerate with non-video setType, handleProviderChange, searchPrompt state,
// clearVeoSelection chain verification, model query defaults, and setType mutability.

import IllustrateProviders
import XCTest
@testable import Illustrate

@MainActor
final class BaseVideoViewModelLogicTests: XCTestCase {
    private var viewModel: BaseVideoViewModel!

    override func setUp() async throws {
        try await super.setUp()
        viewModel = BaseVideoViewModel()
    }

    override func tearDown() async throws {
        viewModel = nil
        try await super.tearDown()
    }

    // MARK: - canGenerate Prompt Edge Cases

    func testCanGenerate_newlineOnlyPrompt_returnsFalse() {
        viewModel.prompt = "\n\n"
        XCTAssertFalse(viewModel.canGenerate)
    }

    func testCanGenerate_tabOnlyPrompt_returnsFalse() {
        viewModel.prompt = "\t\t"
        XCTAssertFalse(viewModel.canGenerate)
    }

    func testCanGenerate_mixedWhitespace_returnsFalse() {
        viewModel.prompt = " \n \t "
        XCTAssertFalse(viewModel.canGenerate)
    }

    func testCanGenerate_leadingTrailingWhitespace_withContent_returnsTrue() {
        viewModel.prompt = "   cinematic   "
        viewModel.setType = .VIDEO_GENERATE
        XCTAssertTrue(viewModel.canGenerate)
    }

    func testCanGenerate_unicodePrompt_returnsTrue() {
        viewModel.prompt = "美しい映像"
        viewModel.setType = .VIDEO_GENERATE
        XCTAssertTrue(viewModel.canGenerate)
    }

    func testCanGenerate_singleCharPrompt_returnsTrue() {
        viewModel.prompt = "A"
        viewModel.setType = .VIDEO_GENERATE
        XCTAssertTrue(viewModel.canGenerate)
    }

    // MARK: - canGenerate SetType Branching

    func testCanGenerate_imageGenerateSetType_returnsFalse() {
        viewModel.prompt = "A sunset"
        viewModel.setType = .IMAGE_GENERATE
        // IMAGE_GENERATE falls through to default case → false
        XCTAssertFalse(viewModel.canGenerate)
    }

    func testCanGenerate_videoGenerate_promptOnly_returnsTrue() {
        viewModel.prompt = "A cinematic scene"
        viewModel.setType = .VIDEO_GENERATE
        XCTAssertTrue(viewModel.canGenerate)
    }

    func testCanGenerate_XAIVideo15_requiresSourceImage() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .XAI_GROK_IMAGINE_VIDEO_1_5))
        viewModel.prompt = "Animate this aircraft"
        viewModel.setType = .VIDEO_GENERATE
        viewModel.selectedModelId = model.modelId.uuidString

        XCTAssertFalse(viewModel.canGenerate)

        viewModel.selectedImage = makePlatformImage()
        XCTAssertTrue(viewModel.canGenerate)
    }

    func testCanGenerate_XAIReferenceVideoEnforcesModeAndDuration() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .XAI_GROK_IMAGINE_VIDEO))
        viewModel.prompt = "Keep the aircraft consistent"
        viewModel.setType = .VIDEO_GENERATE
        viewModel.selectedModelId = model.modelId.uuidString
        viewModel.durationSeconds = 15
        viewModel.addReferenceImage(image: makePlatformImage(), referenceType: "")

        XCTAssertEqual(viewModel.durationSeconds, 10)
        XCTAssertFalse(viewModel.supportsSourceImage())
        XCTAssertTrue(viewModel.canGenerate)

        viewModel.durationSeconds = 11
        XCTAssertEqual(viewModel.durationSeconds, 10)
        XCTAssertTrue(viewModel.canGenerate)

        viewModel.selectedImage = makePlatformImage()
        XCTAssertFalse(viewModel.canGenerate)
        XCTAssertFalse(viewModel.supportsReferenceImages())
    }

    func testCanGenerate_videoExtend_withVideoData_returnsTrue() {
        viewModel.prompt = "Extend this"
        viewModel.setType = .VIDEO_EXTEND
        viewModel.selectedVideoURL = URL(fileURLWithPath: "/tmp/test.mp4")
        XCTAssertTrue(viewModel.canGenerate)
    }

    func testCanGenerate_videoExtend_noVideoData_returnsFalse() {
        viewModel.prompt = "Extend this"
        viewModel.setType = .VIDEO_EXTEND
        viewModel.selectedVideoURL = nil
        XCTAssertFalse(viewModel.canGenerate)
    }

    func testCanGenerate_videoExtend_withGeneratedSoraVideo_returnsTrue() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .OPENAI_SORA_2_REMIX))
        viewModel.prompt = "Extend this"
        viewModel.setType = .VIDEO_EXTEND
        viewModel.selectedModelId = model.modelId.uuidString
        viewModel.selectedPreviousGeneration = makeGeneratedVideo(metadata: ["soraVideoId": "video_123"])
        viewModel.selectedVideoURL = nil

        XCTAssertTrue(viewModel.canGenerate)
    }

    func testCanGenerate_videoExtend_requiresGeneratedSoraVideoSelection() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .OPENAI_SORA_2_REMIX))
        viewModel.prompt = "Extend this"
        viewModel.setType = .VIDEO_EXTEND
        viewModel.selectedModelId = model.modelId.uuidString
        viewModel.selectedPreviousGeneration = nil
        viewModel.selectedVideoURL = URL(fileURLWithPath: "/tmp/test.mp4")

        XCTAssertFalse(viewModel.canGenerate)
    }

    func testCanGenerate_videoExtend_withGeneratedGeminiInteractionVideo_returnsTrue() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .GOOGLE_GEMINI_OMNI_FLASH_VIDEO_EDIT))
        viewModel.prompt = "Make the lighting more dramatic"
        viewModel.setType = .VIDEO_EXTEND
        viewModel.selectedModelId = model.modelId.uuidString
        viewModel.selectedPreviousGeneration = makeGeneratedVideo(
            metadata: [GeminiInteractionMetadataKey.interactionId: "v1_omni"]
        )
        viewModel.selectedVideoURL = nil

        XCTAssertTrue(viewModel.requiresGeminiInteractionVideo())
        XCTAssertTrue(viewModel.canGenerate)
    }

    func testCanGenerate_videoExtend_requiresGeneratedGeminiInteractionVideoSelection() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .GOOGLE_GEMINI_OMNI_FLASH_VIDEO_EDIT))
        viewModel.prompt = "Make the lighting more dramatic"
        viewModel.setType = .VIDEO_EXTEND
        viewModel.selectedModelId = model.modelId.uuidString
        viewModel.selectedPreviousGeneration = nil
        viewModel.selectedVideoURL = URL(fileURLWithPath: "/tmp/test.mp4")

        XCTAssertTrue(viewModel.requiresGeminiInteractionVideo())
        XCTAssertFalse(viewModel.canGenerate)
    }

    func testCanGenerate_videoExtend_requiresGeminiInteractionMetadata() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .GOOGLE_GEMINI_OMNI_FLASH_VIDEO_EDIT))
        viewModel.prompt = "Make the lighting more dramatic"
        viewModel.setType = .VIDEO_EXTEND
        viewModel.selectedModelId = model.modelId.uuidString
        viewModel.selectedPreviousGeneration = makeGeneratedVideo(metadata: [:])
        viewModel.sourceMetadata = [:]

        XCTAssertTrue(viewModel.requiresGeminiInteractionVideo())
        XCTAssertFalse(viewModel.canGenerate)
    }

    func testCanGenerate_videoExtend_withGeneratedLumaVideo_returnsTrue() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2_EXTEND))
        viewModel.prompt = "Continue the camera move"
        viewModel.setType = .VIDEO_EXTEND
        viewModel.selectedModelId = model.modelId.uuidString
        viewModel.selectedPreviousGeneration = makeGeneratedVideo(metadata: ["lumaGenerationId": "gen_123"])
        viewModel.selectedVideoURL = nil

        XCTAssertTrue(viewModel.requiresLumaGeneratedVideo())
        XCTAssertTrue(viewModel.canGenerate)
    }

    func testCanGenerate_videoExtend_requiresLumaGenerationMetadata() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2_EXTEND))
        viewModel.prompt = "Continue the camera move"
        viewModel.setType = .VIDEO_EXTEND
        viewModel.selectedModelId = model.modelId.uuidString
        viewModel.selectedPreviousGeneration = makeGeneratedVideo(metadata: [:])
        viewModel.sourceMetadata = [:]

        XCTAssertTrue(viewModel.requiresLumaGeneratedVideo())
        XCTAssertFalse(viewModel.canGenerate)
    }

    func testCanGenerate_videoEdit_withGeneratedLumaVideo_returnsTrue() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2_EDIT))
        viewModel.prompt = "Restyle the video as moonlit 35mm film"
        viewModel.setType = .VIDEO_EXTEND
        viewModel.selectedModelId = model.modelId.uuidString
        viewModel.selectedPreviousGeneration = makeGeneratedVideo(metadata: ["lumaGenerationId": "gen_123"])
        viewModel.selectedVideoURL = nil

        XCTAssertTrue(viewModel.requiresLumaGeneratedVideo())
        XCTAssertTrue(viewModel.usesLumaVideoEdit())
        XCTAssertTrue(viewModel.canGenerate)
    }

    func testCanGenerate_videoEdit_requiresLumaGenerationMetadata() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2_EDIT))
        viewModel.prompt = "Restyle the video as moonlit 35mm film"
        viewModel.setType = .VIDEO_EXTEND
        viewModel.selectedModelId = model.modelId.uuidString
        viewModel.selectedPreviousGeneration = makeGeneratedVideo(metadata: [:])
        viewModel.sourceMetadata = [:]
        viewModel.selectedVideoURL = URL(fileURLWithPath: "/tmp/test.mp4")

        XCTAssertTrue(viewModel.requiresLumaGeneratedVideo())
        XCTAssertTrue(viewModel.usesLumaVideoEdit())
        XCTAssertFalse(viewModel.canGenerate)
    }

    func testCanGenerate_videoReframe_withGeneratedLumaVideo_returnsTrue() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2_REFRAME))
        viewModel.prompt = "Reframe as a cinematic landscape shot"
        viewModel.setType = .VIDEO_EXTEND
        viewModel.selectedModelId = model.modelId.uuidString
        viewModel.selectedPreviousGeneration = makeGeneratedVideo(metadata: ["lumaGenerationId": "gen_123"])
        viewModel.selectedVideoURL = nil

        XCTAssertTrue(viewModel.requiresLumaGeneratedVideo())
        XCTAssertTrue(viewModel.usesLumaVideoReframe())
        XCTAssertTrue(viewModel.canGenerate)
    }

    func testCanGenerate_videoReframe_requiresLumaGenerationMetadata() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2_REFRAME))
        viewModel.prompt = "Reframe as a cinematic landscape shot"
        viewModel.setType = .VIDEO_EXTEND
        viewModel.selectedModelId = model.modelId.uuidString
        viewModel.selectedPreviousGeneration = makeGeneratedVideo(metadata: [:])
        viewModel.sourceMetadata = [:]
        viewModel.selectedVideoURL = URL(fileURLWithPath: "/tmp/test.mp4")

        XCTAssertTrue(viewModel.requiresLumaGeneratedVideo())
        XCTAssertTrue(viewModel.usesLumaVideoReframe())
        XCTAssertFalse(viewModel.canGenerate)
    }

    func testVideoReframe_initializesVerticalTargetAt720p() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2_REFRAME))
        viewModel.selectedModelId = model.modelId.uuidString

        viewModel.initializeModelParams(modelParams: model.modelParams)

        XCTAssertEqual(viewModel.dimensions, "9:16")
        XCTAssertEqual(viewModel.selectedResolution, "720p")
    }

    func testVideoReframe_selectGeneratedVideoUsesSourceDuration() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2_REFRAME))
        viewModel.selectedModelId = model.modelId.uuidString
        viewModel.durationSeconds = 8

        viewModel.selectGeneratedVideo(makeGeneratedVideo(metadata: [
            "lumaGenerationId": "gen_123",
            "duration_seconds": "12",
        ]))

        XCTAssertEqual(viewModel.durationSeconds, 12)
    }

    func testCanGenerate_videoKeyframes_requiresTimelineKeyframe() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2_KEYFRAMES))
        viewModel.prompt = "Choreograph a product reveal"
        viewModel.setType = .VIDEO_GENERATE
        viewModel.selectedModelId = model.modelId.uuidString

        XCTAssertTrue(viewModel.usesLumaMultiKeyframes())
        XCTAssertFalse(viewModel.canGenerate)
        XCTAssertEqual(viewModel.lumaKeyframeValidationMessage(), "Add at least one keyframe image.")
    }

    func testCanGenerate_videoKeyframes_withUniqueTimelineFrames_returnsTrue() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2_KEYFRAMES))
        viewModel.prompt = "Choreograph a product reveal"
        viewModel.setType = .VIDEO_GENERATE
        viewModel.selectedModelId = model.modelId.uuidString
        viewModel.durationSeconds = 10
        viewModel.lumaKeyframes = [
            VideoKeyframeImage(image: makePlatformImage(), frameIndex: 0),
            VideoKeyframeImage(image: makePlatformImage(), frameIndex: 240),
        ]

        XCTAssertNil(viewModel.lumaKeyframeValidationMessage())
        XCTAssertTrue(viewModel.canGenerate)
    }

    func testCanGenerate_videoKeyframes_rejectsDuplicateFrameIndexes() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2_KEYFRAMES))
        viewModel.prompt = "Choreograph a product reveal"
        viewModel.setType = .VIDEO_GENERATE
        viewModel.selectedModelId = model.modelId.uuidString
        viewModel.lumaKeyframes = [
            VideoKeyframeImage(image: makePlatformImage(), frameIndex: 0),
            VideoKeyframeImage(image: makePlatformImage(), frameIndex: 0),
        ]

        XCTAssertEqual(viewModel.lumaKeyframeValidationMessage(), "Keyframe frame positions must be unique.")
        XCTAssertFalse(viewModel.canGenerate)
    }

    func testVideoKeyframes_clampsFrameIndexesWhenDurationChanges() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2_KEYFRAMES))
        viewModel.selectedModelId = model.modelId.uuidString
        viewModel.durationSeconds = 10
        viewModel.lumaKeyframes = [
            VideoKeyframeImage(image: makePlatformImage(), frameIndex: 240),
        ]

        viewModel.durationSeconds = 5
        viewModel.clampLumaKeyframesToCurrentDuration()

        XCTAssertEqual(viewModel.lumaKeyframeMaxFrameIndex, 120)
        XCTAssertEqual(viewModel.lumaKeyframes.first?.frameIndex, 120)
    }

    func testVideoKeyframes_modelChangeClearsTimelineForNonKeyframeModel() throws {
        let keyframeModel = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2_KEYFRAMES))
        let rayModel = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2))
        viewModel.selectedModelId = keyframeModel.modelId.uuidString
        viewModel.lumaKeyframes = [
            VideoKeyframeImage(image: makePlatformImage(), frameIndex: 0),
        ]

        viewModel.selectedModelId = rayModel.modelId.uuidString
        viewModel.handleModelChange()

        XCTAssertFalse(viewModel.usesLumaMultiKeyframes())
        XCTAssertTrue(viewModel.lumaKeyframes.isEmpty)
    }

    func testVideoKeyframes_modelChangeClearsStaleSourceImage() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2_KEYFRAMES))
        viewModel.selectedImage = makePlatformImage()
        viewModel.selectedModelId = model.modelId.uuidString

        viewModel.handleModelChange()

        XCTAssertTrue(viewModel.usesLumaMultiKeyframes())
        XCTAssertNil(viewModel.selectedImage)
    }

    func testLumaOutputControlsSupportMatrix() throws {
        let ray = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2))
        viewModel.selectedModelId = ray.modelId.uuidString
        XCTAssertTrue(viewModel.supportsLumaHDR())
        XCTAssertTrue(viewModel.supportsLumaLoop())

        let keyframes = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2_KEYFRAMES))
        viewModel.selectedModelId = keyframes.modelId.uuidString
        XCTAssertTrue(viewModel.supportsLumaHDR())
        XCTAssertFalse(viewModel.supportsLumaLoop())

        let edit = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2_EDIT))
        viewModel.selectedModelId = edit.modelId.uuidString
        XCTAssertTrue(viewModel.supportsLumaHDR())
        XCTAssertFalse(viewModel.supportsLumaLoop())

        let reframe = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2_REFRAME))
        viewModel.selectedModelId = reframe.modelId.uuidString
        XCTAssertFalse(viewModel.supportsLumaHDR())
        XCTAssertFalse(viewModel.supportsLumaLoop())
    }

    func testCanGenerate_lumaHDRGenerationRejectsTenSecondTextOnlyClip() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2))
        viewModel.prompt = "A cinematic scene"
        viewModel.setType = .VIDEO_GENERATE
        viewModel.selectedModelId = model.modelId.uuidString
        viewModel.durationSeconds = 10
        viewModel.selectedResolution = "720p"
        viewModel.lumaHDR = true

        XCTAssertEqual(viewModel.lumaOutputControlsValidationMessage(), "HDR generation supports 5s clips.")
        XCTAssertFalse(viewModel.canGenerate)
    }

    func testCanGenerate_lumaHDRGenerationAllowsTenSecondSelectionWithSourceFrame() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2))
        viewModel.prompt = "A cinematic scene"
        viewModel.setType = .VIDEO_GENERATE
        viewModel.selectedModelId = model.modelId.uuidString
        viewModel.durationSeconds = 10
        viewModel.selectedResolution = "720p"
        viewModel.selectedImage = makePlatformImage()
        viewModel.lumaHDR = true

        XCTAssertNil(viewModel.lumaOutputControlsValidationMessage())
        XCTAssertTrue(viewModel.canGenerate)
    }

    func testCanGenerate_lumaLoopRejectsLastFrame() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2))
        viewModel.prompt = "A seamless product turntable"
        viewModel.setType = .VIDEO_GENERATE
        viewModel.selectedModelId = model.modelId.uuidString
        viewModel.durationSeconds = 5
        viewModel.selectedLastFrame = makePlatformImage()
        viewModel.lumaLoop = true

        XCTAssertEqual(viewModel.lumaOutputControlsValidationMessage(), "Loop cannot be combined with a last frame.")
        XCTAssertFalse(viewModel.canGenerate)
    }

    func testCanGenerate_lumaEditHDRRejectsLowResolution() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2_EDIT))
        viewModel.prompt = "Restyle the source"
        viewModel.setType = .VIDEO_EXTEND
        viewModel.selectedModelId = model.modelId.uuidString
        viewModel.selectedResolution = "540p"
        viewModel.selectedPreviousGeneration = makeGeneratedVideo(metadata: ["lumaGenerationId": "gen_123"])
        viewModel.lumaHDR = true

        XCTAssertEqual(viewModel.lumaOutputControlsValidationMessage(), "HDR requires 720p or 1080p.")
        XCTAssertFalse(viewModel.canGenerate)
    }

    func testLumaOutputControls_modelChangeClearsUnsupportedFlags() throws {
        let reframe = try XCTUnwrap(ProviderService.shared.model(by: .LUMA_RAY_3_2_REFRAME))
        viewModel.selectedModelId = reframe.modelId.uuidString
        viewModel.lumaHDR = true
        viewModel.lumaEXRExport = true
        viewModel.lumaLoop = true

        viewModel.handleModelChange()

        XCTAssertFalse(viewModel.lumaHDR)
        XCTAssertFalse(viewModel.lumaEXRExport)
        XCTAssertFalse(viewModel.lumaLoop)
    }

    // MARK: - canGenerate Interaction Between Prompt and Video State

    func testCanGenerate_emptyPrompt_withVideoData_returnsFalse() {
        viewModel.prompt = ""
        viewModel.setType = .VIDEO_EXTEND
        viewModel.selectedVideoURL = URL(fileURLWithPath: "/tmp/test.mp4")
        XCTAssertFalse(viewModel.canGenerate)
    }

    func testCanGenerate_emptyPrompt_videoGenerate_returnsFalse() {
        viewModel.prompt = ""
        viewModel.setType = .VIDEO_GENERATE
        // Prompt check happens first → false
        XCTAssertFalse(viewModel.canGenerate)
    }

    // MARK: - handleProviderChange

    func testHandleProviderChange_resetsModelId() {
        viewModel.selectedModelId = "some-model"
        viewModel.selectedProviderId = ""

        viewModel.handleProviderChange()

        // No provider → getSupportedModels returns [] → first is nil → ""
        XCTAssertEqual(viewModel.selectedModelId, "")
    }

    // MARK: - clearVeoSelection Chain Behavior

    func testClearVeoSelection_clearsPreviousGeneration() {
        viewModel.sourceMetadata = ["veoUri": "test-uri"]
        viewModel.selectedVideoData = Data([0x01, 0x02])

        viewModel.clearVeoSelection()

        XCTAssertNil(viewModel.selectedPreviousGeneration)
        XCTAssertTrue(viewModel.sourceMetadata.isEmpty)
        // clearVideo is called internally, clearing video state
        XCTAssertNil(viewModel.selectedVideoData)
        XCTAssertNil(viewModel.selectedVideoItem)
        XCTAssertNil(viewModel.selectedVideoThumbnail)
        XCTAssertNil(viewModel.selectedVideoURL)
    }

    // MARK: - Model Query Defaults

    func testGetSelectedModel_emptyModelId_returnsNil() {
        XCTAssertNil(viewModel.getSelectedModel())
    }

    func testGetSupportedModels_emptyProviderId_returnsEmpty() {
        XCTAssertTrue(viewModel.getSupportedModels().isEmpty)
    }

    func testSupportsLastFrame_noModel_returnsFalse() {
        XCTAssertFalse(viewModel.supportsLastFrame())
    }

    func testRequiresVeoGeneratedVideo_noModel_returnsFalse() {
        XCTAssertFalse(viewModel.requiresVeoGeneratedVideo())
    }

    func testRequiresSoraGeneratedVideo_noModel_returnsFalse() {
        XCTAssertFalse(viewModel.requiresSoraGeneratedVideo())
    }

    func testRequiresGeminiInteractionVideo_noModel_returnsFalse() {
        XCTAssertFalse(viewModel.requiresGeminiInteractionVideo())
    }

    func testGetRequiredMetadataKeys_noModel_returnsEmpty() {
        XCTAssertTrue(viewModel.getRequiredMetadataKeys().isEmpty)
    }

    func testSupportsVideoUpload_noModel_returnsFalse() {
        XCTAssertFalse(viewModel.supportsVideoUpload())
    }

    func testSupportsSourceImage_noModel_returnsFalse() {
        XCTAssertFalse(viewModel.supportsSourceImage())
    }

    func testSupportsReferenceImages_noModel_returnsFalse() {
        XCTAssertFalse(viewModel.supportsReferenceImages())
    }

    func testMaxReferenceImages_noModel_returnsZero() {
        XCTAssertEqual(viewModel.maxReferenceImages(), 0)
    }

    func testCanAddMoreReferenceImages_noModel_returnsFalse() {
        XCTAssertFalse(viewModel.canAddMoreReferenceImages())
    }

    func testSupportedReferenceTypes_noModel_returnsEmpty() {
        XCTAssertTrue(viewModel.supportedReferenceTypes().isEmpty)
    }

    func testSupportedTools_noModel_returnsEmpty() {
        XCTAssertTrue(viewModel.supportedTools().isEmpty)
    }

    // MARK: - addReferenceImage Guard

    func testAddReferenceImage_noModel_doesNotAdd() {
        #if os(macOS)
        let image = NSImage()
        #else
        let image = UIImage()
        #endif

        viewModel.addReferenceImage(image: image, referenceType: "style")
        XCTAssertTrue(viewModel.referenceImages.isEmpty)
    }

    // MARK: - setType Mutability

    func testSetType_defaultIsVideoGenerate() {
        XCTAssertEqual(viewModel.setType, .VIDEO_GENERATE)
    }

    func testSetType_canBeChanged() {
        viewModel.setType = .VIDEO_EXTEND
        XCTAssertEqual(viewModel.setType, .VIDEO_EXTEND)
    }

    func testSetType_changesAffectCanGenerate() {
        viewModel.prompt = "A scene"

        viewModel.setType = .VIDEO_GENERATE
        XCTAssertTrue(viewModel.canGenerate)

        viewModel.setType = .IMAGE_GENERATE
        XCTAssertFalse(viewModel.canGenerate)
    }

    // MARK: - searchPrompt State

    func testSearchPrompt_defaultEmpty() {
        XCTAssertEqual(viewModel.searchPrompt, "")
    }

    func testSearchPrompt_canBeSet() {
        viewModel.searchPrompt = "ocean waves"
        XCTAssertEqual(viewModel.searchPrompt, "ocean waves")
    }

    // MARK: - supportsFlexibleReferenceDimensions

    func testSupportsFlexibleReferenceDimensions_noModel_returnsTrue() {
        // Default is true via ?? true
        XCTAssertTrue(viewModel.supportsFlexibleReferenceDimensions())
    }

    // MARK: - updateDimensions Guard Path

    func testUpdateDimensions_differentDimension_updatesState() {
        viewModel.dimensions = "1920x1080"
        #if os(macOS)
        viewModel.selectedImage = NSImage()
        #else
        viewModel.selectedImage = UIImage()
        #endif

        viewModel.updateDimensions(dimension: "1280x720")

        XCTAssertEqual(viewModel.dimensions, "1280x720")
        XCTAssertNil(viewModel.selectedImage)
    }

    func testUpdateDimensions_sameDimension_preservesState() {
        viewModel.dimensions = "1920x1080"
        #if os(macOS)
        viewModel.selectedImage = NSImage()
        #else
        viewModel.selectedImage = UIImage()
        #endif

        viewModel.updateDimensions(dimension: "1920x1080")

        // Guard returns early, image preserved
        XCTAssertNotNil(viewModel.selectedImage)
        XCTAssertEqual(viewModel.dimensions, "1920x1080")
    }

    func testUpdateDimensions_clearsLastFrame() {
        #if os(macOS)
        viewModel.selectedLastFrame = NSImage()
        #else
        viewModel.selectedLastFrame = UIImage()
        #endif

        viewModel.updateDimensions(dimension: "1280x720")

        XCTAssertNil(viewModel.selectedLastFrame)
    }

    private func makeGeneratedVideo(metadata: [String: String]) -> Generation {
        Generation(
            id: UUID(),
            setId: UUID(),
            modelId: UUID().uuidString,
            prompt: "Original Sora video",
            promptEnhanceOpted: false,
            promptAfterEnhance: "",
            dimensions: "1280x720",
            size: 1024,
            creditUsed: 0.4,
            status: .GENERATED,
            colorPalette: [],
            contentType: .VIDEO,
            metadata: metadata
        )
    }

    private func makePlatformImage() -> PlatformImage {
        #if os(macOS)
        NSImage(size: NSSize(width: 16, height: 16))
        #else
        UIImage()
        #endif
    }
}
