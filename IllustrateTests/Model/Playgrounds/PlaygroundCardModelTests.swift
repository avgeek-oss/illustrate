// MARK: - PlaygroundCardModelTests.swift

// Tests for PlaygroundCard model, PlaygroundCardStatus, and PlaygroundCardType enums.
//
// Covers:
// - PlaygroundCardStatus backward-compatible decoding (uppercase + lowercase)
// - PlaygroundCardType backward-compatible decoding, displayName, icon
// - PlaygroundCard initialization and defaults
// - PlaygroundCard position computed property
// - PlaygroundCard Codable round-trip

import XCTest
@testable import Illustrate

final class PlaygroundCardModelTests: XCTestCase {
    // MARK: - PlaygroundCardStatus Backward-Compatible Decoding

    func testCardStatus_decode_lowercaseProcessing() throws {
        let decoded = try JSONDecoder().decode(
            PlaygroundCardStatus.self,
            from: Data("\"processing\"".utf8)
        )
        XCTAssertEqual(decoded, .PROCESSING)
    }

    func testCardStatus_decode_uppercaseProcessing() throws {
        let decoded = try JSONDecoder().decode(
            PlaygroundCardStatus.self,
            from: Data("\"PROCESSING\"".utf8)
        )
        XCTAssertEqual(decoded, .PROCESSING)
    }

    func testCardStatus_decode_lowercaseGenerated() throws {
        let decoded = try JSONDecoder().decode(
            PlaygroundCardStatus.self,
            from: Data("\"generated\"".utf8)
        )
        XCTAssertEqual(decoded, .GENERATED)
    }

    func testCardStatus_decode_uppercaseGenerated() throws {
        let decoded = try JSONDecoder().decode(
            PlaygroundCardStatus.self,
            from: Data("\"GENERATED\"".utf8)
        )
        XCTAssertEqual(decoded, .GENERATED)
    }

    func testCardStatus_decode_lowercaseFailed() throws {
        let decoded = try JSONDecoder().decode(
            PlaygroundCardStatus.self,
            from: Data("\"failed\"".utf8)
        )
        XCTAssertEqual(decoded, .FAILED)
    }

    func testCardStatus_decode_uppercaseFailed() throws {
        let decoded = try JSONDecoder().decode(
            PlaygroundCardStatus.self,
            from: Data("\"FAILED\"".utf8)
        )
        XCTAssertEqual(decoded, .FAILED)
    }

