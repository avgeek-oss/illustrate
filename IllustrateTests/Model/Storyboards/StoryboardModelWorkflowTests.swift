// MARK: - StoryboardModelWorkflowTests.swift

// Workflow tests for Storyboard and StoryboardScene models.
//
// Tests cover:
// - StoryboardMode enum: raw values, backward-compatible decoding,
//   displayName, description, icon
// - Storyboard defaults, custom init, Codable round-trip,
//   decodeIfPresent fallback for missing optional fields
// - StoryboardSceneStatus enum: raw values, backward-compatible decoding,
//   icon, color
// - StoryboardScene defaults, init with parameters, Codable round-trip

import SwiftUI
import XCTest
@testable import Illustrate

final class StoryboardModelWorkflowTests: XCTestCase {
    // MARK: - StoryboardMode Raw Values

    func testStoryboardMode_RawValue_AutoExtend() {
        XCTAssertEqual(StoryboardMode.AUTO_EXTEND.rawValue, "AUTO_EXTEND")
    }

    func testStoryboardMode_RawValue_FrameBased() {
        XCTAssertEqual(StoryboardMode.FRAME_BASED.rawValue, "FRAME_BASED")
    }

    // MARK: - StoryboardMode Backward Compatible Decoding

    func testStoryboardMode_Decode_CamelCase_AutoExtend() throws {
        let json = "\"autoExtend\""
        let decoded = try JSONDecoder().decode(StoryboardMode.self, from: Data(json.utf8))
        XCTAssertEqual(decoded, .AUTO_EXTEND)
    }

    func testStoryboardMode_Decode_UpperCase_AutoExtend() throws {
        let json = "\"AUTO_EXTEND\""
        let decoded = try JSONDecoder().decode(StoryboardMode.self, from: Data(json.utf8))
        XCTAssertEqual(decoded, .AUTO_EXTEND)
    }

    func testStoryboardMode_Decode_CamelCase_FrameBased() throws {
        let json = "\"frameBased\""
        let decoded = try JSONDecoder().decode(StoryboardMode.self, from: Data(json.utf8))
        XCTAssertEqual(decoded, .FRAME_BASED)
    }

    func testStoryboardMode_Decode_UpperCase_FrameBased() throws {
        let json = "\"FRAME_BASED\""
        let decoded = try JSONDecoder().decode(StoryboardMode.self, from: Data(json.utf8))
        XCTAssertEqual(decoded, .FRAME_BASED)
    }

    func testStoryboardMode_Decode_UnknownValue_Throws() {
        let json = "\"unknown_mode\""
        XCTAssertThrowsError(
            try JSONDecoder().decode(StoryboardMode.self, from: Data(json.utf8))
        )
    }

    // MARK: - StoryboardMode Computed Properties

    func testStoryboardMode_DisplayName_AutoExtend() {
        XCTAssertEqual(StoryboardMode.AUTO_EXTEND.displayName, "Auto Extend")
    }

    func testStoryboardMode_DisplayName_FrameBased() {
        XCTAssertEqual(StoryboardMode.FRAME_BASED.displayName, "Frame Based")
    }

    func testStoryboardMode_Description_AutoExtend_NonEmpty() {
        XCTAssertFalse(StoryboardMode.AUTO_EXTEND.description.isEmpty)
    }

    func testStoryboardMode_Description_FrameBased_NonEmpty() {
        XCTAssertFalse(StoryboardMode.FRAME_BASED.description.isEmpty)
    }

    func testStoryboardMode_Icon_AutoExtend() {
        XCTAssertEqual(StoryboardMode.AUTO_EXTEND.icon, "arrow.right.circle")
    }

    func testStoryboardMode_Icon_FrameBased() {
        XCTAssertEqual(StoryboardMode.FRAME_BASED.icon, "photo.on.rectangle")
    }

    // MARK: - Storyboard Default Values

