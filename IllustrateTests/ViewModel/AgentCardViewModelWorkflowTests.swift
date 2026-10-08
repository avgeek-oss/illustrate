// MARK: - AgentCardViewModelWorkflowTests.swift

// Workflow tests for AgentCardViewModel and AgentVideoCardViewModel.
//
// Covers:
// - Image ViewModel workflow scenarios
// - Video ViewModel workflow scenarios
// - Image vs Video comparison tests
// - Edge cases (Unicode, long prompts, set/clear IDs)
// - Property independence between VM instances

import XCTest
@testable import Illustrate
@testable import IllustrateProviders

@MainActor
final class AgentCardViewModelWorkflowTests: XCTestCase {
    // MARK: - Image ViewModel Workflow

    func testImageWorkflow_setAllProperties_hasContentTrue() {
        let vm = AgentCardViewModel()
        vm.prompt = "A beautiful landscape"
        vm.selectedProviderId = EnumProviderCode.OPENAI.providerId.uuidString
        vm.selectedModelId = "test-model"
        vm.dimensions = "512x512"
        XCTAssertTrue(vm.hasContent)
    }

    func testImageWorkflow_clearPrompt_hasContentDependsOnReferences() {
        let vm = AgentCardViewModel()
        vm.prompt = "Something"
        XCTAssertTrue(vm.hasContent)

        vm.prompt = ""
        XCTAssertFalse(vm.hasContent)

        vm.usePreviousImageAsReference = true
        XCTAssertTrue(vm.hasContent)
    }

    func testImageWorkflow_multipleProviderChanges_lastWins() {
        let vm = AgentCardViewModel()
        vm.selectedProviderId = EnumProviderCode.OPENAI.providerId.uuidString
        XCTAssertEqual(vm.selectedProviderName, "OpenAI")

        vm.selectedProviderId = EnumProviderCode.STABILITY_AI.providerId.uuidString
        XCTAssertEqual(vm.selectedProviderName, "Stability AI")

        vm.selectedProviderId = EnumProviderCode.GOOGLE_CLOUD.providerId.uuidString
        XCTAssertEqual(vm.selectedProviderName, "Google Cloud")
    }

    func testImageWorkflow_multipleModelChanges_lastWins() {
        let vm = AgentCardViewModel()
        vm.selectedModelId = "model-a"
        XCTAssertTrue(vm.hasSupportedModel)

        vm.selectedModelId = "model-b"
        XCTAssertTrue(vm.hasSupportedModel)
        XCTAssertEqual(vm.selectedModelId, "model-b")
    }

    // MARK: - Video ViewModel Workflow

    func testVideoWorkflow_setAllProperties_hasContentTrue() {
        let vm = AgentVideoCardViewModel()
        vm.prompt = "A timelapse of clouds"
        vm.selectedProviderId = EnumProviderCode.REPLICATE.providerId.uuidString
        vm.selectedModelId = "video-model"
        vm.durationSeconds = 8
        vm.selectedFPS = 30
        XCTAssertTrue(vm.hasContent)
    }

    func testVideoWorkflow_clearPrompt_dependsOnSourceImage() {
        let vm = AgentVideoCardViewModel()
        vm.prompt = "Something"
        XCTAssertTrue(vm.hasContent)

        vm.prompt = ""
        XCTAssertFalse(vm.hasContent)

        vm.usePreviousImageAsSourceImage = true
        XCTAssertTrue(vm.hasContent)
    }

    func testVideoWorkflow_multipleChanges_lastWins() {
        let vm = AgentVideoCardViewModel()
        vm.durationSeconds = 3
        vm.durationSeconds = 5
        vm.durationSeconds = 10
        XCTAssertEqual(vm.durationSeconds, 10)
    }

    // MARK: - Image vs Video Comparison

    func testComparison_sameProvider_differentSetTypes() {
        let imageVM = AgentCardViewModel()
        let videoVM = AgentVideoCardViewModel()

        imageVM.selectedProviderId = EnumProviderCode.OPENAI.providerId.uuidString
        videoVM.selectedProviderId = EnumProviderCode.OPENAI.providerId.uuidString

        XCTAssertEqual(imageVM.setType, .IMAGE_GENERATE)
        XCTAssertEqual(videoVM.setType, .VIDEO_GENERATE)
        XCTAssertEqual(imageVM.selectedProviderName, videoVM.selectedProviderName)
    }

