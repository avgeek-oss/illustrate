// MARK: - ChatMessageWorkflowTests.swift

// Workflow tests for ChatMessage realistic lifecycle scenarios.
//
// ChatMessageModelTests covers: init details, computed property edge cases,
// Codable decodeIfPresent defaults, prompt edge cases.
// ChatThreadModelWorkflowTests covers: basic lifecycle, generationIds basics,
// queueItemIds basics, imageGenerationConfiguration basics.
//
// This file adds: multi-step message lifecycle, generation tracking workflows,
// delink scenarios, configuration preservation across status changes,
// concurrent generationIds/queueItemIds, and pendingCount tracking.

import XCTest
@testable import Illustrate

final class ChatMessageWorkflowTests: XCTestCase {
    // MARK: - Message Lifecycle

    func testLifecycle_createMessage_defaultProcessing() {
        let msg = ChatMessage(threadId: UUID(), prompt: "Draw a cat")
        XCTAssertEqual(msg.status, .PROCESSING)
        XCTAssertTrue(msg.generationIds.isEmpty)
        XCTAssertTrue(msg.queueItemIds.isEmpty)
        XCTAssertNil(msg.errorMessage)
    }

    func testLifecycle_addGenerationIds_statusStillProcessing() {
        let msg = ChatMessage(threadId: UUID(), prompt: "Draw a cat")
        let genId = UUID()
        msg.generationIds = [genId]

        XCTAssertEqual(msg.status, .PROCESSING)
        XCTAssertEqual(msg.generationIds.count, 1)
        XCTAssertEqual(msg.generationIds.first, genId)
    }

    func testLifecycle_setGenerated_preservesGenerationIds() {
        let msg = ChatMessage(threadId: UUID(), prompt: "Draw a cat")
        let genIds = [UUID(), UUID()]
        msg.generationIds = genIds

        msg.status = .GENERATED

        XCTAssertEqual(msg.status, .GENERATED)
        XCTAssertEqual(msg.generationIds.count, 2)
        XCTAssertEqual(msg.generationIds, genIds)
    }

    func testLifecycle_setFailed_preservesErrorMessage() {
        let msg = ChatMessage(threadId: UUID(), prompt: "Draw a cat")
        msg.status = .FAILED
        msg.errorMessage = "Rate limit exceeded"

        XCTAssertEqual(msg.status, .FAILED)
        XCTAssertEqual(msg.errorMessage, "Rate limit exceeded")
    }

    func testLifecycle_failedWithGenerationIds_bothPreserved() {
        let msg = ChatMessage(threadId: UUID(), prompt: "Draw a cat")
        let genId = UUID()
        msg.generationIds = [genId]
        msg.status = .FAILED
        msg.errorMessage = "Partial failure"

        XCTAssertEqual(msg.generationIds.first, genId)
        XCTAssertEqual(msg.errorMessage, "Partial failure")
    }

    // MARK: - Generation Tracking Workflows

