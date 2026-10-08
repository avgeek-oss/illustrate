// MARK: - BulkSessionExtendedTests.swift

// Extended tests for BulkSession and BulkSessionItem models.
//
// Tests cover:
// - BulkSession Codable round-trip with non-default values
// - BulkSession decode with missing optional fields (all decodeIfPresent defaults)
// - BulkSession Pinnable conformance
// - BulkSessionItem initialization and defaults
// - BulkSessionItem Codable round-trip
// - BulkSessionItem decode with missing optional fields
// - BulkSessionItemStatus backward-compatible decoding extended cases

import Foundation
import XCTest
@testable import Illustrate

// MARK: - BulkSession Codable Round-Trip Tests

final class BulkSessionExtendedTests: XCTestCase {
    // MARK: - BulkSession Codable Round-Trip

    func testBulkSession_codableRoundTrip_preservesAllFields() throws {
        let projectId = UUID()
        let session = BulkSession(name: "Batch Gen", projectId: projectId)
        session.isPinned = true
        session.concurrencyLimit = 5
        session.commonPrompt = "cinematic lighting"
        session.selectedProviderId = "openai"
        session.selectedModelId = "dall-e-3"
        session.status = .RUNNING

        let data = try JSONEncoder().encode(session)
        let restored = try JSONDecoder().decode(BulkSession.self, from: data)

        XCTAssertEqual(restored.id, session.id)
        XCTAssertEqual(restored.projectId, projectId)
        XCTAssertEqual(restored.name, "Batch Gen")
        XCTAssertTrue(restored.isPinned)
        XCTAssertEqual(restored.concurrencyLimit, 5)
        XCTAssertEqual(restored.commonPrompt, "cinematic lighting")
        XCTAssertEqual(restored.selectedProviderId, "openai")
        XCTAssertEqual(restored.selectedModelId, "dall-e-3")
        XCTAssertEqual(restored.status, .RUNNING)
    }

    func testBulkSession_codableRoundTrip_preservesCompletedStatus() throws {
        let session = BulkSession(name: "Done")
        session.status = .COMPLETED

        let data = try JSONEncoder().encode(session)
        let restored = try JSONDecoder().decode(BulkSession.self, from: data)

        XCTAssertEqual(restored.status, .COMPLETED)
    }

    func testBulkSession_codableRoundTrip_preservesConfigurationData() throws {
        let session = BulkSession(name: "Config Test")
        var config = ImageGenerationConfiguration()
        config.prompt = "test prompt"
        session.savedConfiguration = config

        let data = try JSONEncoder().encode(session)
        let restored = try JSONDecoder().decode(BulkSession.self, from: data)

        XCTAssertNotNil(restored.configurationData)
    }

    // MARK: - BulkSession Decode with Missing Optional Fields

    func testBulkSession_decode_missingProjectId_defaultsToDefault() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(BulkSession.self, from: data)
        XCTAssertEqual(restored.projectId, Project.defaultProjectId)
    }

    func testBulkSession_decode_missingIsPinned_defaultsToFalse() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(BulkSession.self, from: data)
        XCTAssertFalse(restored.isPinned)
    }

    func testBulkSession_decode_missingConcurrencyLimit_defaultsTo2() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(BulkSession.self, from: data)
        XCTAssertEqual(restored.concurrencyLimit, 2)
    }

    func testBulkSession_decode_missingCommonPrompt_defaultsToEmpty() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(BulkSession.self, from: data)
        XCTAssertEqual(restored.commonPrompt, "")
    }

    func testBulkSession_decode_missingSelectedProviderId_defaultsToEmpty() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(BulkSession.self, from: data)
        XCTAssertEqual(restored.selectedProviderId, "")
    }

    func testBulkSession_decode_missingSelectedModelId_defaultsToEmpty() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(BulkSession.self, from: data)
        XCTAssertEqual(restored.selectedModelId, "")
    }

    func testBulkSession_decode_missingConfigurationData_defaultsToNil() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(BulkSession.self, from: data)
        XCTAssertNil(restored.configurationData)
    }

    func testBulkSession_decode_missingStatus_defaultsToIdle() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(BulkSession.self, from: data)
        XCTAssertEqual(restored.status, .IDLE)
    }

    func testBulkSession_decode_missingAllOptionals_allDefaults() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Minimal Session",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(BulkSession.self, from: data)

        XCTAssertEqual(restored.name, "Minimal Session")
        XCTAssertEqual(restored.projectId, Project.defaultProjectId)
        XCTAssertFalse(restored.isPinned)
        XCTAssertEqual(restored.concurrencyLimit, 2)
        XCTAssertEqual(restored.commonPrompt, "")
        XCTAssertEqual(restored.selectedProviderId, "")
        XCTAssertEqual(restored.selectedModelId, "")
        XCTAssertNil(restored.configurationData)
        XCTAssertEqual(restored.status, .IDLE)
    }

    // MARK: - BulkSession Pinnable Conformance

    func testBulkSession_pinnable_projectIdMatches() {
        let projectId = UUID()
        let session = BulkSession(projectId: projectId)
        XCTAssertEqual(session.projectId, projectId)
    }

    func testBulkSession_pinnable_isPinnedUpdatable() {
        let session = BulkSession()
        XCTAssertFalse(session.isPinned)
        session.isPinned = true
        XCTAssertTrue(session.isPinned)
    }

    // MARK: - BulkSession Constants

    func testBulkSessionMaxItems_is250() {
        XCTAssertEqual(bulkSessionMaxItems, 250)
    }
}

