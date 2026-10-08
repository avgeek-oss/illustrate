// MARK: - AgentRunModelTests.swift

// Tests for the AgentRun model - execution tracking for agent workflows.
//
// Tests cover:
// - AgentRunStatus enum cases and backward-compatible decoding
// - AgentRun initialization and default values
// - Status computed property get/set
// - Codable round-trip serialization
// - Error tracking fields

import Foundation
import XCTest
@testable import Illustrate

// MARK: - AgentRunStatus Tests

final class AgentRunStatusTests: XCTestCase {
    // MARK: - Case Validation

    func testAgentRunStatus_allCases() {
        let cases = AgentRunStatus.allCases
        XCTAssertEqual(cases.count, 3)
        XCTAssertTrue(cases.contains(.RUNNING))
        XCTAssertTrue(cases.contains(.SUCCESSFUL))
        XCTAssertTrue(cases.contains(.ERRORED))
    }

    func testAgentRunStatus_rawValues() {
        XCTAssertEqual(AgentRunStatus.RUNNING.rawValue, "RUNNING")
        XCTAssertEqual(AgentRunStatus.SUCCESSFUL.rawValue, "SUCCESSFUL")
        XCTAssertEqual(AgentRunStatus.ERRORED.rawValue, "ERRORED")
    }

    func testAgentRunStatus_identifiable() {
        XCTAssertEqual(AgentRunStatus.RUNNING.id, "RUNNING")
        XCTAssertEqual(AgentRunStatus.SUCCESSFUL.id, "SUCCESSFUL")
        XCTAssertEqual(AgentRunStatus.ERRORED.id, "ERRORED")
    }

    // MARK: - Backward Compatible Decoding

    func testAgentRunStatus_decodesUppercase() throws {
        let json = "\"RUNNING\""
        let data = Data(json.utf8)
        let status = try JSONDecoder().decode(AgentRunStatus.self, from: data)
        XCTAssertEqual(status, .RUNNING)
    }

    func testAgentRunStatus_decodesLowercase() throws {
        let json = "\"running\""
        let data = Data(json.utf8)
        let status = try JSONDecoder().decode(AgentRunStatus.self, from: data)
        XCTAssertEqual(status, .RUNNING)
    }

    func testAgentRunStatus_decodesLowercaseSuccessful() throws {
        let json = "\"successful\""
        let data = Data(json.utf8)
        let status = try JSONDecoder().decode(AgentRunStatus.self, from: data)
        XCTAssertEqual(status, .SUCCESSFUL)
    }

    func testAgentRunStatus_decodesLowercaseErrored() throws {
        let json = "\"errored\""
        let data = Data(json.utf8)
        let status = try JSONDecoder().decode(AgentRunStatus.self, from: data)
        XCTAssertEqual(status, .ERRORED)
    }

    func testAgentRunStatus_decodingUnknownValue_throws() {
        let json = "\"UNKNOWN\""
        let data = Data(json.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(AgentRunStatus.self, from: data))
    }
}

// MARK: - AgentRun Model Tests

final class AgentRunModelTests: XCTestCase {
    // MARK: - Initialization

    func testAgentRun_defaultInit_statusIsRunning() {
        let agentId = UUID()
        let run = AgentRun(agentId: agentId)
        XCTAssertEqual(run.status, .RUNNING)
        XCTAssertEqual(run.statusRaw, "RUNNING")
    }

    func testAgentRun_defaultInit_setsAgentId() {
        let agentId = UUID()
        let run = AgentRun(agentId: agentId)
        XCTAssertEqual(run.agentId, agentId)
    }

    func testAgentRun_defaultInit_setsDefaultProjectId() {
        let run = AgentRun(agentId: UUID())
        XCTAssertEqual(run.projectId, Project.defaultProjectId)
    }

    func testAgentRun_customProjectId() {
        let projectId = UUID()
        let run = AgentRun(agentId: UUID(), projectId: projectId)
        XCTAssertEqual(run.projectId, projectId)
    }

