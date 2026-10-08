// MARK: - PlaygroundModelWorkflowTests.swift

// Workflow tests for PlaygroundCard model and its enums.
//
// Tests cover:
// - PlaygroundCardStatus enum: raw values, backward-compatible decoding
// - PlaygroundCardType enum: raw values, backward-compatible decoding,
//   displayName, icon
// - PlaygroundCard defaults, position computed property (get/set),
//   imageGenerationConfiguration and videoGenerationConfiguration
//   accessors with round-trip and corrupt-data resilience

import XCTest
@testable import Illustrate

final class PlaygroundModelWorkflowTests: XCTestCase {
    // MARK: - PlaygroundCardStatus Raw Values

    func testPlaygroundCardStatus_RawValue_Processing() {
        XCTAssertEqual(PlaygroundCardStatus.PROCESSING.rawValue, "PROCESSING")
    }

    func testPlaygroundCardStatus_RawValue_Generated() {
        XCTAssertEqual(PlaygroundCardStatus.GENERATED.rawValue, "GENERATED")
    }

    func testPlaygroundCardStatus_RawValue_Failed() {
        XCTAssertEqual(PlaygroundCardStatus.FAILED.rawValue, "FAILED")
    }

    // MARK: - PlaygroundCardStatus Backward Compatible Decoding

    func testPlaygroundCardStatus_Decode_Lowercase_Processing() throws {
        let decoded = try JSONDecoder().decode(
            PlaygroundCardStatus.self,
            from: Data("\"processing\"".utf8)
        )
        XCTAssertEqual(decoded, .PROCESSING)
    }

    func testPlaygroundCardStatus_Decode_Lowercase_Generated() throws {
        let decoded = try JSONDecoder().decode(
            PlaygroundCardStatus.self,
            from: Data("\"generated\"".utf8)
        )
        XCTAssertEqual(decoded, .GENERATED)
    }

    func testPlaygroundCardStatus_Decode_Lowercase_Failed() throws {
        let decoded = try JSONDecoder().decode(
            PlaygroundCardStatus.self,
            from: Data("\"failed\"".utf8)
        )
        XCTAssertEqual(decoded, .FAILED)
    }

