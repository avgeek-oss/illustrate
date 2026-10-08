// MARK: - AgentCardConfigurationWorkflowTests.swift

// Tests for AgentCard configuration structs and their serialization.
//
// Tests cover:
// - ImageGenerationConfiguration Codable round-trip with all fields
// - VideoGenerationConfiguration Codable round-trip
// - StartCardConfiguration for different input types
// - ReferenceImageConfig serialization
// - Configuration storage via AgentCard.configurationData
// - Default value verification
// - Previous image flags

import Foundation
import XCTest
@testable import Illustrate

// MARK: - ImageGenerationConfiguration Tests

final class ImageGenerationConfigurationTests: XCTestCase {
    // MARK: - Default Values

    func testImageGenerationConfig_defaultValues() {
        let config = ImageGenerationConfiguration()

        XCTAssertEqual(config.selectedProviderId, "")
        XCTAssertEqual(config.selectedModelId, "")
        XCTAssertEqual(config.prompt, "")
        XCTAssertEqual(config.negativePrompt, "")
        XCTAssertEqual(config.searchPrompt, "")
        XCTAssertEqual(config.selectedDimensions, "1024x1024")
        XCTAssertEqual(config.selectedQuality, "standard")
        XCTAssertEqual(config.selectedStyle, "")
        XCTAssertEqual(config.selectedVariant, "")
        XCTAssertEqual(config.selectedInputFidelity, "")
        XCTAssertEqual(config.selectedModeration, "")
        XCTAssertEqual(config.selectedResolution, "")
        XCTAssertEqual(config.stepsValue, 28)
        XCTAssertEqual(config.guidanceValue, 3.5)
        XCTAssertEqual(config.seedValue, "")
        XCTAssertEqual(config.safetyValue, 5)
        XCTAssertEqual(config.growMaskValue, 3)
        XCTAssertTrue(config.modelPromptEnhance)
        XCTAssertEqual(config.personGeneration, "")
        XCTAssertTrue(config.selectedTools.isEmpty)
        XCTAssertTrue(config.referenceImages.isEmpty)
        XCTAssertFalse(config.usePreviousImageAsReference)
        XCTAssertFalse(config.usePreviousImageAsSourceImage)
    }

    // MARK: - Codable Round-Trip

    func testImageGenerationConfig_codableRoundTrip_allFields() throws {
        var config = ImageGenerationConfiguration()
        config.selectedProviderId = UUID().uuidString
        config.selectedModelId = UUID().uuidString
        config.prompt = "A beautiful sunset"
        config.negativePrompt = "ugly, blurry"
        config.searchPrompt = "sunset landscape"
        config.selectedDimensions = "1536x1024"
        config.selectedQuality = "hd"
        config.selectedStyle = "vivid"
        config.selectedVariant = "natural"
        config.selectedInputFidelity = "high"
        config.selectedModeration = "strict"
        config.selectedResolution = "2k"
        config.stepsValue = 50
        config.guidanceValue = 7.5
        config.seedValue = "42"
        config.safetyValue = 3
        config.growMaskValue = 5
        config.modelPromptEnhance = false
        config.personGeneration = "allow"
        config.selectedTools = ["tool1", "tool2"]
        config.usePreviousImageAsReference = true
        config.usePreviousImageAsSourceImage = true

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ImageGenerationConfiguration.self, from: data)

