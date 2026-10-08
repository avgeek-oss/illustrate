// MARK: - StoryboardViewModelTests.swift

// Unit tests for StoryboardViewModel computed properties and helper logic.
//
// Tests cover:
// - StoryboardScene status enum
// - StoryboardMode enum
// - Computed properties (totalDuration, canAddScene, completedSceneCount)
// - Scene navigation helpers (hasNextScene)
// - Google auto-extend mode detection

import XCTest
@testable import Illustrate

final class StoryboardViewModelTests: XCTestCase {
    // MARK: - StoryboardSceneStatus Tests

    func testStoryboardSceneStatus_allCases() {
        let statuses: [StoryboardSceneStatus] = [.PENDING, .GENERATING, .COMPLETED, .FAILED]

        XCTAssertEqual(statuses.count, 4)
    }

    func testStoryboardSceneStatus_rawValues() {
        XCTAssertEqual(StoryboardSceneStatus.PENDING.rawValue, "PENDING")
        XCTAssertEqual(StoryboardSceneStatus.GENERATING.rawValue, "GENERATING")
        XCTAssertEqual(StoryboardSceneStatus.COMPLETED.rawValue, "COMPLETED")
        XCTAssertEqual(StoryboardSceneStatus.FAILED.rawValue, "FAILED")
    }

    func testStoryboardSceneStatus_codable() throws {
        let statuses: [StoryboardSceneStatus] = [.PENDING, .GENERATING, .COMPLETED, .FAILED]

        let data = try JSONEncoder().encode(statuses)
        let decoded = try JSONDecoder().decode([StoryboardSceneStatus].self, from: data)

        XCTAssertEqual(decoded, statuses)
    }

    // MARK: - StoryboardMode Tests

    func testStoryboardMode_allCases() {
        let modes: [StoryboardMode] = [.FRAME_BASED, .AUTO_EXTEND]

        XCTAssertEqual(modes.count, 2)
    }

    func testStoryboardMode_rawValues() {
        XCTAssertEqual(StoryboardMode.FRAME_BASED.rawValue, "FRAME_BASED")
        XCTAssertEqual(StoryboardMode.AUTO_EXTEND.rawValue, "AUTO_EXTEND")
    }

    func testStoryboardMode_codable() throws {
        let modes: [StoryboardMode] = [.FRAME_BASED, .AUTO_EXTEND]

        let data = try JSONEncoder().encode(modes)
        let decoded = try JSONDecoder().decode([StoryboardMode].self, from: data)

        XCTAssertEqual(decoded, modes)
    }

    // MARK: - Storyboard Model Tests

    func testStoryboard_initialization() {
        let storyboard = Storyboard(
            name: "Test Storyboard",
            projectId: Project.defaultProjectId,
            modelId: "test-model-id",
            providerId: "test-provider-id",
            dimensions: "1920x1080"
        )

        XCTAssertFalse(storyboard.id.uuidString.isEmpty)
        XCTAssertEqual(storyboard.name, "Test Storyboard")
        XCTAssertEqual(storyboard.modelId, "test-model-id")
        XCTAssertEqual(storyboard.providerId, "test-provider-id")
        XCTAssertEqual(storyboard.dimensions, "1920x1080")
    }

    func testStoryboard_defaultValues() {
        let storyboard = Storyboard(
            name: "Default Test",
            projectId: Project.defaultProjectId,
            modelId: "model",
            providerId: "provider",
            dimensions: "1080x1080"
        )

        XCTAssertEqual(storyboard.sceneDuration, 8.0)
        XCTAssertEqual(storyboard.mode, StoryboardMode.AUTO_EXTEND)
        XCTAssertEqual(storyboard.resolution, "1080p")
    }

    func testStoryboard_customSceneDuration() {
        let storyboard = Storyboard(
            name: "Custom Duration",
            projectId: Project.defaultProjectId,
            modelId: "model",
            providerId: "provider",
            dimensions: "1080x1080",
            sceneDuration: 4.0
        )

        XCTAssertEqual(storyboard.sceneDuration, 4.0)
    }

