// MARK: - StoryboardSceneWorkflowTests.swift

// Workflow tests for StoryboardScene realistic lifecycle scenarios.
//
// StoryboardSceneModelTests covers: backward-compatible decode, icon/color,
// init defaults, Codable round-trip, decode with missing optionals.
//
// This file adds: scene lifecycle transitions, timeline ordering,
// JSON edge cases, frame-based mode workflows, and encode validation.

import XCTest
@testable import Illustrate

final class StoryboardSceneWorkflowTests: XCTestCase {
    // MARK: - Scene Lifecycle Workflow

    func testLifecycle_pendingToGenerating() {
        let scene = StoryboardScene(storyboardId: UUID(), orderIndex: 0, prompt: "test")
        XCTAssertEqual(scene.status, .PENDING)

        scene.status = .GENERATING
        XCTAssertEqual(scene.status, .GENERATING)
    }

    func testLifecycle_generatingToCompleted_withGenerationId() {
        let scene = StoryboardScene(storyboardId: UUID(), orderIndex: 0, prompt: "test")
        scene.status = .GENERATING

        let genId = UUID()
        scene.status = .COMPLETED
        scene.generationId = genId

        XCTAssertEqual(scene.status, .COMPLETED)
        XCTAssertEqual(scene.generationId, genId)
    }

    func testLifecycle_generatingToFailed_withErrorMessage() {
        let scene = StoryboardScene(storyboardId: UUID(), orderIndex: 0, prompt: "test")
        scene.status = .GENERATING

        scene.status = .FAILED
        scene.errorMessage = "API rate limit exceeded"

        XCTAssertEqual(scene.status, .FAILED)
        XCTAssertEqual(scene.errorMessage, "API rate limit exceeded")
    }

    func testLifecycle_fullSuccessPath_encodeDecode() throws {
        let scene = StoryboardScene(storyboardId: UUID(), orderIndex: 0, prompt: "Underwater coral reef")
        scene.status = .GENERATING

        let genId = UUID()
        let queueId = UUID()
        scene.queueItemId = queueId
        scene.status = .COMPLETED
        scene.generationId = genId

        let data = try JSONEncoder().encode(scene)
        let decoded = try JSONDecoder().decode(StoryboardScene.self, from: data)

        XCTAssertEqual(decoded.status, .COMPLETED)
        XCTAssertEqual(decoded.generationId, genId)
        XCTAssertEqual(decoded.queueItemId, queueId)
        XCTAssertEqual(decoded.prompt, "Underwater coral reef")
    }

    func testLifecycle_failedWithError_encodeDecode() throws {
        let scene = StoryboardScene(storyboardId: UUID(), orderIndex: 0, prompt: "test")
        scene.status = .FAILED
        scene.errorMessage = "Content policy violation"

        let data = try JSONEncoder().encode(scene)
        let decoded = try JSONDecoder().decode(StoryboardScene.self, from: data)

        XCTAssertEqual(decoded.status, .FAILED)
        XCTAssertEqual(decoded.errorMessage, "Content policy violation")
    }

    // MARK: - Scene Timeline Ordering

    func testTimeline_sortByOrderIndex_producesCorrectOrder() {
        let storyboardId = UUID()
        let scene0 = StoryboardScene(storyboardId: storyboardId, orderIndex: 2, prompt: "Third")
        let scene1 = StoryboardScene(storyboardId: storyboardId, orderIndex: 0, prompt: "First")
        let scene2 = StoryboardScene(storyboardId: storyboardId, orderIndex: 1, prompt: "Second")

        let sorted = [scene0, scene1, scene2].sorted { $0.orderIndex < $1.orderIndex }

        XCTAssertEqual(sorted[0].prompt, "First")
        XCTAssertEqual(sorted[1].prompt, "Second")
        XCTAssertEqual(sorted[2].prompt, "Third")
    }