        XCTAssertEqual(decoded.selectedProviderId, config.selectedProviderId)
        XCTAssertEqual(decoded.selectedModelId, config.selectedModelId)
        XCTAssertEqual(decoded.prompt, config.prompt)
        XCTAssertEqual(decoded.negativePrompt, config.negativePrompt)
        XCTAssertEqual(decoded.searchPrompt, config.searchPrompt)
        XCTAssertEqual(decoded.selectedDimensions, config.selectedDimensions)
        XCTAssertEqual(decoded.selectedQuality, config.selectedQuality)
        XCTAssertEqual(decoded.selectedStyle, config.selectedStyle)
        XCTAssertEqual(decoded.selectedVariant, config.selectedVariant)
        XCTAssertEqual(decoded.selectedInputFidelity, config.selectedInputFidelity)
        XCTAssertEqual(decoded.selectedModeration, config.selectedModeration)
        XCTAssertEqual(decoded.selectedResolution, config.selectedResolution)
        XCTAssertEqual(decoded.stepsValue, config.stepsValue)
        XCTAssertEqual(decoded.guidanceValue, config.guidanceValue)
        XCTAssertEqual(decoded.seedValue, config.seedValue)
        XCTAssertEqual(decoded.safetyValue, config.safetyValue)
        XCTAssertEqual(decoded.growMaskValue, config.growMaskValue)
        XCTAssertEqual(decoded.modelPromptEnhance, config.modelPromptEnhance)
        XCTAssertEqual(decoded.personGeneration, config.personGeneration)
        XCTAssertEqual(decoded.selectedTools, config.selectedTools)
        XCTAssertEqual(decoded.usePreviousImageAsReference, config.usePreviousImageAsReference)
        XCTAssertEqual(decoded.usePreviousImageAsSourceImage, config.usePreviousImageAsSourceImage)
    }

    func testImageGenerationConfig_codableRoundTrip_withReferenceImages() throws {
        var config = ImageGenerationConfiguration()
        config.referenceImages = [
            ReferenceImageConfig(imagePath: "/path/to/image1.png", referenceType: "style"),
            ReferenceImageConfig(imagePath: "/path/to/image2.png", referenceType: "composition"),
        ]

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ImageGenerationConfiguration.self, from: data)

        XCTAssertEqual(decoded.referenceImages.count, 2)
        XCTAssertEqual(decoded.referenceImages[0].imagePath, "/path/to/image1.png")
        XCTAssertEqual(decoded.referenceImages[0].referenceType, "style")
        XCTAssertEqual(decoded.referenceImages[1].imagePath, "/path/to/image2.png")
        XCTAssertEqual(decoded.referenceImages[1].referenceType, "composition")
    }

    // MARK: - Previous Image Flags

    func testImageGenerationConfig_previousImageFlags_defaultFalse() {
        let config = ImageGenerationConfiguration()
        XCTAssertFalse(config.usePreviousImageAsReference)
        XCTAssertFalse(config.usePreviousImageAsSourceImage)
    }

    func testImageGenerationConfig_previousImageFlags_independentlySettable() {
        var config = ImageGenerationConfiguration()

        config.usePreviousImageAsReference = true
        XCTAssertTrue(config.usePreviousImageAsReference)
        XCTAssertFalse(config.usePreviousImageAsSourceImage)

        config.usePreviousImageAsSourceImage = true
        XCTAssertTrue(config.usePreviousImageAsReference)
        XCTAssertTrue(config.usePreviousImageAsSourceImage)
    }
}

// MARK: - VideoGenerationConfiguration Tests

final class VideoGenerationConfigurationTests: XCTestCase {
    func testVideoGenerationConfig_defaultValues() {
        let config = VideoGenerationConfiguration()

        XCTAssertEqual(config.selectedProviderId, "")
        XCTAssertEqual(config.selectedModelId, "")
        XCTAssertEqual(config.prompt, "")
        XCTAssertEqual(config.negativePrompt, "")
        XCTAssertEqual(config.selectedDimensions, "1280x720")
        XCTAssertEqual(config.selectedResolution, "")
        XCTAssertEqual(config.durationSeconds, 5)
        XCTAssertEqual(config.selectedFPS, 24)
        XCTAssertFalse(config.generateAudio)
        XCTAssertEqual(config.guidanceValue, 3.5)
        XCTAssertEqual(config.seedValue, "")
        XCTAssertEqual(config.safetyValue, 5)
        XCTAssertTrue(config.modelPromptEnhance)
        XCTAssertTrue(config.selectedTools.isEmpty)
        XCTAssertFalse(config.usePreviousImageAsSourceImage)
    }

