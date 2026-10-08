// MARK: - BaseImageViewModelLogicTests.swift

// Extended logic tests for BaseImageViewModel computed properties and state management.
//
// BaseViewModelTests covers: init defaults (4), canGenerate empty/whitespace/valid (3),
// hasSupportedModel (2), resetNavigation (1), clearReferenceImages (1),
// removeReferenceImage (2), cancelReferenceImageCropping (1), handleCropCancel (1).
//
// This file adds: canGenerate edge cases (setType branching, newline/tab prompts),
// handleDimensionChange, handleProviderChange, addReferenceImage guard,
// canAddMoreReferenceImages, and setType mutability.

import IllustrateProviders
import XCTest
@testable import Illustrate

@MainActor
final class BaseImageViewModelLogicTests: XCTestCase {
    private var viewModel: BaseImageViewModel!

    override func setUp() async throws {
        try await super.setUp()
        viewModel = BaseImageViewModel()
    }

    override func tearDown() async throws {
        viewModel = nil
        try await super.tearDown()
    }

    // MARK: - canGenerate SetType Branching

    func testCanGenerate_imageGenerate_validPrompt_returnsTrue() {
        viewModel.setType = .IMAGE_GENERATE
        viewModel.prompt = "A sunset"
        XCTAssertTrue(viewModel.canGenerate)
    }

    func testCanGenerate_nonImageGenerate_noImage_returnsFalse() {
        viewModel.setType = .VIDEO_GENERATE
        viewModel.prompt = "A sunset"
        // No selectedImage set
        XCTAssertFalse(viewModel.canGenerate)
    }

    func testCanGenerate_nonImageGenerate_withImage_returnsTrue() {
        viewModel.setType = .VIDEO_GENERATE
        viewModel.prompt = "A sunset"
        #if os(macOS)
        viewModel.selectedImage = NSImage()
        #else
        viewModel.selectedImage = UIImage()
        #endif
        XCTAssertTrue(viewModel.canGenerate)
    }

    func testCanGenerate_videoExtend_withImage_returnsTrue() {
        viewModel.setType = .VIDEO_EXTEND
        viewModel.prompt = "Extend this"
        #if os(macOS)
        viewModel.selectedImage = NSImage()
        #else
        viewModel.selectedImage = UIImage()
        #endif
        XCTAssertTrue(viewModel.canGenerate)
    }

    func testCanGenerate_videoExtend_noImage_returnsFalse() {
        viewModel.setType = .VIDEO_EXTEND
        viewModel.prompt = "Extend this"
        XCTAssertFalse(viewModel.canGenerate)
    }

    // MARK: - canGenerate Prompt Edge Cases

    func testCanGenerate_newlineOnlyPrompt_returnsFalse() {
        viewModel.prompt = "\n\n\n"
        XCTAssertFalse(viewModel.canGenerate)
    }

    func testCanGenerate_tabOnlyPrompt_returnsFalse() {
        viewModel.prompt = "\t\t"
        XCTAssertFalse(viewModel.canGenerate)
    }

    func testCanGenerate_mixedWhitespacePrompt_returnsFalse() {
        viewModel.prompt = " \n \t \n "
        XCTAssertFalse(viewModel.canGenerate)
    }

    func testCanGenerate_leadingTrailingWhitespace_withContent_returnsTrue() {
        viewModel.prompt = "   Hello World   "
        XCTAssertTrue(viewModel.canGenerate)
    }

    func testCanGenerate_unicodePrompt_returnsTrue() {
        viewModel.prompt = "美しい風景"
        XCTAssertTrue(viewModel.canGenerate)
    }

    func testCanGenerate_singleCharPrompt_returnsTrue() {
        viewModel.prompt = "A"
        XCTAssertTrue(viewModel.canGenerate)
    }

    func testCanGenerate_emojiPrompt_returnsTrue() {
        viewModel.prompt = "🌅🏔️"
        XCTAssertTrue(viewModel.canGenerate)
    }

    // MARK: - handleDimensionChange

    func testHandleDimensionChange_clearsSelectedImage() {
        #if os(macOS)
        viewModel.selectedImage = NSImage()
        #else
        viewModel.selectedImage = UIImage()
        #endif

        viewModel.handleDimensionChange()

        XCTAssertNil(viewModel.selectedImage)
    }

    func testHandleDimensionChange_clearsColorPalette() {
        viewModel.colorPalette = ["#FF0000", "#00FF00", "#0000FF"]

        viewModel.handleDimensionChange()

        XCTAssertTrue(viewModel.colorPalette.isEmpty)
    }

    func testHandleDimensionChange_preservesOtherState() {
        viewModel.prompt = "Keep this"
        viewModel.negativePrompt = "Negative"
        viewModel.dimensions = "1024x1024"

        viewModel.handleDimensionChange()

        XCTAssertEqual(viewModel.prompt, "Keep this")
        XCTAssertEqual(viewModel.negativePrompt, "Negative")
        XCTAssertEqual(viewModel.dimensions, "1024x1024")
    }

