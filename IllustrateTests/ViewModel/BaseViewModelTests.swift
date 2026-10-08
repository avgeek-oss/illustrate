// MARK: - BaseViewModelTests.swift

// Unit tests for BaseImageViewModel and BaseVideoViewModel.
//
// Tests cover:
// - ReferenceImage struct
// - VideoTransferable struct
// - ViewModel initialization
// - Computed properties
// - Model parameter handling
// - Navigation state

import IllustrateProviders
import XCTest
@testable import Illustrate

final class BaseViewModelTests: XCTestCase {
    // MARK: - ReferenceImage Tests

    func testReferenceImage_initialization() {
        #if os(macOS)
        let image = NSImage()
        #else
        let image = UIImage()
        #endif

        let refImage = ReferenceImage(image: image, referenceType: "style")

        XCTAssertFalse(refImage.id.uuidString.isEmpty)
        XCTAssertNotNil(refImage.image)
        XCTAssertEqual(refImage.referenceType, "style")
    }

    func testReferenceImage_customId() {
        #if os(macOS)
        let image = NSImage()
        #else
        let image = UIImage()
        #endif
        let customId = UUID()

        let refImage = ReferenceImage(id: customId, image: image, referenceType: "subject")

        XCTAssertEqual(refImage.id, customId)
    }

    func testReferenceImage_identifiable() {
        #if os(macOS)
        let image = NSImage()
        #else
        let image = UIImage()
        #endif

        let ref1 = ReferenceImage(image: image, referenceType: "style")
        let ref2 = ReferenceImage(image: image, referenceType: "style")

        XCTAssertNotEqual(ref1.id, ref2.id)
    }

    func testReferenceImage_mutableReferenceType() {
        #if os(macOS)
        let image = NSImage()
        #else
        let image = UIImage()
        #endif

        var refImage = ReferenceImage(image: image, referenceType: "style")
        refImage.referenceType = "subject"

        XCTAssertEqual(refImage.referenceType, "subject")
    }

    // MARK: - BaseImageViewModel Initialization Tests

    @MainActor
    func testBaseImageViewModel_initialization() {
        let viewModel = BaseImageViewModel()

        XCTAssertEqual(viewModel.selectedProviderId, "")
        XCTAssertEqual(viewModel.selectedModelId, "")
        XCTAssertEqual(viewModel.prompt, "")
        XCTAssertEqual(viewModel.negativePrompt, "")
        XCTAssertEqual(viewModel.dimensions, "")
        XCTAssertEqual(viewModel.numberOfImages, 1)
        XCTAssertTrue(viewModel.referenceImages.isEmpty)
        XCTAssertEqual(viewModel.setType, .IMAGE_GENERATE)
    }

    @MainActor
    func testBaseImageViewModel_defaultStateValues() {
        let viewModel = BaseImageViewModel()

        XCTAssertFalse(viewModel.isPhotoPickerOpen)
        XCTAssertNil(viewModel.selectedImageItem)
        XCTAssertNil(viewModel.selectedImage)
        XCTAssertTrue(viewModel.colorPalette.isEmpty)
        XCTAssertFalse(viewModel.isCropSheetOpen)
        XCTAssertFalse(viewModel.isNavigationActive)
        XCTAssertNil(viewModel.selectedSetId)
    }

    @MainActor
    func testBaseImageViewModel_modelParameterDefaults() {
        let viewModel = BaseImageViewModel()

        XCTAssertEqual(viewModel.quality, "")
        XCTAssertEqual(viewModel.style, "")
        XCTAssertEqual(viewModel.variant, "")
        XCTAssertEqual(viewModel.background, "")
        XCTAssertEqual(viewModel.inputFidelity, "")
        XCTAssertEqual(viewModel.moderation, "")
        XCTAssertFalse(viewModel.promptEnhanceOpted)
        XCTAssertEqual(viewModel.selectedResolution, "")
        XCTAssertTrue(viewModel.selectedTools.isEmpty)
        XCTAssertEqual(viewModel.stepsValue, 28)
        XCTAssertEqual(viewModel.guidanceValue, 3.5)
        XCTAssertEqual(viewModel.seedValue, "")
        XCTAssertEqual(viewModel.safetyValue, 5)
        XCTAssertEqual(viewModel.growMaskValue, 3)
        XCTAssertTrue(viewModel.modelPromptEnhance)
        XCTAssertEqual(viewModel.personGeneration, "")
    }

