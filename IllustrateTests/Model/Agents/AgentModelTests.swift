// MARK: - AgentModelTests.swift

// Tests for the Agent model - workflow container on infinite canvas.
//
// Tests cover:
// - Agent initialization with default and custom values
// - Canvas state properties (scale, offset, locked)
// - Codable round-trip serialization
// - Decode with missing optional fields (decodeIfPresent defaults)
// - Pinnable protocol conformance

import Foundation
import XCTest
@testable import Illustrate

final class AgentModelTests: XCTestCase {
    // MARK: - Initialization Defaults

    func testAgent_defaultInit_nameIsUntitledAgent() {
        let agent = Agent()
        XCTAssertEqual(agent.name, "Untitled Agent")
    }

    func testAgent_defaultInit_projectIdIsDefault() {
        let agent = Agent()
        XCTAssertEqual(agent.projectId, Project.defaultProjectId)
    }

    func testAgent_defaultInit_canvasScaleIs1() {
        let agent = Agent()
        XCTAssertEqual(agent.canvasScale, 1.0)
    }

    func testAgent_defaultInit_canvasOffsetXIs0() {
        let agent = Agent()
        XCTAssertEqual(agent.canvasOffsetX, 0.0)
    }

    func testAgent_defaultInit_canvasOffsetYIs0() {
        let agent = Agent()
        XCTAssertEqual(agent.canvasOffsetY, 0.0)
    }

    func testAgent_defaultInit_isLockedIsFalse() {
        let agent = Agent()
        XCTAssertFalse(agent.isLocked)
    }

    func testAgent_defaultInit_isPinnedIsFalse() {
        let agent = Agent()
        XCTAssertFalse(agent.isPinned)
    }

    func testAgent_defaultInit_createdAtIsSet() {
        let before = Date()
        let agent = Agent()
        let after = Date()
        XCTAssertGreaterThanOrEqual(agent.createdAt, before)
        XCTAssertLessThanOrEqual(agent.createdAt, after)
    }

    func testAgent_customInit_setsName() {
        let agent = Agent(name: "My Workflow")
        XCTAssertEqual(agent.name, "My Workflow")
    }

    func testAgent_customInit_setsProjectId() {
        let projectId = UUID()
        let agent = Agent(name: "Test", projectId: projectId)
        XCTAssertEqual(agent.projectId, projectId)
    }

    // MARK: - Mutability

    func testAgent_setCanvasScale_updatesValue() {
        let agent = Agent()
        agent.canvasScale = 2.5
        XCTAssertEqual(agent.canvasScale, 2.5)
    }

    func testAgent_setCanvasOffsets_updatesValues() {
        let agent = Agent()
        agent.canvasOffsetX = 100.0
        agent.canvasOffsetY = -50.0
        XCTAssertEqual(agent.canvasOffsetX, 100.0)
        XCTAssertEqual(agent.canvasOffsetY, -50.0)
    }

    func testAgent_setIsLocked_updatesValue() {
        let agent = Agent()
        agent.isLocked = true
        XCTAssertTrue(agent.isLocked)
    }

    func testAgent_setIsPinned_updatesValue() {
        let agent = Agent()
        agent.isPinned = true
        XCTAssertTrue(agent.isPinned)
    }

    func testAgent_setName_updatesValue() {
        let agent = Agent()
        agent.name = "Updated Name"
        XCTAssertEqual(agent.name, "Updated Name")
    }

    // MARK: - Codable Round-Trip

    func testAgent_codableRoundTrip_preservesAllFields() throws {
        let agent = Agent(name: "Test Agent")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(agent)
        let restored = try decoder.decode(Agent.self, from: data)

        XCTAssertEqual(restored.id, agent.id)
        XCTAssertEqual(restored.projectId, agent.projectId)
        XCTAssertEqual(restored.name, agent.name)
        XCTAssertEqual(restored.canvasScale, agent.canvasScale)
        XCTAssertEqual(restored.canvasOffsetX, agent.canvasOffsetX)
        XCTAssertEqual(restored.canvasOffsetY, agent.canvasOffsetY)
        XCTAssertEqual(restored.isLocked, agent.isLocked)
        XCTAssertEqual(restored.isPinned, agent.isPinned)
    }

    func testAgent_codableRoundTrip_nonDefaultCanvasState() throws {
        let agent = Agent(name: "Zoomed")
        agent.canvasScale = 2.5
        agent.canvasOffsetX = 100.0
        agent.canvasOffsetY = -50.0

        let data = try JSONEncoder().encode(agent)
        let restored = try JSONDecoder().decode(Agent.self, from: data)

        XCTAssertEqual(restored.canvasScale, 2.5)
        XCTAssertEqual(restored.canvasOffsetX, 100.0)
        XCTAssertEqual(restored.canvasOffsetY, -50.0)
    }

    func testAgent_codableRoundTrip_pinnedAndLocked() throws {
        let agent = Agent(name: "Locked")
        agent.isPinned = true
        agent.isLocked = true

        let data = try JSONEncoder().encode(agent)
        let restored = try JSONDecoder().decode(Agent.self, from: data)

        XCTAssertTrue(restored.isPinned)
        XCTAssertTrue(restored.isLocked)
    }

    // MARK: - Decode with Missing Optional Fields

    func testAgent_decode_missingProjectId_defaultsToDefaultProjectId() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(Agent.self, from: data)
        XCTAssertEqual(restored.projectId, Project.defaultProjectId)
    }

    func testAgent_decode_missingCanvasScale_defaultsTo1() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(Agent.self, from: data)
        XCTAssertEqual(restored.canvasScale, 1.0)
    }

    func testAgent_decode_missingCanvasOffsetX_defaultsTo0() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(Agent.self, from: data)
        XCTAssertEqual(restored.canvasOffsetX, 0.0)
    }

    func testAgent_decode_missingCanvasOffsetY_defaultsTo0() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(Agent.self, from: data)
        XCTAssertEqual(restored.canvasOffsetY, 0.0)
    }

    func testAgent_decode_missingIsLocked_defaultsToFalse() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(Agent.self, from: data)
        XCTAssertFalse(restored.isLocked)
    }

    func testAgent_decode_missingIsPinned_defaultsToFalse() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(Agent.self, from: data)
        XCTAssertFalse(restored.isPinned)
    }

    func testAgent_decode_missingAllOptionals_allDefaults() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Minimal Agent",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(Agent.self, from: data)

        XCTAssertEqual(restored.name, "Minimal Agent")
        XCTAssertEqual(restored.projectId, Project.defaultProjectId)
        XCTAssertEqual(restored.canvasScale, 1.0)
        XCTAssertEqual(restored.canvasOffsetX, 0.0)
        XCTAssertEqual(restored.canvasOffsetY, 0.0)
        XCTAssertFalse(restored.isLocked)
        XCTAssertFalse(restored.isPinned)
    }

    // MARK: - Pinnable Conformance

    func testAgent_pinnableId_isUUID() {
        let agent = Agent()
        XCTAssertNotNil(agent.id)
    }

    func testAgent_pinnableName_matchesName() {
        let agent = Agent(name: "Pinnable Test")
        XCTAssertEqual(agent.name, "Pinnable Test")
    }

    func testAgent_pinnableProjectId_matchesProjectId() {
        let projectId = UUID()
        let agent = Agent(projectId: projectId)
        XCTAssertEqual(agent.projectId, projectId)
    }

    func testAgent_twoInstances_haveDifferentIds() {
        let a1 = Agent()
        let a2 = Agent()
        XCTAssertNotEqual(a1.id, a2.id)
    }
}