    func testComparison_defaultDimensions_differ() {
        let imageVM = AgentCardViewModel()
        let videoVM = AgentVideoCardViewModel()

        XCTAssertEqual(imageVM.dimensions, "1024x1024")
        XCTAssertEqual(videoVM.dimensions, "1280x720")
    }

    func testComparison_bothEmpty_bothHasContentFalse() {
        let imageVM = AgentCardViewModel()
        let videoVM = AgentVideoCardViewModel()

        XCTAssertFalse(imageVM.hasContent)
        XCTAssertFalse(videoVM.hasContent)
    }

    func testComparison_bothWithPrompt_bothHasContentTrue() {
        let imageVM = AgentCardViewModel()
        let videoVM = AgentVideoCardViewModel()

        imageVM.prompt = "Test"
        videoVM.prompt = "Test"

        XCTAssertTrue(imageVM.hasContent)
        XCTAssertTrue(videoVM.hasContent)
    }

    // MARK: - Edge Cases

    func testEdgeCase_unicodePrompt_hasContentTrue() {
        let vm = AgentCardViewModel()
        vm.prompt = "中文提示" // Chinese prompt
        XCTAssertTrue(vm.hasContent)
    }

    func testEdgeCase_arabicPrompt_hasContentTrue() {
        let vm = AgentCardViewModel()
        vm.prompt = "مرحبا" // Arabic
        XCTAssertTrue(vm.hasContent)
    }

    func testEdgeCase_veryLongPrompt_hasContentTrue() {
        let vm = AgentCardViewModel()
        vm.prompt = String(repeating: "x", count: 5000)
        XCTAssertTrue(vm.hasContent)
    }

    func testEdgeCase_setProviderIdThenClear() {
        let vm = AgentCardViewModel()
        vm.selectedProviderId = EnumProviderCode.OPENAI.providerId.uuidString
        XCTAssertEqual(vm.selectedProviderName, "OpenAI")

        vm.selectedProviderId = ""
        XCTAssertEqual(vm.selectedProviderName, "Select Provider")
    }

    func testEdgeCase_setModelIdThenClear() {
        let vm = AgentCardViewModel()
        vm.selectedModelId = "test"
        XCTAssertTrue(vm.hasSupportedModel)

        vm.selectedModelId = ""
        XCTAssertFalse(vm.hasSupportedModel)
        XCTAssertEqual(vm.selectedModelName, "Select Model")
    }

    // MARK: - Property Independence

    func testIndependence_twoImageVMs_independentState() {
        let vm1 = AgentCardViewModel()
        let vm2 = AgentCardViewModel()

        vm1.prompt = "First"
        vm2.prompt = "Second"

        XCTAssertEqual(vm1.prompt, "First")
        XCTAssertEqual(vm2.prompt, "Second")
    }

    func testIndependence_twoVideoVMs_independentState() {
        let vm1 = AgentVideoCardViewModel()
        let vm2 = AgentVideoCardViewModel()

        vm1.durationSeconds = 3
        vm2.durationSeconds = 10

        XCTAssertEqual(vm1.durationSeconds, 3)
        XCTAssertEqual(vm2.durationSeconds, 10)
    }

    func testIndependence_imageAndVideoVM_independent() {
        let imageVM = AgentCardViewModel()
        let videoVM = AgentVideoCardViewModel()

        imageVM.prompt = "Image prompt"
        videoVM.prompt = "Video prompt"

        XCTAssertEqual(imageVM.prompt, "Image prompt")
        XCTAssertEqual(videoVM.prompt, "Video prompt")
    }

    func testIndependence_imageVM_referenceImagesDefaultEmpty() {
        let vm = AgentCardViewModel()
        XCTAssertTrue(vm.referenceImages.isEmpty)
    }

    func testIndependence_imageVM_isImagePickerOpenDefaultFalse() {
        let vm = AgentCardViewModel()
        XCTAssertFalse(vm.isImagePickerOpen)
    }
}