// MARK: - BulkSessionItem Tests

final class BulkSessionItemExtendedTests: XCTestCase {
    // MARK: - Initialization

    func testBulkSessionItem_init_setsSessionId() {
        let sessionId = UUID()
        let item = BulkSessionItem(sessionId: sessionId, prompt: "Test")
        XCTAssertEqual(item.sessionId, sessionId)
    }

    func testBulkSessionItem_init_setsPrompt() {
        let item = BulkSessionItem(sessionId: UUID(), prompt: "A beautiful sunset")
        XCTAssertEqual(item.prompt, "A beautiful sunset")
    }

    func testBulkSessionItem_init_defaultStatusIsPending() {
        let item = BulkSessionItem(sessionId: UUID(), prompt: "Test")
        XCTAssertEqual(item.status, .PENDING)
    }

    func testBulkSessionItem_init_optionalFieldsNil() {
        let item = BulkSessionItem(sessionId: UUID(), prompt: "Test")
        XCTAssertNil(item.generationId)
        XCTAssertNil(item.errorMessage)
        XCTAssertNil(item.queueItemId)
    }

    func testBulkSessionItem_init_createdAtIsSet() {
        let before = Date()
        let item = BulkSessionItem(sessionId: UUID(), prompt: "Test")
        let after = Date()
        XCTAssertGreaterThanOrEqual(item.createdAt, before)
        XCTAssertLessThanOrEqual(item.createdAt, after)
    }

    // MARK: - BulkSessionItem Codable Round-Trip

    func testBulkSessionItem_codableRoundTrip_preservesAllFields() throws {
        let sessionId = UUID()
        let item = BulkSessionItem(sessionId: sessionId, prompt: "Mountain landscape")
        let genId = UUID()
        item.generationId = genId
        item.status = .COMPLETED

        let data = try JSONEncoder().encode(item)
        let restored = try JSONDecoder().decode(BulkSessionItem.self, from: data)

        XCTAssertEqual(restored.id, item.id)
        XCTAssertEqual(restored.sessionId, sessionId)
        XCTAssertEqual(restored.prompt, "Mountain landscape")
        XCTAssertEqual(restored.status, .COMPLETED)
        XCTAssertEqual(restored.generationId, genId)
    }

    func testBulkSessionItem_codableRoundTrip_withError() throws {
        let item = BulkSessionItem(sessionId: UUID(), prompt: "Test")
        item.status = .FAILED
        item.errorMessage = "API timeout"

        let data = try JSONEncoder().encode(item)
        let restored = try JSONDecoder().decode(BulkSessionItem.self, from: data)

        XCTAssertEqual(restored.status, .FAILED)
        XCTAssertEqual(restored.errorMessage, "API timeout")
    }

    // MARK: - BulkSessionItem Decode with Missing Optional Fields

    func testBulkSessionItem_decode_missingStatus_defaultsToPending() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "sessionId": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "prompt": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(BulkSessionItem.self, from: data)
        XCTAssertEqual(restored.status, .PENDING)
    }

    func testBulkSessionItem_decode_missingOptionalUUIDs_defaultsToNil() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "sessionId": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "prompt": "Test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(BulkSessionItem.self, from: data)
        XCTAssertNil(restored.generationId)
        XCTAssertNil(restored.errorMessage)
        XCTAssertNil(restored.queueItemId)
    }

    // MARK: - BulkSessionItemStatus Extended Decoding

    func testBulkSessionItemStatus_decode_camelCase_inProgress() throws {
        let decoded = try JSONDecoder().decode(
            BulkSessionItemStatus.self,
            from: Data("\"inProgress\"".utf8)
        )
        XCTAssertEqual(decoded, .IN_PROGRESS)
    }

    func testBulkSessionItemStatus_decode_snakeCase_inProgress() throws {
        let decoded = try JSONDecoder().decode(
            BulkSessionItemStatus.self,
            from: Data("\"in_progress\"".utf8)
        )
        XCTAssertEqual(decoded, .IN_PROGRESS)
    }

    func testBulkSessionItemStatus_decode_uppercase_inProgress() throws {
        let decoded = try JSONDecoder().decode(
            BulkSessionItemStatus.self,
            from: Data("\"IN_PROGRESS\"".utf8)
        )
        XCTAssertEqual(decoded, .IN_PROGRESS)
    }

    func testBulkSessionItemStatus_decode_lowercase_cancelled() throws {
        let decoded = try JSONDecoder().decode(
            BulkSessionItemStatus.self,
            from: Data("\"cancelled\"".utf8)
        )
        XCTAssertEqual(decoded, .CANCELLED)
    }

    func testBulkSessionItemStatus_decode_uppercase_cancelled() throws {
        let decoded = try JSONDecoder().decode(
            BulkSessionItemStatus.self,
            from: Data("\"CANCELLED\"".utf8)
        )
        XCTAssertEqual(decoded, .CANCELLED)
    }

    func testBulkSessionItemStatus_decode_unknownValue_throws() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                BulkSessionItemStatus.self,
                from: Data("\"unknown\"".utf8)
            )
        )
    }

    // MARK: - Identifiable

    func testBulkSessionItem_twoInstances_haveDifferentIds() {
        let sessionId = UUID()
        let i1 = BulkSessionItem(sessionId: sessionId, prompt: "A")
        let i2 = BulkSessionItem(sessionId: sessionId, prompt: "B")
        XCTAssertNotEqual(i1.id, i2.id)
    }
}