    @MainActor
    func testBaseImageViewModel_referenceImageDefaults() {
        let viewModel = BaseImageViewModel()

        XCTAssertNil(viewModel.selectedReferenceImageItem)
        XCTAssertFalse(viewModel.isReferenceImagePickerOpen)
        XCTAssertFalse(viewModel.isReferenceImageCropSheetOpen)
        XCTAssertNil(viewModel.pendingReferenceImage)
        XCTAssertEqual(viewModel.pendingReferenceImageType, "")
    }

    // MARK: - BaseImageViewModel Computed Properties Tests

    @MainActor
    func testBaseImageViewModel_canGenerate_emptyPrompt() {
        let viewModel = BaseImageViewModel()
        viewModel.prompt = ""

        XCTAssertFalse(viewModel.canGenerate)
    }

    @MainActor
    func testBaseImageViewModel_canGenerate_whitespacePrompt() {
        let viewModel = BaseImageViewModel()
        viewModel.prompt = "   "

        XCTAssertFalse(viewModel.canGenerate)
    }

    @MainActor
    func testBaseImageViewModel_canGenerate_validPrompt() {
        let viewModel = BaseImageViewModel()
        viewModel.prompt = "A beautiful sunset"

        XCTAssertTrue(viewModel.canGenerate)
    }

    @MainActor
    func testBaseImageViewModel_hasSupportedModel_empty() {
        let viewModel = BaseImageViewModel()

        XCTAssertFalse(viewModel.hasSupportedModel)
    }

    @MainActor
    func testBaseImageViewModel_hasSupportedModel_withModelId() {
        let viewModel = BaseImageViewModel()
        viewModel.selectedModelId = "test-model-id"

        XCTAssertTrue(viewModel.hasSupportedModel)
    }

    // MARK: - BaseImageViewModel Navigation Tests

    @MainActor
    func testBaseImageViewModel_resetNavigation() {
        let viewModel = BaseImageViewModel()
        viewModel.isNavigationActive = true
        viewModel.selectedSetId = UUID()

        viewModel.resetNavigation()

        XCTAssertFalse(viewModel.isNavigationActive)
        XCTAssertNil(viewModel.selectedSetId)
    }

    // MARK: - BaseImageViewModel Reference Image Tests

    @MainActor
    func testBaseImageViewModel_clearReferenceImages() {
        let viewModel = BaseImageViewModel()

        #if os(macOS)
        let image = NSImage()
        #else
        let image = UIImage()
        #endif

        viewModel.referenceImages = [
            ReferenceImage(image: image, referenceType: "style"),
            ReferenceImage(image: image, referenceType: "subject"),
        ]

        viewModel.clearReferenceImages()

        XCTAssertTrue(viewModel.referenceImages.isEmpty)
    }

    @MainActor
    func testBaseImageViewModel_removeReferenceImage() {
        let viewModel = BaseImageViewModel()

        #if os(macOS)
        let image = NSImage()
        #else
        let image = UIImage()
        #endif

        let ref1 = ReferenceImage(image: image, referenceType: "style")
        let ref2 = ReferenceImage(image: image, referenceType: "subject")

        viewModel.referenceImages = [ref1, ref2]
        viewModel.removeReferenceImage(id: ref1.id)

        XCTAssertEqual(viewModel.referenceImages.count, 1)
        XCTAssertEqual(viewModel.referenceImages.first?.id, ref2.id)
    }

    @MainActor
    func testBaseImageViewModel_removeReferenceImage_nonExistent() {
        let viewModel = BaseImageViewModel()

        #if os(macOS)
        let image = NSImage()
        #else
        let image = UIImage()
        #endif

        viewModel.referenceImages = [ReferenceImage(image: image, referenceType: "style")]
        viewModel.removeReferenceImage(id: UUID())

        XCTAssertEqual(viewModel.referenceImages.count, 1)
    }

