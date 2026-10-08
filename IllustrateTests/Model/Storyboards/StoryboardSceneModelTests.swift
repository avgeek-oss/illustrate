// MARK: - StoryboardSceneModelTests.swift

// Tests for StoryboardScene model and StoryboardSceneStatus enum.
//
// Covers:
// - StoryboardSceneStatus backward-compatible decoding (uppercase + lowercase)
// - StoryboardSceneStatus computed properties (icon, color)
// - StoryboardSceneStatus metadata (allCases, Identifiable)
// - StoryboardScene initialization and defaults
// - StoryboardScene Codable round-trip
// - StoryboardScene decode with missing optional fields

import SwiftUI
import XCTest
@testable import Illustrate

final class StoryboardSceneModelTests: XCTestCase {
    // MARK: - StoryboardSceneStatus Backward-Compatible Decoding

    func testStatus_decode_lowercasePending() throws {
        let decoded = try JSONDecoder().decode(
            StoryboardSceneStatus.self,
            from: Data("\"pending\"".utf8)
        )
        XCTAssertEqual(decoded, .PENDING)
    }

    func testStatus_decode_uppercasePending() throws {
        let decoded = try JSONDecoder().decode(
            StoryboardSceneStatus.self,
            from: Data("\"PENDING\"".utf8)
        )
        XCTAssertEqual(decoded, .PENDING)
    }

    func testStatus_decode_lowercaseGenerating() throws {
        let decoded = try JSONDecoder().decode(
            StoryboardSceneStatus.self,
            from: Data("\"generating\"".utf8)
        )
        XCTAssertEqual(decoded, .GENERATING)
    }

    func testStatus_decode_uppercaseGenerating() throws {
        let decoded = try JSONDecoder().decode(
            StoryboardSceneStatus.self,
            from: Data("\"GENERATING\"".utf8)
        )
        XCTAssertEqual(decoded, .GENERATING)
    }

    func testStatus_decode_lowercaseCompleted() throws {
        let decoded = try JSONDecoder().decode(
            StoryboardSceneStatus.self,
            from: Data("\"completed\"".utf8)
        )
        XCTAssertEqual(decoded, .COMPLETED)
    }

    func testStatus_decode_uppercaseCompleted() throws {
        let decoded = try JSONDecoder().decode(
            StoryboardSceneStatus.self,
            from: Data("\"COMPLETED\"".utf8)
        )
        XCTAssertEqual(decoded, .COMPLETED)
    }

    func testStatus_decode_lowercaseFailed() throws {
        let decoded = try JSONDecoder().decode(
            StoryboardSceneStatus.self,
            from: Data("\"failed\"".utf8)
        )
        XCTAssertEqual(decoded, .FAILED)
    }

    func testStatus_decode_uppercaseFailed() throws {
        let decoded = try JSONDecoder().decode(
            StoryboardSceneStatus.self,
            from: Data("\"FAILED\"".utf8)
        )
        XCTAssertEqual(decoded, .FAILED)
    }