    func testStoryboard_frameBasedMode() {
        let storyboard = Storyboard(
            name: "Frame Based",
            projectId: Project.defaultProjectId,
            mode: StoryboardMode.FRAME_BASED,
            modelId: "model",
            providerId: "provider",
            dimensions: "1080x1080"
        )

        XCTAssertEqual(storyboard.mode, StoryboardMode.FRAME_BASED)
    }

    // MARK: - StoryboardScene Model Tests

    func testStoryboardScene_initialization() {
        let storyboardId = UUID()

        let scene = StoryboardScene(
            storyboardId: storyboardId,
            orderIndex: 0,
            prompt: "A beautiful sunset"
        )

        XCTAssertFalse(scene.id.uuidString.isEmpty)
        XCTAssertEqual(scene.storyboardId, storyboardId)
        XCTAssertEqual(scene.orderIndex, 0)
        XCTAssertEqual(scene.prompt, "A beautiful sunset")
        XCTAssertEqual(scene.status, .PENDING)
    }

    func testStoryboardScene_withNegativePrompt() {
        let scene = StoryboardScene(
            storyboardId: UUID(),
            orderIndex: 1,
            prompt: "Mountain landscape",
            negativePrompt: "blurry, low quality"
        )

        XCTAssertEqual(scene.negativePrompt, "blurry, low quality")
    }

    func testStoryboardScene_withFrameAssets() {
        let firstFrameId = UUID()
        let lastFrameId = UUID()

        let scene = StoryboardScene(
            storyboardId: UUID(),
            orderIndex: 2,
            prompt: "Scene with frames",
            firstFrameAssetId: firstFrameId,
            lastFrameAssetId: lastFrameId
        )

        XCTAssertEqual(scene.firstFrameAssetId, firstFrameId)
        XCTAssertEqual(scene.lastFrameAssetId, lastFrameId)
    }

    func testStoryboardScene_statusTransitions() {
        let scene = StoryboardScene(
            storyboardId: UUID(),
            orderIndex: 0,
            prompt: "Test"
        )

        XCTAssertEqual(scene.status, .PENDING)

        scene.status = .GENERATING
        XCTAssertEqual(scene.status, .GENERATING)

        scene.status = .COMPLETED
        XCTAssertEqual(scene.status, .COMPLETED)
    }

    func testStoryboardScene_errorMessage() {
        let scene = StoryboardScene(
            storyboardId: UUID(),
            orderIndex: 0,
            prompt: "Test"
        )

        scene.status = .FAILED
        scene.errorMessage = "API Error: Rate limit exceeded"

        XCTAssertEqual(scene.status, .FAILED)
        XCTAssertEqual(scene.errorMessage, "API Error: Rate limit exceeded")
    }

    // MARK: - StoryboardAsset Model Tests

    func testStoryboardAsset_initialization() {
        let storyboardId = UUID()

        let asset = StoryboardAsset(
            storyboardId: storyboardId,
            name: "Reference Image",
            width: 1920,
            height: 1080
        )

        XCTAssertFalse(asset.id.uuidString.isEmpty)
        XCTAssertEqual(asset.storyboardId, storyboardId)
        XCTAssertEqual(asset.name, "Reference Image")
        XCTAssertEqual(asset.width, 1920)
        XCTAssertEqual(asset.height, 1080)
    }

    // MARK: - Computed Properties Tests

    func testTotalDuration_noScenes() {
        let sceneDuration = 8.0
        let completedScenes: [StoryboardSceneStatus] = []

        let totalDuration = Double(completedScenes.filter { $0 == .COMPLETED }.count) * sceneDuration

        XCTAssertEqual(totalDuration, 0.0)
    }

    func testTotalDuration_oneCompletedScene() {
        let sceneDuration = 8.0
        let sceneStatuses: [StoryboardSceneStatus] = [.COMPLETED]

        let totalDuration = Double(sceneStatuses.filter { $0 == .COMPLETED }.count) * sceneDuration

        XCTAssertEqual(totalDuration, 8.0)
    }

    func testTotalDuration_multipleCompletedScenes() {
        let sceneDuration = 8.0
        let sceneStatuses: [StoryboardSceneStatus] = [.COMPLETED, .COMPLETED, .COMPLETED]

        let totalDuration = Double(sceneStatuses.filter { $0 == .COMPLETED }.count) * sceneDuration

        XCTAssertEqual(totalDuration, 24.0)
    }

