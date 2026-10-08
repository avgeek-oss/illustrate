// MARK: - QueueManagerTests.swift

// Unit tests for QueueManager and related types.
//
// Tests cover:
// - QueueItemStatus enum
// - QueueItemSource enum and shouldAutoRemoveOnSuccess
// - QueueItem initialization and properties
// - QueueManager queue operations (add, remove, cancel, clear)
// - QueueManager filtering (inProgress, successful, failed)
// - QueueManager computed properties

import XCTest
@testable import Illustrate

final class QueueManagerTests: XCTestCase {
    // MARK: - QueueItemStatus Tests

    func testQueueItemStatus_rawValues() {
        XCTAssertEqual(QueueItemStatus.IN_PROGRESS.rawValue, "IN_PROGRESS")
        XCTAssertEqual(QueueItemStatus.SUCCESSFUL.rawValue, "SUCCESSFUL")
        XCTAssertEqual(QueueItemStatus.FAILED.rawValue, "FAILED")
    }

    func testQueueItemStatus_codable() throws {
        let statuses: [QueueItemStatus] = [.IN_PROGRESS, .SUCCESSFUL, .FAILED]

        let data = try JSONEncoder().encode(statuses)
        let decoded = try JSONDecoder().decode([QueueItemStatus].self, from: data)

        XCTAssertEqual(decoded, statuses)
    }

    // MARK: - QueueItemSource Tests

    func testQueueItemSource_allRawValues() {
        XCTAssertEqual(QueueItemSource.IMAGE_GENERATE.rawValue, "IMAGE_GENERATE")
        XCTAssertEqual(QueueItemSource.VIDEO_GENERATE.rawValue, "VIDEO_GENERATE")
        XCTAssertEqual(QueueItemSource.CHAT_THREADS.rawValue, "CHAT_THREADS")
        XCTAssertEqual(QueueItemSource.FLOW_CANVAS.rawValue, "FLOW_CANVAS")
        XCTAssertEqual(QueueItemSource.BULK_GENERATE.rawValue, "BULK_GENERATE")
        XCTAssertEqual(QueueItemSource.STORYBOARD.rawValue, "STORYBOARD")
        XCTAssertEqual(QueueItemSource.CREATIVE_STUDIO.rawValue, "CREATIVE_STUDIO")
        XCTAssertEqual(QueueItemSource.PRODUCT_PHOTOSHOOTS.rawValue, "PRODUCT_PHOTOSHOOTS")
        XCTAssertEqual(QueueItemSource.AGENT_BUILDER.rawValue, "AGENT_BUILDER")
    }

    func testQueueItemSource_shouldAutoRemoveOnSuccess_imageGenerate() {
        XCTAssertFalse(QueueItemSource.IMAGE_GENERATE.shouldAutoRemoveOnSuccess)
    }

    func testQueueItemSource_shouldAutoRemoveOnSuccess_videoGenerate() {
        XCTAssertFalse(QueueItemSource.VIDEO_GENERATE.shouldAutoRemoveOnSuccess)
    }

    func testQueueItemSource_shouldAutoRemoveOnSuccess_chatThreads() {
        XCTAssertTrue(QueueItemSource.CHAT_THREADS.shouldAutoRemoveOnSuccess)
    }

    func testQueueItemSource_shouldAutoRemoveOnSuccess_flowCanvas() {
        XCTAssertTrue(QueueItemSource.FLOW_CANVAS.shouldAutoRemoveOnSuccess)
    }

    func testQueueItemSource_shouldAutoRemoveOnSuccess_bulkGenerate() {
        XCTAssertTrue(QueueItemSource.BULK_GENERATE.shouldAutoRemoveOnSuccess)
    }

    func testQueueItemSource_shouldAutoRemoveOnSuccess_storyboard() {
        XCTAssertTrue(QueueItemSource.STORYBOARD.shouldAutoRemoveOnSuccess)
    }

