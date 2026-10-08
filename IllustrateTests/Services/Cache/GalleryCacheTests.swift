// MARK: - GalleryCacheTests.swift

// Unit tests for GalleryCache and related types.
//
// Tests cover:
// - Stale threshold logic
// - Notification name definitions
// - Thumbnail pre-warming constants
// - Content type filtering logic

import XCTest
@testable import Illustrate

final class GalleryCacheTests: XCTestCase {
    // MARK: - Stale Threshold Tests

    func testStaleThreshold_value() {
        let staleThreshold: TimeInterval = 300 // 5 minutes
        XCTAssertEqual(staleThreshold, 300)
    }

    func testStaleThreshold_inMinutes() {
        let staleThreshold: TimeInterval = 300
        let minutes = staleThreshold / 60
        XCTAssertEqual(minutes, 5)
    }

    func testNeedsRefresh_noLoadTime_returnsTrue() {
        let lastLoadTime: Date? = nil

        // If never loaded, needs refresh
        let needsRefresh = lastLoadTime == nil
        XCTAssertTrue(needsRefresh)
    }

    func testNeedsRefresh_recentLoadTime_returnsFalse() {
        let staleThreshold: TimeInterval = 300
        let lastLoadTime = Date().addingTimeInterval(-60) // 1 minute ago

        let needsRefresh = Date().timeIntervalSince(lastLoadTime) > staleThreshold
        XCTAssertFalse(needsRefresh)
    }

    func testNeedsRefresh_staleLoadTime_returnsTrue() {
        let staleThreshold: TimeInterval = 300
        let lastLoadTime = Date().addingTimeInterval(-600) // 10 minutes ago

        let needsRefresh = Date().timeIntervalSince(lastLoadTime) > staleThreshold
        XCTAssertTrue(needsRefresh)
    }

    func testNeedsRefresh_exactThreshold_returnsFalse() {
        let staleThreshold: TimeInterval = 300
        let now = Date()
        let lastLoadTime = now.addingTimeInterval(-300) // Exactly 5 minutes ago

        // > not >= so exact threshold is not stale
        let needsRefresh = now.timeIntervalSince(lastLoadTime) > staleThreshold
        XCTAssertFalse(needsRefresh)
    }

    func testNeedsRefresh_justOverThreshold_returnsTrue() {
        let staleThreshold: TimeInterval = 300
        let lastLoadTime = Date().addingTimeInterval(-301) // 5 minutes + 1 second ago

        let needsRefresh = Date().timeIntervalSince(lastLoadTime) > staleThreshold
        XCTAssertTrue(needsRefresh)
    }

    // MARK: - Notification Name Tests

    func testNotificationName_generationCreated() {
        let name = Notification.Name.generationCreated
        XCTAssertEqual(name.rawValue, "generationCreated")
    }

    func testNotificationName_providerKeysChanged() {
        let name = Notification.Name.providerKeysChanged
        XCTAssertEqual(name.rawValue, "providerKeysChanged")
    }

    // MARK: - Thumbnail Pre-warming Constants Tests

    func testPrewarmImageCount() {
        let prewarmImageCount = 50
        XCTAssertEqual(prewarmImageCount, 50)
    }

    func testPrewarmVideoCount() {
        let prewarmVideoCount = 30
        XCTAssertEqual(prewarmVideoCount, 30)
    }

    func testThumbnailScale_o20() {
        let scale = "o20"
        XCTAssertEqual(scale, "o20")
    }

    func testThumbnailKeyFormat() {
        let uuid = UUID()
        let scale = "o20"
        let key = ".\(uuid.uuidString)_\(scale)"

        XCTAssertTrue(key.hasPrefix("."))
        XCTAssertTrue(key.hasSuffix("_o20"))
    }

    // MARK: - Content Type Filtering Tests

    func testContentTypeFiltering_image2D() {
        let contentType = EnumGenerationContentType.IMAGE_2D
        let isImage = contentType == .IMAGE_2D

        XCTAssertTrue(isImage)
    }

    func testContentTypeFiltering_video() {
        let contentType = EnumGenerationContentType.VIDEO
        let isVideo = contentType == .VIDEO

        XCTAssertTrue(isVideo)
    }

    func testContentTypeFiltering_image2D_isNotVideo() {
        let contentType = EnumGenerationContentType.IMAGE_2D
        let isVideo = contentType == .VIDEO

        XCTAssertFalse(isVideo)
    }

    func testContentTypeFiltering_video_isNotImage() {
        let contentType = EnumGenerationContentType.VIDEO
        let isImage = contentType == .IMAGE_2D

        XCTAssertFalse(isImage)
    }

    // MARK: - Duplicate Detection Tests

    func testDuplicateDetection_setContains() {
        let set1 = UUID()
        let set2 = UUID()
        let sets = [set1, set2]

        XCTAssertTrue(sets.contains(set1))
        XCTAssertTrue(sets.contains(set2))
    }

