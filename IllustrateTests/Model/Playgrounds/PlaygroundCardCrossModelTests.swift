// MARK: - PlaygroundCardCrossModelTests.swift

// Cross-model tests for PlaygroundCard interacting with configuration structs.
//
// Covers:
// - ImageGenerationConfiguration through PlaygroundCard encode/decode cycles
// - VideoGenerationConfiguration through PlaygroundCard encode/decode cycles
// - Configuration edge cases (shared storage, nil data, corrupted data)
// - CanvasPositionable conformance

import XCTest
@testable import Illustrate

final class PlaygroundCardCrossModelTests: XCTestCase {
    // MARK: - ImageGenerationConfiguration Through PlaygroundCard

    func testImageConfig_throughCard_allFieldsPreserved() throws {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        var config = ImageGenerationConfiguration()
        config.selectedProviderId = "provider-123"
        config.selectedModelId = "model-abc"
        config.prompt = "Beautiful sunset"
        config.selectedDimensions = "512x512"
        config.guidanceValue = 7.5
        config.seedValue = "42"
        card.imageGenerationConfiguration = config

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)

        let retrievedConfig = decoded.imageGenerationConfiguration
        XCTAssertEqual(retrievedConfig.selectedProviderId, "provider-123")
        XCTAssertEqual(retrievedConfig.selectedModelId, "model-abc")
        XCTAssertEqual(retrievedConfig.prompt, "Beautiful sunset")
        XCTAssertEqual(retrievedConfig.selectedDimensions, "512x512")
        XCTAssertEqual(retrievedConfig.guidanceValue, 7.5)
        XCTAssertEqual(retrievedConfig.seedValue, "42")
    }

    func testImageConfig_survivesMultipleEncodeDecode() throws {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        var config = ImageGenerationConfiguration()
        config.prompt = "Test prompt"
        config.selectedDimensions = "1024x1024"
        card.imageGenerationConfiguration = config

        var current = card
        for _ in 0 ..< 3 {
            let data = try JSONEncoder().encode(current)
            current = try JSONDecoder().decode(PlaygroundCard.self, from: data)
        }

        XCTAssertEqual(current.imageGenerationConfiguration.prompt, "Test prompt")
        XCTAssertEqual(current.imageGenerationConfiguration.selectedDimensions, "1024x1024")
    }

    func testImageConfig_allNonDefaults_preserved() throws {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        var config = ImageGenerationConfiguration()
        config.selectedProviderId = "prov"
        config.selectedModelId = "mdl"
        config.prompt = "Prompt"
        config.negativePrompt = "No bad things"
        config.selectedDimensions = "768x768"
        config.guidanceValue = 10.0
        config.stepsValue = 40
        config.seedValue = "1337"
        card.imageGenerationConfiguration = config

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)
        let retrieved = decoded.imageGenerationConfiguration

        XCTAssertEqual(retrieved.negativePrompt, "No bad things")
        XCTAssertEqual(retrieved.stepsValue, 40)
    }

    // MARK: - VideoGenerationConfiguration Through PlaygroundCard

    func testVideoConfig_throughCard_allFieldsPreserved() throws {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .VIDEO)
        var config = VideoGenerationConfiguration()
        config.selectedProviderId = "video-provider"
        config.prompt = "Waves crashing"
        config.durationSeconds = 8
        config.selectedFPS = 30
        config.generateAudio = true
        card.videoGenerationConfiguration = config

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)

        let retrievedConfig = decoded.videoGenerationConfiguration
        XCTAssertEqual(retrievedConfig.selectedProviderId, "video-provider")
        XCTAssertEqual(retrievedConfig.prompt, "Waves crashing")
        XCTAssertEqual(retrievedConfig.durationSeconds, 8)
        XCTAssertEqual(retrievedConfig.selectedFPS, 30)
        XCTAssertTrue(retrievedConfig.generateAudio)
    }

    func testVideoConfig_survivesMultipleEncodeDecode() throws {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .VIDEO)
        var config = VideoGenerationConfiguration()
        config.prompt = "Timelapse"
        config.durationSeconds = 10
        card.videoGenerationConfiguration = config

        var current = card
        for _ in 0 ..< 3 {
            let data = try JSONEncoder().encode(current)
            current = try JSONDecoder().decode(PlaygroundCard.self, from: data)
        }

        XCTAssertEqual(current.videoGenerationConfiguration.prompt, "Timelapse")
        XCTAssertEqual(current.videoGenerationConfiguration.durationSeconds, 10)
    }

    func testVideoConfig_nonDefaults_preserved() throws {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .VIDEO)
        var config = VideoGenerationConfiguration()
        config.guidanceValue = 5.0
        config.seedValue = "999"
        config.selectedResolution = "720p"
        card.videoGenerationConfiguration = config

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)
        let retrieved = decoded.videoGenerationConfiguration

        XCTAssertEqual(retrieved.guidanceValue, 5.0)
        XCTAssertEqual(retrieved.seedValue, "999")
        XCTAssertEqual(retrieved.selectedResolution, "720p")
    }

    // MARK: - Configuration Edge Cases

    func testSetImageThenVideo_videoConfigReadable() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        var imageConfig = ImageGenerationConfiguration()
        imageConfig.prompt = "Image prompt"
        card.imageGenerationConfiguration = imageConfig

        var videoConfig = VideoGenerationConfiguration()
        videoConfig.prompt = "Video prompt"
        card.videoGenerationConfiguration = videoConfig

        let retrieved = card.videoGenerationConfiguration
        XCTAssertEqual(retrieved.prompt, "Video prompt")
    }

    func testNilConfigurationData_bothGettersReturnDefaults() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        XCTAssertNil(card.configurationData)

        let imageConfig = card.imageGenerationConfiguration
        XCTAssertEqual(imageConfig.prompt, "")
        XCTAssertEqual(imageConfig.selectedDimensions, "1024x1024")

        let videoConfig = card.videoGenerationConfiguration
        XCTAssertEqual(videoConfig.prompt, "")
        XCTAssertEqual(videoConfig.durationSeconds, 5)
    }

    func testCorruptedConfigurationData_gracefulDefaultReturn() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        card.configurationData = Data("not valid json at all".utf8)

        let config = card.imageGenerationConfiguration
        XCTAssertEqual(config.prompt, "")
        XCTAssertEqual(config.selectedModelId, "")
    }

    func testEmptyDataConfigurationData_defaultReturn() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        card.configurationData = Data()

        let config = card.imageGenerationConfiguration
        XCTAssertEqual(config.prompt, "")
    }

    // MARK: - CanvasPositionable Conformance

    func testCanvasPositionable_id_accessible() {
        let card = PlaygroundCard(
            flowCanvasId: UUID(),
            cardType: .IMAGE,
            position: CGPoint(x: 50, y: 75)
        )
        let positionable: any CanvasPositionable = card
        XCTAssertNotNil(positionable.id)
    }

    func testCanvasPositionable_positionXY_accessible() {
        let card = PlaygroundCard(
            flowCanvasId: UUID(),
            cardType: .IMAGE,
            position: CGPoint(x: 50, y: 75)
        )
        let positionable: any CanvasPositionable = card
        XCTAssertEqual(positionable.positionX, 50)
        XCTAssertEqual(positionable.positionY, 75)
    }
}