    func testQueueItemSource_shouldAutoRemoveOnSuccess_creativeStudio() {
        XCTAssertTrue(QueueItemSource.CREATIVE_STUDIO.shouldAutoRemoveOnSuccess)
    }

    func testQueueItemSource_shouldAutoRemoveOnSuccess_productPhotoshoots() {
        XCTAssertTrue(QueueItemSource.PRODUCT_PHOTOSHOOTS.shouldAutoRemoveOnSuccess)
    }

    func testQueueItemSource_shouldAutoRemoveOnSuccess_agentBuilder() {
        XCTAssertTrue(QueueItemSource.AGENT_BUILDER.shouldAutoRemoveOnSuccess)
    }

    func testQueueItemSource_codable() throws {
        let sources: [QueueItemSource] = [.IMAGE_GENERATE, .VIDEO_GENERATE, .CHAT_THREADS]

        let data = try JSONEncoder().encode(sources)
        let decoded = try JSONDecoder().decode([QueueItemSource].self, from: data)

        XCTAssertEqual(decoded, sources)
    }

    // MARK: - QueueItem Initialization Tests

    func testQueueItem_defaultInitialization() {
        let item = QueueItem(prompt: "Test prompt", source: .IMAGE_GENERATE)

        XCTAssertFalse(item.id.uuidString.isEmpty)
        XCTAssertEqual(item.prompt, "Test prompt")
        XCTAssertEqual(item.source, .IMAGE_GENERATE)
        XCTAssertEqual(item.status, .IN_PROGRESS)
        XCTAssertNil(item.resultSetId)
        XCTAssertNil(item.errorMessage)
        XCTAssertNil(item.rawResponse)
        XCTAssertFalse(item.isVideoGeneration)
        XCTAssertNil(item.progress)
        XCTAssertNil(item.task)
    }

    func testQueueItem_fullInitialization() {
        let id = UUID()
        let setId = UUID()

        let item = QueueItem(
            id: id,
            prompt: "Full test",
            source: .VIDEO_GENERATE,
            status: .SUCCESSFUL,
            resultSetId: setId,
            errorMessage: nil,
            rawResponse: nil,
            isVideoGeneration: true,
            progress: 50
        )

        XCTAssertEqual(item.id, id)
        XCTAssertEqual(item.prompt, "Full test")
        XCTAssertEqual(item.source, .VIDEO_GENERATE)
        XCTAssertEqual(item.status, .SUCCESSFUL)
        XCTAssertEqual(item.resultSetId, setId)
        XCTAssertTrue(item.isVideoGeneration)
        XCTAssertEqual(item.progress, 50)
    }

    func testQueueItem_failedInitialization() {
        let item = QueueItem(
            prompt: "Failed prompt",
            source: .BULK_GENERATE,
            status: .FAILED,
            errorMessage: "API Error",
            rawResponse: "{\"error\": \"rate_limit\"}"
        )

        XCTAssertEqual(item.status, .FAILED)
        XCTAssertEqual(item.errorMessage, "API Error")
        XCTAssertEqual(item.rawResponse, "{\"error\": \"rate_limit\"}")
    }

    func testQueueItem_createdAtIsSet() {
        let beforeCreation = Date()
        let item = QueueItem(prompt: "Time test", source: .IMAGE_GENERATE)
        let afterCreation = Date()

        XCTAssertGreaterThanOrEqual(item.createdAt, beforeCreation)
        XCTAssertLessThanOrEqual(item.createdAt, afterCreation)
    }

    func testQueueItem_cancel() {
        let item = QueueItem(prompt: "Cancel test", source: .IMAGE_GENERATE)

        // Create a mock task
        item.task = Task {
            try? await Task.sleep(for: .seconds(10))
        }

        // Verify task is set before cancel
        XCTAssertNotNil(item.task)

        // Cancel the item
        item.cancel()

        // Verify task is cleared after cancel
        XCTAssertNil(item.task)
    }

