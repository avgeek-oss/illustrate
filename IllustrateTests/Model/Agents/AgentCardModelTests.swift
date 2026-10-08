// MARK: - AgentCardModelTests.swift

// Tests for AgentCard model, CardType, and ProcessCardType enums.
//
// Tests cover:
// - CardType enum: allCases, rawValues, id, Codable round-trip
// - ProcessCardType enum: allCases, rawValues, displayName, icon, Codable
// - AgentCard factory methods (createDefault, createProcessCard, createOutputCard)
// - AgentCard position computed property (get/set with CGPoint)
// - AgentCard Codable round-trip and missing optional field defaults

import CoreGraphics
import Foundation
import XCTest
@testable import Illustrate

// MARK: - CardType Tests

final class CardTypeTests: XCTestCase {
    func testCardType_allCases_count() {
        XCTAssertEqual(CardType.allCases.count, 3)
    }

    func testCardType_rawValue_start() {
        XCTAssertEqual(CardType.start.rawValue, "start")
    }

    func testCardType_rawValue_process() {
        XCTAssertEqual(CardType.process.rawValue, "process")
    }

    func testCardType_rawValue_output() {
        XCTAssertEqual(CardType.output.rawValue, "output")
    }

    func testCardType_id_matchesRawValue() {
        for cardType in CardType.allCases {
            XCTAssertEqual(cardType.id, cardType.rawValue)
        }
    }

    func testCardType_codableRoundTrip() throws {
        for cardType in CardType.allCases {
            let data = try JSONEncoder().encode(cardType)
            let restored = try JSONDecoder().decode(CardType.self, from: data)
            XCTAssertEqual(restored, cardType)
        }
    }
}

// MARK: - ProcessCardType Tests

final class ProcessCardTypeTests: XCTestCase {
    func testProcessCardType_allCases_count() {
        XCTAssertEqual(ProcessCardType.allCases.count, 2)
    }

    func testProcessCardType_rawValue_imageGeneration() {
        XCTAssertEqual(ProcessCardType.imageGeneration.rawValue, "image_generation")
    }

    func testProcessCardType_rawValue_videoGeneration() {
        XCTAssertEqual(ProcessCardType.videoGeneration.rawValue, "video_generation")
    }

    func testProcessCardType_id_matchesRawValue() {
        for processType in ProcessCardType.allCases {
            XCTAssertEqual(processType.id, processType.rawValue)
        }
    }

    func testProcessCardType_displayName_imageGeneration() {
        XCTAssertEqual(ProcessCardType.imageGeneration.displayName, "Image Generation")
    }

    func testProcessCardType_displayName_videoGeneration() {
        XCTAssertEqual(ProcessCardType.videoGeneration.displayName, "Video Generation")
    }

    func testProcessCardType_icon_imageGeneration() {
        XCTAssertEqual(ProcessCardType.imageGeneration.icon, "photo.fill")
    }

    func testProcessCardType_icon_videoGeneration() {
        XCTAssertEqual(ProcessCardType.videoGeneration.icon, "video.fill")
    }

    func testProcessCardType_codableRoundTrip_imageGeneration() throws {
        let data = try JSONEncoder().encode(ProcessCardType.imageGeneration)
        let restored = try JSONDecoder().decode(ProcessCardType.self, from: data)
        XCTAssertEqual(restored, .imageGeneration)
    }

    func testProcessCardType_codableRoundTrip_videoGeneration() throws {
        let data = try JSONEncoder().encode(ProcessCardType.videoGeneration)
        let restored = try JSONDecoder().decode(ProcessCardType.self, from: data)
        XCTAssertEqual(restored, .videoGeneration)
    }
}

// MARK: - AgentCard Model Tests

final class AgentCardModelTests: XCTestCase {
    // MARK: - Factory: createDefault

    func testAgentCard_createDefault_cardTypeIsStart() {
        let card = AgentCard.createDefault(agentId: UUID())
        XCTAssertEqual(card.cardType, .start)
    }

    func testAgentCard_createDefault_isDefaultTrue() {
        let card = AgentCard.createDefault(agentId: UUID())
        XCTAssertTrue(card.isDefault)
    }

