// MARK: - VideoGenerationConfigTests.swift

// Tests for VideoGenerationConfiguration struct covering defaults,
// Codable round-trip, and comparison with ImageGenerationConfiguration.

import XCTest
@testable import Illustrate

final class VideoGenerationConfigTests: XCTestCase {
    // MARK: - Default Values

    func testDefault_SelectedProviderId_Empty() {
        let config = VideoGenerationConfiguration()
        XCTAssertEqual(config.selectedProviderId, "")
    }

    func testDefault_SelectedModelId_Empty() {
        let config = VideoGenerationConfiguration()
        XCTAssertEqual(config.selectedModelId, "")
    }

    func testDefault_Prompt_Empty() {
        let config = VideoGenerationConfiguration()
        XCTAssertEqual(config.prompt, "")
    }

    func testDefault_NegativePrompt_Empty() {
        let config = VideoGenerationConfiguration()
        XCTAssertEqual(config.negativePrompt, "")
    }

    func testDefault_SelectedDimensions_1280x720() {
        let config = VideoGenerationConfiguration()
        XCTAssertEqual(config.selectedDimensions, "1280x720")
    }

    func testDefault_SelectedResolution_Empty() {
        let config = VideoGenerationConfiguration()
        XCTAssertEqual(config.selectedResolution, "")
    }

    func testDefault_DurationSeconds_5() {
        let config = VideoGenerationConfiguration()
        XCTAssertEqual(config.durationSeconds, 5)
    }

    func testDefault_SelectedFPS_24() {
        let config = VideoGenerationConfiguration()
        XCTAssertEqual(config.selectedFPS, 24)
    }

    func testDefault_GenerateAudio_False() {
        let config = VideoGenerationConfiguration()
        XCTAssertFalse(config.generateAudio)
    }

    func testDefault_GuidanceValue_3Point5() {
        let config = VideoGenerationConfiguration()
        XCTAssertEqual(config.guidanceValue, 3.5)
    }

    func testDefault_SeedValue_Empty() {
        let config = VideoGenerationConfiguration()
        XCTAssertEqual(config.seedValue, "")
    }

    func testDefault_SafetyValue_5() {
        let config = VideoGenerationConfiguration()
        XCTAssertEqual(config.safetyValue, 5)
    }

    func testDefault_ModelPromptEnhance_True() {
        let config = VideoGenerationConfiguration()
        XCTAssertTrue(config.modelPromptEnhance)
    }

    func testDefault_SelectedTools_Empty() {
        let config = VideoGenerationConfiguration()
        XCTAssertTrue(config.selectedTools.isEmpty)
    }

    func testDefault_UsePreviousImageAsSourceImage_False() {
        let config = VideoGenerationConfiguration()
        XCTAssertFalse(config.usePreviousImageAsSourceImage)
    }

    // MARK: - Codable Round-Trip With Defaults

    func testCodableRoundTrip_AllDefaults() throws {
        let original = VideoGenerationConfiguration()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VideoGenerationConfiguration.self, from: data)