    func testVideoGenerationConfig_codableRoundTrip() throws {
        var config = VideoGenerationConfiguration()
        config.selectedProviderId = UUID().uuidString
        config.selectedModelId = UUID().uuidString
        config.prompt = "A spinning globe"
        config.negativePrompt = "static, boring"
        config.selectedDimensions = "1920x1080"
        config.durationSeconds = 10
        config.selectedFPS = 30
        config.generateAudio = true
        config.guidanceValue = 5.0
        config.seedValue = "123"
        config.safetyValue = 2
        config.modelPromptEnhance = false
        config.usePreviousImageAsSourceImage = true

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(VideoGenerationConfiguration.self, from: data)

        XCTAssertEqual(decoded.selectedProviderId, config.selectedProviderId)
        XCTAssertEqual(decoded.selectedModelId, config.selectedModelId)
        XCTAssertEqual(decoded.prompt, config.prompt)
        XCTAssertEqual(decoded.negativePrompt, config.negativePrompt)
        XCTAssertEqual(decoded.selectedDimensions, config.selectedDimensions)
        XCTAssertEqual(decoded.durationSeconds, config.durationSeconds)
        XCTAssertEqual(decoded.selectedFPS, config.selectedFPS)
        XCTAssertEqual(decoded.generateAudio, config.generateAudio)
        XCTAssertEqual(decoded.guidanceValue, config.guidanceValue)
        XCTAssertEqual(decoded.seedValue, config.seedValue)
        XCTAssertEqual(decoded.safetyValue, config.safetyValue)
        XCTAssertEqual(decoded.modelPromptEnhance, config.modelPromptEnhance)
        XCTAssertEqual(decoded.usePreviousImageAsSourceImage, config.usePreviousImageAsSourceImage)
    }
}

// MARK: - StartCardConfiguration Tests

final class StartCardConfigurationTests: XCTestCase {
    func testStartCardConfig_defaultValues() {
        let config = StartCardConfiguration()
        XCTAssertEqual(config.inputType, "Text")
        XCTAssertEqual(config.textInput, "")
        XCTAssertNil(config.imagePath)
        XCTAssertNil(config.videoPath)
    }

    func testStartCardConfig_codableRoundTrip_textInput() throws {
        var config = StartCardConfiguration()
        config.inputType = "Text"
        config.textInput = "A beautiful sunrise"

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(StartCardConfiguration.self, from: data)

        XCTAssertEqual(decoded.inputType, "Text")
        XCTAssertEqual(decoded.textInput, "A beautiful sunrise")
        XCTAssertNil(decoded.imagePath)
        XCTAssertNil(decoded.videoPath)
    }

    func testStartCardConfig_codableRoundTrip_imageInput() throws {
        var config = StartCardConfiguration()
        config.inputType = "Image"
        config.imagePath = "/path/to/image.png"

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(StartCardConfiguration.self, from: data)

        XCTAssertEqual(decoded.inputType, "Image")
        XCTAssertEqual(decoded.imagePath, "/path/to/image.png")
    }

    func testStartCardConfig_codableRoundTrip_videoInput() throws {
        var config = StartCardConfiguration()
        config.inputType = "Video"
        config.videoPath = "/path/to/video.mp4"

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(StartCardConfiguration.self, from: data)

        XCTAssertEqual(decoded.inputType, "Video")
        XCTAssertEqual(decoded.videoPath, "/path/to/video.mp4")
    }
}

// MARK: - ReferenceImageConfig Tests

final class ReferenceImageConfigTests: XCTestCase {
    func testReferenceImageConfig_codableRoundTrip() throws {
        let config = ReferenceImageConfig(imagePath: "/path/to/ref.png", referenceType: "style")

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ReferenceImageConfig.self, from: data)

