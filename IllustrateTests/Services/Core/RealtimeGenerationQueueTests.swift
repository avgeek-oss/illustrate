// MARK: - RealtimeGenerationQueueTests.swift

// Tests for the RealtimeGenerationQueue actor from RealtimeEditEngine.
//
// RealtimeGenerationQueue is a thread-safe queue with max 2 items:
// one in-progress and one pending. It enforces FPS-based throttling
// and supports pending slot swapping.
//
// Tests cover:
// - Enqueue: empty → inProgress, occupied → pending, swap, throttle
// - Dequeue: from inProgress, pending promotion
// - State management: markInProgressComplete, clear
// - Workflow: full lifecycle, burst scenarios, queue draining

import XCTest
@testable import Illustrate

final class RealtimeGenerationQueueTests: XCTestCase {
    // MARK: - Helpers

    /// Creates a minimal RealtimeEditEngineInput for testing
    private func makeInput(prompt: String = "test", seed: String = "") -> RealtimeEditEngineInput {
        RealtimeEditEngineInput(
            layers: [],
            boundingBox: .zero,
            prompt: prompt,
            providerId: "",
            modelId: "",
            seed: seed,
            dimensions: "1024x1024"
        )
    }

    /// Creates a queue with a very short throttle interval for most tests
    private func makeQueue(intervalMs: Double = 1) -> RealtimeGenerationQueue {
        RealtimeGenerationQueue(minimumEnqueueIntervalMs: intervalMs)
    }

    // MARK: - Enqueue: Empty Queue

    func testEnqueue_EmptyQueue_ReturnsInProgress() async {
        let queue = makeQueue()
        let result = await queue.enqueue(input: makeInput())
        if case let .enqueued(position) = result {
            XCTAssertEqual(position, .inProgress)
        } else {
            XCTFail("Expected .enqueued(.inProgress), got \(result)")
        }
    }

    func testEnqueue_EmptyQueue_HasInProgressBecomesTrue() async {
        let queue = makeQueue()
        _ = await queue.enqueue(input: makeInput())
        let hasIP = await queue.hasInProgress
        XCTAssertTrue(hasIP)
    }

    func testEnqueue_EmptyQueue_HasPendingRemainsFalse() async {
        let queue = makeQueue()
        _ = await queue.enqueue(input: makeInput())
        let hasPend = await queue.hasPending
        XCTAssertFalse(hasPend)
    }

    // MARK: - Enqueue: Occupied Queue

    func testEnqueue_OccupiedInProgress_ReturnsPending() async {
        let queue = makeQueue()
        _ = await queue.enqueue(input: makeInput(prompt: "first"))
        // Small delay to avoid throttle
        try? await Task.sleep(nanoseconds: 2_000_000) // 2ms
        let result = await queue.enqueue(input: makeInput(prompt: "second"))
        if case let .enqueued(position) = result {
            XCTAssertEqual(position, .pending)
        } else {
            XCTFail("Expected .enqueued(.pending), got \(result)")
        }
    }

    func testEnqueue_OccupiedInProgress_HasPendingBecomesTrue() async {
        let queue = makeQueue()
        _ = await queue.enqueue(input: makeInput(prompt: "first"))
        try? await Task.sleep(nanoseconds: 2_000_000)
        _ = await queue.enqueue(input: makeInput(prompt: "second"))
        let hasPend = await queue.hasPending
        XCTAssertTrue(hasPend)
    }

    func testEnqueue_PendingOccupied_ReturnsReplaced() async {
        let queue = makeQueue()
        _ = await queue.enqueue(input: makeInput(prompt: "first"))
        try? await Task.sleep(nanoseconds: 2_000_000)
        _ = await queue.enqueue(input: makeInput(prompt: "second"))
        try? await Task.sleep(nanoseconds: 2_000_000)
        let result = await queue.enqueue(input: makeInput(prompt: "third"))
        if case .replaced = result {
            // Expected
        } else {
            XCTFail("Expected .replaced, got \(result)")
        }
    }

    // MARK: - Enqueue: Throttling

