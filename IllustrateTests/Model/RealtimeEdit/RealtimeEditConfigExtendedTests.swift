// MARK: - RealtimeEditConfigExtendedTests.swift

// Extended tests for RealtimeEditConfiguration struct.
//
// Tests cover:
// - All initialization defaults (12 fields)
// - Full Codable round-trip with all fields set to non-default values
// - Convenience initializer

import Foundation
import XCTest
@testable import Illustrate

final class RealtimeEditConfigExtendedTests: XCTestCase {
    // MARK: - Initialization Defaults

    func testRealtimeEditConfig_default_selectedProviderId() {
        let config = RealtimeEditConfiguration()
        XCTAssertEqual(config.selectedProviderId, "")
    }

    func testRealtimeEditConfig_default_selectedModelId() {
        let config = RealtimeEditConfiguration()
        XCTAssertEqual(config.selectedModelId, "")
    }

    func testRealtimeEditConfig_default_selectedDimensions() {
        let config = RealtimeEditConfiguration()
        XCTAssertEqual(config.selectedDimensions, "1024x1024")
    }

    func testRealtimeEditConfig_default_selectedToolRawValue() {
        let config = RealtimeEditConfiguration()
        XCTAssertEqual(config.selectedToolRawValue, "select")
    }

    func testRealtimeEditConfig_default_prompt() {
        let config = RealtimeEditConfiguration()
        XCTAssertEqual(config.prompt, "")
    }

    func testRealtimeEditConfig_default_negativePrompt() {
        let config = RealtimeEditConfiguration()
        XCTAssertEqual(config.negativePrompt, "")
    }

    func testRealtimeEditConfig_default_stepsValue() {
        let config = RealtimeEditConfiguration()
        XCTAssertEqual(config.stepsValue, 28)
    }

    func testRealtimeEditConfig_default_guidanceValue() {
        let config = RealtimeEditConfiguration()
        XCTAssertEqual(config.guidanceValue, 3.5)
    }

    func testRealtimeEditConfig_default_seedValue() {
        let config = RealtimeEditConfiguration()
        XCTAssertEqual(config.seedValue, "")
    }

    func testRealtimeEditConfig_default_selectedQuality() {
        let config = RealtimeEditConfiguration()
        XCTAssertEqual(config.selectedQuality, "standard")
    }

    func testRealtimeEditConfig_default_selectedStyle() {
        let config = RealtimeEditConfiguration()
        XCTAssertEqual(config.selectedStyle, "")
    }

    func testRealtimeEditConfig_default_modelPromptEnhance() {
        let config = RealtimeEditConfiguration()
        XCTAssertTrue(config.modelPromptEnhance)
    }

    // MARK: - Convenience Initializer

    func testRealtimeEditConfig_convenienceInit_setsProviderId() {
        let config = RealtimeEditConfiguration(providerId: "openai")
        XCTAssertEqual(config.selectedProviderId, "openai")
    }

    func testRealtimeEditConfig_convenienceInit_setsModelId() {
        let config = RealtimeEditConfiguration(modelId: "dall-e-3")
        XCTAssertEqual(config.selectedModelId, "dall-e-3")
    }

    func testRealtimeEditConfig_convenienceInit_setsDimensions() {
        let config = RealtimeEditConfiguration(dimensions: "512x512")
        XCTAssertEqual(config.selectedDimensions, "512x512")
    }

    // MARK: - Full Codable Round-Trip

    func testRealtimeEditConfig_codableRoundTrip_allFieldsNonDefault() throws {
        var config = RealtimeEditConfiguration()
        config.selectedProviderId = "stability"
        config.selectedModelId = "core-v2"
        config.selectedDimensions = "512x512"
        config.selectedToolRawValue = "brush"
        config.prompt = "A beautiful landscape"
        config.negativePrompt = "blurry, low quality"
        config.stepsValue = 50
        config.guidanceValue = 7.5
        config.seedValue = "12345"
        config.selectedQuality = "high"
        config.selectedStyle = "cinematic"
        config.modelPromptEnhance = false

        let data = try JSONEncoder().encode(config)
        let restored = try JSONDecoder().decode(RealtimeEditConfiguration.self, from: data)

        XCTAssertEqual(restored.selectedProviderId, "stability")
        XCTAssertEqual(restored.selectedModelId, "core-v2")
        XCTAssertEqual(restored.selectedDimensions, "512x512")
        XCTAssertEqual(restored.selectedToolRawValue, "brush")
        XCTAssertEqual(restored.prompt, "A beautiful landscape")
        XCTAssertEqual(restored.negativePrompt, "blurry, low quality")
        XCTAssertEqual(restored.stepsValue, 50)
        XCTAssertEqual(restored.guidanceValue, 7.5)
        XCTAssertEqual(restored.seedValue, "12345")
        XCTAssertEqual(restored.selectedQuality, "high")
        XCTAssertEqual(restored.selectedStyle, "cinematic")
        XCTAssertFalse(restored.modelPromptEnhance)
    }

    func testRealtimeEditConfig_codableRoundTrip_preservesPrompt() throws {
        var config = RealtimeEditConfiguration()
        config.prompt = "Test prompt with special chars: é ñ ü"

        let data = try JSONEncoder().encode(config)
        let restored = try JSONDecoder().decode(RealtimeEditConfiguration.self, from: data)

        XCTAssertEqual(restored.prompt, "Test prompt with special chars: é ñ ü")
    }

    func testRealtimeEditConfig_codableRoundTrip_preservesGuidanceAndSteps() throws {
        var config = RealtimeEditConfiguration()
        config.stepsValue = 100
        config.guidanceValue = 15.0

        let data = try JSONEncoder().encode(config)
        let restored = try JSONDecoder().decode(RealtimeEditConfiguration.self, from: data)

        XCTAssertEqual(restored.stepsValue, 100)
        XCTAssertEqual(restored.guidanceValue, 15.0)
    }

    func testRealtimeEditConfig_codableRoundTrip_preservesModelPromptEnhanceFalse() throws {
        var config = RealtimeEditConfiguration()
        config.modelPromptEnhance = false

        let data = try JSONEncoder().encode(config)
        let restored = try JSONDecoder().decode(RealtimeEditConfiguration.self, from: data)

        XCTAssertFalse(restored.modelPromptEnhance)
    }
}
