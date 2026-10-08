// MARK: - PlaygroundCardCodableTests.swift

// Codable edge case and configuration accessor tests for PlaygroundCard.
//
// PlaygroundCardModelTests covers: status/type decode, init, position, basic round-trip.
//
// This file adds: decode with missing optionals, JSON edge cases,
// encode validation, and configuration accessor tests.

import XCTest
@testable import Illustrate

final class PlaygroundCardCodableTests: XCTestCase {
    // MARK: - Helpers

    private func makeFullJSON(overrides: [String: Any] = [:]) throws -> Data {
        var json: [String: Any] = [
            "id": UUID().uuidString,
            "flowCanvasId": UUID().uuidString,
            "cardType": "IMAGE",
            "status": "PROCESSING",
            "positionX": 0,
            "positionY": 0,
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        for (key, value) in overrides {
            json[key] = value
        }
        return try JSONSerialization.data(withJSONObject: json)
    }

    // MARK: - Decode with Missing Optionals

    func testDecode_missingParentCardId_defaultsToNil() throws {
        let data = try makeFullJSON()
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)
        XCTAssertNil(decoded.parentCardId)
    }

    func testDecode_missingGenerationId_defaultsToNil() throws {
        let data = try makeFullJSON()
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)
        XCTAssertNil(decoded.generationId)
    }

    func testDecode_missingErrorMessage_defaultsToNil() throws {
        let data = try makeFullJSON()
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)
        XCTAssertNil(decoded.errorMessage)
    }

    func testDecode_missingConfigurationData_defaultsToNil() throws {
        let data = try makeFullJSON()
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)
        XCTAssertNil(decoded.configurationData)
    }

    func testDecode_missingQueueItemId_defaultsToNil() throws {
        let data = try makeFullJSON()
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)
        XCTAssertNil(decoded.queueItemId)
    }

    func testDecode_missingAllOptionals_allDefaults() throws {
        let data = try makeFullJSON()
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)

        XCTAssertNil(decoded.parentCardId)
        XCTAssertNil(decoded.generationId)
        XCTAssertNil(decoded.errorMessage)
        XCTAssertNil(decoded.configurationData)
        XCTAssertNil(decoded.queueItemId)
    }

    // MARK: - JSON Edge Cases: Missing Required Fields

    func testDecode_missingId_throws() {
        let json: [String: Any] = [
            "flowCanvasId": UUID().uuidString,
            "cardType": "IMAGE",
            "status": "PROCESSING",
            "positionX": 0,
            "positionY": 0,
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        XCTAssertThrowsError(try {
            let data = try JSONSerialization.data(withJSONObject: json)
            _ = try JSONDecoder().decode(PlaygroundCard.self, from: data)
        }())
    }

    func testDecode_missingFlowCanvasId_throws() {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "cardType": "IMAGE",
            "status": "PROCESSING",
            "positionX": 0,
            "positionY": 0,
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        XCTAssertThrowsError(try {
            let data = try JSONSerialization.data(withJSONObject: json)
            _ = try JSONDecoder().decode(PlaygroundCard.self, from: data)
        }())
    }

    func testDecode_missingCardType_throws() {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "flowCanvasId": UUID().uuidString,
            "status": "PROCESSING",
            "positionX": 0,
            "positionY": 0,
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        XCTAssertThrowsError(try {
            let data = try JSONSerialization.data(withJSONObject: json)
            _ = try JSONDecoder().decode(PlaygroundCard.self, from: data)
        }())
    }

    func testDecode_missingStatus_throws() {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "flowCanvasId": UUID().uuidString,
            "cardType": "IMAGE",
            "positionX": 0,
            "positionY": 0,
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        XCTAssertThrowsError(try {
            let data = try JSONSerialization.data(withJSONObject: json)
            _ = try JSONDecoder().decode(PlaygroundCard.self, from: data)
        }())
    }

    func testDecode_missingPositionX_throws() {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "flowCanvasId": UUID().uuidString,
            "cardType": "IMAGE",
            "status": "PROCESSING",
            "positionY": 0,
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        XCTAssertThrowsError(try {
            let data = try JSONSerialization.data(withJSONObject: json)
            _ = try JSONDecoder().decode(PlaygroundCard.self, from: data)
        }())
    }

    func testDecode_missingCreatedAt_throws() {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "flowCanvasId": UUID().uuidString,
            "cardType": "IMAGE",
            "status": "PROCESSING",
            "positionX": 0,
            "positionY": 0,
        ]
        XCTAssertThrowsError(try {
            let data = try JSONSerialization.data(withJSONObject: json)
            _ = try JSONDecoder().decode(PlaygroundCard.self, from: data)
        }())
    }

    func testDecode_extraUnknownKeys_succeeds() throws {
        let data = try makeFullJSON(overrides: [
            "unknownField": "ignored",
            "anotherUnknown": 42,
        ])
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)
        XCTAssertEqual(decoded.cardType, .IMAGE)
    }

    func testDecode_invalidCardType_throws() throws {
        let data = try makeFullJSON(overrides: ["cardType": "AUDIO"])
        XCTAssertThrowsError(try JSONDecoder().decode(PlaygroundCard.self, from: data))
    }

    func testDecode_invalidStatus_throws() throws {
        let data = try makeFullJSON(overrides: ["status": "DELETED"])
        XCTAssertThrowsError(try JSONDecoder().decode(PlaygroundCard.self, from: data))
    }

    // MARK: - Encode Validation

    func testEncode_producesValidJSON() throws {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        let data = try JSONEncoder().encode(card)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(jsonObject is [String: Any])
    }

    func testEncode_multipleRoundTrips_stable() throws {
        let card = PlaygroundCard(
            flowCanvasId: UUID(),
            cardType: .VIDEO,
            position: CGPoint(x: 42, y: 84)
        )
        card.status = .GENERATED
        card.generationId = UUID()

        var current = card
        for _ in 0 ..< 3 {
            let data = try JSONEncoder().encode(current)
            current = try JSONDecoder().decode(PlaygroundCard.self, from: data)
        }

        XCTAssertEqual(current.id, card.id)
        XCTAssertEqual(current.cardType, .VIDEO)
        XCTAssertEqual(current.status, .GENERATED)
        XCTAssertEqual(current.positionX, 42, accuracy: 0.001)
    }

    // MARK: - Configuration Accessor Tests

    func testImageConfig_defaultWhenNil() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        let config = card.imageGenerationConfiguration
        XCTAssertEqual(config.prompt, "")
        XCTAssertEqual(config.selectedModelId, "")
        XCTAssertEqual(config.selectedDimensions, "1024x1024")
    }

    func testImageConfig_setAndGet() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        var config = ImageGenerationConfiguration()
        config.selectedProviderId = "provider-123"
        config.prompt = "A sunset"
        config.selectedDimensions = "512x512"
        card.imageGenerationConfiguration = config

        let retrieved = card.imageGenerationConfiguration
        XCTAssertEqual(retrieved.selectedProviderId, "provider-123")
        XCTAssertEqual(retrieved.prompt, "A sunset")
        XCTAssertEqual(retrieved.selectedDimensions, "512x512")
    }

    func testImageConfig_roundTrip() throws {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        var config = ImageGenerationConfiguration()
        config.selectedModelId = "model-abc"
        config.guidanceValue = 7.5
        config.seedValue = "42"
        card.imageGenerationConfiguration = config

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)

        let retrieved = decoded.imageGenerationConfiguration
        XCTAssertEqual(retrieved.selectedModelId, "model-abc")
        XCTAssertEqual(retrieved.guidanceValue, 7.5)
        XCTAssertEqual(retrieved.seedValue, "42")
    }

    func testVideoConfig_defaultWhenNil() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .VIDEO)
        let config = card.videoGenerationConfiguration
        XCTAssertEqual(config.prompt, "")
        XCTAssertEqual(config.selectedDimensions, "1280x720")
        XCTAssertEqual(config.durationSeconds, 5)
    }

    func testVideoConfig_setAndGet() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .VIDEO)
        var config = VideoGenerationConfiguration()
        config.selectedProviderId = "video-provider"
        config.prompt = "A timelapse"
        config.durationSeconds = 10
        config.selectedFPS = 30
        card.videoGenerationConfiguration = config

        let retrieved = card.videoGenerationConfiguration
        XCTAssertEqual(retrieved.selectedProviderId, "video-provider")
        XCTAssertEqual(retrieved.prompt, "A timelapse")
        XCTAssertEqual(retrieved.durationSeconds, 10)
        XCTAssertEqual(retrieved.selectedFPS, 30)
    }

    func testVideoConfig_roundTrip() throws {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .VIDEO)
        var config = VideoGenerationConfiguration()
        config.generateAudio = true
        config.guidanceValue = 5.0
        card.videoGenerationConfiguration = config

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)

        let retrieved = decoded.videoGenerationConfiguration
        XCTAssertTrue(retrieved.generateAudio)
        XCTAssertEqual(retrieved.guidanceValue, 5.0)
    }

    func testConfig_overwriteImageWithVideo() {
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

    func testConfig_invalidData_returnsDefault() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        card.configurationData = Data("not valid json".utf8)

        let config = card.imageGenerationConfiguration
        XCTAssertEqual(config.prompt, "")
        XCTAssertEqual(config.selectedModelId, "")
    }

    func testConfig_emptyData_returnsDefault() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        card.configurationData = Data()

        let config = card.imageGenerationConfiguration
        XCTAssertEqual(config.prompt, "")
    }

    func testCanvasPositionable_conformance() {
        let card = PlaygroundCard(
            flowCanvasId: UUID(),
            cardType: .IMAGE,
            position: CGPoint(x: 50, y: 75)
        )
        let positionable: any CanvasPositionable = card
        XCTAssertEqual(positionable.positionX, 50)
        XCTAssertEqual(positionable.positionY, 75)
        XCTAssertNotNil(positionable.id)
    }
}