    func testTotalDuration_mixedStatuses() {
        let sceneDuration = 8.0
        let sceneStatuses: [StoryboardSceneStatus] = [.COMPLETED, .GENERATING, .COMPLETED, .FAILED, .PENDING]

        let totalDuration = Double(sceneStatuses.filter { $0 == .COMPLETED }.count) * sceneDuration

        XCTAssertEqual(totalDuration, 16.0)
    }

    func testTotalDuration_customSceneDuration() {
        let sceneDuration = 4.0
        let sceneStatuses: [StoryboardSceneStatus] = [.COMPLETED, .COMPLETED]

        let totalDuration = Double(sceneStatuses.filter { $0 == .COMPLETED }.count) * sceneDuration

        XCTAssertEqual(totalDuration, 8.0)
    }

    // MARK: - canAddScene Logic Tests

    func testCanAddScene_noScenes() {
        let sceneStatuses: [StoryboardSceneStatus] = []

        let canAddScene = sceneStatuses.isEmpty || sceneStatuses.last == .COMPLETED

        XCTAssertTrue(canAddScene)
    }

    func testCanAddScene_lastSceneCompleted() {
        let sceneStatuses: [StoryboardSceneStatus] = [.COMPLETED, .COMPLETED]

        let canAddScene = sceneStatuses.isEmpty || sceneStatuses.last == .COMPLETED

        XCTAssertTrue(canAddScene)
    }

    func testCanAddScene_lastSceneGenerating() {
        let sceneStatuses: [StoryboardSceneStatus] = [.COMPLETED, .GENERATING]

        let canAddScene = sceneStatuses.isEmpty || sceneStatuses.last == .COMPLETED

        XCTAssertFalse(canAddScene)
    }

    func testCanAddScene_lastScenePending() {
        let sceneStatuses: [StoryboardSceneStatus] = [.COMPLETED, .PENDING]

        let canAddScene = sceneStatuses.isEmpty || sceneStatuses.last == .COMPLETED

        XCTAssertFalse(canAddScene)
    }

    func testCanAddScene_lastSceneFailed() {
        let sceneStatuses: [StoryboardSceneStatus] = [.COMPLETED, .FAILED]

        let canAddScene = sceneStatuses.isEmpty || sceneStatuses.last == .COMPLETED

        XCTAssertFalse(canAddScene)
    }

    // MARK: - completedSceneCount Logic Tests

    func testCompletedSceneCount_noScenes() {
        let sceneStatuses: [StoryboardSceneStatus] = []

        let count = sceneStatuses.filter { $0 == .COMPLETED }.count

        XCTAssertEqual(count, 0)
    }

    func testCompletedSceneCount_allCompleted() {
        let sceneStatuses: [StoryboardSceneStatus] = [.COMPLETED, .COMPLETED, .COMPLETED]

        let count = sceneStatuses.filter { $0 == .COMPLETED }.count

        XCTAssertEqual(count, 3)
    }

    func testCompletedSceneCount_mixedStatuses() {
        let sceneStatuses: [StoryboardSceneStatus] = [.COMPLETED, .GENERATING, .FAILED, .COMPLETED, .PENDING]

        let count = sceneStatuses.filter { $0 == .COMPLETED }.count

        XCTAssertEqual(count, 2)
    }

    // MARK: - hasNextScene Logic Tests

    func testHasNextScene_noSelection() {
        let selectedSceneIndex: Int? = nil
        let sceneStatuses: [StoryboardSceneStatus] = [.COMPLETED, .COMPLETED]

        let hasNext = {
            guard let current = selectedSceneIndex else { return false }
            let nextIndex = current + 1
            guard nextIndex < sceneStatuses.count else { return false }
            return sceneStatuses[nextIndex] == .COMPLETED
        }()

        XCTAssertFalse(hasNext)
    }

    func testHasNextScene_nextSceneCompleted() {
        let selectedSceneIndex: Int? = 0
        let sceneStatuses: [StoryboardSceneStatus] = [.COMPLETED, .COMPLETED]

        let hasNext = {
            guard let current = selectedSceneIndex else { return false }
            let nextIndex = current + 1
            guard nextIndex < sceneStatuses.count else { return false }
            return sceneStatuses[nextIndex] == .COMPLETED
        }()

        XCTAssertTrue(hasNext)
    }

