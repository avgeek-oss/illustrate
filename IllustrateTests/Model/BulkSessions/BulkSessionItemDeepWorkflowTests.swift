// MARK: - BulkSessionItemDeepWorkflowTests.swift

// Deep workflow tests for BulkSessionItem lifecycle and batch scenarios.
//
// BulkSessionExtendedTests covers: basic init, basic codable round-trip,
// basic decode with missing optionals, IN_PROGRESS/CANCELLED decode.
// BulkSessionWorkflowTests covers: raw values, basic backward-compat decode.
//
// This file adds: lifecycle transition workflows, batch processing scenarios,
// JSON edge cases, codable edge cases, and field mutation workflows.

import XCTest
@testable import Illustrate

final class BulkSessionItemDeepWorkflowTests: XCTestCase {
    // MARK: - Lifecycle Workflows

    func testLifecycle_pendingToInProgressToCompleted() {
        let item = BulkSessionItem(sessionId: UUID(), prompt: "A mountain landscape")
        XCTAssertEqual(item.status, .PENDING)

        item.status = .IN_PROGRESS
        XCTAssertEqual(item.status, .IN_PROGRESS)

        let genId = UUID()
        item.status = .COMPLETED
        item.generationId = genId
        XCTAssertEqual(item.status, .COMPLETED)
        XCTAssertEqual(item.generationId, genId)
    }

    func testLifecycle_pendingToInProgressToFailed() {
        let item = BulkSessionItem(sessionId: UUID(), prompt: "test")
        item.status = .IN_PROGRESS
        item.status = .FAILED
        item.errorMessage = "Provider returned 429"

        XCTAssertEqual(item.status, .FAILED)
        XCTAssertEqual(item.errorMessage, "Provider returned 429")
        XCTAssertNil(item.generationId)
    }

    func testLifecycle_pendingToCancelled() {
        let item = BulkSessionItem(sessionId: UUID(), prompt: "test")
        item.status = .CANCELLED

        XCTAssertEqual(item.status, .CANCELLED)
        XCTAssertNil(item.generationId)
        XCTAssertNil(item.errorMessage)
    }

    func testLifecycle_fullSuccessPath_encodeDecode() throws {
        let sessionId = UUID()
        let item = BulkSessionItem(sessionId: sessionId, prompt: "Beautiful sunset")

        item.status = .IN_PROGRESS
        let queueId = UUID()
        item.queueItemId = queueId

        let genId = UUID()
        item.status = .COMPLETED
        item.generationId = genId

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(BulkSessionItem.self, from: data)

        XCTAssertEqual(decoded.sessionId, sessionId)
        XCTAssertEqual(decoded.prompt, "Beautiful sunset")
        XCTAssertEqual(decoded.status, .COMPLETED)
        XCTAssertEqual(decoded.generationId, genId)
        XCTAssertEqual(decoded.queueItemId, queueId)
    }

    func testLifecycle_failedWithQueueItemId() throws {
        let item = BulkSessionItem(sessionId: UUID(), prompt: "test")
        item.status = .FAILED
        item.errorMessage = "Timeout"
        item.queueItemId = UUID()

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(BulkSessionItem.self, from: data)

        XCTAssertEqual(decoded.status, .FAILED)
        XCTAssertEqual(decoded.errorMessage, "Timeout")
        XCTAssertNotNil(decoded.queueItemId)
    }

    func testLifecycle_allStatusTransitions() {
        let item = BulkSessionItem(sessionId: UUID(), prompt: "test")
        let allStatuses: [BulkSessionItemStatus] = [.PENDING, .IN_PROGRESS, .COMPLETED, .FAILED, .CANCELLED]

        for status in allStatuses {
            item.status = status
            XCTAssertEqual(item.status, status)
        }
    }

    // MARK: - Batch Workflow Scenarios

    func testBatch_createMultipleItems_allPending() {
        let sessionId = UUID()
        let items = (0 ..< 10).map { BulkSessionItem(sessionId: sessionId, prompt: "Prompt \($0)") }

        XCTAssertEqual(items.count, 10)
        XCTAssertTrue(items.allSatisfy { $0.status == .PENDING })
    }