    func testTimeline_filterByStoryboardId() {
        let storyboardA = UUID()
        let storyboardB = UUID()
        let sceneA1 = StoryboardScene(storyboardId: storyboardA, orderIndex: 0)
        let sceneB1 = StoryboardScene(storyboardId: storyboardB, orderIndex: 0)
        let sceneA2 = StoryboardScene(storyboardId: storyboardA, orderIndex: 1)

        let filtered = [sceneA1, sceneB1, sceneA2].filter { $0.storyboardId == storyboardA }
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.storyboardId == storyboardA })
    }

    func testTimeline_multipleScenesWithDifferentStatuses() {
        let storyboardId = UUID()
        let scenes = (0 ..< 4).map { StoryboardScene(storyboardId: storyboardId, orderIndex: $0) }
        scenes[0].status = .COMPLETED
        scenes[0].generationId = UUID()
        scenes[1].status = .COMPLETED
        scenes[1].generationId = UUID()
        scenes[2].status = .GENERATING
        scenes[3].status = .PENDING

        let completed = scenes.filter { $0.status == .COMPLETED }
        XCTAssertEqual(completed.count, 2)

        let pending = scenes.filter { $0.status == .PENDING }
        XCTAssertEqual(pending.count, 1)
    }

    func testTimeline_completedScenesHaveGenerationIds() {
        let scene = StoryboardScene(storyboardId: UUID(), orderIndex: 0)
        scene.status = .COMPLETED
        scene.generationId = UUID()

        XCTAssertNotNil(scene.generationId)
    }

    func testTimeline_allCompleted_boolCheck() {
        let storyboardId = UUID()
        let scenes = (0 ..< 3).map { StoryboardScene(storyboardId: storyboardId, orderIndex: $0) }
        for scene in scenes {
            scene.status = .COMPLETED
            scene.generationId = UUID()
        }

        XCTAssertTrue(scenes.allSatisfy { $0.status == .COMPLETED })
    }

    // MARK: - Scene JSON Edge Cases

    func testDecode_extraUnknownKeys_succeeds() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "storyboardId": UUID().uuidString,
            "orderIndex": 0,
            "prompt": "test",
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "unknownField": "should be ignored",
            "anotherUnknown": 42,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(StoryboardScene.self, from: data)
        XCTAssertEqual(decoded.prompt, "test")
    }

    func testDecode_missingRequiredField_id_throws() {
        let json: [String: Any] = [
            "storyboardId": UUID().uuidString,
            "orderIndex": 0,
            "prompt": "test",
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        XCTAssertThrowsError(try {
            let data = try JSONSerialization.data(withJSONObject: json)
            _ = try JSONDecoder().decode(StoryboardScene.self, from: data)
        }())
    }

    func testDecode_missingRequiredField_storyboardId_throws() {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "orderIndex": 0,
            "prompt": "test",
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        XCTAssertThrowsError(try {
            let data = try JSONSerialization.data(withJSONObject: json)
            _ = try JSONDecoder().decode(StoryboardScene.self, from: data)
        }())
    }

    func testDecode_missingRequiredField_orderIndex_throws() {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "storyboardId": UUID().uuidString,
            "prompt": "test",
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        XCTAssertThrowsError(try {
            let data = try JSONSerialization.data(withJSONObject: json)
            _ = try JSONDecoder().decode(StoryboardScene.self, from: data)
        }())
    }

    func testDecode_missingRequiredField_prompt_throws() {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "storyboardId": UUID().uuidString,
            "orderIndex": 0,
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        XCTAssertThrowsError(try {
            let data = try JSONSerialization.data(withJSONObject: json)
            _ = try JSONDecoder().decode(StoryboardScene.self, from: data)
        }())
    }

    func testEncode_producesValidJSON() throws {
        let scene = StoryboardScene(storyboardId: UUID(), orderIndex: 0, prompt: "test")
        let data = try JSONEncoder().encode(scene)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(jsonObject is [String: Any])
    }

    func testEncode_statusEncodesAsRawValue() throws {
        let scene = StoryboardScene(storyboardId: UUID(), orderIndex: 0)
        scene.status = .GENERATING

        let data = try JSONEncoder().encode(scene)
        let jsonDict = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(jsonDict["status"] as? String, "GENERATING")
    }

    func testEncodeDecodeArray_preservesOrder() throws {
        let storyboardId = UUID()
        let scenes = (0 ..< 5).map {
            StoryboardScene(storyboardId: storyboardId, orderIndex: $0, prompt: "Scene \($0)")
        }

        let data = try JSONEncoder().encode(scenes)
        let decoded = try JSONDecoder().decode([StoryboardScene].self, from: data)

        XCTAssertEqual(decoded.count, 5)
        for i in 0 ..< 5 {
            XCTAssertEqual(decoded[i].orderIndex, i)
            XCTAssertEqual(decoded[i].prompt, "Scene \(i)")
        }
    }

    // MARK: - Frame-Based Mode Workflow

    func testFrameMode_firstFrameOnly() throws {
        let firstFrame = UUID()
        let scene = StoryboardScene(
            storyboardId: UUID(),
            orderIndex: 0,
            firstFrameAssetId: firstFrame
        )

        let data = try JSONEncoder().encode(scene)
        let decoded = try JSONDecoder().decode(StoryboardScene.self, from: data)

        XCTAssertEqual(decoded.firstFrameAssetId, firstFrame)
        XCTAssertNil(decoded.lastFrameAssetId)
    }

    func testFrameMode_bothFrames() throws {
        let firstFrame = UUID()
        let lastFrame = UUID()
        let scene = StoryboardScene(
            storyboardId: UUID(),
            orderIndex: 0,
            firstFrameAssetId: firstFrame,
            lastFrameAssetId: lastFrame
        )

        let data = try JSONEncoder().encode(scene)
        let decoded = try JSONDecoder().decode(StoryboardScene.self, from: data)

        XCTAssertEqual(decoded.firstFrameAssetId, firstFrame)
        XCTAssertEqual(decoded.lastFrameAssetId, lastFrame)
    }

    func testFrameMode_clearFrameAssets() throws {
        let scene = StoryboardScene(
            storyboardId: UUID(),
            orderIndex: 0,
            firstFrameAssetId: UUID(),
            lastFrameAssetId: UUID()
        )
        scene.firstFrameAssetId = nil
        scene.lastFrameAssetId = nil

        let data = try JSONEncoder().encode(scene)
        let decoded = try JSONDecoder().decode(StoryboardScene.self, from: data)

        XCTAssertNil(decoded.firstFrameAssetId)
        XCTAssertNil(decoded.lastFrameAssetId)
    }

    // MARK: - Field Mutation

    func testMutateGenerationId_setAndClear() {
        let scene = StoryboardScene(storyboardId: UUID(), orderIndex: 0)
        XCTAssertNil(scene.generationId)

        let genId = UUID()
        scene.generationId = genId
        XCTAssertEqual(scene.generationId, genId)

        scene.generationId = nil
        XCTAssertNil(scene.generationId)
    }

    func testMutateErrorMessage_setAndClear() {
        let scene = StoryboardScene(storyboardId: UUID(), orderIndex: 0)
        XCTAssertNil(scene.errorMessage)

        scene.errorMessage = "Error occurred"
        XCTAssertEqual(scene.errorMessage, "Error occurred")

        scene.errorMessage = nil
        XCTAssertNil(scene.errorMessage)
    }

    func testMutateStatus_allTransitions() {
        let scene = StoryboardScene(storyboardId: UUID(), orderIndex: 0)
        let allStatuses: [StoryboardSceneStatus] = [.PENDING, .GENERATING, .COMPLETED, .FAILED]

        for status in allStatuses {
            scene.status = status
            XCTAssertEqual(scene.status, status)
        }
    }

    func testSpecialCharactersInPrompt_preserved() throws {
        let prompt = "画面中有一个美丽的日落 🌅\nWith \"quotes\" & <brackets>"
        let scene = StoryboardScene(storyboardId: UUID(), orderIndex: 0, prompt: prompt)

        let data = try JSONEncoder().encode(scene)
        let decoded = try JSONDecoder().decode(StoryboardScene.self, from: data)

        XCTAssertEqual(decoded.prompt, prompt)
    }
}