    func testHandleDimensionChange_calledMultipleTimes_safe() {
        #if os(macOS)
        viewModel.selectedImage = NSImage()
        #else
        viewModel.selectedImage = UIImage()
        #endif

        viewModel.handleDimensionChange()
        viewModel.handleDimensionChange()
        viewModel.handleDimensionChange()

        XCTAssertNil(viewModel.selectedImage)
        XCTAssertTrue(viewModel.colorPalette.isEmpty)
    }

    func testHandleDimensionChange_alreadyNil_noEffect() {
        XCTAssertNil(viewModel.selectedImage)
        XCTAssertTrue(viewModel.colorPalette.isEmpty)

        viewModel.handleDimensionChange()

        XCTAssertNil(viewModel.selectedImage)
        XCTAssertTrue(viewModel.colorPalette.isEmpty)
    }

    // MARK: - handleProviderChange

    func testHandleProviderChange_resetsModelId() {
        viewModel.selectedModelId = "some-model-id"
        viewModel.selectedProviderId = ""

        viewModel.handleProviderChange()

        // With no provider selected, getSupportedModels returns []
        XCTAssertEqual(viewModel.selectedModelId, "")
    }

    // MARK: - addReferenceImage Guard Behavior

    func testAddReferenceImage_noModelSelected_doesNotAdd() {
        // Without a model selected, canAddMoreReferenceImages returns false
        #if os(macOS)
        let image = NSImage()
        #else
        let image = UIImage()
        #endif

        viewModel.addReferenceImage(image: image, referenceType: "style")

        XCTAssertTrue(viewModel.referenceImages.isEmpty)
    }

    // MARK: - canAddMoreReferenceImages

    func testCanAddMoreReferenceImages_noModel_returnsFalse() {
        XCTAssertFalse(viewModel.canAddMoreReferenceImages())
    }

    // MARK: - supportsReferenceImages

    func testSupportsReferenceImages_noModel_returnsFalse() {
        XCTAssertFalse(viewModel.supportsReferenceImages())
    }

    // MARK: - maxReferenceImages

    func testMaxReferenceImages_noModel_returnsZero() {
        XCTAssertEqual(viewModel.maxReferenceImages(), 0)
    }

    func testMaxReferenceImages_XAIReservesOneSlotForSourceImage() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .XAI_GROK_IMAGINE_IMAGE))
        viewModel.selectedModelId = model.modelId.uuidString
        XCTAssertEqual(viewModel.maxReferenceImages(), 3)

        #if os(macOS)
        viewModel.selectedImage = NSImage()
        #else
        viewModel.selectedImage = UIImage()
        #endif
        XCTAssertEqual(viewModel.maxReferenceImages(), 2)
    }

    func testMaxReferenceImages_ReveReservesOneSlotForSourceImage() throws {
        let model = try XCTUnwrap(ProviderService.shared.model(by: .REPLICATE_REVE_2_1))
        viewModel.selectedModelId = model.modelId.uuidString
        XCTAssertEqual(viewModel.maxReferenceImages(), 8)

        #if os(macOS)
        viewModel.selectedImage = NSImage()
        #else
        viewModel.selectedImage = UIImage()
        #endif
        XCTAssertEqual(viewModel.maxReferenceImages(), 7)
    }

    // MARK: - supportedReferenceTypes

    func testSupportedReferenceTypes_noModel_returnsEmpty() {
        XCTAssertTrue(viewModel.supportedReferenceTypes().isEmpty)
    }

    // MARK: - supportedTools

    func testSupportedTools_noModel_returnsEmpty() {
        XCTAssertTrue(viewModel.supportedTools().isEmpty)
    }

    // MARK: - supportsFlexibleReferenceDimensions

    func testSupportsFlexibleReferenceDimensions_noModel_returnsTrue() {
        // Default is true when model is nil (via ?? true)
        XCTAssertTrue(viewModel.supportsFlexibleReferenceDimensions())
    }

    // MARK: - setType Mutability

    func testSetType_defaultIsImageGenerate() {
        XCTAssertEqual(viewModel.setType, .IMAGE_GENERATE)
    }

    func testSetType_canBeChanged() {
        viewModel.setType = .VIDEO_GENERATE
        XCTAssertEqual(viewModel.setType, .VIDEO_GENERATE)
    }

    func testSetType_changesAffectCanGenerate() {
        viewModel.prompt = "A sunset"

        viewModel.setType = .IMAGE_GENERATE
        XCTAssertTrue(viewModel.canGenerate)

        viewModel.setType = .VIDEO_EXTEND
        // No image selected, so false for non-IMAGE_GENERATE
        XCTAssertFalse(viewModel.canGenerate)
    }

    // MARK: - searchPrompt State

    func testSearchPrompt_defaultEmpty() {
        XCTAssertEqual(viewModel.searchPrompt, "")
    }

    func testSearchPrompt_canBeSet() {
        viewModel.searchPrompt = "landscape scenery"
        XCTAssertEqual(viewModel.searchPrompt, "landscape scenery")
    }

    // MARK: - getSelectedModel Without Provider

    func testGetSelectedModel_emptyModelId_returnsNil() {
        XCTAssertNil(viewModel.getSelectedModel())
    }

    // MARK: - getSupportedModels Without Provider

    func testGetSupportedModels_emptyProviderId_returnsEmpty() {
        XCTAssertTrue(viewModel.getSupportedModels().isEmpty)
    }
}