    func testBatch_processItems_partialCompletion() {
        let sessionId = UUID()
        let items = (0 ..< 5).map { BulkSessionItem(sessionId: sessionId, prompt: "Prompt \($0)") }

        items[0].status = .COMPLETED
        items[0].generationId = UUID()
        items[1].status = .COMPLETED
        items[1].generationId = UUID()
        items[2].status = .COMPLETED
        items[2].generationId = UUID()
        items[3].status = .FAILED
        items[3].errorMessage = "Error"
        items[4].status = .CANCELLED

        let completed = items.filter { $0.status == .COMPLETED }
        let failed = items.filter { $0.status == .FAILED }
        let cancelled = items.filter { $0.status == .CANCELLED }

        XCTAssertEqual(completed.count, 3)
        XCTAssertEqual(failed.count, 1)
        XCTAssertEqual(cancelled.count, 1)
    }

    func testBatch_encodeDecodeArray_preservesOrder() throws {
        let sessionId = UUID()
        let items = (0 ..< 5).map { BulkSessionItem(sessionId: sessionId, prompt: "Item \($0)") }

        let data = try JSONEncoder().encode(items)
        let decoded = try JSONDecoder().decode([BulkSessionItem].self, from: data)

        XCTAssertEqual(decoded.count, 5)
        for i in 0 ..< 5 {
            XCTAssertEqual(decoded[i].prompt, "Item \(i)")
            XCTAssertEqual(decoded[i].id, items[i].id)
        }
    }

    func testBatch_mixedStatuses_encodeDecodePreserved() throws {
        let sessionId = UUID()
        let items = (0 ..< 5).map { BulkSessionItem(sessionId: sessionId, prompt: "P\($0)") }
        items[0].status = .PENDING
        items[1].status = .IN_PROGRESS
        items[2].status = .COMPLETED
        items[3].status = .FAILED
        items[4].status = .CANCELLED

        let data = try JSONEncoder().encode(items)
        let decoded = try JSONDecoder().decode([BulkSessionItem].self, from: data)

        XCTAssertEqual(decoded[0].status, .PENDING)
        XCTAssertEqual(decoded[1].status, .IN_PROGRESS)
        XCTAssertEqual(decoded[2].status, .COMPLETED)
        XCTAssertEqual(decoded[3].status, .FAILED)
        XCTAssertEqual(decoded[4].status, .CANCELLED)
    }

    func testBatch_filterByStatus() {
        let sessionId = UUID()
        let items = (0 ..< 10).map { BulkSessionItem(sessionId: sessionId, prompt: "P\($0)") }
        items[0 ..< 5].forEach { $0.status = .COMPLETED }
        items[5 ..< 8].forEach { $0.status = .FAILED }
        items[8 ..< 10].forEach { $0.status = .PENDING }

        let completed = items.filter { $0.status == .COMPLETED }
        XCTAssertEqual(completed.count, 5)
    }

    func testBatch_filterBySessionId() {
        let sessionA = UUID()
        let sessionB = UUID()
        let itemsA = (0 ..< 3).map { BulkSessionItem(sessionId: sessionA, prompt: "A\($0)") }
        let itemsB = (0 ..< 2).map { BulkSessionItem(sessionId: sessionB, prompt: "B\($0)") }
        let allItems = itemsA + itemsB

        let filtered = allItems.filter { $0.sessionId == sessionA }
        XCTAssertEqual(filtered.count, 3)
    }

    func testBatch_groupByStatus() {
        let sessionId = UUID()
        let items = (0 ..< 6).map { BulkSessionItem(sessionId: sessionId, prompt: "P\($0)") }
        items[0].status = .COMPLETED
        items[1].status = .COMPLETED
        items[2].status = .FAILED
        items[3].status = .PENDING
        items[4].status = .PENDING
        items[5].status = .PENDING

        let grouped = Dictionary(grouping: items, by: { $0.status })
        XCTAssertEqual(grouped[.COMPLETED]?.count, 2)
        XCTAssertEqual(grouped[.FAILED]?.count, 1)
        XCTAssertEqual(grouped[.PENDING]?.count, 3)
    }

