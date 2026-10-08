// MARK: - QueueManagerWorkflowTests.swift

// Workflow tests for QueueManager observable operations.
//
// Tests cover:
// - QueueItemStatus and QueueItemSource enum properties
// - shouldAutoRemoveOnSuccess for all QueueItemSource cases
// - QueueManager updateItemStatus, clearAllFailed, clearAllCompleted, cancelItem
// - Edge cases for queue manipulation

import XCTest
@testable import Illustrate

@MainActor
final class QueueManagerWorkflowTests: XCTestCase {
    private var manager: QueueManager!

    override func setUp() async throws {
        try await super.setUp()
        manager = QueueManager()
    }

    override func tearDown() async throws {
        manager = nil
        try await super.tearDown()
    }

    // MARK: - QueueItemStatus Enum Tests

    func testQueueItemStatus_AllRawValues() {
        XCTAssertEqual(QueueItemStatus.IN_PROGRESS.rawValue, "IN_PROGRESS")
        XCTAssertEqual(QueueItemStatus.SUCCESSFUL.rawValue, "SUCCESSFUL")
        XCTAssertEqual(QueueItemStatus.FAILED.rawValue, "FAILED")
    }

    // MARK: - QueueItemSource Enum Tests

    func testQueueItemSource_AllCasesExist() {
        let sources: [QueueItemSource] = [
            .IMAGE_GENERATE, .VIDEO_GENERATE, .CHAT_THREADS,
            .FLOW_CANVAS, .BULK_GENERATE, .STORYBOARD,
            .CREATIVE_STUDIO, .PRODUCT_PHOTOSHOOTS, .AGENT_BUILDER,
        ]
        XCTAssertEqual(sources.count, 9)
    }

    // MARK: - shouldAutoRemoveOnSuccess Tests

    func testShouldAutoRemoveOnSuccess_ImageGenerate_ReturnsFalse() {
        XCTAssertFalse(QueueItemSource.IMAGE_GENERATE.shouldAutoRemoveOnSuccess)
    }

    func testShouldAutoRemoveOnSuccess_VideoGenerate_ReturnsFalse() {
        XCTAssertFalse(QueueItemSource.VIDEO_GENERATE.shouldAutoRemoveOnSuccess)
    }

    func testShouldAutoRemoveOnSuccess_ChatThreads_ReturnsTrue() {
        XCTAssertTrue(QueueItemSource.CHAT_THREADS.shouldAutoRemoveOnSuccess)
    }

    func testShouldAutoRemoveOnSuccess_AllAutoRemoveSources_ReturnTrue() {
        let autoRemoveSources: [QueueItemSource] = [
            .CHAT_THREADS, .FLOW_CANVAS, .BULK_GENERATE,
            .STORYBOARD, .CREATIVE_STUDIO, .PRODUCT_PHOTOSHOOTS,
            .AGENT_BUILDER,
        ]

        for source in autoRemoveSources {
            XCTAssertTrue(
                source.shouldAutoRemoveOnSuccess,
                "\(source.rawValue) should auto-remove on success"
            )
        }
    }

    // MARK: - QueueManager updateItemStatus Tests

    func testUpdateItemStatus_SetsStatusAndResults() {
        let item = QueueItem(prompt: "Update test", source: .IMAGE_GENERATE)
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

    func testUpdateItemStatus_NonExistentId_NoEffect() {
        let item = QueueItem(prompt: "Keep", source: .IMAGE_GENERATE)
        manager.addItem(item)

        manager.updateItemStatus(UUID(), status: .FAILED, errorMessage: "Error")

        XCTAssertEqual(item.status, .IN_PROGRESS)
        XCTAssertNil(item.errorMessage)
    }

    // MARK: - QueueManager clearAllFailed Tests

    func testClearAllFailed_RemovesOnlyFailed() {
        let successItem = QueueItem(prompt: "S", source: .IMAGE_GENERATE, status: .SUCCESSFUL)
        let failedItem = QueueItem(prompt: "F", source: .IMAGE_GENERATE, status: .FAILED)
        let inProgressItem = QueueItem(prompt: "IP", source: .IMAGE_GENERATE, status: .IN_PROGRESS)

        manager.addItem(successItem)
        manager.addItem(failedItem)
        manager.addItem(inProgressItem)
        XCTAssertEqual(manager.items.count, 3)

        manager.clearAllFailed()

        XCTAssertEqual(manager.items.count, 2)
        XCTAssertFalse(manager.items.contains { $0.status == .FAILED })
        XCTAssertTrue(manager.items.contains { $0.status == .SUCCESSFUL })
        XCTAssertTrue(manager.items.contains { $0.status == .IN_PROGRESS })
    }

    // MARK: - QueueManager clearAllCompleted Tests

    func testClearAllCompleted_RemovesOnlySuccessful() {
        let s1 = QueueItem(prompt: "S1", source: .IMAGE_GENERATE, status: .SUCCESSFUL)
        let s2 = QueueItem(prompt: "S2", source: .VIDEO_GENERATE, status: .SUCCESSFUL)
        let f1 = QueueItem(prompt: "F1", source: .IMAGE_GENERATE, status: .FAILED)

        manager.addItem(s1)
        manager.addItem(s2)
        manager.addItem(f1)

        manager.clearAllCompleted()

        XCTAssertEqual(manager.items.count, 1)
        XCTAssertFalse(manager.items.contains { $0.status == .SUCCESSFUL })
    }

    // MARK: - QueueManager cancelItem Tests

    func testCancelItem_SetsFailedAndMessage() {
        let item = QueueItem(prompt: "Cancel me", source: .IMAGE_GENERATE)
        manager.addItem(item)

        manager.cancelItem(item)

        XCTAssertEqual(item.status, .FAILED)
        XCTAssertEqual(item.errorMessage, "Cancelled by user")
    }

    func testCancelItemById_SetsFailedStatus() {
        let item = QueueItem(prompt: "Cancel by ID", source: .VIDEO_GENERATE)
        manager.addItem(item)

        manager.cancelItem(by: item.id)

        XCTAssertEqual(item.status, .FAILED)
    }

    func testCancelItemById_NonExistentId_NoEffect() {
        let item = QueueItem(prompt: "Stay alive", source: .IMAGE_GENERATE)
        manager.addItem(item)

        manager.cancelItem(by: UUID())

        XCTAssertEqual(item.status, .IN_PROGRESS)
    }
}