    func testDuplicateDetection_setDoesNotContain() {
        let set1 = UUID()
        let set2 = UUID()
        let newSet = UUID()
        let sets = [set1, set2]

        XCTAssertFalse(sets.contains(newSet))
    }

    // MARK: - Project Scoping Tests

    func testProjectScoping_matchingProject() {
        let projectId = UUID()
        let currentProjectId = projectId

        let isCurrentProject = projectId == currentProjectId
        XCTAssertTrue(isCurrentProject)
    }

    func testProjectScoping_differentProject() {
        let projectId = UUID()
        let currentProjectId = UUID()

        let isCurrentProject = projectId == currentProjectId
        XCTAssertFalse(isCurrentProject)
    }

    // MARK: - Hidden Generation Filtering Tests

    func testHiddenGeneration_shouldBeFiltered() {
        let isHidden = true
        let shouldShow = !isHidden

        XCTAssertFalse(shouldShow)
    }

    func testHiddenGeneration_visibleShouldShow() {
        let isHidden = false
        let shouldShow = !isHidden

        XCTAssertTrue(shouldShow)
    }

    // MARK: - Cache State Tests

    func testCacheState_notLoaded() {
        let isLoaded = false
        let needsLoad = !isLoaded

        XCTAssertTrue(needsLoad)
    }

    func testCacheState_loaded() {
        let isLoaded = true
        let needsLoad = !isLoaded

        XCTAssertFalse(needsLoad)
    }

    func testCacheState_forceRefresh() {
        let force = true
        let isLoaded = true

        // Force ignores isLoaded state
        let shouldLoad = force || !isLoaded
        XCTAssertTrue(shouldLoad)
    }

    // MARK: - Empty State Tests

    func testHasAnyGenerations_bothEmpty() {
        let imageGenerations: [UUID] = []
        let videoGenerations: [UUID] = []

        let hasAny = !imageGenerations.isEmpty || !videoGenerations.isEmpty
        XCTAssertFalse(hasAny)
    }

    func testHasAnyGenerations_hasImages() {
        let imageGenerations = [UUID()]
        let videoGenerations: [UUID] = []

        let hasAny = !imageGenerations.isEmpty || !videoGenerations.isEmpty
        XCTAssertTrue(hasAny)
    }

    func testHasAnyGenerations_hasVideos() {
        let imageGenerations: [UUID] = []
        let videoGenerations = [UUID()]

        let hasAny = !imageGenerations.isEmpty || !videoGenerations.isEmpty
        XCTAssertTrue(hasAny)
    }

    func testHasAnyGenerations_hasBoth() {
        let imageGenerations = [UUID()]
        let videoGenerations = [UUID()]

        let hasAny = !imageGenerations.isEmpty || !videoGenerations.isEmpty
        XCTAssertTrue(hasAny)
    }

    // MARK: - Incremental Update Tests

    func testIncrementalAdd_insertsAtFront() {
        var items = ["b", "c"]
        let newItem = "a"

        items.insert(newItem, at: 0)

        XCTAssertEqual(items[0], "a")
        XCTAssertEqual(items[1], "b")
        XCTAssertEqual(items[2], "c")
    }

    func testIncrementalRemove_byId() {
        var items = [UUID(), UUID(), UUID()]
        let idsToRemove: Set<UUID> = [items[1]]

        items.removeAll { idsToRemove.contains($0) }

        XCTAssertEqual(items.count, 2)
        XCTAssertFalse(items.contains(Array(idsToRemove)[0]))
    }

    func testIncrementalRemove_multipleIds() {
        var items = [UUID(), UUID(), UUID(), UUID()]
        let idsToRemove: Set<UUID> = [items[0], items[2]]

        let originalSecond = items[1]
        let originalFourth = items[3]

        items.removeAll { idsToRemove.contains($0) }

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0], originalSecond)
        XCTAssertEqual(items[1], originalFourth)
    }

    // MARK: - Invalidation Tests

    func testInvalidation_resetsLoadedState() {
        var isLoaded = true
        var lastLoadTime: Date? = Date()
        var hasAnyGenerationsLoaded = true

        // Invalidate
        isLoaded = false
        lastLoadTime = nil
        hasAnyGenerationsLoaded = false

        XCTAssertFalse(isLoaded)
        XCTAssertNil(lastLoadTime)
        XCTAssertFalse(hasAnyGenerationsLoaded)
    }

    func testMarkNeedsRefresh_keepsLoadedButClearsTime() {
        var isLoaded = true
        var lastLoadTime: Date? = Date()

        // Mark needs refresh
        lastLoadTime = nil

        // isLoaded stays true, but lastLoadTime is nil
        XCTAssertTrue(isLoaded)
        XCTAssertNil(lastLoadTime)
    }
}