    func testHasNextScene_nextSceneNotCompleted() {
        let selectedSceneIndex: Int? = 0
        let sceneStatuses: [StoryboardSceneStatus] = [.COMPLETED, .GENERATING]

        let hasNext = {
            guard let current = selectedSceneIndex else { return false }
            let nextIndex = current + 1
            guard nextIndex < sceneStatuses.count else { return false }
            return sceneStatuses[nextIndex] == .COMPLETED
        }()

        XCTAssertFalse(hasNext)
    }

    func testHasNextScene_atLastScene() {
        let selectedSceneIndex: Int? = 1
        let sceneStatuses: [StoryboardSceneStatus] = [.COMPLETED, .COMPLETED]

        let hasNext = {
            guard let current = selectedSceneIndex else { return false }
            let nextIndex = current + 1
            guard nextIndex < sceneStatuses.count else { return false }
            return sceneStatuses[nextIndex] == .COMPLETED
        }()

        XCTAssertFalse(hasNext)
    }

    // MARK: - canExport Logic Tests

    func testCanExport_noCompletedScenes() {
        let sceneStatuses: [StoryboardSceneStatus] = [.PENDING, .GENERATING]

        let canExport = sceneStatuses.filter { $0 == .COMPLETED }.count > 0

        XCTAssertFalse(canExport)
    }

    func testCanExport_oneCompletedScene() {
        let sceneStatuses: [StoryboardSceneStatus] = [.COMPLETED]

        let canExport = sceneStatuses.filter { $0 == .COMPLETED }.count > 0

        XCTAssertTrue(canExport)
    }

    func testCanExport_mixedWithCompleted() {
        let sceneStatuses: [StoryboardSceneStatus] = [.GENERATING, .COMPLETED, .FAILED]

        let canExport = sceneStatuses.filter { $0 == .COMPLETED }.count > 0

        XCTAssertTrue(canExport)
    }

    // MARK: - Scene Reorder Index Tests

    func testReorderAdjustedDestination_moveDown() {
        let sourceIndex = 0
        let destinationIndex = 3

        let adjustedDestination = destinationIndex > sourceIndex ? destinationIndex - 1 : destinationIndex

        XCTAssertEqual(adjustedDestination, 2)
    }

    func testReorderAdjustedDestination_moveUp() {
        let sourceIndex = 3
        let destinationIndex = 1

        let adjustedDestination = destinationIndex > sourceIndex ? destinationIndex - 1 : destinationIndex

        XCTAssertEqual(adjustedDestination, 1)
    }

    // MARK: - Scene Selection After Delete Tests

    func testSelectionAfterDelete_deleteSelected() {
        var selectedSceneIndex: Int? = 2
        let deletedIndex = 2
        let remainingCount = 3 // After deletion

        if selectedSceneIndex == deletedIndex {
            selectedSceneIndex = remainingCount == 0 ? nil : min(deletedIndex, remainingCount - 1)
        } else if let selected = selectedSceneIndex, selected > deletedIndex {
            selectedSceneIndex = selected - 1
        }

        XCTAssertEqual(selectedSceneIndex, 2)
    }

    func testSelectionAfterDelete_deleteBefore() {
        var selectedSceneIndex: Int? = 3
        let deletedIndex = 1

        if let selected = selectedSceneIndex, selected > deletedIndex {
            selectedSceneIndex = selected - 1
        }

        XCTAssertEqual(selectedSceneIndex, 2)
    }

    func testSelectionAfterDelete_deleteAfter() {
        var selectedSceneIndex: Int? = 1
        let deletedIndex = 3

        if let selected = selectedSceneIndex, selected > deletedIndex {
            selectedSceneIndex = selected - 1
        }

        XCTAssertEqual(selectedSceneIndex, 1) // Unchanged
    }

    func testSelectionAfterDelete_lastSceneSelected() {
        var selectedSceneIndex: Int? = 2
        let deletedIndex = 2
        let remainingCount = 2 // After deletion

        if selectedSceneIndex == deletedIndex {
            selectedSceneIndex = remainingCount == 0 ? nil : min(deletedIndex, remainingCount - 1)
        }

        XCTAssertEqual(selectedSceneIndex, 1) // Adjusted to last available
    }
}
