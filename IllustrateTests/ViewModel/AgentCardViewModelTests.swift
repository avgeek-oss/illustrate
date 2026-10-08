// MARK: - AgentCardViewModelTests.swift

// Tests for AgentCardViewModel computed properties and @Published state.
//
// Covers:
// - Default initialization values
// - hasContent computed property (prompt, references, whitespace handling)
// - hasSupportedModel computed property
// - selectedProviderName / selectedModelName computed properties
// - getSupportedModels / getSelectedModel with empty IDs
// - Published property mutations

import XCTest
@testable import Illustrate
@testable import IllustrateProviders

@MainActor
final class AgentCardViewModelTests: XCTestCase {
    // MARK: - Initialization

    func testInit_defaultSelectedProviderId_isEmpty() {
        let vm = AgentCardViewModel()
        XCTAssertEqual(vm.selectedProviderId, "")
    }

    func testInit_defaultSelectedModelId_isEmpty() {
        let vm = AgentCardViewModel()
        XCTAssertEqual(vm.selectedModelId, "")
    }

    func testInit_defaultPrompt_isEmpty() {
        let vm = AgentCardViewModel()
        XCTAssertEqual(vm.prompt, "")
    }

    func testInit_defaultDimensions_is1024x1024() {
        let vm = AgentCardViewModel()
        XCTAssertEqual(vm.dimensions, "1024x1024")
    }

    func testInit_setType_isImageGenerate() {
        let vm = AgentCardViewModel()
        XCTAssertEqual(vm.setType, .IMAGE_GENERATE)
    }

    // MARK: - hasContent

    func testHasContent_emptyPromptNoReferences_isFalse() {
        let vm = AgentCardViewModel()
        XCTAssertFalse(vm.hasContent)
    }

    func testHasContent_nonEmptyPrompt_isTrue() {
        let vm = AgentCardViewModel()
        vm.prompt = "A sunset"
        XCTAssertTrue(vm.hasContent)
    }

    func testHasContent_whitespaceOnly_isFalse() {
        let vm = AgentCardViewModel()
        vm.prompt = "   "
        XCTAssertFalse(vm.hasContent)
    }

    func testHasContent_newlineOnly_isFalse() {
        let vm = AgentCardViewModel()
        vm.prompt = "\n"
        XCTAssertFalse(vm.hasContent)
    }

    func testHasContent_tabAndSpaces_isFalse() {
        let vm = AgentCardViewModel()
        vm.prompt = "\t   "
        XCTAssertFalse(vm.hasContent)
    }

    func testHasContent_usePreviousImageAsReference_isTrue() {
        let vm = AgentCardViewModel()
        vm.usePreviousImageAsReference = true
        XCTAssertTrue(vm.hasContent)
    }

    func testHasContent_promptAndReference_isTrue() {
        let vm = AgentCardViewModel()
        vm.prompt = "Test prompt"
        vm.usePreviousImageAsReference = true
        XCTAssertTrue(vm.hasContent)
    }

    // MARK: - hasSupportedModel

    func testHasSupportedModel_emptyModelId_isFalse() {
        let vm = AgentCardViewModel()
        XCTAssertFalse(vm.hasSupportedModel)
    }

    func testHasSupportedModel_nonEmptyModelId_isTrue() {
        let vm = AgentCardViewModel()
        vm.selectedModelId = "some-model-id"
        XCTAssertTrue(vm.hasSupportedModel)
    }

    // MARK: - selectedProviderName

    func testSelectedProviderName_emptyProviderId_isSelectProvider() {
        let vm = AgentCardViewModel()
        XCTAssertEqual(vm.selectedProviderName, "Select Provider")
    }

    func testSelectedProviderName_validProviderId_returnsProviderName() {
        let vm = AgentCardViewModel()
        vm.selectedProviderId = EnumProviderCode.OPENAI.providerId.uuidString
        XCTAssertEqual(vm.selectedProviderName, "OpenAI")
    }

    func testSelectedProviderName_invalidProviderId_isSelectProvider() {
        let vm = AgentCardViewModel()
        vm.selectedProviderId = UUID().uuidString
        XCTAssertEqual(vm.selectedProviderName, "Select Provider")
    }

    // MARK: - selectedModelName

    func testSelectedModelName_emptyModelId_isSelectModel() {
        let vm = AgentCardViewModel()
        XCTAssertEqual(vm.selectedModelName, "Select Model")
    }

