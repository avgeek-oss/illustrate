// MARK: - CardLinkModelTests.swift

// Tests for the CardLink model - connections between agent workflow cards.
//
// Tests cover:
// - CardLink initialization with required fields
// - Codable round-trip serialization preserving all fields
// - Edge cases (self-links, multiple links per agent)
// - Identifiable conformance and id stability

import Foundation
import XCTest
@testable import Illustrate

final class CardLinkModelTests: XCTestCase {
    // MARK: - Initialization

    func testCardLink_init_setsAgentId() {
        let agentId = UUID()
        let link = CardLink(agentId: agentId, sourceCardId: UUID(), targetCardId: UUID())
        XCTAssertEqual(link.agentId, agentId)
    }

    func testCardLink_init_setsSourceCardId() {
        let sourceId = UUID()
        let link = CardLink(agentId: UUID(), sourceCardId: sourceId, targetCardId: UUID())
        XCTAssertEqual(link.sourceCardId, sourceId)
    }

    func testCardLink_init_setsTargetCardId() {
        let targetId = UUID()
        let link = CardLink(agentId: UUID(), sourceCardId: UUID(), targetCardId: targetId)
        XCTAssertEqual(link.targetCardId, targetId)
    }

    func testCardLink_init_generatesUniqueId() {
        let link = CardLink(agentId: UUID(), sourceCardId: UUID(), targetCardId: UUID())
        XCTAssertNotNil(link.id)
    }

    func testCardLink_init_createdAtIsSet() {
        let before = Date()
        let link = CardLink(agentId: UUID(), sourceCardId: UUID(), targetCardId: UUID())
        let after = Date()
        XCTAssertGreaterThanOrEqual(link.createdAt, before)
        XCTAssertLessThanOrEqual(link.createdAt, after)
    }

    func testCardLink_twoInstances_haveDifferentIds() {
        let agentId = UUID()
        let link1 = CardLink(agentId: agentId, sourceCardId: UUID(), targetCardId: UUID())
        let link2 = CardLink(agentId: agentId, sourceCardId: UUID(), targetCardId: UUID())
        XCTAssertNotEqual(link1.id, link2.id)
    }

    // MARK: - Codable Round-Trip

    func testCardLink_codableRoundTrip_preservesAllFields() throws {
        let agentId = UUID()
        let sourceId = UUID()
        let targetId = UUID()
        let link = CardLink(agentId: agentId, sourceCardId: sourceId, targetCardId: targetId)

        let data = try JSONEncoder().encode(link)
        let restored = try JSONDecoder().decode(CardLink.self, from: data)

        XCTAssertEqual(restored.id, link.id)
        XCTAssertEqual(restored.agentId, agentId)
        XCTAssertEqual(restored.sourceCardId, sourceId)
        XCTAssertEqual(restored.targetCardId, targetId)
    }

    func testCardLink_codableRoundTrip_preservesId() throws {
        let link = CardLink(agentId: UUID(), sourceCardId: UUID(), targetCardId: UUID())
        let originalId = link.id

        let data = try JSONEncoder().encode(link)
        let restored = try JSONDecoder().decode(CardLink.self, from: data)

        XCTAssertEqual(restored.id, originalId)
    }

    func testCardLink_codableRoundTrip_preservesCreatedAt() throws {
        let link = CardLink(agentId: UUID(), sourceCardId: UUID(), targetCardId: UUID())

        let data = try JSONEncoder().encode(link)
        let restored = try JSONDecoder().decode(CardLink.self, from: data)

        XCTAssertEqual(
            restored.createdAt.timeIntervalSinceReferenceDate,
            link.createdAt.timeIntervalSinceReferenceDate,
            accuracy: 0.001
        )
    }

    func testCardLink_multipleEncodeDecodes_preservesId() throws {
        let link = CardLink(agentId: UUID(), sourceCardId: UUID(), targetCardId: UUID())
        let originalId = link.id

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data1 = try encoder.encode(link)
        let restored1 = try decoder.decode(CardLink.self, from: data1)
        let data2 = try encoder.encode(restored1)
        let restored2 = try decoder.decode(CardLink.self, from: data2)

        XCTAssertEqual(restored2.id, originalId)
    }

    // MARK: - Edge Cases

    func testCardLink_sameSourceAndTarget_isAllowed() {
        let cardId = UUID()
        let link = CardLink(agentId: UUID(), sourceCardId: cardId, targetCardId: cardId)
        XCTAssertEqual(link.sourceCardId, link.targetCardId)
    }

    func testCardLink_sameAgentDifferentCards_distinguishable() {
        let agentId = UUID()
        let link1 = CardLink(agentId: agentId, sourceCardId: UUID(), targetCardId: UUID())
        let link2 = CardLink(agentId: agentId, sourceCardId: UUID(), targetCardId: UUID())

        XCTAssertEqual(link1.agentId, link2.agentId)
        XCTAssertNotEqual(link1.id, link2.id)
        XCTAssertNotEqual(link1.sourceCardId, link2.sourceCardId)
    }

    func testCardLink_multipleLinks_sameAgent_differentIds() {
        let agentId = UUID()
        let ids = (0 ..< 5).map { _ in
            CardLink(agentId: agentId, sourceCardId: UUID(), targetCardId: UUID()).id
        }
        XCTAssertEqual(Set(ids).count, 5, "All link IDs should be unique")
    }

    // MARK: - Identifiable

    func testCardLink_identifiable_idIsUUID() {
        let link = CardLink(agentId: UUID(), sourceCardId: UUID(), targetCardId: UUID())
        // id is UUID type — verify it's accessible and not nil
        let _: UUID = link.id
        XCTAssertNotNil(link.id)
    }

    func testCardLink_identifiable_idIsStable() {
        let link = CardLink(agentId: UUID(), sourceCardId: UUID(), targetCardId: UUID())
        let firstAccess = link.id
        let secondAccess = link.id
        XCTAssertEqual(firstAccess, secondAccess)
    }
}