    func testBatch_allCompleted_check() {
        let sessionId = UUID()
        let items = (0 ..< 3).map { BulkSessionItem(sessionId: sessionId, prompt: "P\($0)") }
        for item in items {
            item.status = .COMPLETED
            item.generationId = UUID()
        }

        XCTAssertTrue(items.allSatisfy { $0.status == .COMPLETED })
    }

    func testBatch_hasFailures_check() {
        let sessionId = UUID()
        let items = (0 ..< 3).map { BulkSessionItem(sessionId: sessionId, prompt: "P\($0)") }
        items[0].status = .COMPLETED
        items[1].status = .FAILED
        items[2].status = .COMPLETED

        XCTAssertTrue(items.contains { $0.status == .FAILED })
    }

    // MARK: - JSON Edge Cases

    func testDecode_extraUnknownKeys_succeeds() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "sessionId": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "prompt": "test",
            "unknownKey": "ignored",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(BulkSessionItem.self, from: data)
        XCTAssertEqual(decoded.prompt, "test")
    }

    func testDecode_missingRequiredField_id_throws() {
        let json: [String: Any] = [
            "sessionId": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "prompt": "test",
        ]
        XCTAssertThrowsError(try {
            let data = try JSONSerialization.data(withJSONObject: json)
            _ = try JSONDecoder().decode(BulkSessionItem.self, from: data)
        }())
    }

    func testDecode_missingRequiredField_sessionId_throws() {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "prompt": "test",
        ]
        XCTAssertThrowsError(try {
            let data = try JSONSerialization.data(withJSONObject: json)
            _ = try JSONDecoder().decode(BulkSessionItem.self, from: data)
        }())
    }

    func testDecode_missingRequiredField_prompt_throws() {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "sessionId": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        XCTAssertThrowsError(try {
            let data = try JSONSerialization.data(withJSONObject: json)
            _ = try JSONDecoder().decode(BulkSessionItem.self, from: data)
        }())
    }

    func testDecode_invalidUUID_throws() {
        let json: [String: Any] = [
            "id": "not-a-valid-uuid",
            "sessionId": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "prompt": "test",
        ]
        XCTAssertThrowsError(try {
            let data = try JSONSerialization.data(withJSONObject: json)
            _ = try JSONDecoder().decode(BulkSessionItem.self, from: data)
        }())
    }

    func testDecode_invalidStatusValue_throws() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "sessionId": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "prompt": "test",
            "status": "UNKNOWN_STATUS",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try JSONDecoder().decode(BulkSessionItem.self, from: data))
    }

    // MARK: - Codable Edge Cases

    func testCodableRoundTrip_withQueueItemId() throws {
        let item = BulkSessionItem(sessionId: UUID(), prompt: "test")
        let queueId = UUID()
        item.queueItemId = queueId

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(BulkSessionItem.self, from: data)

        XCTAssertEqual(decoded.queueItemId, queueId)
    }

    func testCodableRoundTrip_withAllOptionalFields() throws {
        let item = BulkSessionItem(sessionId: UUID(), prompt: "test")
        let genId = UUID()
        let queueId = UUID()
        item.generationId = genId
        item.errorMessage = "Some error"
        item.queueItemId = queueId

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(BulkSessionItem.self, from: data)

        XCTAssertEqual(decoded.generationId, genId)
        XCTAssertEqual(decoded.errorMessage, "Some error")
        XCTAssertEqual(decoded.queueItemId, queueId)
    }

    func testCodableRoundTrip_emptyPrompt() throws {
        let item = BulkSessionItem(sessionId: UUID(), prompt: "")

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(BulkSessionItem.self, from: data)

        XCTAssertEqual(decoded.prompt, "")
    }

    func testCodableRoundTrip_longPrompt() throws {
        let longPrompt = String(repeating: "A beautiful landscape with mountains. ", count: 30)
        let item = BulkSessionItem(sessionId: UUID(), prompt: longPrompt)

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(BulkSessionItem.self, from: data)

        XCTAssertEqual(decoded.prompt, longPrompt)
    }

    func testCodableRoundTrip_specialCharactersInPrompt() throws {
        let prompt = "日本語テスト 🎨\nWith \"quotes\" & <brackets>"
        let item = BulkSessionItem(sessionId: UUID(), prompt: prompt)

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(BulkSessionItem.self, from: data)

        XCTAssertEqual(decoded.prompt, prompt)
    }

    func testCodableRoundTrip_cancelledWithQueueItemId() throws {
        let item = BulkSessionItem(sessionId: UUID(), prompt: "test")
        item.status = .CANCELLED
        item.queueItemId = UUID()

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(BulkSessionItem.self, from: data)

        XCTAssertEqual(decoded.status, .CANCELLED)
        XCTAssertNotNil(decoded.queueItemId)
    }

    func testCodableRoundTrip_failedWithAllFields() throws {
        let item = BulkSessionItem(sessionId: UUID(), prompt: "test")
        item.status = .FAILED
        item.errorMessage = "Provider error"
        item.queueItemId = UUID()

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(BulkSessionItem.self, from: data)

        XCTAssertEqual(decoded.status, .FAILED)
        XCTAssertEqual(decoded.errorMessage, "Provider error")
        XCTAssertNotNil(decoded.queueItemId)
        XCTAssertNil(decoded.generationId)
    }

    func testCodableRoundTrip_multipleRoundTrips_stable() throws {
        let item = BulkSessionItem(sessionId: UUID(), prompt: "Stable test")
        item.status = .COMPLETED
        item.generationId = UUID()

        var current = item
        for _ in 0 ..< 3 {
            let data = try JSONEncoder().encode(current)
            current = try JSONDecoder().decode(BulkSessionItem.self, from: data)
        }

        XCTAssertEqual(current.id, item.id)
        XCTAssertEqual(current.prompt, "Stable test")
        XCTAssertEqual(current.status, .COMPLETED)
        XCTAssertEqual(current.generationId, item.generationId)
    }

    func testEncode_producesValidJSON() throws {
        let item = BulkSessionItem(sessionId: UUID(), prompt: "test")
        let data = try JSONEncoder().encode(item)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(jsonObject is [String: Any])
    }

    // MARK: - Field Mutation

    func testMutateGenerationId_setAndClear() {
        let item = BulkSessionItem(sessionId: UUID(), prompt: "test")
        XCTAssertNil(item.generationId)

        let genId = UUID()
        item.generationId = genId
        XCTAssertEqual(item.generationId, genId)

        item.generationId = nil
        XCTAssertNil(item.generationId)
    }

    func testMutateErrorMessage_setAndClear() {
        let item = BulkSessionItem(sessionId: UUID(), prompt: "test")
        XCTAssertNil(item.errorMessage)

        item.errorMessage = "Error"
        XCTAssertEqual(item.errorMessage, "Error")

        item.errorMessage = nil
        XCTAssertNil(item.errorMessage)
    }

    func testMutateQueueItemId_setAndClear() {
        let item = BulkSessionItem(sessionId: UUID(), prompt: "test")
        XCTAssertNil(item.queueItemId)

        let queueId = UUID()
        item.queueItemId = queueId
        XCTAssertEqual(item.queueItemId, queueId)

        item.queueItemId = nil
        XCTAssertNil(item.queueItemId)
    }

    func testId_preservedAfterEncodeDecode() throws {
        let item = BulkSessionItem(sessionId: UUID(), prompt: "test")
        let originalId = item.id

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(BulkSessionItem.self, from: data)

        XCTAssertEqual(decoded.id, originalId)
    }

    func testCreatedAt_preservedAfterEncodeDecode() throws {
        let item = BulkSessionItem(sessionId: UUID(), prompt: "test")
        let originalDate = item.createdAt

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(BulkSessionItem.self, from: data)

        XCTAssertEqual(
            decoded.createdAt.timeIntervalSinceReferenceDate,
            originalDate.timeIntervalSinceReferenceDate,
            accuracy: 0.001
        )
    }

    func testEmptySessionItems_encodeDecodeArray() throws {
        let items: [BulkSessionItem] = []
        let data = try JSONEncoder().encode(items)
        let decoded = try JSONDecoder().decode([BulkSessionItem].self, from: data)
        XCTAssertTrue(decoded.isEmpty)
    }
}