    func testSelectedModelName_invalidModelId_isSelectModel() {
        let vm = AgentCardViewModel()
        vm.selectedModelId = "nonexistent"
        XCTAssertEqual(vm.selectedModelName, "Select Model")
    }

    // MARK: - getSupportedModels / getSelectedModel

    func testGetSupportedModels_emptyProviderId_returnsEmpty() {
        let vm = AgentCardViewModel()
        XCTAssertTrue(vm.getSupportedModels().isEmpty)
    }

    func testGetSelectedModel_emptyModelId_returnsNil() {
        let vm = AgentCardViewModel()
        XCTAssertNil(vm.getSelectedModel())
    }

    func testMaxReferenceImages_xAIReservesPreviousInputs() {
        let vm = AgentCardViewModel()
        vm.selectedModelId = EnumProviderModelCode.XAI_GROK_IMAGINE_IMAGE.modelId.uuidString

        XCTAssertEqual(vm.maxReferenceImages(), 3)
        vm.usePreviousImageAsSourceImage = true
        XCTAssertEqual(vm.maxReferenceImages(), 2)
        vm.usePreviousImageAsReference = true
        XCTAssertEqual(vm.maxReferenceImages(), 1)
    }

    // MARK: - Published Property Mutations

    func testMutate_prompt() {
        let vm = AgentCardViewModel()
        vm.prompt = "New prompt"
        XCTAssertEqual(vm.prompt, "New prompt")
    }

    func testMutate_negativePrompt() {
        let vm = AgentCardViewModel()
        vm.negativePrompt = "No people"
        XCTAssertEqual(vm.negativePrompt, "No people")
    }

    func testMutate_dimensions() {
        let vm = AgentCardViewModel()
        vm.dimensions = "512x512"
        XCTAssertEqual(vm.dimensions, "512x512")
    }

    func testMutate_quality() {
        let vm = AgentCardViewModel()
        vm.quality = "hd"
        XCTAssertEqual(vm.quality, "hd")
    }

    func testMutate_style() {
        let vm = AgentCardViewModel()
        vm.style = "vivid"
        XCTAssertEqual(vm.style, "vivid")
    }

    func testMutate_guidanceValue() {
        let vm = AgentCardViewModel()
        vm.guidanceValue = 7.5
        XCTAssertEqual(vm.guidanceValue, 7.5)
    }

    func testMutate_stepsValue() {
        let vm = AgentCardViewModel()
        vm.stepsValue = 50
        XCTAssertEqual(vm.stepsValue, 50)
    }

    func testMutate_seedValue() {
        let vm = AgentCardViewModel()
        vm.seedValue = "42"
        XCTAssertEqual(vm.seedValue, "42")
    }

    func testMutate_modelPromptEnhance() {
        let vm = AgentCardViewModel()
        vm.modelPromptEnhance = false
        XCTAssertFalse(vm.modelPromptEnhance)
    }

    func testMutate_selectedTools() {
        let vm = AgentCardViewModel()
        vm.selectedTools = ["tool1", "tool2"]
        XCTAssertEqual(vm.selectedTools.count, 2)
    }

    func testMutate_usePreviousImageAsReference() {
        let vm = AgentCardViewModel()
        vm.usePreviousImageAsReference = true
        XCTAssertTrue(vm.usePreviousImageAsReference)
    }

    func testMutate_usePreviousImageAsSourceImage() {
        let vm = AgentCardViewModel()
        vm.usePreviousImageAsSourceImage = true
        XCTAssertTrue(vm.usePreviousImageAsSourceImage)
    }

    func testMutate_selectedResolution() {
        let vm = AgentCardViewModel()
        vm.selectedResolution = "1080p"
        XCTAssertEqual(vm.selectedResolution, "1080p")
    }

    func testMutate_selectedProviderId() {
        let vm = AgentCardViewModel()
        vm.selectedProviderId = "test-provider"
        XCTAssertEqual(vm.selectedProviderId, "test-provider")
    }

    func testReferenceImages_defaultEmpty() {
        let vm = AgentCardViewModel()
        XCTAssertTrue(vm.referenceImages.isEmpty)
    }

    func testIsImagePickerOpen_defaultFalse() {
        let vm = AgentCardViewModel()
        XCTAssertFalse(vm.isImagePickerOpen)
    }

    func testSelectedTools_defaultEmpty() {
        let vm = AgentCardViewModel()
        XCTAssertTrue(vm.selectedTools.isEmpty)
    }

    func testSeedValue_defaultEmpty() {
        let vm = AgentCardViewModel()
        XCTAssertEqual(vm.seedValue, "")
    }
}