        XCTAssertEqual(decoded.id, config.id)
        XCTAssertEqual(decoded.imagePath, "/path/to/ref.png")
        XCTAssertEqual(decoded.referenceType, "style")
    }

    func testReferenceImageConfig_identifiable_uniqueIds() {
        let config1 = ReferenceImageConfig(imagePath: "/a.png", referenceType: "style")
        let config2 = ReferenceImageConfig(imagePath: "/b.png", referenceType: "composition")
        XCTAssertNotEqual(config1.id, config2.id)
    }
}

// MARK: - AgentCard Configuration Storage Tests

final class AgentCardConfigurationStorageTests: XCTestCase {
    func testAgentCard_imageGenerationConfig_storedAndRetrieved() {
        let agentId = UUID()
        let card = AgentCard(
            agentId: agentId,
            cardType: .process,
            processCardType: .imageGeneration
        )

        var config = card.imageGenerationConfiguration
        config.prompt = "Test prompt for storage"
        config.selectedDimensions = "512x512"
        config.stepsValue = 40
        card.imageGenerationConfiguration = config

        let retrieved = card.imageGenerationConfiguration
        XCTAssertEqual(retrieved.prompt, "Test prompt for storage")
        XCTAssertEqual(retrieved.selectedDimensions, "512x512")
        XCTAssertEqual(retrieved.stepsValue, 40)
    }

    func testAgentCard_videoGenerationConfig_storedAndRetrieved() {
        let agentId = UUID()
        let card = AgentCard(
            agentId: agentId,
            cardType: .process,
            processCardType: .videoGeneration
        )

        var config = card.videoGenerationConfiguration
        config.prompt = "Test video prompt"
        config.durationSeconds = 15
        config.selectedFPS = 60
        card.videoGenerationConfiguration = config

        let retrieved = card.videoGenerationConfiguration
        XCTAssertEqual(retrieved.prompt, "Test video prompt")
        XCTAssertEqual(retrieved.durationSeconds, 15)
        XCTAssertEqual(retrieved.selectedFPS, 60)
    }

    func testAgentCard_startConfig_storedAndRetrieved() {
        let agentId = UUID()
        let card = AgentCard.createDefault(agentId: agentId)

        var config = card.startConfiguration
        config.inputType = "Image"
        config.imagePath = "/test/image.png"
        card.startConfiguration = config

        let retrieved = card.startConfiguration
        XCTAssertEqual(retrieved.inputType, "Image")
        XCTAssertEqual(retrieved.imagePath, "/test/image.png")
    }

    func testAgentCard_configurationData_nilReturnsDefaults() {
        let agentId = UUID()
        let card = AgentCard(
            agentId: agentId,
            cardType: .process,
            processCardType: .imageGeneration
        )
        // configurationData is nil by default — should return default config
        let config = card.imageGenerationConfiguration
        XCTAssertEqual(config.selectedDimensions, "1024x1024")
        XCTAssertEqual(config.stepsValue, 28)
    }
}

// MARK: - PreviousCardInput Tests

final class PreviousCardInputTests: XCTestCase {
    func testPreviousCardInput_hasText_emptyStringIsFalse() {
        let input = PreviousCardInput(text: "")
        XCTAssertFalse(input.hasText)
    }

    func testPreviousCardInput_hasText_nonEmptyIsTrue() {
        let input = PreviousCardInput(text: "hello")
        XCTAssertTrue(input.hasText)
    }

    func testPreviousCardInput_hasText_nilIsFalse() {
        let input = PreviousCardInput()
        XCTAssertFalse(input.hasText)
    }

    func testPreviousCardInput_hasAnyInput_allNil() {
        let input = PreviousCardInput()
        XCTAssertFalse(input.hasAnyInput)
    }

    func testPreviousCardInput_hasAnyInput_withTextOnly() {
        let input = PreviousCardInput(text: "hello")
        XCTAssertTrue(input.hasAnyInput)
    }

    func testPreviousCardInput_canProvideImage_withPlaceholder() {
        let input = PreviousCardInput(isImagePlaceholder: true)
        XCTAssertTrue(input.canProvideImage)
    }
}