    func testQueueItem_identifiable() {
        let item1 = QueueItem(prompt: "Test 1", source: .IMAGE_GENERATE)
        let item2 = QueueItem(prompt: "Test 2", source: .IMAGE_GENERATE)

        XCTAssertNotEqual(item1.id, item2.id)
    }

    // MARK: - QueueManager Tests

    @MainActor
    func testQueueManager_addItem() {
        let manager = QueueManager()
        let item = QueueItem(prompt: "Add test", source: .IMAGE_GENERATE)

        manager.addItem(item)

        XCTAssertEqual(manager.items.count, 1)
        XCTAssertEqual(manager.items.first?.id, item.id)
    }

    @MainActor
    func testQueueManager_addItem_insertsAtBeginning() {
        let manager = QueueManager()
        let item1 = QueueItem(prompt: "First", source: .IMAGE_GENERATE)
        let item2 = QueueItem(prompt: "Second", source: .IMAGE_GENERATE)

        manager.addItem(item1)
        manager.addItem(item2)

        XCTAssertEqual(manager.items.count, 2)
        XCTAssertEqual(manager.items[0].prompt, "Second")
        XCTAssertEqual(manager.items[1].prompt, "First")
    }

    @MainActor
    func testQueueManager_removeItem() {
        let manager = QueueManager()
        let item = QueueItem(prompt: "Remove test", source: .IMAGE_GENERATE)

        manager.addItem(item)
        XCTAssertEqual(manager.items.count, 1)

        manager.removeItem(item)
        XCTAssertEqual(manager.items.count, 0)
    }

    @MainActor
    func testQueueManager_removeItemById() {
        let manager = QueueManager()
        let item = QueueItem(prompt: "Remove by ID", source: .IMAGE_GENERATE)

        manager.addItem(item)
        manager.removeItem(by: item.id)

        XCTAssertEqual(manager.items.count, 0)
    }

    @MainActor
    func testQueueManager_removeItemById_nonExistent() {
        let manager = QueueManager()
        let item = QueueItem(prompt: "Keep this", source: .IMAGE_GENERATE)

        manager.addItem(item)
        manager.removeItem(by: UUID())

        XCTAssertEqual(manager.items.count, 1)
    }

    @MainActor
    func testQueueManager_cancelItem() {
        let manager = QueueManager()
        let item = QueueItem(prompt: "Cancel test", source: .IMAGE_GENERATE)

        manager.addItem(item)
        manager.cancelItem(item)

        XCTAssertEqual(item.status, .FAILED)
        XCTAssertEqual(item.errorMessage, "Cancelled by user")
    }

    @MainActor
    func testQueueManager_cancelItemById() {
        let manager = QueueManager()
        let item = QueueItem(prompt: "Cancel by ID", source: .IMAGE_GENERATE)

        manager.addItem(item)
        manager.cancelItem(by: item.id)

        XCTAssertEqual(item.status, .FAILED)
    }

    @MainActor
    func testQueueManager_cancelItemById_nonExistent() {
        let manager = QueueManager()
        let item = QueueItem(prompt: "Keep active", source: .IMAGE_GENERATE)

        manager.addItem(item)
        manager.cancelItem(by: UUID())

        // Item should remain unchanged
        XCTAssertEqual(item.status, .IN_PROGRESS)
    }

    @MainActor
    func testQueueManager_updateItemStatus() {
        let manager = QueueManager()
        let item = QueueItem(prompt: "Update status", source: .IMAGE_GENERATE)
        let setId = UUID()
        let genId = UUID()

        manager.addItem(item)
        manager.updateItemStatus(
            item.id,
            status: .SUCCESSFUL,
            resultSetId: setId,
            resultGenerationId: genId
        )

        XCTAssertEqual(item.status, .SUCCESSFUL)
        XCTAssertEqual(item.resultSetId, setId)
        XCTAssertEqual(item.resultGenerationId, genId)
    }