    @MainActor
    func testBaseImageViewModel_cancelReferenceImageCropping() {
        let viewModel = BaseImageViewModel()

        #if os(macOS)
        viewModel.pendingReferenceImage = NSImage()
        #else
        viewModel.pendingReferenceImage = UIImage()
        #endif

        viewModel.pendingReferenceImageType = "style"
        viewModel.isReferenceImageCropSheetOpen = true

        viewModel.cancelReferenceImageCropping()

        XCTAssertNil(viewModel.pendingReferenceImage)
        XCTAssertEqual(viewModel.pendingReferenceImageType, "")
        XCTAssertFalse(viewModel.isReferenceImageCropSheetOpen)
    }

    // MARK: - BaseImageViewModel Crop Tests

    @MainActor
    func testBaseImageViewModel_handleCropCancel() {
        let viewModel = BaseImageViewModel()

        #if os(macOS)
        viewModel.selectedImage = NSImage()
        #else
        viewModel.selectedImage = UIImage()
        #endif

        viewModel.colorPalette = ["#FF0000"]
        viewModel.isCropSheetOpen = true

        viewModel.handleCropCancel()

        XCTAssertNil(viewModel.selectedImage)
        XCTAssertTrue(viewModel.colorPalette.isEmpty)
        XCTAssertFalse(viewModel.isCropSheetOpen)
    }

    // MARK: - BaseVideoViewModel Initialization Tests

    @MainActor
    func testBaseVideoViewModel_initialization() {
        let viewModel = BaseVideoViewModel()

        XCTAssertEqual(viewModel.selectedProviderId, "")
        XCTAssertEqual(viewModel.selectedModelId, "")
        XCTAssertEqual(viewModel.prompt, "")
        XCTAssertEqual(viewModel.negativePrompt, "")
        XCTAssertEqual(viewModel.dimensions, "")
        XCTAssertEqual(viewModel.durationSeconds, 8)
        XCTAssertTrue(viewModel.generateAudio)
        XCTAssertEqual(viewModel.setType, .VIDEO_GENERATE)
    }

    @MainActor
    func testBaseVideoViewModel_videoStateDefaults() {
        let viewModel = BaseVideoViewModel()

        XCTAssertNil(viewModel.selectedVideoItem)
        XCTAssertNil(viewModel.selectedVideoData)
        XCTAssertNil(viewModel.selectedVideoThumbnail)
        XCTAssertNil(viewModel.selectedVideoURL)
        XCTAssertFalse(viewModel.isVideoPickerOpen)
        XCTAssertFalse(viewModel.isProcessingVideo)
    }

    @MainActor
    func testBaseVideoViewModel_lastFrameDefaults() {
        let viewModel = BaseVideoViewModel()

        XCTAssertNil(viewModel.selectedLastFrameItem)
        XCTAssertNil(viewModel.selectedLastFrame)
        XCTAssertFalse(viewModel.isLastFramePickerOpen)
        XCTAssertFalse(viewModel.isLastFrameCropSheetOpen)
    }

    @MainActor
    func testBaseVideoViewModel_previousGenerationDefaults() {
        let viewModel = BaseVideoViewModel()

        XCTAssertNil(viewModel.selectedPreviousGeneration)
        XCTAssertFalse(viewModel.isPreviousGenerationVideoPickerOpen)
        XCTAssertTrue(viewModel.sourceMetadata.isEmpty)
    }