    func testAgentRun_defaultInit_completedAtIsNil() {
        let run = AgentRun(agentId: UUID())
        XCTAssertNil(run.completedAt)
    }

    func testAgentRun_defaultInit_noErrors() {
        let run = AgentRun(agentId: UUID())
        XCTAssertNil(run.errorMessage)
        XCTAssertNil(run.errorCardId)
    }

    func testAgentRun_defaultInit_createdAtIsSet() {
        let before = Date()
        let run = AgentRun(agentId: UUID())
        let after = Date()
        XCTAssertGreaterThanOrEqual(run.createdAt, before)
        XCTAssertLessThanOrEqual(run.createdAt, after)
    }

    // MARK: - Status Transitions

    func testAgentRun_statusTransition_runningToSuccessful() {
        let run = AgentRun(agentId: UUID())
        XCTAssertEqual(run.status, .RUNNING)

        run.status = .SUCCESSFUL
        XCTAssertEqual(run.status, .SUCCESSFUL)
        XCTAssertEqual(run.statusRaw, "SUCCESSFUL")
    }

    func testAgentRun_statusTransition_runningToErrored() {
        let run = AgentRun(agentId: UUID())
        run.status = .ERRORED
        XCTAssertEqual(run.status, .ERRORED)
        XCTAssertEqual(run.statusRaw, "ERRORED")
    }

    // MARK: - Error Tracking

    func testAgentRun_errorTracking_storesCardIdAndMessage() {
        let run = AgentRun(agentId: UUID())
        let failedCardId = UUID()

        run.status = .ERRORED
        run.errorMessage = "Provider key not found"
        run.errorCardId = failedCardId

        XCTAssertEqual(run.errorMessage, "Provider key not found")
        XCTAssertEqual(run.errorCardId, failedCardId)
    }

    // MARK: - Codable Round-Trip

    func testAgentRun_codableRoundTrip_runningState() throws {
        let run = AgentRun(agentId: UUID())

        let encoder = JSONEncoder()
        let data = try encoder.encode(run)
        let decoded = try JSONDecoder().decode(AgentRun.self, from: data)

        XCTAssertEqual(decoded.id, run.id)
        XCTAssertEqual(decoded.agentId, run.agentId)
        XCTAssertEqual(decoded.projectId, run.projectId)
        XCTAssertEqual(decoded.status, .RUNNING)
        XCTAssertNil(decoded.completedAt)
        XCTAssertNil(decoded.errorMessage)
        XCTAssertNil(decoded.errorCardId)
    }

    func testAgentRun_codableRoundTrip_erroredState() throws {
        let run = AgentRun(agentId: UUID())
        run.status = .ERRORED
        run.errorMessage = "Test error"
        run.errorCardId = UUID()

        let data = try JSONEncoder().encode(run)
        let decoded = try JSONDecoder().decode(AgentRun.self, from: data)

        XCTAssertEqual(decoded.status, .ERRORED)
        XCTAssertEqual(decoded.errorMessage, "Test error")
        XCTAssertEqual(decoded.errorCardId, run.errorCardId)
    }

    func testAgentRun_codableRoundTrip_successfulState() throws {
        let run = AgentRun(agentId: UUID())
        run.status = .SUCCESSFUL
        run.completedAt = Date()

        let data = try JSONEncoder().encode(run)
        let decoded = try JSONDecoder().decode(AgentRun.self, from: data)

        XCTAssertEqual(decoded.status, .SUCCESSFUL)
        XCTAssertNotNil(decoded.completedAt)
    }

    func testAgentRun_codableRoundTrip_missingOptionalFields() throws {
        // Simulate a JSON payload with only required fields
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "agentId": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(AgentRun.self, from: data)

        XCTAssertEqual(decoded.status, .RUNNING, "Missing statusRaw should default to RUNNING")
        XCTAssertEqual(decoded.projectId, Project.defaultProjectId, "Missing projectId should default")
    }
}