    func testStoryboard_Default_Name() {
        let storyboard = Storyboard()
        XCTAssertEqual(storyboard.name, "Untitled Storyboard")
    }

    func testStoryboard_Default_Mode() {
        let storyboard = Storyboard()
        XCTAssertEqual(storyboard.mode, .AUTO_EXTEND)
    }

    func testStoryboard_Default_Dimensions() {
        let storyboard = Storyboard()
        XCTAssertEqual(storyboard.dimensions, "1920x1080")
    }

    func testStoryboard_Default_SceneDuration() {
        let storyboard = Storyboard()
        XCTAssertEqual(storyboard.sceneDuration, 8.0)
    }

    func testStoryboard_Default_Resolution() {
        let storyboard = Storyboard()
        XCTAssertEqual(storyboard.resolution, "1080p")
    }

    func testStoryboard_Default_IsPinned() {
        let storyboard = Storyboard()
        XCTAssertFalse(storyboard.isPinned)
    }

    func testStoryboard_Default_ModelIdEmpty() {
        let storyboard = Storyboard()
        XCTAssertEqual(storyboard.modelId, "")
    }

    // MARK: - Storyboard Custom Init

    func testStoryboard_CustomInit_SetsAllProperties() {
        let projectId = UUID()
        let storyboard = Storyboard(
            name: "My Movie",
            projectId: projectId,
            mode: .FRAME_BASED,
            modelId: "model-abc",
            providerId: "provider-xyz",
            dimensions: "1280x720",
            sceneDuration: 5.0,
            resolution: "720p"
        )

        XCTAssertEqual(storyboard.name, "My Movie")
        XCTAssertEqual(storyboard.projectId, projectId)
        XCTAssertEqual(storyboard.mode, .FRAME_BASED)
        XCTAssertEqual(storyboard.modelId, "model-abc")
        XCTAssertEqual(storyboard.providerId, "provider-xyz")
        XCTAssertEqual(storyboard.dimensions, "1280x720")
        XCTAssertEqual(storyboard.sceneDuration, 5.0)
        XCTAssertEqual(storyboard.resolution, "720p")
    }

    // MARK: - Storyboard Codable Round-Trip

    func testStoryboard_CodableRoundTrip_PreservesAllFields() throws {
        let projectId = UUID()
        let storyboard = Storyboard(
            name: "Encoded Movie",
            projectId: projectId,
            mode: .FRAME_BASED,
            modelId: "model-123",
            providerId: "provider-456",
            dimensions: "3840x2160",
            sceneDuration: 12.0,
            resolution: "4K"
        )

        let data = try JSONEncoder().encode(storyboard)
        let decoded = try JSONDecoder().decode(Storyboard.self, from: data)

        XCTAssertEqual(decoded.id, storyboard.id)
        XCTAssertEqual(decoded.projectId, projectId)
        XCTAssertEqual(decoded.name, "Encoded Movie")
        XCTAssertEqual(decoded.mode, .FRAME_BASED)
        XCTAssertEqual(decoded.modelId, "model-123")
        XCTAssertEqual(decoded.providerId, "provider-456")
        XCTAssertEqual(decoded.dimensions, "3840x2160")
        XCTAssertEqual(decoded.sceneDuration, 12.0)
        XCTAssertEqual(decoded.resolution, "4K")
        XCTAssertEqual(decoded.isPinned, false)
    }

