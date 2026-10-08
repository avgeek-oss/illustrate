// MARK: - AgentVideoCardViewModelTests.swift

// Tests for AgentVideoCardViewModel computed properties and @Published state.
//
// Covers:
// - Default initialization values (video-specific defaults)
// - hasContent computed property
// - hasSupportedModel computed property
// - selectedProviderName / selectedModelName computed properties
// - Video-specific fallback methods (when no model selected)
// - Published property mutations

import XCTest
@testable import Illustrate
@testable import IllustrateProviders

@MainActor
final class AgentVideoCardViewModelTests: XCTestCase {
    // MARK: - Initialization

    func testInit_defaultSelectedProviderId_isEmpty() {
        let vm = AgentVideoCardViewModel()
        XCTAssertEqual(vm.selectedProviderId, "")
    }

    func testInit_defaultSelectedModelId_isEmpty() {
        let vm = AgentVideoCardViewModel()
        XCTAssertEqual(vm.selectedModelId, "")
    }

    func testInit_defaultPrompt_isEmpty() {
        let vm = AgentVideoCardViewModel()
        XCTAssertEqual(vm.prompt, "")
    }

    func testInit_defaultDimensions_is1280x720() {
        let vm = AgentVideoCardViewModel()
        XCTAssertEqual(vm.dimensions, "1280x720")
    }

    func testInit_setType_isVideoGenerate() {
        let vm = AgentVideoCardViewModel()
        XCTAssertEqual(vm.setType, .VIDEO_GENERATE)
    }

    func testInit_defaultDuration_is5() {
        let vm = AgentVideoCardViewModel()
        XCTAssertEqual(vm.durationSeconds, 5)
    }

    func testInit_defaultFPS_is24() {
        let vm = AgentVideoCardViewModel()
        XCTAssertEqual(vm.selectedFPS, 24)
    }

    func testInit_defaultGenerateAudio_isFalse() {
        let vm = AgentVideoCardViewModel()
        XCTAssertFalse(vm.generateAudio)
    }

    // MARK: - hasContent

    func testHasContent_emptyPromptNoSource_isFalse() {
        let vm = AgentVideoCardViewModel()
        XCTAssertFalse(vm.hasContent)
    }

    func testHasContent_nonEmptyPrompt_isTrue() {
        let vm = AgentVideoCardViewModel()
        vm.prompt = "A video of waves"
        XCTAssertTrue(vm.hasContent)
    }

    func testHasContent_whitespaceOnly_isFalse() {
        let vm = AgentVideoCardViewModel()
        vm.prompt = "   "
        XCTAssertFalse(vm.hasContent)
    }

    func testHasContent_newlineOnly_isFalse() {
        let vm = AgentVideoCardViewModel()
        vm.prompt = "\n"
        XCTAssertFalse(vm.hasContent)
    }

    func testHasContent_usePreviousImageAsSourceImage_isTrue() {
        let vm = AgentVideoCardViewModel()
        vm.usePreviousImageAsSourceImage = true
        XCTAssertTrue(vm.hasContent)
    }

    func testHasContent_promptAndSource_isTrue() {
        let vm = AgentVideoCardViewModel()
        vm.prompt = "Waves"
        vm.usePreviousImageAsSourceImage = true
        XCTAssertTrue(vm.hasContent)
    }

    func testHasContent_xAIVideo15RequiresSourceImage() {
        let vm = AgentVideoCardViewModel()
        vm.selectedModelId = EnumProviderModelCode.XAI_GROK_IMAGINE_VIDEO_1_5.modelId.uuidString
        vm.prompt = "Animate a landscape"

        XCTAssertFalse(vm.hasContent)
        vm.usePreviousImageAsSourceImage = true
        XCTAssertTrue(vm.hasContent)
    }

    // MARK: - hasSupportedModel

    func testHasSupportedModel_emptyModelId_isFalse() {
        let vm = AgentVideoCardViewModel()
        XCTAssertFalse(vm.hasSupportedModel)
    }

    func testHasSupportedModel_nonEmptyModelId_isTrue() {
        let vm = AgentVideoCardViewModel()
        vm.selectedModelId = "some-video-model"
        XCTAssertTrue(vm.hasSupportedModel)
    }

