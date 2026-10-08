// MARK: - RealtimeEditEngineTypesTests.swift

// Tests for RealtimeEditEngine supporting types:
// RealtimeQueueItem, RealtimeEditEngineInput, and RealtimeEditEngineState.
// These value types are testable without MainActor/SwiftData dependencies.

import XCTest
@testable import Illustrate

final class RealtimeEditEngineTypesTests: XCTestCase {
    // MARK: - Helpers

    private func makeInput(prompt: String = "test prompt") -> RealtimeEditEngineInput {
        RealtimeEditEngineInput(
            layers: [],
            boundingBox: CGRect(x: 0, y: 0, width: 512, height: 512),
            prompt: prompt,
            providerId: "provider-123",
            modelId: "model-456",
            seed: "",
            dimensions: "1024x1024"
        )
    }

    // MARK: - RealtimeQueueItem

    func testQueueItem_IdIsUnique() {
        let input = makeInput()
        let item1 = RealtimeQueueItem(input: input)
        let item2 = RealtimeQueueItem(input: input)
        XCTAssertNotEqual(item1.id, item2.id)
    }

    func testQueueItem_EnqueuedAtIsSet() {
        let before = Date()
        let item = RealtimeQueueItem(input: makeInput())
        let after = Date()
        XCTAssertGreaterThanOrEqual(item.enqueuedAt, before)
        XCTAssertLessThanOrEqual(item.enqueuedAt, after)
    }

    func testQueueItem_StoresInputReference() {
        let input = makeInput(prompt: "my prompt")
        let item = RealtimeQueueItem(input: input)
        XCTAssertEqual(item.input.prompt, "my prompt")
    }

    func testQueueItem_EnqueuedAtIsReasonable() {
        let item = RealtimeQueueItem(input: makeInput())
        let elapsed = Date().timeIntervalSince(item.enqueuedAt)
        XCTAssertLessThan(elapsed, 1.0, "enqueuedAt should be within the last second")
    }

    func testQueueItem_Identifiable() {
        let item = RealtimeQueueItem(input: makeInput())
        XCTAssertFalse(item.id.uuidString.isEmpty)
    }

    // MARK: - RealtimeEditEngineInput

    func testInput_StoresAllFields() {
        let layers = [RealtimeEditLayer(sessionId: UUID(), layerType: .image)]
        let bbox = CGRect(x: 10, y: 20, width: 300, height: 400)
        let input = RealtimeEditEngineInput(
            layers: layers,
            boundingBox: bbox,
            prompt: "sunset",
            providerId: "prov-id",
            modelId: "model-id",
            seed: "42",
            dimensions: "512x512"
        )

        XCTAssertEqual(input.layers.count, 1)
        XCTAssertEqual(input.boundingBox, bbox)
        XCTAssertEqual(input.prompt, "sunset")
        XCTAssertEqual(input.providerId, "prov-id")
        XCTAssertEqual(input.modelId, "model-id")
        XCTAssertEqual(input.seed, "42")
        XCTAssertEqual(input.dimensions, "512x512")
    }

    func testInput_EmptyLayers() {
        let input = makeInput()
        XCTAssertTrue(input.layers.isEmpty)
    }

    func testInput_NonZeroBoundingBox() {
        let input = RealtimeEditEngineInput(
            layers: [],
            boundingBox: CGRect(x: 100, y: 200, width: 1024, height: 768),
            prompt: "",
            providerId: "",
            modelId: "",
            seed: "",
            dimensions: ""
        )
        XCTAssertEqual(input.boundingBox.origin.x, 100)
        XCTAssertEqual(input.boundingBox.origin.y, 200)
        XCTAssertEqual(input.boundingBox.size.width, 1024)
        XCTAssertEqual(input.boundingBox.size.height, 768)
    }

    func testInput_StringFieldsPreserved() {
        let input = RealtimeEditEngineInput(
            layers: [],
            boundingBox: .zero,
            prompt: "A beautiful landscape with 日本語",
            providerId: "provider-with-special-chars",
            modelId: "model/v2.1",
            seed: "12345",
            dimensions: "1920x1080"
        )
        XCTAssertEqual(input.prompt, "A beautiful landscape with 日本語")
        XCTAssertEqual(input.providerId, "provider-with-special-chars")
        XCTAssertEqual(input.modelId, "model/v2.1")
        XCTAssertEqual(input.seed, "12345")
        XCTAssertEqual(input.dimensions, "1920x1080")
    }

    func testInput_EmptySeed() {
        let input = makeInput()
        XCTAssertEqual(input.seed, "")
    }

    // MARK: - RealtimeEditEngineState Equatable

    func testState_IdleEqualsIdle() {
        XCTAssertEqual(RealtimeEditEngineState.idle, RealtimeEditEngineState.idle)
    }

    func testState_GeneratingEqualsGenerating() {
        XCTAssertEqual(RealtimeEditEngineState.generating, RealtimeEditEngineState.generating)
    }

    func testState_GeneratingWithPendingEquals() {
        XCTAssertEqual(
            RealtimeEditEngineState.generatingWithPending,
            RealtimeEditEngineState.generatingWithPending
        )
    }

    func testState_ErrorSameMessage_Equal() {
        XCTAssertEqual(
            RealtimeEditEngineState.error("timeout"),
            RealtimeEditEngineState.error("timeout")
        )
    }

    func testState_ErrorDifferentMessage_NotEqual() {
        XCTAssertNotEqual(
            RealtimeEditEngineState.error("a"),
            RealtimeEditEngineState.error("b")
        )
    }

    func testState_IdleNotEqualToGenerating() {
        XCTAssertNotEqual(RealtimeEditEngineState.idle, RealtimeEditEngineState.generating)
    }

    func testState_GeneratingNotEqualToGeneratingWithPending() {
        XCTAssertNotEqual(
            RealtimeEditEngineState.generating,
            RealtimeEditEngineState.generatingWithPending
        )
    }

    func testState_ErrorNotEqualToIdle() {
        XCTAssertNotEqual(RealtimeEditEngineState.error("e"), RealtimeEditEngineState.idle)
    }

    // MARK: - RealtimeEditEngineState Pattern Matching

    func testState_PatternMatching_AllCases() {
        let states: [RealtimeEditEngineState] = [
            .idle, .generating, .generatingWithPending, .error("test"),
        ]
        var idleCount = 0, genCount = 0, genPendCount = 0, errCount = 0

        for state in states {
            switch state {
            case .idle: idleCount += 1
            case .generating: genCount += 1
            case .generatingWithPending: genPendCount += 1
            case .error: errCount += 1
            }
        }

        XCTAssertEqual(idleCount, 1)
        XCTAssertEqual(genCount, 1)
        XCTAssertEqual(genPendCount, 1)
        XCTAssertEqual(errCount, 1)
    }

    func testState_ErrorExtracts_AssociatedValue() {
        let state = RealtimeEditEngineState.error("Network timeout")
        if case let .error(message) = state {
            XCTAssertEqual(message, "Network timeout")
        } else {
            XCTFail("Expected .error case")
        }
    }

    // MARK: - All States Distinguishable

    func testState_AllDistinguishable() {
        let states: [RealtimeEditEngineState] = [
            .idle, .generating, .generatingWithPending, .error("e"),
        ]
        for i in 0 ..< states.count {
            for j in (i + 1) ..< states.count {
                XCTAssertNotEqual(states[i], states[j])
            }
        }
    }
}
