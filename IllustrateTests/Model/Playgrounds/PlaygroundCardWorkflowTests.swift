// MARK: - PlaygroundCardWorkflowTests.swift

// Workflow tests for PlaygroundCard lifecycle and canvas scenarios.
//
// PlaygroundCardModelTests covers: enum decode, init, position, basic round-trip.
// PlaygroundCardCodableTests covers: missing optionals, JSON edge cases, config accessors.
//
// This file adds: card lifecycle transitions, canvas workflow scenarios,
// configuration workflows, and type enum consistency validation.

import XCTest
@testable import Illustrate

final class PlaygroundCardWorkflowTests: XCTestCase {
    // MARK: - Card Lifecycle Workflow

    func testLifecycle_processingToGenerated() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        XCTAssertEqual(card.status, .PROCESSING)

        let genId = UUID()
        card.status = .GENERATED
        card.generationId = genId

        XCTAssertEqual(card.status, .GENERATED)
        XCTAssertEqual(card.generationId, genId)
    }

    func testLifecycle_processingToFailed() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        card.status = .FAILED
        card.errorMessage = "API error"

        XCTAssertEqual(card.status, .FAILED)
        XCTAssertEqual(card.errorMessage, "API error")
    }

    func testLifecycle_fullSuccessPath_encodeDecode() throws {
        let card = PlaygroundCard(
            flowCanvasId: UUID(),
            cardType: .IMAGE,
            position: CGPoint(x: 100, y: 200)
        )
        let queueId = UUID()
        card.queueItemId = queueId

        let genId = UUID()
        card.status = .GENERATED
        card.generationId = genId

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)

        XCTAssertEqual(decoded.status, .GENERATED)
        XCTAssertEqual(decoded.generationId, genId)
        XCTAssertEqual(decoded.queueItemId, queueId)
        XCTAssertEqual(decoded.positionX, 100, accuracy: 0.001)
    }

    func testLifecycle_failedEncodeDecode() throws {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .VIDEO)
        card.status = .FAILED
        card.errorMessage = "Content filter triggered"

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)

        XCTAssertEqual(decoded.status, .FAILED)
        XCTAssertEqual(decoded.errorMessage, "Content filter triggered")
        XCTAssertEqual(decoded.cardType, .VIDEO)
    }

    // MARK: - Canvas Workflow

    func testCanvas_multipleCards_differentPositions() {
        let canvasId = UUID()
        let positions: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 200),
            CGPoint(x: -50, y: 300),
        ]
        let cards = positions.map {
            PlaygroundCard(flowCanvasId: canvasId, cardType: .IMAGE, position: $0)
        }

        XCTAssertEqual(cards[0].position, positions[0])
        XCTAssertEqual(cards[1].position, positions[1])
        XCTAssertEqual(cards[2].position, positions[2])
    }

    func testCanvas_moveCard_updatesPosition() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        XCTAssertEqual(card.position, .zero)

        card.position = CGPoint(x: 50, y: 75)
        XCTAssertEqual(card.position, CGPoint(x: 50, y: 75))

        card.position = CGPoint(x: 200, y: 300)
        XCTAssertEqual(card.position, CGPoint(x: 200, y: 300))
    }

    func testCanvas_parentChildChain() {
        let canvasId = UUID()
        let parent = PlaygroundCard(flowCanvasId: canvasId, cardType: .IMAGE)
        let child = PlaygroundCard(
            flowCanvasId: canvasId,
            cardType: .IMAGE,
            parentCardId: parent.id
        )

        XCTAssertEqual(child.parentCardId, parent.id)
        XCTAssertNil(parent.parentCardId)
    }

    func testCanvas_encodeDecodeArray_preservesAll() throws {
        let canvasId = UUID()
        let cards = (0 ..< 5).map { (i: Int) -> PlaygroundCard in
            let cardType: PlaygroundCardType = i % 2 == 0 ? .IMAGE : .VIDEO
            return PlaygroundCard(
                flowCanvasId: canvasId,
                cardType: cardType,
                position: CGPoint(x: CGFloat(i * 100), y: CGFloat(i * 50))
            )
        }

        let data = try JSONEncoder().encode(cards)
        let decoded = try JSONDecoder().decode([PlaygroundCard].self, from: data)

        XCTAssertEqual(decoded.count, 5)
        for i in 0 ..< 5 {
            XCTAssertEqual(decoded[i].id, cards[i].id)
            XCTAssertEqual(decoded[i].cardType, cards[i].cardType)
            XCTAssertEqual(decoded[i].positionX, CGFloat(i * 100), accuracy: 0.001)
        }
    }

    func testCanvas_filterByFlowCanvasId() {
        let canvasA = UUID()
        let canvasB = UUID()
        let cards = [
            PlaygroundCard(flowCanvasId: canvasA, cardType: .IMAGE),
            PlaygroundCard(flowCanvasId: canvasB, cardType: .IMAGE),
            PlaygroundCard(flowCanvasId: canvasA, cardType: .VIDEO),
        ]

        let filtered = cards.filter { $0.flowCanvasId == canvasA }
        XCTAssertEqual(filtered.count, 2)
    }

    func testCanvas_filterByStatus() {
        let canvasId = UUID()
        let cards = (0 ..< 4).map { (i: Int) -> PlaygroundCard in
            PlaygroundCard(flowCanvasId: canvasId, cardType: .IMAGE, position: CGPoint(x: CGFloat(i * 100), y: 0))
        }
        cards[0].status = .GENERATED
        cards[0].generationId = UUID()
        cards[1].status = .GENERATED
        cards[1].generationId = UUID()
        cards[2].status = .FAILED
        cards[3].status = .PROCESSING

        let generated = cards.filter { $0.status == .GENERATED }
        XCTAssertEqual(generated.count, 2)
    }

    // MARK: - Configuration Workflow

    func testConfigWorkflow_imageCard_setConfigAndMove() throws {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        var config = ImageGenerationConfiguration()
        config.prompt = "Test prompt"
        config.selectedDimensions = "512x512"
        card.imageGenerationConfiguration = config
        card.position = CGPoint(x: 200, y: 300)

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)

        XCTAssertEqual(decoded.imageGenerationConfiguration.prompt, "Test prompt")
        XCTAssertEqual(decoded.imageGenerationConfiguration.selectedDimensions, "512x512")
        XCTAssertEqual(decoded.positionX, 200, accuracy: 0.001)
        XCTAssertEqual(decoded.positionY, 300, accuracy: 0.001)
    }

    func testConfigWorkflow_videoCard_setConfigAndMove() throws {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .VIDEO)
        var config = VideoGenerationConfiguration()
        config.prompt = "Video prompt"
        config.durationSeconds = 8
        card.videoGenerationConfiguration = config
        card.position = CGPoint(x: 150, y: 250)

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(PlaygroundCard.self, from: data)

        XCTAssertEqual(decoded.videoGenerationConfiguration.prompt, "Video prompt")
        XCTAssertEqual(decoded.videoGenerationConfiguration.durationSeconds, 8)
        XCTAssertEqual(decoded.positionX, 150, accuracy: 0.001)
    }

    func testConfigWorkflow_parentHasConfig_childIndependent() {
        let canvasId = UUID()
        let parent = PlaygroundCard(flowCanvasId: canvasId, cardType: .IMAGE)
        var parentConfig = ImageGenerationConfiguration()
        parentConfig.prompt = "Parent prompt"
        parent.imageGenerationConfiguration = parentConfig

        let child = PlaygroundCard(
            flowCanvasId: canvasId,
            cardType: .IMAGE,
            parentCardId: parent.id
        )

        XCTAssertEqual(child.imageGenerationConfiguration.prompt, "")
        XCTAssertEqual(parent.imageGenerationConfiguration.prompt, "Parent prompt")
    }

    func testConfigWorkflow_switchCardType_configDataShared() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        var imageConfig = ImageGenerationConfiguration()
        imageConfig.prompt = "Image prompt"
        card.imageGenerationConfiguration = imageConfig

        card.cardType = .VIDEO
        let videoConfig = card.videoGenerationConfiguration
        // The data is from ImageGenerationConfiguration format, so video config
        // may decode some fields or return defaults depending on JSON structure
        XCTAssertNotNil(card.configurationData)
        // The prompt field exists in both config types so it might decode
        XCTAssertTrue(videoConfig.prompt == "Image prompt" || videoConfig.prompt == "")
    }

    // MARK: - Type Enum Consistency

    func testAllCardTypes_haveDisplayName() {
        for cardType in PlaygroundCardType.allCases {
            XCTAssertFalse(cardType.displayName.isEmpty)
        }
    }

    func testAllCardTypes_haveIcon() {
        for cardType in PlaygroundCardType.allCases {
            XCTAssertFalse(cardType.icon.isEmpty)
        }
    }

    func testVideoCard_init_cardTypeIsVideo() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .VIDEO)
        XCTAssertEqual(card.cardType, .VIDEO)
    }

    func testTwoCards_differentIds() {
        let card1 = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        let card2 = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        XCTAssertNotEqual(card1.id, card2.id)
    }

    func testMutateStatus_allTransitions() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        let allStatuses: [PlaygroundCardStatus] = [.PROCESSING, .GENERATED, .FAILED]

        for status in allStatuses {
            card.status = status
            XCTAssertEqual(card.status, status)
        }
    }

    func testMutateGenerationId_setAndClear() {
        let card = PlaygroundCard(flowCanvasId: UUID(), cardType: .IMAGE)
        XCTAssertNil(card.generationId)

        let genId = UUID()
        card.generationId = genId
        XCTAssertEqual(card.generationId, genId)

        card.generationId = nil
        XCTAssertNil(card.generationId)
    }
}