    @MainActor
    func testBaseVideoViewModel_modelParameterDefaults() {
        let viewModel = BaseVideoViewModel()

        XCTAssertEqual(viewModel.quality, "")
        XCTAssertEqual(viewModel.style, "")
        XCTAssertEqual(viewModel.variant, "")
        XCTAssertEqual(viewModel.inputFidelity, "")
        XCTAssertEqual(viewModel.moderation, "")
        XCTAssertEqual(viewModel.selectedResolution, "")
        XCTAssertEqual(viewModel.selectedFPS, 24)
        XCTAssertTrue(viewModel.selectedTools.isEmpty)
        XCTAssertEqual(viewModel.numberOfVideos, 1)
        XCTAssertEqual(viewModel.motion, 135)
        XCTAssertEqual(viewModel.stickyness, 2.0)
        XCTAssertEqual(viewModel.guidanceValue, 3.5)
        XCTAssertEqual(viewModel.safetyValue, 5)
        XCTAssertEqual(viewModel.seedValue, "")
        XCTAssertTrue(viewModel.modelPromptEnhance)
    }

    // MARK: - BaseVideoViewModel Computed Properties Tests

    @MainActor
    func testBaseVideoViewModel_canGenerate_emptyPrompt() {
        let viewModel = BaseVideoViewModel()
        viewModel.prompt = ""

        XCTAssertFalse(viewModel.canGenerate)
    }

    @MainActor
    func testBaseVideoViewModel_canGenerate_validPrompt_videoGenerate() {
        let viewModel = BaseVideoViewModel()
        viewModel.prompt = "A cinematic scene"
        viewModel.setType = .VIDEO_GENERATE

        XCTAssertTrue(viewModel.canGenerate)
    }

    @MainActor
    func testBaseVideoViewModel_canGenerate_videoExtend_noVideo() {
        let viewModel = BaseVideoViewModel()
        viewModel.prompt = "Extend this video"
        viewModel.setType = .VIDEO_EXTEND
        viewModel.selectedVideoData = nil

        XCTAssertFalse(viewModel.canGenerate)
    }

    @MainActor
    func testBaseVideoViewModel_canGenerate_videoExtend_withVideo() {
        let viewModel = BaseVideoViewModel()
        viewModel.prompt = "Extend this video"
        viewModel.setType = .VIDEO_EXTEND
        viewModel.selectedVideoURL = URL(fileURLWithPath: "/tmp/test.mp4")

        XCTAssertTrue(viewModel.canGenerate)
    }

    @MainActor
    func testBaseVideoViewModel_hasSupportedModel_empty() {
        let viewModel = BaseVideoViewModel()

        XCTAssertFalse(viewModel.hasSupportedModel)
    }

    @MainActor
    func testBaseVideoViewModel_hasSupportedModel_withModelId() {
        let viewModel = BaseVideoViewModel()
        viewModel.selectedModelId = "video-model-id"

        XCTAssertTrue(viewModel.hasSupportedModel)
    }

    // MARK: - BaseVideoViewModel Navigation Tests

    @MainActor
    func testBaseVideoViewModel_resetNavigation() {
        let viewModel = BaseVideoViewModel()
        viewModel.isNavigationActive = true
        viewModel.selectedSetId = UUID()

        viewModel.resetNavigation()

        XCTAssertFalse(viewModel.isNavigationActive)
        XCTAssertNil(viewModel.selectedSetId)
    }

    // MARK: - BaseVideoViewModel Dimension Tests

    @MainActor
    func testBaseVideoViewModel_updateDimensions() {
        let viewModel = BaseVideoViewModel()
        viewModel.dimensions = "1920x1080"

        #if os(macOS)
        viewModel.selectedImage = NSImage()
        viewModel.selectedLastFrame = NSImage()
        #else
        viewModel.selectedImage = UIImage()
        viewModel.selectedLastFrame = UIImage()
        #endif

        viewModel.colorPalette = ["#FF0000"]

        viewModel.updateDimensions(dimension: "1280x720")

        XCTAssertEqual(viewModel.dimensions, "1280x720")
        XCTAssertNil(viewModel.selectedImage)
        XCTAssertNil(viewModel.selectedLastFrame)
        XCTAssertTrue(viewModel.colorPalette.isEmpty)
    }

    @MainActor
    func testBaseVideoViewModel_updateDimensions_sameDimension() {
        let viewModel = BaseVideoViewModel()
        viewModel.dimensions = "1920x1080"

        #if os(macOS)
        viewModel.selectedImage = NSImage()
        #else
        viewModel.selectedImage = UIImage()
        #endif

        viewModel.updateDimensions(dimension: "1920x1080")

        // Image should NOT be cleared when dimension is the same
        XCTAssertNotNil(viewModel.selectedImage)
    }