        XCTAssertEqual(decoded.selectedProviderId, "")
        XCTAssertEqual(decoded.selectedModelId, "")
        XCTAssertEqual(decoded.prompt, "")
        XCTAssertEqual(decoded.negativePrompt, "")
        XCTAssertEqual(decoded.selectedDimensions, "1280x720")
        XCTAssertEqual(decoded.selectedResolution, "")
        XCTAssertEqual(decoded.durationSeconds, 5)
        XCTAssertEqual(decoded.selectedFPS, 24)
        XCTAssertFalse(decoded.generateAudio)
        XCTAssertEqual(decoded.guidanceValue, 3.5)
        XCTAssertEqual(decoded.seedValue, "")
        XCTAssertEqual(decoded.safetyValue, 5)
        XCTAssertTrue(decoded.modelPromptEnhance)
        XCTAssertTrue(decoded.selectedTools.isEmpty)
        XCTAssertFalse(decoded.usePreviousImageAsSourceImage)
    }

    // MARK: - Codable Round-Trip With Custom Values

    func testCodableRoundTrip_AllCustomValues() throws {
        var config = VideoGenerationConfiguration()
        config.selectedProviderId = "provider-fal"
        config.selectedModelId = "fal-kling-v26"
        config.prompt = "A flying drone over mountains"
        config.negativePrompt = "blurry, low quality"
        config.selectedDimensions = "1920x1080"
        config.selectedResolution = "1080p"
        config.durationSeconds = 10
        config.selectedFPS = 30
        config.generateAudio = true
        config.guidanceValue = 7.0
        config.seedValue = "12345"
        config.safetyValue = 3
        config.modelPromptEnhance = false
        config.selectedTools = ["upscale", "enhance"]
        config.usePreviousImageAsSourceImage = true

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(VideoGenerationConfiguration.self, from: data)

        XCTAssertEqual(decoded.selectedProviderId, "provider-fal")
        XCTAssertEqual(decoded.selectedModelId, "fal-kling-v26")
        XCTAssertEqual(decoded.prompt, "A flying drone over mountains")
        XCTAssertEqual(decoded.negativePrompt, "blurry, low quality")
        XCTAssertEqual(decoded.selectedDimensions, "1920x1080")
        XCTAssertEqual(decoded.selectedResolution, "1080p")
        XCTAssertEqual(decoded.durationSeconds, 10)
        XCTAssertEqual(decoded.selectedFPS, 30)
        XCTAssertTrue(decoded.generateAudio)
        XCTAssertEqual(decoded.guidanceValue, 7.0)
        XCTAssertEqual(decoded.seedValue, "12345")
        XCTAssertEqual(decoded.safetyValue, 3)
        XCTAssertFalse(decoded.modelPromptEnhance)
        XCTAssertEqual(decoded.selectedTools, ["upscale", "enhance"])
        XCTAssertTrue(decoded.usePreviousImageAsSourceImage)
    }

    func testCodableRoundTrip_DurationSeconds_Preserved() throws {
        var config = VideoGenerationConfiguration()
        config.durationSeconds = 15
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(VideoGenerationConfiguration.self, from: data)
        XCTAssertEqual(decoded.durationSeconds, 15)
    }

    func testCodableRoundTrip_SelectedFPS_Preserved() throws {
        var config = VideoGenerationConfiguration()
        config.selectedFPS = 60
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(VideoGenerationConfiguration.self, from: data)
        XCTAssertEqual(decoded.selectedFPS, 60)
    }

    func testCodableRoundTrip_GenerateAudio_True_Preserved() throws {
        var config = VideoGenerationConfiguration()
        config.generateAudio = true
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(VideoGenerationConfiguration.self, from: data)
        XCTAssertTrue(decoded.generateAudio)
    }

    func testCodableRoundTrip_SelectedToolsArray_Preserved() throws {
        var config = VideoGenerationConfiguration()
        config.selectedTools = ["tool1", "tool2", "tool3"]
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(VideoGenerationConfiguration.self, from: data)
        XCTAssertEqual(decoded.selectedTools, ["tool1", "tool2", "tool3"])
    }

    // MARK: - Comparison With ImageGenerationConfiguration

    func testVideoDefaultDimensions_DifferFromImage() {
        let videoConfig = VideoGenerationConfiguration()
        let imageConfig = ImageGenerationConfiguration()
        XCTAssertEqual(videoConfig.selectedDimensions, "1280x720")
        XCTAssertEqual(imageConfig.selectedDimensions, "1024x1024")
        XCTAssertNotEqual(videoConfig.selectedDimensions, imageConfig.selectedDimensions)
    }

    func testVideoConfig_HasDurationSecondsField() {
        var config = VideoGenerationConfiguration()
        config.durationSeconds = 10
        XCTAssertEqual(config.durationSeconds, 10)
    }

    func testVideoConfig_HasSelectedFPSField() {
        var config = VideoGenerationConfiguration()
        config.selectedFPS = 30
        XCTAssertEqual(config.selectedFPS, 30)
    }

    func testVideoConfig_HasGenerateAudioField() {
        var config = VideoGenerationConfiguration()
        config.generateAudio = true
        XCTAssertTrue(config.generateAudio)
    }

    // MARK: - Edge Cases

    func testDurationSeconds_ZeroValue() throws {
        var config = VideoGenerationConfiguration()
        config.durationSeconds = 0
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(VideoGenerationConfiguration.self, from: data)
        XCTAssertEqual(decoded.durationSeconds, 0)
    }

    func testSelectedFPS_LargeValue() throws {
        var config = VideoGenerationConfiguration()
        config.selectedFPS = 120
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(VideoGenerationConfiguration.self, from: data)
        XCTAssertEqual(decoded.selectedFPS, 120)
    }

    func testSafetyValue_ZeroValue() throws {
        var config = VideoGenerationConfiguration()
        config.safetyValue = 0
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(VideoGenerationConfiguration.self, from: data)
        XCTAssertEqual(decoded.safetyValue, 0)
    }
}