    func testPlaygroundCardStatus_Decode_UnknownValue_Throws() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                PlaygroundCardStatus.self,
                from: Data("\"invalid\"".utf8)
            )
        )
    }

    // MARK: - PlaygroundCardType Raw Values

    func testPlaygroundCardType_RawValue_Image() {
        XCTAssertEqual(PlaygroundCardType.IMAGE.rawValue, "IMAGE")
    }

    func testPlaygroundCardType_RawValue_Video() {
        XCTAssertEqual(PlaygroundCardType.VIDEO.rawValue, "VIDEO")
    }

    // MARK: - PlaygroundCardType Backward Compatible Decoding

    func testPlaygroundCardType_Decode_Lowercase_Image() throws {
        let decoded = try JSONDecoder().decode(
            PlaygroundCardType.self,
            from: Data("\"image\"".utf8)
        )
        XCTAssertEqual(decoded, .IMAGE)
    }

    func testPlaygroundCardType_Decode_Lowercase_Video() throws {
        let decoded = try JSONDecoder().decode(
            PlaygroundCardType.self,
            from: Data("\"video\"".utf8)
        )
        XCTAssertEqual(decoded, .VIDEO)
    }

    func testPlaygroundCardType_Decode_UnknownValue_Throws() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                PlaygroundCardType.self,
                from: Data("\"audio\"".utf8)
            )
        )
    }

    // MARK: - PlaygroundCardType Computed Properties

    func testPlaygroundCardType_DisplayName_Image() {
        XCTAssertEqual(PlaygroundCardType.IMAGE.displayName, "Image")
    }

    func testPlaygroundCardType_DisplayName_Video() {
        XCTAssertEqual(PlaygroundCardType.VIDEO.displayName, "Video")
    }

    func testPlaygroundCardType_Icon_Image() {
        XCTAssertEqual(PlaygroundCardType.IMAGE.icon, "photo.fill")
    }

    func testPlaygroundCardType_Icon_Video() {
        XCTAssertEqual(PlaygroundCardType.VIDEO.icon, "video.fill")
    }

    // MARK: - PlaygroundCard Default Values

    func testPlaygroundCard_Default_StatusIsProcessing() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        XCTAssertEqual(card.status, .PROCESSING)
    }

    func testPlaygroundCard_Default_CardTypeFromInit() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .VIDEO)
        XCTAssertEqual(card.cardType, .VIDEO)
    }

    func testPlaygroundCard_Default_PositionIsZero() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        XCTAssertEqual(card.positionX, 0)
        XCTAssertEqual(card.positionY, 0)
    }

    func testPlaygroundCard_Default_OptionalFieldsAreNil() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        XCTAssertNil(card.parentCardId)
        XCTAssertNil(card.generationId)
        XCTAssertNil(card.errorMessage)
        XCTAssertNil(card.configurationData)
        XCTAssertNil(card.queueItemId)
    }

    // MARK: - PlaygroundCard Position Computed Property

    func testPlaygroundCard_Position_Getter_ReturnsCGPoint() {
        let card = PlaygroundCard(
            flowCanvasId: UUID(),
            cardType: .IMAGE,
            position: CGPoint(x: 100, y: 200)
        )
        XCTAssertEqual(card.position, CGPoint(x: 100, y: 200))
    }

    func testPlaygroundCard_Position_Setter_UpdatesXAndY() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        card.position = CGPoint(x: 42.5, y: 99.9)
        XCTAssertEqual(card.positionX, 42.5)
        XCTAssertEqual(card.positionY, 99.9)
    }

    func testPlaygroundCard_Position_NegativeCoordinates() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        card.position = CGPoint(x: -150, y: -300)
        XCTAssertEqual(card.position.x, -150)
        XCTAssertEqual(card.position.y, -300)
    }

    func testPlaygroundCard_Position_ZeroCoordinates() {
        let card = PlaygroundCard(
            flowCanvasId: UUID(),
            cardType: .IMAGE,
            position: CGPoint(x: 500, y: 500)
        )
        card.position = .zero
        XCTAssertEqual(card.position, .zero)
    }

    // MARK: - PlaygroundCard imageGenerationConfiguration Accessor

    func testPlaygroundCard_ImageConfig_DefaultWhenNilData() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        let config = card.imageGenerationConfiguration
        XCTAssertEqual(config.prompt, "")
        XCTAssertEqual(config.selectedModelId, "")
    }

    func testPlaygroundCard_ImageConfig_Setter_EncodesData() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        var config = ImageGenerationConfiguration()
        config.prompt = "A beautiful sunset"
        config.selectedModelId = "dalle-3"
        card.imageGenerationConfiguration = config

        XCTAssertNotNil(card.configurationData)
    }

    func testPlaygroundCard_ImageConfig_RoundTrip() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        var config = ImageGenerationConfiguration()
        config.prompt = "Round trip test"
        config.selectedModelId = "stability-core"
        config.selectedDimensions = "512x512"
        card.imageGenerationConfiguration = config

        let retrieved = card.imageGenerationConfiguration
        XCTAssertEqual(retrieved.prompt, "Round trip test")
        XCTAssertEqual(retrieved.selectedModelId, "stability-core")
        XCTAssertEqual(retrieved.selectedDimensions, "512x512")
    }

    func testPlaygroundCard_ImageConfig_CorruptData_ReturnsDefault() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        card.configurationData = Data("not valid json".utf8)

        let config = card.imageGenerationConfiguration
        XCTAssertEqual(config.prompt, "")
        XCTAssertEqual(config.selectedModelId, "")
    }

    // MARK: - PlaygroundCard videoGenerationConfiguration Accessor

    func testPlaygroundCard_VideoConfig_DefaultWhenNilData() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .VIDEO)
        let config = card.videoGenerationConfiguration
        XCTAssertEqual(config.prompt, "")
    }

    func testPlaygroundCard_VideoConfig_Setter_EncodesData() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .VIDEO)
        var config = VideoGenerationConfiguration()
        config.prompt = "A flying bird"
        card.videoGenerationConfiguration = config

        XCTAssertNotNil(card.configurationData)
    }

    func testPlaygroundCard_VideoConfig_RoundTrip() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .VIDEO)
        var config = VideoGenerationConfiguration()
        config.prompt = "Video round trip"
        config.selectedModelId = "sora-2"
        card.videoGenerationConfiguration = config

        let retrieved = card.videoGenerationConfiguration
        XCTAssertEqual(retrieved.prompt, "Video round trip")
        XCTAssertEqual(retrieved.selectedModelId, "sora-2")
    }

    func testPlaygroundCard_VideoConfig_CorruptData_ReturnsDefault() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .VIDEO)
        card.configurationData = Data("{\"invalid\":true}".utf8)

        // VideoGenerationConfiguration should fail to decode from a dict
        // that doesn't match its schema, falling back to default
        let config = card.videoGenerationConfiguration
        XCTAssertEqual(config.prompt, "")
    }

    // MARK: - PlaygroundCard Codable Round-Trip

    func testPlaygroundCard_CodableRoundTrip_PreservesAllFields() throws {
        let canvasId = UUID()
        let parentId = UUID()
        let genId = UUID()
        let card = PlaygroundCard(
            flowCanvasId: canvasId,
            cardType: .VIDEO,
            position: CGPoint(x: 250, y: 350),
            parentCardId: parentId
        )
        card.generationId = genId
        card.status = .GENERATED
        card.errorMessage = nil

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)

        XCTAssertEqual(decoded.id, card.id)
        XCTAssertEqual(decoded.flowCanvasId, canvasId)
        XCTAssertEqual(decoded.cardType, .VIDEO)
        XCTAssertEqual(decoded.status, .GENERATED)
        XCTAssertEqual(decoded.positionX, 250)
        XCTAssertEqual(decoded.positionY, 350)
        XCTAssertEqual(decoded.parentCardId, parentId)
        XCTAssertEqual(decoded.generationId, genId)
    }
}