    // MARK: - selectedProviderName / selectedModelName

    func testSelectedProviderName_emptyProviderId_isSelectProvider() {
        let vm = AgentVideoCardViewModel()
        XCTAssertEqual(vm.selectedProviderName, "Select Provider")
    }

    func testSelectedProviderName_validProviderId_returnsProviderName() {
        let vm = AgentVideoCardViewModel()
        vm.selectedProviderId = EnumProviderCode.OPENAI.providerId.uuidString
        XCTAssertEqual(vm.selectedProviderName, "OpenAI")
    }

    func testSelectedProviderName_invalidProviderId_isSelectProvider() {
        let vm = AgentVideoCardViewModel()
        vm.selectedProviderId = UUID().uuidString
        XCTAssertEqual(vm.selectedProviderName, "Select Provider")
    }

    func testSelectedModelName_emptyModelId_isSelectModel() {
        let vm = AgentVideoCardViewModel()
        XCTAssertEqual(vm.selectedModelName, "Select Model")
    }

    // MARK: - Video-Specific Fallbacks (No Model Selected)

    func testNoModel_supportedVideoDurations_isEmpty() {
        let vm = AgentVideoCardViewModel()
        XCTAssertTrue(vm.supportedVideoDurations().isEmpty)
    }

    func testNoModel_supportedVideoFPS_isEmpty() {
        let vm = AgentVideoCardViewModel()
        XCTAssertTrue(vm.supportedVideoFPS().isEmpty)
    }

    func testNoModel_supportedVideoResolutions_isEmpty() {
        let vm = AgentVideoCardViewModel()
        XCTAssertTrue(vm.supportedVideoResolutions().isEmpty)
    }

    func testNoModel_supportsAudio_isFalse() {
        let vm = AgentVideoCardViewModel()
        XCTAssertFalse(vm.supportsAudio())
    }

    func testNoModel_supportsSourceImage_isFalse() {
        let vm = AgentVideoCardViewModel()
        XCTAssertFalse(vm.supportsSourceImage())
    }

    func testNoModel_supportedTools_isEmpty() {
        let vm = AgentVideoCardViewModel()
        XCTAssertTrue(vm.supportedTools().isEmpty)
    }

    // MARK: - Published Property Mutations

    func testMutate_durationSeconds() {
        let vm = AgentVideoCardViewModel()
        vm.durationSeconds = 10
        XCTAssertEqual(vm.durationSeconds, 10)
    }

    func testMutate_selectedFPS() {
        let vm = AgentVideoCardViewModel()
        vm.selectedFPS = 30
        XCTAssertEqual(vm.selectedFPS, 30)
    }

    func testMutate_generateAudio() {
        let vm = AgentVideoCardViewModel()
        vm.generateAudio = true
        XCTAssertTrue(vm.generateAudio)
    }

    func testMutate_selectedResolution() {
        let vm = AgentVideoCardViewModel()
        vm.selectedResolution = "720p"
        XCTAssertEqual(vm.selectedResolution, "720p")
    }

    func testMutate_guidanceValue() {
        let vm = AgentVideoCardViewModel()
        vm.guidanceValue = 5.0
        XCTAssertEqual(vm.guidanceValue, 5.0)
    }

    func testMutate_seedValue() {
        let vm = AgentVideoCardViewModel()
        vm.seedValue = "123"
        XCTAssertEqual(vm.seedValue, "123")
    }

    func testMutate_selectedTools() {
        let vm = AgentVideoCardViewModel()
        vm.selectedTools = ["tool1"]
        XCTAssertEqual(vm.selectedTools.count, 1)
    }

    func testSelectedTools_defaultEmpty() {
        let vm = AgentVideoCardViewModel()
        XCTAssertTrue(vm.selectedTools.isEmpty)
    }

    func testSeedValue_defaultEmpty() {
        let vm = AgentVideoCardViewModel()
        XCTAssertEqual(vm.seedValue, "")
    }

    func testUsePreviousImageAsSourceImage_defaultFalse() {
        let vm = AgentVideoCardViewModel()
        XCTAssertFalse(vm.usePreviousImageAsSourceImage)
    }
}