    func testCardStatus_decode_unknownValue_throws() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                PlaygroundCardStatus.self,
                from: Data("\"unknown\"".utf8)
            )
        )
    }

    func testCardStatus_decode_emptyString_throws() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                PlaygroundCardStatus.self,
                from: Data("\"\"".utf8)
            )
        )
    }

    func testCardStatus_rawValues() {
        XCTAssertEqual(PlaygroundCardStatus.PROCESSING.rawValue, "PROCESSING")
        XCTAssertEqual(PlaygroundCardStatus.GENERATED.rawValue, "GENERATED")
        XCTAssertEqual(PlaygroundCardStatus.FAILED.rawValue, "FAILED")
    }

    func testCardStatus_encodeDecode_allCases() throws {
        let allStatuses: [PlaygroundCardStatus] = [.PROCESSING, .GENERATED, .FAILED]
        for status in allStatuses {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(PlaygroundCardStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }

    // MARK: - PlaygroundCardType Backward-Compatible Decoding

    func testCardType_decode_lowercaseImage() throws {
        let decoded = try JSONDecoder().decode(
            PlaygroundCardType.self,
            from: Data("\"image\"".utf8)
        )
        XCTAssertEqual(decoded, .IMAGE)
    }

    func testCardType_decode_uppercaseImage() throws {
        let decoded = try JSONDecoder().decode(
            PlaygroundCardType.self,
            from: Data("\"IMAGE\"".utf8)
        )
        XCTAssertEqual(decoded, .IMAGE)
    }

    func testCardType_decode_lowercaseVideo() throws {
        let decoded = try JSONDecoder().decode(
            PlaygroundCardType.self,
            from: Data("\"video\"".utf8)
        )
        XCTAssertEqual(decoded, .VIDEO)
    }

    func testCardType_decode_uppercaseVideo() throws {
        let decoded = try JSONDecoder().decode(
            PlaygroundCardType.self,
            from: Data("\"VIDEO\"".utf8)
        )
        XCTAssertEqual(decoded, .VIDEO)
    }

    func testCardType_decode_unknownValue_throws() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                PlaygroundCardType.self,
                from: Data("\"audio\"".utf8)
            )
        )
    }

    func testCardType_decode_emptyString_throws() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                PlaygroundCardType.self,
                from: Data("\"\"".utf8)
            )
        )
    }

    // MARK: - PlaygroundCardType Properties

    func testCardType_displayName_image() {
        XCTAssertEqual(PlaygroundCardType.IMAGE.displayName, "Image")
    }

    func testCardType_displayName_video() {
        XCTAssertEqual(PlaygroundCardType.VIDEO.displayName, "Video")
    }

    func testCardType_icon_image() {
        XCTAssertEqual(PlaygroundCardType.IMAGE.icon, "photo.fill")
    }

    func testCardType_icon_video() {
        XCTAssertEqual(PlaygroundCardType.VIDEO.icon, "video.fill")
    }

    func testCardType_caseIterable_countIsTwo() {
        XCTAssertEqual(PlaygroundCardType.allCases.count, 2)
    }

    func testCardType_identifiable_idMatchesRawValue() {
        for cardType in PlaygroundCardType.allCases {
            XCTAssertEqual(cardType.id, cardType.rawValue)
        }
    }

    func testCardType_encodeDecode_allCases() throws {
        for cardType in PlaygroundCardType.allCases {
            let data = try JSONEncoder().encode(cardType)
            let decoded = try JSONDecoder().decode(PlaygroundCardType.self, from: data)
            XCTAssertEqual(decoded, cardType)
        }
    }

    // MARK: - PlaygroundCard Initialization

    func testInit_setsFlowCanvasId() {
        let canvasId = UUID()
        let card = PlaygroundCard(flowCanvasId: canvasId, cardType: .IMAGE)
        XCTAssertEqual(card.flowCanvasId, canvasId)
    }

    func testInit_setsCardType_image() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        XCTAssertEqual(card.cardType, .IMAGE)
    }

    func testInit_setsCardType_video() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .VIDEO)
        XCTAssertEqual(card.cardType, .VIDEO)
    }

    func testInit_defaultPosition_isZero() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        XCTAssertEqual(card.positionX, 0)
        XCTAssertEqual(card.positionY, 0)
    }

    func testInit_customPosition() {
        let card = PlaygroundCard(
            flowCanvasId: UUID(),
            cardType: .IMAGE,
            position: CGPoint(x: 100, y: 200)
        )
        XCTAssertEqual(card.positionX, 100)
        XCTAssertEqual(card.positionY, 200)
    }

    func testInit_defaultStatusIsProcessing() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        XCTAssertEqual(card.status, .PROCESSING)
    }

    func testInit_parentCardIdDefaultNil() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        XCTAssertNil(card.parentCardId)
    }

    func testInit_customParentCardId() {
        let parentId = UUID()
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE, parentCardId: parentId)
        XCTAssertEqual(card.parentCardId, parentId)
    }

    func testInit_optionalFieldsNil() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        XCTAssertNil(card.generationId)
        XCTAssertNil(card.errorMessage)
        XCTAssertNil(card.configurationData)
        XCTAssertNil(card.queueItemId)
    }

    func testInit_createdAtIsSet() {
        let before = Date()
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        let after = Date()
        XCTAssertGreaterThanOrEqual(card.createdAt, before)
        XCTAssertLessThanOrEqual(card.createdAt, after)
    }

    func testInit_idIsUnique() {
        let card1 = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        let card2 = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        XCTAssertNotEqual(card1.id, card2.id)
    }

    // MARK: - Position Computed Property

    func testPosition_getter_returnsCGPoint() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        card.positionX = 150
        card.positionY = 250

        XCTAssertEqual(card.position, CGPoint(x: 150, y: 250))
    }

    func testPosition_setter_updatesXY() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        card.position = CGPoint(x: 300, y: 400)

        XCTAssertEqual(card.positionX, 300)
        XCTAssertEqual(card.positionY, 400)
    }

    func testPosition_negativeCoordinates() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        card.position = CGPoint(x: -100, y: -200)

        XCTAssertEqual(card.position, CGPoint(x: -100, y: -200))
    }

    func testPosition_largeCoordinates() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        card.position = CGPoint(x: 10000, y: 10000)

        XCTAssertEqual(card.position.x, 10000, accuracy: 0.001)
        XCTAssertEqual(card.position.y, 10000, accuracy: 0.001)
    }

    func testPosition_zero() {
        let card = PlaygroundCard(
            flowCanvasId: UUID(),
            cardType: .IMAGE,
            position: CGPoint(x: 100, y: 200)
        )
        card.position = .zero

        XCTAssertEqual(card.position, .zero)
        XCTAssertEqual(card.positionX, 0)
        XCTAssertEqual(card.positionY, 0)
    }

    // MARK: - Codable Round-Trip

    func testCodableRoundTrip_allFields() throws {
        let canvasId = UUID()
        let parentId = UUID()
        let genId = UUID()
        let queueId = UUID()

        let card = PlaygroundCard(
            flowCanvasId: canvasId,
            cardType: .IMAGE,
            position: CGPoint(x: 150, y: 250),
            parentCardId: parentId
        )
        card.status = .GENERATED
        card.generationId = genId
        card.queueItemId = queueId

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)

        XCTAssertEqual(decoded.id, card.id)
        XCTAssertEqual(decoded.flowCanvasId, canvasId)
        XCTAssertEqual(decoded.cardType, .IMAGE)
        XCTAssertEqual(decoded.status, .GENERATED)
        XCTAssertEqual(decoded.positionX, 150, accuracy: 0.001)
        XCTAssertEqual(decoded.positionY, 250, accuracy: 0.001)
        XCTAssertEqual(decoded.parentCardId, parentId)
        XCTAssertEqual(decoded.generationId, genId)
        XCTAssertEqual(decoded.queueItemId, queueId)
    }

    func testCodableRoundTrip_imageCard() throws {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)

        XCTAssertEqual(decoded.cardType, .IMAGE)
    }

    func testCodableRoundTrip_videoCard() throws {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .VIDEO)

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)

        XCTAssertEqual(decoded.cardType, .VIDEO)
    }

    func testCodableRoundTrip_nonZeroPosition() throws {
        let card = PlaygroundCard(
            flowCanvasId: UUID(),
            cardType: .IMAGE,
            position: CGPoint(x: -50.5, y: 123.7)
        )

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)

        XCTAssertEqual(decoded.positionX, -50.5, accuracy: 0.001)
        XCTAssertEqual(decoded.positionY, 123.7, accuracy: 0.001)
    }

    func testCodableRoundTrip_preservesParentCardId() throws {
        let parentId = UUID()
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE, parentCardId: parentId)

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)

        XCTAssertEqual(decoded.parentCardId, parentId)
    }

    func testCodableRoundTrip_failedWithError() throws {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        card.status = .FAILED
        card.errorMessage = "Provider error"

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)

        XCTAssertEqual(decoded.status, .FAILED)
        XCTAssertEqual(decoded.errorMessage, "Provider error")
    }
}