    func testEnqueue_TooSoon_ReturnsThrottled() async {
        let queue = makeQueue(intervalMs: 5000) // 5 seconds
        _ = await queue.enqueue(input: makeInput(prompt: "first"))
        let result = await queue.enqueue(input: makeInput(prompt: "second"))
        if case let .throttled(remainingMs) = result {
            XCTAssertGreaterThan(remainingMs, 0)
            XCTAssertLessThanOrEqual(remainingMs, 5000)
        } else {
            XCTFail("Expected .throttled, got \(result)")
        }
    }

    func testEnqueue_TooSoon_RetainsLatestInputUntilThrottleExpires() async {
        let queue = makeQueue(intervalMs: 20)
        _ = await queue.enqueue(input: makeInput(prompt: "first"))
        _ = await queue.enqueue(input: makeInput(seed: "41"))
        _ = await queue.enqueue(input: makeInput(seed: "42"))

        await queue.markInProgressComplete()

        let deferredItem = await queue.dequeue()
        XCTAssertNil(deferredItem, "Pending input must not start inside the throttle interval")

        try? await Task.sleep(nanoseconds: 30_000_000)

        let retainedItem = await queue.dequeue()
        XCTAssertEqual(retainedItem?.input.seed, "42")
    }

    func testEnqueue_AfterThrottleInterval_Succeeds() async {
        let queue = makeQueue(intervalMs: 1) // 1ms interval
        _ = await queue.enqueue(input: makeInput(prompt: "first"))
        try? await Task.sleep(nanoseconds: 5_000_000) // 5ms — well past 1ms throttle
        let result = await queue.enqueue(input: makeInput(prompt: "second"))
        switch result {
        case .enqueued, .replaced:
            break // Success
        case .throttled:
            XCTFail("Should not be throttled after waiting longer than interval")
        }
    }

    func testSetMinimumInterval_ChangesThrottleBehavior() async {
        let queue = makeQueue(intervalMs: 1) // Start with 1ms
        _ = await queue.enqueue(input: makeInput())
        await queue.setMinimumInterval(5000) // Change to 5 seconds
        let result = await queue.enqueue(input: makeInput())
        if case .throttled = result {
            // Expected — 5 second interval not elapsed
        } else {
            XCTFail("Expected throttled after increasing interval, got \(result)")
        }
    }

    // MARK: - Dequeue

    func testDequeue_EmptyQueue_ReturnsNil() async {
        let queue = makeQueue()
        let item = await queue.dequeue()
        XCTAssertNil(item)
    }

