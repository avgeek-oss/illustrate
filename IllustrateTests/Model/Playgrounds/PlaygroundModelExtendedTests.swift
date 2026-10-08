// MARK: - PlaygroundModelExtendedTests.swift

// Extended tests for the Playground (Flow Canvas) parent model.
//
// Tests cover:
// - Initialization with default and custom values
// - Canvas state properties (scale, offset, locked)
// - Codable round-trip serialization
// - Decode with missing optional fields (decodeIfPresent defaults)
// - Pinnable conformance
// - Mutability of mutable properties

import Foundation
import XCTest
@testable import Illustrate

final class PlaygroundModelExtendedTests: XCTestCase {
    // MARK: - Initialization Defaults

    func testPlayground_defaultInit_nameIsUntitledCanvas() {
        let playground = Playground()
        XCTAssertEqual(playground.name, "Untitled Canvas")
    }

    func testPlayground_defaultInit_projectIdIsDefault() {
        let playground = Playground()
        XCTAssertEqual(playground.projectId, Project.defaultProjectId)
    }

    func testPlayground_defaultInit_canvasScaleIs1() {
        let playground = Playground()
        XCTAssertEqual(playground.canvasScale, 1.0)
    }

    func testPlayground_defaultInit_canvasOffsetXIs0() {
        let playground = Playground()
        XCTAssertEqual(playground.canvasOffsetX, 0.0)
    }

    func testPlayground_defaultInit_canvasOffsetYIs0() {
        let playground = Playground()
        XCTAssertEqual(playground.canvasOffsetY, 0.0)
    }

    func testPlayground_defaultInit_isLockedIsFalse() {
        let playground = Playground()
        XCTAssertFalse(playground.isLocked)
    }

    func testPlayground_defaultInit_isPinnedIsFalse() {
        let playground = Playground()
        XCTAssertFalse(playground.isPinned)
    }

    func testPlayground_defaultInit_createdAtIsSet() {
        let before = Date()
        let playground = Playground()
        let after = Date()
        XCTAssertGreaterThanOrEqual(playground.createdAt, before)
        XCTAssertLessThanOrEqual(playground.createdAt, after)
    }

    func testPlayground_customInit_setsName() {
        let playground = Playground(name: "My Canvas")
        XCTAssertEqual(playground.name, "My Canvas")
    }

    func testPlayground_customInit_setsProjectId() {
        let projectId = UUID()
        let playground = Playground(name: "Test", projectId: projectId)
        XCTAssertEqual(playground.projectId, projectId)
    }

    // MARK: - Mutability

    func testPlayground_setCanvasScale_updatesValue() {
        let playground = Playground()
        playground.canvasScale = 3.0
        XCTAssertEqual(playground.canvasScale, 3.0)
    }

    func testPlayground_setIsLocked_updatesValue() {
        let playground = Playground()
        playground.isLocked = true
        XCTAssertTrue(playground.isLocked)
    }

    func testPlayground_setIsPinned_updatesValue() {
        let playground = Playground()
        playground.isPinned = true
        XCTAssertTrue(playground.isPinned)
    }

    func testPlayground_setName_updatesValue() {
        let playground = Playground()
        playground.name = "Renamed Canvas"
        XCTAssertEqual(playground.name, "Renamed Canvas")
    }

    // MARK: - Codable Round-Trip

    func testPlayground_codableRoundTrip_preservesAllFields() throws {
        let projectId = UUID()
        let playground = Playground(name: "Test Canvas", projectId: projectId)

        let data = try JSONEncoder().encode(playground)
        let restored = try JSONDecoder().decode(Playground.self, from: data)

        XCTAssertEqual(restored.id, playground.id)
        XCTAssertEqual(restored.projectId, projectId)
        XCTAssertEqual(restored.name, "Test Canvas")
        XCTAssertEqual(restored.canvasScale, 1.0)
        XCTAssertEqual(restored.canvasOffsetX, 0.0)
        XCTAssertEqual(restored.canvasOffsetY, 0.0)
        XCTAssertFalse(restored.isLocked)
        XCTAssertFalse(restored.isPinned)
    }

    func testPlayground_codableRoundTrip_nonDefaultCanvasState() throws {
        let playground = Playground(name: "Zoomed")
        playground.canvasScale = 2.5
        playground.canvasOffsetX = 150.0
        playground.canvasOffsetY = -75.0

        let data = try JSONEncoder().encode(playground)
        let restored = try JSONDecoder().decode(Playground.self, from: data)

        XCTAssertEqual(restored.canvasScale, 2.5)
        XCTAssertEqual(restored.canvasOffsetX, 150.0)
        XCTAssertEqual(restored.canvasOffsetY, -75.0)
    }

    func testPlayground_codableRoundTrip_pinnedAndLocked() throws {
        let playground = Playground(name: "Locked")
        playground.isPinned = true
        playground.isLocked = true

        let data = try JSONEncoder().encode(playground)
        let restored = try JSONDecoder().decode(Playground.self, from: data)

        XCTAssertTrue(restored.isPinned)
        XCTAssertTrue(restored.isLocked)
    }

    // MARK: - Decode with Missing Optional Fields

    func testPlayground_decode_missingProjectId_defaultsToDefaultProjectId() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(Playground.self, from: data)
        XCTAssertEqual(restored.projectId, Project.defaultProjectId)
    }

    func testPlayground_decode_missingCanvasScale_defaultsTo1() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(Playground.self, from: data)
        XCTAssertEqual(restored.canvasScale, 1.0)
    }

    func testPlayground_decode_missingCanvasOffsetX_defaultsTo0() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(Playground.self, from: data)
        XCTAssertEqual(restored.canvasOffsetX, 0.0)
    }

    func testPlayground_decode_missingCanvasOffsetY_defaultsTo0() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(Playground.self, from: data)
        XCTAssertEqual(restored.canvasOffsetY, 0.0)
    }

    func testPlayground_decode_missingIsLocked_defaultsToFalse() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(Playground.self, from: data)
        XCTAssertFalse(restored.isLocked)
    }

    func testPlayground_decode_missingIsPinned_defaultsToFalse() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(Playground.self, from: data)
        XCTAssertFalse(restored.isPinned)
    }

    func testPlayground_decode_missingAllOptionals_allDefaults() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Minimal Canvas",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(Playground.self, from: data)

        XCTAssertEqual(restored.name, "Minimal Canvas")
        XCTAssertEqual(restored.projectId, Project.defaultProjectId)
        XCTAssertEqual(restored.canvasScale, 1.0)
        XCTAssertEqual(restored.canvasOffsetX, 0.0)
        XCTAssertEqual(restored.canvasOffsetY, 0.0)
        XCTAssertFalse(restored.isLocked)
        XCTAssertFalse(restored.isPinned)
    }

    // MARK: - Pinnable Conformance

    func testPlayground_pinnableProjectId_matchesProjectId() {
        let projectId = UUID()
        let playground = Playground(projectId: projectId)
        XCTAssertEqual(playground.projectId, projectId)
    }

    func testPlayground_pinnableName_matchesName() {
        let playground = Playground(name: "Pinnable Test")
        XCTAssertEqual(playground.name, "Pinnable Test")
    }

    func testPlayground_twoInstances_haveDifferentIds() {
        let p1 = Playground()
        let p2 = Playground()
        XCTAssertNotEqual(p1.id, p2.id)
    }
}