    func testStoryboard_Decode_MissingOptionalFields_UsesDefaults() throws {
        // Simulate an older JSON payload that only has required fields
        let id = UUID()
        let dateString = ISO8601DateFormatter().string(from: Date())
        let json = """
        {
            "id": "\(id.uuidString)",
            "createdAt": "\(dateString)",
            "name": "Minimal Storyboard"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Storyboard.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.name, "Minimal Storyboard")
        // Optional fields should fall back to defaults
        XCTAssertEqual(decoded.mode, .AUTO_EXTEND)
        XCTAssertEqual(decoded.dimensions, "1920x1080")
        XCTAssertEqual(decoded.sceneDuration, 8.0)
        XCTAssertEqual(decoded.resolution, "1080p")
        XCTAssertEqual(decoded.modelId, "")
        XCTAssertEqual(decoded.providerId, "")
        XCTAssertFalse(decoded.isPinned)
    }

    // MARK: - StoryboardSceneStatus Raw Values

    func testStoryboardSceneStatus_RawValue_Pending() {
        XCTAssertEqual(StoryboardSceneStatus.PENDING.rawValue, "PENDING")
    }

    func testStoryboardSceneStatus_RawValue_Generating() {
        XCTAssertEqual(StoryboardSceneStatus.GENERATING.rawValue, "GENERATING")
    }

    func testStoryboardSceneStatus_RawValue_Completed() {
        XCTAssertEqual(StoryboardSceneStatus.COMPLETED.rawValue, "COMPLETED")
    }

    func testStoryboardSceneStatus_RawValue_Failed() {
        XCTAssertEqual(StoryboardSceneStatus.FAILED.rawValue, "FAILED")
    }

    // MARK: - StoryboardSceneStatus Backward Compatible Decoding

    func testStoryboardSceneStatus_Decode_Lowercase_Pending() throws {
        let decoded = try JSONDecoder().decode(
            StoryboardSceneStatus.self,
            from: Data("\"pending\"".utf8)
        )
        XCTAssertEqual(decoded, .PENDING)
    }

    func testStoryboardSceneStatus_Decode_Lowercase_Generating() throws {
        let decoded = try JSONDecoder().decode(
            StoryboardSceneStatus.self,
            from: Data("\"generating\"".utf8)
        )
        XCTAssertEqual(decoded, .GENERATING)
    }

    func testStoryboardSceneStatus_Decode_Lowercase_Completed() throws {
        let decoded = try JSONDecoder().decode(
            StoryboardSceneStatus.self,
            from: Data("\"completed\"".utf8)
        )
        XCTAssertEqual(decoded, .COMPLETED)
    }

    func testStoryboardSceneStatus_Decode_Lowercase_Failed() throws {
        let decoded = try JSONDecoder().decode(
            StoryboardSceneStatus.self,
            from: Data("\"failed\"".utf8)
        )
        XCTAssertEqual(decoded, .FAILED)
    }

    func testStoryboardSceneStatus_Decode_UnknownValue_Throws() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                StoryboardSceneStatus.self,
                from: Data("\"invalid\"".utf8)
            )
        )
    }

    // MARK: - StoryboardSceneStatus Computed Properties

    func testStoryboardSceneStatus_Icon_Pending() {
        XCTAssertEqual(StoryboardSceneStatus.PENDING.icon, "clock")
    }

    func testStoryboardSceneStatus_Icon_Generating() {
        XCTAssertEqual(StoryboardSceneStatus.GENERATING.icon, "arrow.trianglehead.2.clockwise")
    }

    func testStoryboardSceneStatus_Icon_Completed() {
        XCTAssertEqual(StoryboardSceneStatus.COMPLETED.icon, "checkmark.circle.fill")
    }

    func testStoryboardSceneStatus_Icon_Failed() {
        XCTAssertEqual(StoryboardSceneStatus.FAILED.icon, "exclamationmark.triangle.fill")
    }

    func testStoryboardSceneStatus_Color_Pending() {
        XCTAssertEqual(StoryboardSceneStatus.PENDING.color, .secondary)
    }

    func testStoryboardSceneStatus_Color_Generating() {
        XCTAssertEqual(StoryboardSceneStatus.GENERATING.color, .blue)
    }

    func testStoryboardSceneStatus_Color_Completed() {
        XCTAssertEqual(StoryboardSceneStatus.COMPLETED.color, .green)
    }

    func testStoryboardSceneStatus_Color_Failed() {
        XCTAssertEqual(StoryboardSceneStatus.FAILED.color, .red)
    }

    // MARK: - StoryboardScene Default Values

    func testStoryboardScene_Default_StatusIsPending() {
        let storyboardId = UUID()
        let scene = StoryboardScene(storyboardId: storyboardId, orderIndex: 0)
        XCTAssertEqual(scene.status, .PENDING)
    }

    func testStoryboardScene_Init_SetsOrderIndex() {
        let storyboardId = UUID()
        let scene = StoryboardScene(storyboardId: storyboardId, orderIndex: 3)
        XCTAssertEqual(scene.orderIndex, 3)
    }

    func testStoryboardScene_Init_SetsPrompt() {
        let storyboardId = UUID()
        let scene = StoryboardScene(storyboardId: storyboardId, orderIndex: 0, prompt: "A sunset over the ocean")
        XCTAssertEqual(scene.prompt, "A sunset over the ocean")
    }

    func testStoryboardScene_Init_OptionalFieldsNilByDefault() {
        let storyboardId = UUID()
        let scene = StoryboardScene(storyboardId: storyboardId, orderIndex: 0)
        XCTAssertNil(scene.generationId)
        XCTAssertNil(scene.queueItemId)
        XCTAssertNil(scene.errorMessage)
        XCTAssertNil(scene.negativePrompt)
        XCTAssertNil(scene.firstFrameAssetId)
        XCTAssertNil(scene.lastFrameAssetId)
    }

    func testStoryboardScene_Init_SetsFrameAssetIds() {
        let storyboardId = UUID()
        let firstFrame = UUID()
        let lastFrame = UUID()
        let scene = StoryboardScene(
            storyboardId: storyboardId,
            orderIndex: 1,
            firstFrameAssetId: firstFrame,
            lastFrameAssetId: lastFrame
        )
        XCTAssertEqual(scene.firstFrameAssetId, firstFrame)
        XCTAssertEqual(scene.lastFrameAssetId, lastFrame)
    }

    // MARK: - StoryboardScene Codable Round-Trip

    func testStoryboardScene_CodableRoundTrip_PreservesAllFields() throws {
        let storyboardId = UUID()
        let generationId = UUID()
        let firstFrame = UUID()

        let scene = StoryboardScene(
            storyboardId: storyboardId,
            orderIndex: 2,
            prompt: "A mountain landscape",
            negativePrompt: "blurry",
            firstFrameAssetId: firstFrame
        )
        scene.generationId = generationId
        scene.status = .COMPLETED

        let data = try JSONEncoder().encode(scene)
        let decoded = try JSONDecoder().decode(StoryboardScene.self, from: data)

        XCTAssertEqual(decoded.id, scene.id)
        XCTAssertEqual(decoded.storyboardId, storyboardId)
        XCTAssertEqual(decoded.orderIndex, 2)
        XCTAssertEqual(decoded.prompt, "A mountain landscape")
        XCTAssertEqual(decoded.negativePrompt, "blurry")
        XCTAssertEqual(decoded.status, .COMPLETED)
        XCTAssertEqual(decoded.generationId, generationId)
        XCTAssertEqual(decoded.firstFrameAssetId, firstFrame)
    }

    func testStoryboardScene_Decode_MissingOptionalFields_UsesDefaults() throws {
        let id = UUID()
        let storyboardId = UUID()
        let json = """
        {
            "id": "\(id.uuidString)",
            "storyboardId": "\(storyboardId.uuidString)",
            "orderIndex": 0,
            "prompt": "Test scene"
        }
        """

        let decoded = try JSONDecoder().decode(StoryboardScene.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.storyboardId, storyboardId)
        XCTAssertEqual(decoded.prompt, "Test scene")
        XCTAssertEqual(decoded.status, .PENDING)
        XCTAssertNil(decoded.generationId)
        XCTAssertNil(decoded.errorMessage)
        XCTAssertNil(decoded.firstFrameAssetId)
        XCTAssertNil(decoded.lastFrameAssetId)
    }
}