    // MARK: - BaseVideoViewModel Clear Methods Tests

    @MainActor
    func testBaseVideoViewModel_clearVideo() {
        let viewModel = BaseVideoViewModel()
        viewModel.selectedVideoData = Data([0x00])

        #if os(macOS)
        viewModel.selectedVideoThumbnail = NSImage()
        #else
        viewModel.selectedVideoThumbnail = UIImage()
        #endif

        viewModel.sourceMetadata = ["key": "value"]

        viewModel.clearVideo()

        XCTAssertNil(viewModel.selectedVideoItem)
        XCTAssertNil(viewModel.selectedVideoData)
        XCTAssertNil(viewModel.selectedVideoThumbnail)
        XCTAssertNil(viewModel.selectedVideoURL)
        XCTAssertNil(viewModel.selectedPreviousGeneration)
        XCTAssertTrue(viewModel.sourceMetadata.isEmpty)
    }

    @MainActor
    func testBaseVideoViewModel_clearVeoSelection() {
        let viewModel = BaseVideoViewModel()
        viewModel.sourceMetadata = ["veoUri": "test"]
        viewModel.selectedVideoData = Data([0x00])

        viewModel.clearVeoSelection()

        XCTAssertNil(viewModel.selectedPreviousGeneration)
        XCTAssertTrue(viewModel.sourceMetadata.isEmpty)
    }

    // MARK: - BaseVideoViewModel Reference Image Tests

    @MainActor
    func testBaseVideoViewModel_clearReferenceImages() {
        let viewModel = BaseVideoViewModel()

        #if os(macOS)
        let image = NSImage()
        #else
        let image = UIImage()
        #endif

        viewModel.referenceImages = [ReferenceImage(image: image, referenceType: "style")]

        viewModel.clearReferenceImages()

        XCTAssertTrue(viewModel.referenceImages.isEmpty)
    }

    @MainActor
    func testBaseVideoViewModel_cancelReferenceImageCropping() {
        let viewModel = BaseVideoViewModel()

        #if os(macOS)
        viewModel.pendingReferenceImage = NSImage()
        #else
        viewModel.pendingReferenceImage = UIImage()
        #endif

        viewModel.pendingReferenceImageType = "style"
        viewModel.isReferenceImageCropSheetOpen = true

        viewModel.cancelReferenceImageCropping()

        XCTAssertNil(viewModel.pendingReferenceImage)
        XCTAssertEqual(viewModel.pendingReferenceImageType, "")
        XCTAssertFalse(viewModel.isReferenceImageCropSheetOpen)
    }

    // MARK: - BaseVideoViewModel Last Frame Tests

    @MainActor
    func testBaseVideoViewModel_cancelLastFrameCropping() {
        let viewModel = BaseVideoViewModel()

        #if os(macOS)
        viewModel.selectedLastFrame = NSImage()
        #else
        viewModel.selectedLastFrame = UIImage()
        #endif

        viewModel.isLastFrameCropSheetOpen = true

        viewModel.cancelLastFrameCropping()

        XCTAssertNil(viewModel.selectedLastFrame)
        XCTAssertFalse(viewModel.isLastFrameCropSheetOpen)
    }

    // MARK: - BaseVideoViewModel Crop Tests

    @MainActor
    func testBaseVideoViewModel_handleCropCancel() {
        let viewModel = BaseVideoViewModel()

        #if os(macOS)
        viewModel.selectedImage = NSImage()
        #else
        viewModel.selectedImage = UIImage()
        #endif

        viewModel.colorPalette = ["#FF0000"]
        viewModel.isCropSheetOpen = true

        viewModel.handleCropCancel()

        XCTAssertNil(viewModel.selectedImage)
        XCTAssertTrue(viewModel.colorPalette.isEmpty)
        XCTAssertFalse(viewModel.isCropSheetOpen)
    }
}