    @MainActor
    func testQueueManager_updateItemStatus_failed() {
        let manager = QueueManager()
        let item = QueueItem(prompt: "Fail test", source: .IMAGE_GENERATE)

        manager.addItem(item)
        manager.updateItemStatus(
            item.id,
            status: .FAILED,
            errorMessage: "Content policy violation",
            rawResponse: "{\"error\": \"content_policy\"}"
        )

        XCTAssertEqual(item.status, .FAILED)
        XCTAssertEqual(item.errorMessage, "Content policy violation")
        XCTAssertEqual(item.rawResponse, "{\"error\": \"content_policy\"}")
    }

    @MainActor
    func testQueueManager_updateVideoItemStatus() {
        let manager = QueueManager()
        let item = QueueItem(prompt: "Video update", source: .VIDEO_GENERATE, isVideoGeneration: true)
        let videoSetId = UUID()

        manager.addItem(item)
        manager.updateVideoItemStatus(
            item.id,
            status: .SUCCESSFUL,
            resultVideoSetId: videoSetId
        )

        XCTAssertEqual(item.status, .SUCCESSFUL)
        XCTAssertEqual(item.resultVideoSetId, videoSetId)
    }

    @MainActor
    func testQueueManager_clearAllFailed() {
        let manager = QueueManager()

        let successItem = QueueItem(prompt: "Success", source: .IMAGE_GENERATE, status: .SUCCESSFUL)
        let failedItem1 = QueueItem(prompt: "Failed 1", source: .IMAGE_GENERATE, status: .FAILED)
        let failedItem2 = QueueItem(prompt: "Failed 2", source: .VIDEO_GENERATE, status: .FAILED)
        let inProgressItem = QueueItem(prompt: "In Progress", source: .IMAGE_GENERATE, status: .IN_PROGRESS)

        manager.addItem(successItem)
        manager.addItem(failedItem1)
        manager.addItem(failedItem2)
        manager.addItem(inProgressItem)

        XCTAssertEqual(manager.items.count, 4)

        manager.clearAllFailed()

        XCTAssertEqual(manager.items.count, 2)
        XCTAssertTrue(manager.items.contains { $0.status == .SUCCESSFUL })
        XCTAssertTrue(manager.items.contains { $0.status == .IN_PROGRESS })
        XCTAssertFalse(manager.items.contains { $0.status == .FAILED })
    }

    @MainActor
    func testQueueManager_clearAllCompleted() {
        let manager = QueueManager()

        let successItem1 = QueueItem(prompt: "Success 1", source: .IMAGE_GENERATE, status: .SUCCESSFUL)
        let successItem2 = QueueItem(prompt: "Success 2", source: .VIDEO_GENERATE, status: .SUCCESSFUL)
        let failedItem = QueueItem(prompt: "Failed", source: .IMAGE_GENERATE, status: .FAILED)
        let inProgressItem = QueueItem(prompt: "In Progress", source: .IMAGE_GENERATE, status: .IN_PROGRESS)

        manager.addItem(successItem1)
        manager.addItem(successItem2)
        manager.addItem(failedItem)
        manager.addItem(inProgressItem)

        manager.clearAllCompleted()

        XCTAssertEqual(manager.items.count, 2)
        XCTAssertFalse(manager.items.contains { $0.status == .SUCCESSFUL })
    }

    // MARK: - Filtering Tests

    @MainActor
    func testQueueManager_inProgressItems() {
        let manager = QueueManager()

        manager.addItem(QueueItem(prompt: "IP 1", source: .IMAGE_GENERATE, status: .IN_PROGRESS))
        manager.addItem(QueueItem(prompt: "IP 2", source: .IMAGE_GENERATE, status: .IN_PROGRESS))
        manager.addItem(QueueItem(prompt: "Success", source: .IMAGE_GENERATE, status: .SUCCESSFUL))
        manager.addItem(QueueItem(prompt: "Failed", source: .IMAGE_GENERATE, status: .FAILED))

        let inProgress = manager.inProgressItems

        XCTAssertEqual(inProgress.count, 2)
        XCTAssertTrue(inProgress.allSatisfy { $0.status == .IN_PROGRESS })
    }