    func testStatus_decode_unknownValue_throws() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                StoryboardSceneStatus.self,
                from: Data("\"unknown\"".utf8)
            )
        )
    }

    func testStatus_decode_emptyString_throws() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                StoryboardSceneStatus.self,
                from: Data("\"\"".utf8)
            )
        )
    }

    // MARK: - StoryboardSceneStatus Computed Properties

    func testStatus_icon_pending() {
        XCTAssertEqual(StoryboardSceneStatus.PENDING.icon, "clock")
    }

    func testStatus_icon_generating() {
        XCTAssertEqual(StoryboardSceneStatus.GENERATING.icon, "arrow.trianglehead.2.clockwise")
    }

    func testStatus_icon_completed() {
        XCTAssertEqual(StoryboardSceneStatus.COMPLETED.icon, "checkmark.circle.fill")
    }

    func testStatus_icon_failed() {
        XCTAssertEqual(StoryboardSceneStatus.FAILED.icon, "exclamationmark.triangle.fill")
    }

    func testStatus_color_pending() {
        XCTAssertEqual(StoryboardSceneStatus.PENDING.color, Color.secondary)
    }

    func testStatus_color_generating() {
        XCTAssertEqual(StoryboardSceneStatus.GENERATING.color, Color.blue)
    }

    func testStatus_color_completed() {
        XCTAssertEqual(StoryboardSceneStatus.COMPLETED.color, Color.green)
    }

    func testStatus_color_failed() {
        XCTAssertEqual(StoryboardSceneStatus.FAILED.color, Color.red)
    }

    // MARK: - StoryboardSceneStatus Metadata

    func testStatus_allCases_countIsFour() {
        XCTAssertEqual(StoryboardSceneStatus.allCases.count, 4)
    }

    func testStatus_identifiable_idMatchesRawValue() {
        for status in StoryboardSceneStatus.allCases {
            XCTAssertEqual(status.id, status.rawValue)
        }
    }

    func testStatus_rawValues() {
        XCTAssertEqual(StoryboardSceneStatus.PENDING.rawValue, "PENDING")
        XCTAssertEqual(StoryboardSceneStatus.GENERATING.rawValue, "GENERATING")
        XCTAssertEqual(StoryboardSceneStatus.COMPLETED.rawValue, "COMPLETED")
        XCTAssertEqual(StoryboardSceneStatus.FAILED.rawValue, "FAILED")
    }

    func testStatus_encodeDecode_allCases() throws {
        for status in StoryboardSceneStatus.allCases {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(StoryboardSceneStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }

    // MARK: - StoryboardScene Initialization

    func testInit_setsStoryboardId() {
        let storyboardId = UUID()
        let scene = StoryboardScene(storyboardId: storyboardId, orderIndex: 0)
        XCTAssertEqual(scene.storyboardId, storyboardId)
    }

    func testInit_setsOrderIndex() {
        let scene = StoryboardScene(storyboardId: UUID(), orderIndex: 3)
        XCTAssertEqual(scene.orderIndex, 3)
    }

    func testInit_defaultPromptIsEmpty() {
        let scene = StoryboardScene(storyboardId: UUID(), orderIndex: 0)
        XCTAssertEqual(scene.prompt, "")
    }

    func testInit_defaultStatusIsPending() {
        let scene = StoryboardScene(storyboardId: UUID(), orderIndex: 0)
        XCTAssertEqual(scene.status, .PENDING)
    }

    func testInit_optionalFieldsAreNil() {
        let scene = StoryboardScene(storyboardId: UUID(), orderIndex: 0)
        XCTAssertNil(scene.generationId)
        XCTAssertNil(scene.queueItemId)
        XCTAssertNil(scene.errorMessage)
        XCTAssertNil(scene.firstFrameAssetId)
        XCTAssertNil(scene.lastFrameAssetId)
    }

    func testInit_customPromptAndNegativePrompt() {
        let scene = StoryboardScene(
            storyboardId: UUID(),
            orderIndex: 1,
            prompt: "A sunset over the ocean",
            negativePrompt: "No people"
        )
        XCTAssertEqual(scene.prompt, "A sunset over the ocean")
        XCTAssertEqual(scene.negativePrompt, "No people")
    }

    func testInit_frameAssetIds() {
        let firstFrame = UUID()
        let lastFrame = UUID()
        let scene = StoryboardScene(
            storyboardId: UUID(),
            orderIndex: 0,
            firstFrameAssetId: firstFrame,
            lastFrameAssetId: lastFrame
        )
        XCTAssertEqual(scene.firstFrameAssetId, firstFrame)
        XCTAssertEqual(scene.lastFrameAssetId, lastFrame)
    }

    func testInit_createdAtIsSet() {
        let before = Date()
        let scene = StoryboardScene(storyboardId: UUID(), orderIndex: 0)
        let after = Date()
        XCTAssertGreaterThanOrEqual(scene.createdAt, before)
        XCTAssertLessThanOrEqual(scene.createdAt, after)
    }

    func testInit_idIsUnique() {
        let s1 = StoryboardScene(storyboardId: UUID(), orderIndex: 0)
        let s2 = StoryboardScene(storyboardId: UUID(), orderIndex: 0)
        XCTAssertNotEqual(s1.id, s2.id)
    }

    // MARK: - StoryboardScene Codable Round-Trip

    func testCodableRoundTrip_allFields() throws {
        let storyboardId = UUID()
        let genId = UUID()
        let queueId = UUID()
        let firstFrame = UUID()
        let lastFrame = UUID()

        let scene = StoryboardScene(
            storyboardId: storyboardId,
            orderIndex: 2,
            prompt: "A spaceship launching",
            negativePrompt: "No smoke",
            firstFrameAssetId: firstFrame,
            lastFrameAssetId: lastFrame
        )
        scene.status = .COMPLETED
        scene.generationId = genId
        scene.queueItemId = queueId
        scene.errorMessage = nil

        let data = try JSONEncoder().encode(scene)
        let decoded = try JSONDecoder().decode(StoryboardScene.self, from: data)

        XCTAssertEqual(decoded.id, scene.id)
        XCTAssertEqual(decoded.storyboardId, storyboardId)
        XCTAssertEqual(decoded.orderIndex, 2)
        XCTAssertEqual(decoded.prompt, "A spaceship launching")
        XCTAssertEqual(decoded.negativePrompt, "No smoke")
        XCTAssertEqual(decoded.status, .COMPLETED)
        XCTAssertEqual(decoded.generationId, genId)
        XCTAssertEqual(decoded.queueItemId, queueId)
        XCTAssertNil(decoded.errorMessage)
        XCTAssertEqual(decoded.firstFrameAssetId, firstFrame)
        XCTAssertEqual(decoded.lastFrameAssetId, lastFrame)
    }

    func testCodableRoundTrip_minimalFields() throws {
        let scene = StoryboardScene(storyboardId: UUID(), orderIndex: 0)

        let data = try JSONEncoder().encode(scene)
        let decoded = try JSONDecoder().decode(StoryboardScene.self, from: data)

        XCTAssertEqual(decoded.id, scene.id)
        XCTAssertEqual(decoded.orderIndex, 0)
        XCTAssertEqual(decoded.prompt, "")
        XCTAssertNil(decoded.negativePrompt)
        XCTAssertEqual(decoded.status, .PENDING)
        XCTAssertNil(decoded.generationId)
    }

    func testCodableRoundTrip_withFrameAssets() throws {
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

    func testCodableRoundTrip_failedWithError() throws {
        let scene = StoryboardScene(storyboardId: UUID(), orderIndex: 0, prompt: "test")
        scene.status = .FAILED
        scene.errorMessage = "Rate limit exceeded"

        let data = try JSONEncoder().encode(scene)
        let decoded = try JSONDecoder().decode(StoryboardScene.self, from: data)

        XCTAssertEqual(decoded.status, .FAILED)
        XCTAssertEqual(decoded.errorMessage, "Rate limit exceeded")
    }

    func testCodableRoundTrip_multipleRoundTrips_stable() throws {
        let scene = StoryboardScene(storyboardId: UUID(), orderIndex: 5, prompt: "Mountains")
        scene.status = .GENERATING

        var current = scene
        for _ in 0 ..< 3 {
            let data = try JSONEncoder().encode(current)
            current = try JSONDecoder().decode(StoryboardScene.self, from: data)
        }

        XCTAssertEqual(current.id, scene.id)
        XCTAssertEqual(current.orderIndex, 5)
        XCTAssertEqual(current.prompt, "Mountains")
        XCTAssertEqual(current.status, .GENERATING)
    }

    // MARK: - StoryboardScene Decode with Missing Optionals

    func testDecode_missingNegativePrompt_defaultsToNil() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "storyboardId": UUID().uuidString,
            "orderIndex": 0,
            "prompt": "test",
            "status": "PENDING",
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(StoryboardScene.self, from: data)
        XCTAssertNil(decoded.negativePrompt)
    }

    func testDecode_missingStatus_defaultsToPending() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "storyboardId": UUID().uuidString,
            "orderIndex": 0,
            "prompt": "test",
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(StoryboardScene.self, from: data)
        XCTAssertEqual(decoded.status, .PENDING)
    }

    func testDecode_missingCreatedAt_defaultsToDate() throws {
        let before = Date()
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "storyboardId": UUID().uuidString,
            "orderIndex": 0,
            "prompt": "test",
            "status": "PENDING",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(StoryboardScene.self, from: data)
        let after = Date()
        XCTAssertGreaterThanOrEqual(decoded.createdAt, before)
        XCTAssertLessThanOrEqual(decoded.createdAt, after)
    }

    func testDecode_missingGenerationId_defaultsToNil() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "storyboardId": UUID().uuidString,
            "orderIndex": 0,
            "prompt": "test",
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(StoryboardScene.self, from: data)
        XCTAssertNil(decoded.generationId)
    }

    func testDecode_missingQueueItemId_defaultsToNil() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "storyboardId": UUID().uuidString,
            "orderIndex": 0,
            "prompt": "test",
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(StoryboardScene.self, from: data)
        XCTAssertNil(decoded.queueItemId)
    }

    func testDecode_missingErrorMessage_defaultsToNil() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "storyboardId": UUID().uuidString,
            "orderIndex": 0,
            "prompt": "test",
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(StoryboardScene.self, from: data)
        XCTAssertNil(decoded.errorMessage)
    }

    func testDecode_missingFrameAssetIds_defaultsToNil() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "storyboardId": UUID().uuidString,
            "orderIndex": 0,
            "prompt": "test",
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(StoryboardScene.self, from: data)
        XCTAssertNil(decoded.firstFrameAssetId)
        XCTAssertNil(decoded.lastFrameAssetId)
    }

    func testDecode_missingAllOptionals_allDefaults() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "storyboardId": UUID().uuidString,
            "orderIndex": 0,
            "prompt": "test",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(StoryboardScene.self, from: data)

        XCTAssertNil(decoded.negativePrompt)
        XCTAssertEqual(decoded.status, .PENDING)
        XCTAssertNil(decoded.generationId)
        XCTAssertNil(decoded.queueItemId)
        XCTAssertNil(decoded.errorMessage)
        XCTAssertNil(decoded.firstFrameAssetId)
        XCTAssertNil(decoded.lastFrameAssetId)
    }
}
