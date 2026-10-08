// MARK: - ChatMessageModelTests.swift

// Extended tests for ChatMessage model covering areas not in ChatThreadModelWorkflowTests.
//
// ChatThreadModelWorkflowTests covers: basic init (4), generationIds basics (4),
// queueItemIds basics (4), imageGenerationConfiguration basics (3), full Codable round-trip (1).
// This file adds: UUID uniqueness, nil defaults, computed property edge cases,
// Codable decodeIfPresent defaults, prompt edge cases, and multi-cycle workflows.

import XCTest
@testable import Illustrate

final class ChatMessageModelTests: XCTestCase {
    // MARK: - Initialization Details

    func testInit_IdIsUniqueUUID() {
        let msg1 = ChatMessage(threadId: UUID(), prompt: "a")
        let msg2 = ChatMessage(threadId: UUID(), prompt: "b")
        XCTAssertNotEqual(msg1.id, msg2.id)
    }

    func testInit_CreatedAtIsSet() {
        let before = Date()
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let after = Date()
        XCTAssertGreaterThanOrEqual(msg.createdAt, before)
        XCTAssertLessThanOrEqual(msg.createdAt, after)
    }

    func testInit_GenerationIdsDataNil() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        XCTAssertNil(msg.generationIdsData)
    }

    func testInit_QueueItemIdsDataNil() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        XCTAssertNil(msg.queueItemIdsData)
    }

    func testInit_ErrorMessageNil() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        XCTAssertNil(msg.errorMessage)
    }

    func testInit_ConfigurationDataNil() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        XCTAssertNil(msg.configurationData)
    }

    // MARK: - generationIds Computed Property Edge Cases

    func testGenerationIds_SetEmptyArray_ReturnsEmpty() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        msg.generationIds = []
        XCTAssertTrue(msg.generationIds.isEmpty)
        // Even empty array encodes to Data
        XCTAssertNotNil(msg.generationIdsData)
    }

    func testGenerationIds_SetSingleUUID_ReturnsSingle() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let singleId = UUID()
        msg.generationIds = [singleId]
        XCTAssertEqual(msg.generationIds, [singleId])
    }

    func testGenerationIds_ReplaceExisting_NewValuesReturned() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let oldIds = [UUID(), UUID()]
        let newIds = [UUID(), UUID(), UUID()]
        msg.generationIds = oldIds
        msg.generationIds = newIds

        XCTAssertEqual(msg.generationIds.count, 3)
        XCTAssertEqual(msg.generationIds, newIds)
    }

    func testGenerationIds_ManyUUIDs_AllPreserved() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let ids = (0 ..< 100).map { _ in UUID() }
        msg.generationIds = ids

        XCTAssertEqual(msg.generationIds.count, 100)
        XCTAssertEqual(msg.generationIds, ids)
    }

    func testGenerationIds_PreservesOrder() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let ids = [UUID(), UUID(), UUID(), UUID(), UUID()]
        msg.generationIds = ids

        for (index, id) in ids.enumerated() {
            XCTAssertEqual(msg.generationIds[index], id)
        }
    }

    // MARK: - queueItemIds Computed Property Edge Cases

    func testQueueItemIds_SetEmptyArray_ReturnsEmpty() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        msg.queueItemIds = []
        XCTAssertTrue(msg.queueItemIds.isEmpty)
    }

    func testQueueItemIds_SetMultiple_PreservesOrder() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let ids = [UUID(), UUID(), UUID(), UUID()]
        msg.queueItemIds = ids

        XCTAssertEqual(msg.queueItemIds.count, 4)
        for (index, id) in ids.enumerated() {
            XCTAssertEqual(msg.queueItemIds[index], id)
        }
    }

    func testQueueItemIds_IndependentFromGenerationIds() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let genIds = [UUID(), UUID()]
        let queueIds = [UUID(), UUID(), UUID()]
        msg.generationIds = genIds
        msg.queueItemIds = queueIds

        XCTAssertEqual(msg.generationIds.count, 2)
        XCTAssertEqual(msg.queueItemIds.count, 3)
        XCTAssertEqual(msg.generationIds, genIds)
        XCTAssertEqual(msg.queueItemIds, queueIds)
    }

    func testQueueItemIds_ReplaceDoesNotAffectGenerationIds() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let genIds = [UUID()]
        msg.generationIds = genIds
        msg.queueItemIds = [UUID(), UUID()]
        msg.queueItemIds = [UUID()]

        XCTAssertEqual(msg.generationIds, genIds)
    }

    // MARK: - imageGenerationConfiguration Extended

    func testImageConfig_PreservesSelectedProviderId() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        var config = ImageGenerationConfiguration()
        config.selectedProviderId = "provider-openai"
        msg.imageGenerationConfiguration = config

        XCTAssertEqual(msg.imageGenerationConfiguration.selectedProviderId, "provider-openai")
    }

    func testImageConfig_PreservesDimensions() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        var config = ImageGenerationConfiguration()
        config.selectedDimensions = "1792x1024"
        msg.imageGenerationConfiguration = config

        XCTAssertEqual(msg.imageGenerationConfiguration.selectedDimensions, "1792x1024")
    }

    func testImageConfig_MultipleSetGetCycles() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")

        var config1 = ImageGenerationConfiguration()
        config1.prompt = "first"
        msg.imageGenerationConfiguration = config1
        XCTAssertEqual(msg.imageGenerationConfiguration.prompt, "first")

        var config2 = ImageGenerationConfiguration()
        config2.prompt = "second"
        msg.imageGenerationConfiguration = config2
        XCTAssertEqual(msg.imageGenerationConfiguration.prompt, "second")

        var config3 = ImageGenerationConfiguration()
        config3.prompt = "third"
        config3.selectedModelId = "model-v3"
        msg.imageGenerationConfiguration = config3
        XCTAssertEqual(msg.imageGenerationConfiguration.prompt, "third")
        XCTAssertEqual(msg.imageGenerationConfiguration.selectedModelId, "model-v3")
    }

    func testImageConfig_PreservesGuidanceAndSeed() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        var config = ImageGenerationConfiguration()
        config.guidanceValue = 7.5
        config.seedValue = "42"
        config.stepsValue = 50
        msg.imageGenerationConfiguration = config

        let retrieved = msg.imageGenerationConfiguration
        XCTAssertEqual(retrieved.guidanceValue, 7.5)
        XCTAssertEqual(retrieved.seedValue, "42")
        XCTAssertEqual(retrieved.stepsValue, 50)
    }

    // MARK: - Codable decodeIfPresent Defaults

    func testCodable_MissingPendingCount_DefaultsToZero() throws {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        msg.pendingCount = 5
        let data = try JSONEncoder().encode(msg)

        // Decode from JSON with pendingCount removed
        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "pendingCount")
        let modifiedData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(ChatMessage.self, from: modifiedData)
        XCTAssertEqual(decoded.pendingCount, 0)
    }

    func testCodable_MissingIsDelinked_DefaultsToFalse() throws {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        msg.isDelinked = true
        let data = try JSONEncoder().encode(msg)

        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "isDelinked")
        let modifiedData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(ChatMessage.self, from: modifiedData)
        XCTAssertFalse(decoded.isDelinked)
    }

    func testCodable_MissingGenerationIdsData_DefaultsToNil() throws {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let data = try JSONEncoder().encode(msg)

        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "generationIdsData")
        let modifiedData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(ChatMessage.self, from: modifiedData)
        XCTAssertNil(decoded.generationIdsData)
        XCTAssertTrue(decoded.generationIds.isEmpty)
    }

    func testCodable_MissingErrorMessage_DefaultsToNil() throws {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let data = try JSONEncoder().encode(msg)

        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "errorMessage")
        let modifiedData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(ChatMessage.self, from: modifiedData)
        XCTAssertNil(decoded.errorMessage)
    }

    func testCodable_MissingConfigurationData_DefaultsToNil() throws {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let data = try JSONEncoder().encode(msg)

        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "configurationData")
        let modifiedData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(ChatMessage.self, from: modifiedData)
        XCTAssertNil(decoded.configurationData)
    }

    func testCodable_MissingQueueItemIdsData_DefaultsToNil() throws {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let data = try JSONEncoder().encode(msg)

        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "queueItemIdsData")
        let modifiedData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(ChatMessage.self, from: modifiedData)
        XCTAssertNil(decoded.queueItemIdsData)
        XCTAssertTrue(decoded.queueItemIds.isEmpty)
    }

    func testCodable_AllOptionalFieldsMissing_AllDefaults() throws {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let data = try JSONEncoder().encode(msg)

        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "pendingCount")
        json.removeValue(forKey: "isDelinked")
        json.removeValue(forKey: "generationIdsData")
        json.removeValue(forKey: "errorMessage")
        json.removeValue(forKey: "configurationData")
        json.removeValue(forKey: "queueItemIdsData")
        let modifiedData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(ChatMessage.self, from: modifiedData)
        XCTAssertEqual(decoded.pendingCount, 0)
        XCTAssertFalse(decoded.isDelinked)
        XCTAssertNil(decoded.generationIdsData)
        XCTAssertNil(decoded.errorMessage)
        XCTAssertNil(decoded.configurationData)
        XCTAssertNil(decoded.queueItemIdsData)
    }

    // MARK: - Codable With Non-Default Values

    func testCodable_PendingCountPreserved() throws {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        msg.pendingCount = 42
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.pendingCount, 42)
    }

    func testCodable_IsDelinkedPreserved() throws {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        msg.isDelinked = true
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertTrue(decoded.isDelinked)
    }

    func testCodable_ErrorMessagePreserved() throws {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        msg.errorMessage = "Rate limit exceeded"
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.errorMessage, "Rate limit exceeded")
    }

    func testCodable_WithGenerationIdsPopulated() throws {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let genIds = [UUID(), UUID(), UUID()]
        msg.generationIds = genIds
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.generationIds, genIds)
    }

    func testCodable_WithQueueItemIdsPopulated() throws {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let queueIds = [UUID(), UUID()]
        msg.queueItemIds = queueIds
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.queueItemIds, queueIds)
    }

    func testCodable_FailedStatusWithError() throws {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        msg.status = .FAILED
        msg.errorMessage = "Provider unavailable"
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.status, .FAILED)
        XCTAssertEqual(decoded.errorMessage, "Provider unavailable")
    }

    // MARK: - Prompt Edge Cases

    func testPrompt_SpecialCharactersPreserved() throws {
        let specialPrompt = "A sunset 🌅 with <brackets> & \"quotes\" and 日本語"
        let msg = ChatMessage(threadId: UUID(), prompt: specialPrompt)
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.prompt, specialPrompt)
    }

    func testPrompt_EmptyStringPreserved() throws {
        let msg = ChatMessage(threadId: UUID(), prompt: "")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.prompt, "")
    }

    func testPrompt_LongStringPreserved() throws {
        let longPrompt = String(repeating: "a beautiful landscape ", count: 200)
        let msg = ChatMessage(threadId: UUID(), prompt: longPrompt)
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.prompt, longPrompt)
    }

    func testPrompt_NewlinesPreserved() throws {
        let multiline = "Line 1\nLine 2\nLine 3"
        let msg = ChatMessage(threadId: UUID(), prompt: multiline)
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.prompt, multiline)
    }

    // MARK: - Identifiable Conformance

    func testIdentifiable_IdIsUUID() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        XCTAssertFalse(msg.id.uuidString.isEmpty)
    }

    func testIdentifiable_IdPreservedThroughCodable() throws {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let originalId = msg.id
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.id, originalId)
    }

    // MARK: - ThreadId Preserved

    func testThreadId_PreservedThroughCodable() throws {
        let threadId = UUID()
        let msg = ChatMessage(threadId: threadId, prompt: "test")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.threadId, threadId)
    }

    // MARK: - CreatedAt Preserved

    func testCreatedAt_PreservedThroughCodable() throws {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(
            decoded.createdAt.timeIntervalSince1970,
            msg.createdAt.timeIntervalSince1970,
            accuracy: 0.001
        )
    }
}