    func testGenerationTracking_setSingleId() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let genId = UUID()
        msg.generationIds = [genId]
        XCTAssertEqual(msg.generationIds, [genId])
    }

    func testGenerationTracking_setMultipleIds_preservesOrder() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let ids = [UUID(), UUID(), UUID()]
        msg.generationIds = ids
        XCTAssertEqual(msg.generationIds, ids)
    }

    func testGenerationTracking_replaceIds_oldOnesGone() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let oldIds = [UUID(), UUID()]
        msg.generationIds = oldIds

        let newIds = [UUID()]
        msg.generationIds = newIds

        XCTAssertEqual(msg.generationIds.count, 1)
        XCTAssertEqual(msg.generationIds, newIds)
    }

    func testGenerationTracking_clearIds() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        msg.generationIds = [UUID(), UUID()]
        msg.generationIds = []
        XCTAssertTrue(msg.generationIds.isEmpty)
    }

    // MARK: - Concurrent GenerationIds and QueueItemIds

    func testConcurrentTracking_bothSetsIndependent() {
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

    func testConcurrentTracking_modifyOneDoesNotAffectOther() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let genIds = [UUID()]
        let queueIds = [UUID(), UUID()]

        msg.generationIds = genIds
        msg.queueItemIds = queueIds

        msg.generationIds = []

        XCTAssertTrue(msg.generationIds.isEmpty)
        XCTAssertEqual(msg.queueItemIds.count, 2)
    }

    // MARK: - QueueItemIds Lifecycle

    func testQueueItemIds_setPendingThenClear() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let queueIds = [UUID(), UUID()]
        msg.queueItemIds = queueIds

        XCTAssertEqual(msg.queueItemIds.count, 2)

        msg.queueItemIds = []
        XCTAssertTrue(msg.queueItemIds.isEmpty)
    }

    // MARK: - Delink Workflow

    func testDelink_defaultIsFalse() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        XCTAssertFalse(msg.isDelinked)
    }

    func testDelink_setTrue_preserved() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        msg.isDelinked = true
        XCTAssertTrue(msg.isDelinked)
    }

    func testDelink_delinkedMessageStillHasGenerationIds() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        let genIds = [UUID(), UUID()]
        msg.generationIds = genIds
        msg.isDelinked = true

        XCTAssertTrue(msg.isDelinked)
        XCTAssertEqual(msg.generationIds, genIds)
    }

    // MARK: - PendingCount Tracking

    func testPendingCount_defaultIsZero() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        XCTAssertEqual(msg.pendingCount, 0)
    }

    func testPendingCount_canBeIncremented() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        msg.pendingCount = 3
        XCTAssertEqual(msg.pendingCount, 3)
    }

    func testPendingCount_decrementToZero() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")
        msg.pendingCount = 5
        msg.pendingCount = 0
        XCTAssertEqual(msg.pendingCount, 0)
    }

    // MARK: - Configuration Preservation Across Status Changes

    func testConfiguration_preservedAcrossStatusChange() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")

        var config = msg.imageGenerationConfiguration
        config.selectedProviderId = "provider-123"
        config.prompt = "detailed sunset"
        config.selectedDimensions = "1024x1024"
        msg.imageGenerationConfiguration = config

        msg.status = .GENERATED

        let retrieved = msg.imageGenerationConfiguration
        XCTAssertEqual(retrieved.selectedProviderId, "provider-123")
        XCTAssertEqual(retrieved.prompt, "detailed sunset")
        XCTAssertEqual(retrieved.selectedDimensions, "1024x1024")
    }

    func testConfiguration_independentFromStatus() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")

        var config = msg.imageGenerationConfiguration
        config.selectedModelId = "model-abc"
        msg.imageGenerationConfiguration = config

        msg.status = .FAILED
        msg.errorMessage = "Error occurred"

        XCTAssertEqual(msg.imageGenerationConfiguration.selectedModelId, "model-abc")
    }

    func testConfiguration_changingStatusDoesNotResetConfig() {
        let msg = ChatMessage(threadId: UUID(), prompt: "test")

        var config = msg.imageGenerationConfiguration
        config.guidanceValue = 7.5
        config.seedValue = "42"
        msg.imageGenerationConfiguration = config

        msg.status = .PROCESSING
        msg.status = .GENERATED
        msg.status = .FAILED

        XCTAssertEqual(msg.imageGenerationConfiguration.guidanceValue, 7.5)
        XCTAssertEqual(msg.imageGenerationConfiguration.seedValue, "42")
    }

    // MARK: - Thread Association

    func testThreadId_preserved() {
        let threadId = UUID()
        let msg = ChatMessage(threadId: threadId, prompt: "test")
        XCTAssertEqual(msg.threadId, threadId)
    }

    func testMultipleMessages_sameThread() {
        let threadId = UUID()
        let msg1 = ChatMessage(threadId: threadId, prompt: "First")
        let msg2 = ChatMessage(threadId: threadId, prompt: "Second")

        XCTAssertEqual(msg1.threadId, msg2.threadId)
        XCTAssertNotEqual(msg1.id, msg2.id)
    }
}