    func testAgentCard_createDefault_titleIsStart() {
        let card = AgentCard.createDefault(agentId: UUID())
        XCTAssertEqual(card.title, "Start")
    }

    func testAgentCard_createDefault_positionIsZero() {
        let card = AgentCard.createDefault(agentId: UUID())
        XCTAssertEqual(card.position, .zero)
    }

    func testAgentCard_createDefault_customPosition() {
        let pos = CGPoint(x: 100, y: 200)
        let card = AgentCard.createDefault(agentId: UUID(), position: pos)
        XCTAssertEqual(card.position, pos)
    }

    func testAgentCard_createDefault_setsAgentId() {
        let agentId = UUID()
        let card = AgentCard.createDefault(agentId: agentId)
        XCTAssertEqual(card.agentId, agentId)
    }

    // MARK: - Factory: createProcessCard

    func testAgentCard_createProcessCard_cardTypeIsProcess() {
        let card = AgentCard.createProcessCard(agentId: UUID(), processType: .imageGeneration)
        XCTAssertEqual(card.cardType, .process)
    }

    func testAgentCard_createProcessCard_setsProcessCardType() {
        let card = AgentCard.createProcessCard(agentId: UUID(), processType: .imageGeneration)
        XCTAssertEqual(card.processCardType, .imageGeneration)
    }

    func testAgentCard_createProcessCard_imageTitle() {
        let card = AgentCard.createProcessCard(agentId: UUID(), processType: .imageGeneration)
        XCTAssertEqual(card.title, "Image Generation")
    }

    func testAgentCard_createProcessCard_videoTitle() {
        let card = AgentCard.createProcessCard(agentId: UUID(), processType: .videoGeneration)
        XCTAssertEqual(card.title, "Video Generation")
    }

    func testAgentCard_createProcessCard_isDefaultFalse() {
        let card = AgentCard.createProcessCard(agentId: UUID(), processType: .imageGeneration)
        XCTAssertFalse(card.isDefault)
    }

    // MARK: - Factory: createOutputCard

    func testAgentCard_createOutputCard_cardTypeIsOutput() {
        let card = AgentCard.createOutputCard(agentId: UUID())
        XCTAssertEqual(card.cardType, .output)
    }

    func testAgentCard_createOutputCard_isDefaultFalse() {
        let card = AgentCard.createOutputCard(agentId: UUID())
        XCTAssertFalse(card.isDefault)
    }

    func testAgentCard_createOutputCard_titleIsOutput() {
        let card = AgentCard.createOutputCard(agentId: UUID())
        XCTAssertEqual(card.title, "Output")
    }

    // MARK: - Position Computed Property

    func testAgentCard_position_getReturnsCGPoint() {
        let card = AgentCard(agentId: UUID(), position: CGPoint(x: 50, y: 75))
        XCTAssertEqual(card.position, CGPoint(x: 50, y: 75))
    }

    func testAgentCard_position_setUpdatesXAndY() {
        let card = AgentCard(agentId: UUID())
        card.position = CGPoint(x: 42.5, y: 99.9)
        XCTAssertEqual(card.positionX, 42.5)
        XCTAssertEqual(card.positionY, 99.9)
    }

    func testAgentCard_position_negativeValues() {
        let card = AgentCard(agentId: UUID())
        card.position = CGPoint(x: -100, y: -200)
        XCTAssertEqual(card.position.x, -100)
        XCTAssertEqual(card.position.y, -200)
    }

    // MARK: - Codable Round-Trip