    func testDequeue_WithInProgress_ReturnsItem() async {
        let queue = makeQueue()
        _ = await queue.enqueue(input: makeInput(prompt: "queued"))
        let item = await queue.dequeue()
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.input.prompt, "queued")
    }

    func testDequeue_PromotesPending_WhenInProgressCleared() async {
        let queue = makeQueue()
        _ = await queue.enqueue(input: makeInput(prompt: "first"))
        try? await Task.sleep(nanoseconds: 2_000_000)
        _ = await queue.enqueue(input: makeInput(prompt: "pending"))

        // Clear in-progress
        await queue.markInProgressComplete()

        // Dequeue should promote pending
        let item = await queue.dequeue()
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.input.prompt, "pending")
    }

    func testDequeue_Promotion_ClearsPendingSlot() async {
        let queue = makeQueue()
        _ = await queue.enqueue(input: makeInput(prompt: "first"))
        try? await Task.sleep(nanoseconds: 2_000_000)
        _ = await queue.enqueue(input: makeInput(prompt: "pending"))

        await queue.markInProgressComplete()
        _ = await queue.dequeue() // Promotes pending

        let hasPend = await queue.hasPending
        XCTAssertFalse(hasPend, "Pending slot should be cleared after promotion")
    }

    func testDequeue_AfterPromotion_HasInProgressTrue() async {
        let queue = makeQueue()
        _ = await queue.enqueue(input: makeInput(prompt: "first"))
        try? await Task.sleep(nanoseconds: 2_000_000)
        _ = await queue.enqueue(input: makeInput(prompt: "pending"))

        await queue.markInProgressComplete()
        _ = await queue.dequeue()

        let hasIP = await queue.hasInProgress
        XCTAssertTrue(hasIP)
    }

    // MARK: - State Management

    func testMarkInProgressComplete_ClearsInProgress() async {
        let queue = makeQueue()
        _ = await queue.enqueue(input: makeInput())
        await queue.markInProgressComplete()
        let hasIP = await queue.hasInProgress
        XCTAssertFalse(hasIP)
    }

    func testClear_RemovesBothSlots() async {
        let queue = makeQueue()
        _ = await queue.enqueue(input: makeInput(prompt: "first"))
        try? await Task.sleep(nanoseconds: 2_000_000)
        _ = await queue.enqueue(input: makeInput(prompt: "pending"))

        await queue.clear()

        let hasIP = await queue.hasInProgress
        let hasPend = await queue.hasPending
        XCTAssertFalse(hasIP)
        XCTAssertFalse(hasPend)
    }

    func testClear_ResetsThrottle_NextEnqueueGoesToInProgress() async {
        let queue = makeQueue(intervalMs: 5000) // Long throttle
        _ = await queue.enqueue(input: makeInput())
        await queue.clear()

        // After clear, should be able to enqueue to inProgress without throttle
        let result = await queue.enqueue(input: makeInput())
        if case let .enqueued(position) = result {
            XCTAssertEqual(position, .inProgress)
        } else {
            XCTFail("Expected .enqueued(.inProgress) after clear, got \(result)")
        }
    }

    // MARK: - Workflow Tests

    func testWorkflow_FullLifecycle() async {
        let queue = makeQueue()

        // 1. Enqueue first → inProgress
        let r1 = await queue.enqueue(input: makeInput(prompt: "gen1"))
        if case .enqueued(.inProgress) = r1 {} else { XCTFail("Step 1 failed") }

        // 2. Dequeue → returns gen1
        let item1 = await queue.dequeue()
        XCTAssertEqual(item1?.input.prompt, "gen1")

        // 3. Mark complete
        await queue.markInProgressComplete()
        let hasIP = await queue.hasInProgress
        XCTAssertFalse(hasIP)

        // 4. Enqueue second → inProgress again (wait past throttle interval)
        try? await Task.sleep(nanoseconds: 2_000_000) // 2ms — past 1ms throttle
        let r2 = await queue.enqueue(input: makeInput(prompt: "gen2"))
        if case .enqueued(.inProgress) = r2 {} else { XCTFail("Step 4 failed") }
    }

    func testWorkflow_BurstScenario() async {
        let queue = makeQueue(intervalMs: 1)

        // First enqueue → inProgress
        let r1 = await queue.enqueue(input: makeInput(prompt: "burst1"))
        if case .enqueued(.inProgress) = r1 {} else { XCTFail("First should be inProgress") }

        try? await Task.sleep(nanoseconds: 2_000_000)

        // Second → pending
        let r2 = await queue.enqueue(input: makeInput(prompt: "burst2"))
        if case .enqueued(.pending) = r2 {} else { XCTFail("Second should be pending") }

        try? await Task.sleep(nanoseconds: 2_000_000)

        // Third → replaces pending
        let r3 = await queue.enqueue(input: makeInput(prompt: "burst3"))
        if case .replaced = r3 {} else { XCTFail("Third should replace pending") }
    }

    func testWorkflow_QueueDraining() async {
        let queue = makeQueue()

        // Enqueue two items
        _ = await queue.enqueue(input: makeInput(prompt: "item1"))
        try? await Task.sleep(nanoseconds: 2_000_000)
        _ = await queue.enqueue(input: makeInput(prompt: "item2"))

        // Process first
        _ = await queue.dequeue()
        await queue.markInProgressComplete()

        // Process second (promoted from pending)
        let item2 = await queue.dequeue()
        XCTAssertEqual(item2?.input.prompt, "item2")
        await queue.markInProgressComplete()

        // Queue should be empty
        let finalItem = await queue.dequeue()
        XCTAssertNil(finalItem)
    }

    func testMinimumEnqueueIntervalMs_ReturnsConfiguredValue() async {
        let queue = makeQueue(intervalMs: 500)
        let interval = await queue.minimumEnqueueIntervalMs
        XCTAssertEqual(interval, 500)
    }
}