    @MainActor
    func testQueueManager_successfulItems() {
        let manager = QueueManager()

        manager.addItem(QueueItem(prompt: "Success 1", source: .IMAGE_GENERATE, status: .SUCCESSFUL))
        manager.addItem(QueueItem(prompt: "Success 2", source: .IMAGE_GENERATE, status: .SUCCESSFUL))
        manager.addItem(QueueItem(prompt: "In Progress", source: .IMAGE_GENERATE, status: .IN_PROGRESS))

        let successful = manager.successfulItems

        XCTAssertEqual(successful.count, 2)
        XCTAssertTrue(successful.allSatisfy { $0.status == .SUCCESSFUL })
    }

    @MainActor
    func testQueueManager_failedItems() {
        let manager = QueueManager()

        manager.addItem(QueueItem(prompt: "Failed 1", source: .IMAGE_GENERATE, status: .FAILED))
        manager.addItem(QueueItem(prompt: "Failed 2", source: .VIDEO_GENERATE, status: .FAILED))
        manager.addItem(QueueItem(prompt: "Success", source: .IMAGE_GENERATE, status: .SUCCESSFUL))

        let failed = manager.failedItems

        XCTAssertEqual(failed.count, 2)
        XCTAssertTrue(failed.allSatisfy { $0.status == .FAILED })
    }

    // MARK: - Computed Properties Tests

    @MainActor
    func testQueueManager_hasActiveItems_true() {
        let manager = QueueManager()
        manager.addItem(QueueItem(prompt: "Active", source: .IMAGE_GENERATE, status: .IN_PROGRESS))

        XCTAssertTrue(manager.hasActiveItems)
    }

    @MainActor
    func testQueueManager_hasActiveItems_false() {
        let manager = QueueManager()
        manager.addItem(QueueItem(prompt: "Done", source: .IMAGE_GENERATE, status: .SUCCESSFUL))

        XCTAssertFalse(manager.hasActiveItems)
    }

    @MainActor
    func testQueueManager_hasActiveItems_empty() {
        let manager = QueueManager()

        XCTAssertFalse(manager.hasActiveItems)
    }

    @MainActor
    func testQueueManager_totalCount() {
        let manager = QueueManager()

        XCTAssertEqual(manager.totalCount, 0)

        manager.addItem(QueueItem(prompt: "1", source: .IMAGE_GENERATE))
        manager.addItem(QueueItem(prompt: "2", source: .IMAGE_GENERATE))
        manager.addItem(QueueItem(prompt: "3", source: .IMAGE_GENERATE))

        XCTAssertEqual(manager.totalCount, 3)
    }

    // MARK: - Mixed Status Tests

    @MainActor
    func testQueueManager_mixedStatuses() {
        let manager = QueueManager()

        manager.addItem(QueueItem(prompt: "IP", source: .IMAGE_GENERATE, status: .IN_PROGRESS))
        manager.addItem(QueueItem(prompt: "S1", source: .IMAGE_GENERATE, status: .SUCCESSFUL))
        manager.addItem(QueueItem(prompt: "S2", source: .IMAGE_GENERATE, status: .SUCCESSFUL))
        manager.addItem(QueueItem(prompt: "F", source: .IMAGE_GENERATE, status: .FAILED))

        XCTAssertEqual(manager.inProgressItems.count, 1)
        XCTAssertEqual(manager.successfulItems.count, 2)
        XCTAssertEqual(manager.failedItems.count, 1)
        XCTAssertEqual(manager.totalCount, 4)
        XCTAssertTrue(manager.hasActiveItems)
    }
}