    func testAgentCard_codableRoundTrip_preservesAllFields() throws {
        let agentId = UUID()
        let card = AgentCard.createProcessCard(
            agentId: agentId,
            processType: .imageGeneration,
            position: CGPoint(x: 300, y: 400)
        )
        card.isRunning = true
        card.isErrored = false
        let genId = UUID()
        card.generationId = genId

        let data = try JSONEncoder().encode(card)
        let restored = try JSONDecoder().decode(AgentCard.self, from: data)

        XCTAssertEqual(restored.id, card.id)
        XCTAssertEqual(restored.agentId, agentId)
        XCTAssertEqual(restored.cardType, .process)
        XCTAssertEqual(restored.processCardType, .imageGeneration)
        XCTAssertEqual(restored.positionX, 300)
        XCTAssertEqual(restored.positionY, 400)
        XCTAssertFalse(restored.isDefault)
        XCTAssertEqual(restored.title, "Image Generation")
        XCTAssertTrue(restored.isRunning)
        XCTAssertFalse(restored.isErrored)
        XCTAssertEqual(restored.generationId, genId)
    }

    func testAgentCard_codableRoundTrip_withProcessCardType() throws {
        let card = AgentCard.createProcessCard(agentId: UUID(), processType: .videoGeneration)

        let data = try JSONEncoder().encode(card)
        let restored = try JSONDecoder().decode(AgentCard.self, from: data)

        XCTAssertEqual(restored.processCardType, .videoGeneration)
    }

    func testAgentCard_codableRoundTrip_withoutProcessCardType() throws {
        let card = AgentCard.createDefault(agentId: UUID())

        let data = try JSONEncoder().encode(card)
        let restored = try JSONDecoder().decode(AgentCard.self, from: data)

        XCTAssertNil(restored.processCardType)
    }

    func testAgentCard_codableRoundTrip_withErrorState() throws {
        let card = AgentCard(agentId: UUID())
        card.isErrored = true
        card.errorMessage = "Generation failed"

        let data = try JSONEncoder().encode(card)
        let restored = try JSONDecoder().decode(AgentCard.self, from: data)

        XCTAssertTrue(restored.isErrored)
        XCTAssertEqual(restored.errorMessage, "Generation failed")
    }

    // MARK: - Decode with Missing Optional Fields

    func testAgentCard_decode_missingIsRunning_defaultsToFalse() throws {
        let card = AgentCard.createDefault(agentId: UUID())
        let data = try JSONEncoder().encode(card)

        // Re-decode with standard decoder — isRunning should be false by default
        let restored = try JSONDecoder().decode(AgentCard.self, from: data)
        XCTAssertFalse(restored.isRunning)
    }

    func testAgentCard_decode_missingIsErrored_defaultsToFalse() throws {
        let card = AgentCard.createDefault(agentId: UUID())
        let data = try JSONEncoder().encode(card)

        let restored = try JSONDecoder().decode(AgentCard.self, from: data)
        XCTAssertFalse(restored.isErrored)
    }

    func testAgentCard_decode_missingErrorMessage_defaultsToNil() throws {
        let card = AgentCard.createDefault(agentId: UUID())
        let data = try JSONEncoder().encode(card)

        let restored = try JSONDecoder().decode(AgentCard.self, from: data)
        XCTAssertNil(restored.errorMessage)
    }

    func testAgentCard_decode_missingProcessCardType_defaultsToNil() throws {
        let card = AgentCard.createDefault(agentId: UUID())
        let data = try JSONEncoder().encode(card)

        let restored = try JSONDecoder().decode(AgentCard.self, from: data)
        XCTAssertNil(restored.processCardType)
    }

    func testAgentCard_decode_missingConfigurationData_defaultsToNil() throws {
        let card = AgentCard.createDefault(agentId: UUID())
        let data = try JSONEncoder().encode(card)

        let restored = try JSONDecoder().decode(AgentCard.self, from: data)
        XCTAssertNil(restored.configurationData)
    }

    func testAgentCard_decode_missingGenerationId_defaultsToNil() throws {
        let card = AgentCard.createDefault(agentId: UUID())
        let data = try JSONEncoder().encode(card)

        let restored = try JSONDecoder().decode(AgentCard.self, from: data)
        XCTAssertNil(restored.generationId)
    }

    // MARK: - Identifiable

    func testAgentCard_twoInstances_haveDifferentIds() {
        let agentId = UUID()
        let c1 = AgentCard(agentId: agentId)
        let c2 = AgentCard(agentId: agentId)
        XCTAssertNotEqual(c1.id, c2.id)
    }
}
