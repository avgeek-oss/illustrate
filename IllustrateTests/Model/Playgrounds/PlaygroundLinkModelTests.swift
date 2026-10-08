// MARK: - PlaygroundLinkModelTests.swift

// Tests for PlaygroundLink model - visual connections between playground cards.
//
// Tests cover:
// - Initialization with required fields
// - Codable round-trip serialization preserving all fields
// - Edge cases (self-links, multiple links per canvas)
// - Identifiable conformance and id stability

import Foundation
import XCTest
@testable import Illustrate

final class PlaygroundLinkModelTests: XCTestCase {
    // MARK: - Initialization

    func testPlaygroundLink_init_setsFlowCanvasId() {
        let canvasId = UUID()
        let link = PlaygroundLink(flowCanvasId: canvasId, sourceCardId: UUID(), targetCardId: UUID())
        XCTAssertEqual(link.flowCanvasId, canvasId)
    }

    func testPlaygroundLink_init_setsSourceCardId() {
        let sourceId = UUID()
        let link = PlaygroundLink(flowCanvasId: UUID(), sourceCardId: sourceId, targetCardId: UUID())
        XCTAssertEqual(link.sourceCardId, sourceId)
    }

    func testPlaygroundLink_init_setsTargetCardId() {
        let targetId = UUID()
        let link = PlaygroundLink(flowCanvasId: UUID(), sourceCardId: UUID(), targetCardId: targetId)
        XCTAssertEqual(link.targetCardId, targetId)
    }

    func testPlaygroundLink_init_generatesUniqueId() {
        let link = PlaygroundLink(flowCanvasId: UUID(), sourceCardId: UUID(), targetCardId: UUID())
        XCTAssertNotNil(link.id)
    }

    func testPlaygroundLink_init_createdAtIsSet() {
        let before = Date()
        let link = PlaygroundLink(flowCanvasId: UUID(), sourceCardId: UUID(), targetCardId: UUID())
        let after = Date()
        XCTAssertGreaterThanOrEqual(link.createdAt, before)
        XCTAssertLessThanOrEqual(link.createdAt, after)
    }

    func testPlaygroundLink_twoInstances_haveDifferentIds() {
        let canvasId = UUID()
        let link1 = PlaygroundLink(flowCanvasId: canvasId, sourceCardId: UUID(), targetCardId: UUID())
        let link2 = PlaygroundLink(flowCanvasId: canvasId, sourceCardId: UUID(), targetCardId: UUID())
        XCTAssertNotEqual(link1.id, link2.id)
    }

    // MARK: - Codable Round-Trip

    func testPlaygroundLink_codableRoundTrip_preservesAllFields() throws {
        let canvasId = UUID()
        let sourceId = UUID()
        let targetId = UUID()
        let link = PlaygroundLink(flowCanvasId: canvasId, sourceCardId: sourceId, targetCardId: targetId)

        let data = try JSONEncoder().encode(link)
        let restored = try JSONDecoder().decode(PlaygroundLink.self, from: data)

        XCTAssertEqual(restored.id, link.id)
        XCTAssertEqual(restored.flowCanvasId, canvasId)
        XCTAssertEqual(restored.sourceCardId, sourceId)
        XCTAssertEqual(restored.targetCardId, targetId)
    }

    func testPlaygroundLink_codableRoundTrip_preservesId() throws {
        let link = PlaygroundLink(flowCanvasId: UUID(), sourceCardId: UUID(), targetCardId: UUID())
        let originalId = link.id

        let data = try JSONEncoder().encode(link)
        let restored = try JSONDecoder().decode(PlaygroundLink.self, from: data)

        XCTAssertEqual(restored.id, originalId)
    }

    func testPlaygroundLink_codableRoundTrip_preservesCreatedAt() throws {
        let link = PlaygroundLink(flowCanvasId: UUID(), sourceCardId: UUID(), targetCardId: UUID())

        let data = try JSONEncoder().encode(link)
        let restored = try JSONDecoder().decode(PlaygroundLink.self, from: data)

        XCTAssertEqual(
            restored.createdAt.timeIntervalSinceReferenceDate,
            link.createdAt.timeIntervalSinceReferenceDate,
            accuracy: 0.001
        )
    }

    func testPlaygroundLink_multipleEncodeDecodes_preservesId() throws {
        let link = PlaygroundLink(flowCanvasId: UUID(), sourceCardId: UUID(), targetCardId: UUID())
        let originalId = link.id

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data1 = try encoder.encode(link)
        let restored1 = try decoder.decode(PlaygroundLink.self, from: data1)
        let data2 = try encoder.encode(restored1)
        let restored2 = try decoder.decode(PlaygroundLink.self, from: data2)

        XCTAssertEqual(restored2.id, originalId)
    }

    // MARK: - Edge Cases

    func testPlaygroundLink_sameSourceAndTarget_isAllowed() {
        let cardId = UUID()
        let link = PlaygroundLink(flowCanvasId: UUID(), sourceCardId: cardId, targetCardId: cardId)
        XCTAssertEqual(link.sourceCardId, link.targetCardId)
    }

    func testPlaygroundLink_sameCanvasDifferentCards_distinguishable() {
        let canvasId = UUID()
        let link1 = PlaygroundLink(flowCanvasId: canvasId, sourceCardId: UUID(), targetCardId: UUID())
        let link2 = PlaygroundLink(flowCanvasId: canvasId, sourceCardId: UUID(), targetCardId: UUID())

        XCTAssertEqual(link1.flowCanvasId, link2.flowCanvasId)
        XCTAssertNotEqual(link1.id, link2.id)
        XCTAssertNotEqual(link1.sourceCardId, link2.sourceCardId)
    }

    func testPlaygroundLink_multipleLinks_sameCanvas_differentIds() {
        let canvasId = UUID()
        let ids = (0 ..< 5).map { _ in
            PlaygroundLink(flowCanvasId: canvasId, sourceCardId: UUID(), targetCardId: UUID()).id
        }
        XCTAssertEqual(Set(ids).count, 5, "All link IDs should be unique")
    }

    // MARK: - Identifiable

    func testPlaygroundLink_identifiable_idIsUUID() {
        let link = PlaygroundLink(flowCanvasId: UUID(), sourceCardId: UUID(), targetCardId: UUID())
        let _: UUID = link.id
        XCTAssertNotNil(link.id)
    }

    func testPlaygroundLink_identifiable_idIsStable() {
        let link = PlaygroundLink(flowCanvasId: UUID(), sourceCardId: UUID(), targetCardId: UUID())
        let firstAccess = link.id
        let secondAccess = link.id
        XCTAssertEqual(firstAccess, secondAccess)
    }
}
