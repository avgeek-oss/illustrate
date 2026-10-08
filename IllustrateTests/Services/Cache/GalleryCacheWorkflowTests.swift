// MARK: - GalleryCacheWorkflowTests.swift

// Tests for GalleryCache lifecycle and incremental update operations.
//
// Tests cover:
// - loadIfNeeded() with empty/populated databases
// - Project scoping (only loads current project's data)
// - Hidden generation filtering
// - Content type separation (IMAGE_2D vs VIDEO)
// - Cache staleness and refresh logic
// - Incremental add/remove operations
// - Invalidation and markNeedsRefresh

import Foundation
import IllustrateProviders
import SwiftData
import XCTest
@testable import Illustrate

@MainActor
final class GalleryCacheWorkflowTests: XCTestCase {
    private var container: ModelContainer!
    private var modelContext: ModelContext!
    private var cache: GalleryCache!

    override func setUp() async throws {
        try await super.setUp()
        container = try makeTestModelContainer()
        modelContext = container.mainContext
        cache = GalleryCache()
    }

    override func tearDown() async throws {
        cache = nil
        container = nil
        modelContext = nil
        try await super.tearDown()
    }

    // MARK: - Load If Needed

    func testLoadIfNeeded_emptyDatabase_loadsEmptyArrays() {
        let projectId = UUID()
        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)

        XCTAssertTrue(cache.isLoaded)
        XCTAssertTrue(cache.imageSets.isEmpty)
        XCTAssertTrue(cache.imageGenerations.isEmpty)
        XCTAssertTrue(cache.videoGenerations.isEmpty)
    }

    func testLoadIfNeeded_withData_loadsCorrectly() {
        let projectId = UUID()
        let gen = TestFixtures.makeGeneration(projectId: projectId, contentType: .IMAGE_2D)
        modelContext.insert(gen)

        let set = TestFixtures.makeImageSet(projectId: projectId)
        modelContext.insert(set)
        try? modelContext.save()

        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)

        XCTAssertTrue(cache.isLoaded)
        XCTAssertEqual(cache.imageGenerations.count, 1)
        XCTAssertEqual(cache.imageSets.count, 1)
    }

    func testLoadIfNeeded_setsIsLoadedTrue() {
        XCTAssertFalse(cache.isLoaded)
        cache.loadIfNeeded(projectId: UUID(), modelContext: modelContext)
        XCTAssertTrue(cache.isLoaded)
    }

    // MARK: - Project Scoping

    func testLoadIfNeeded_projectScoping_onlyLoadsCurrentProject() {
        let projectA = UUID()
        let projectB = UUID()

        let genA = TestFixtures.makeGeneration(projectId: projectA, contentType: .IMAGE_2D)
        let genB = TestFixtures.makeGeneration(projectId: projectB, contentType: .IMAGE_2D)
        modelContext.insert(genA)
        modelContext.insert(genB)
        try? modelContext.save()

        cache.loadIfNeeded(projectId: projectA, modelContext: modelContext)

        XCTAssertEqual(cache.imageGenerations.count, 1)
        XCTAssertEqual(cache.imageGenerations.first?.projectId, projectA)
    }

    // MARK: - Hidden Generation Filtering

    func testLoadIfNeeded_hiddenGenerations_filtered() {
        let projectId = UUID()

        let visible = TestFixtures.makeGeneration(projectId: projectId, contentType: .IMAGE_2D, isHidden: false)
        let hidden = TestFixtures.makeGeneration(projectId: projectId, contentType: .IMAGE_2D, isHidden: true)
        modelContext.insert(visible)
        modelContext.insert(hidden)
        try? modelContext.save()

        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)

        XCTAssertEqual(cache.imageGenerations.count, 1, "Hidden generations should be filtered out")
    }

    // MARK: - Content Type Separation

    func testLoadIfNeeded_separatesImageAndVideo() {
        let projectId = UUID()

        let image = TestFixtures.makeGeneration(projectId: projectId, contentType: .IMAGE_2D)
        let video = TestFixtures.makeGeneration(projectId: projectId, contentType: .VIDEO)
        modelContext.insert(image)
        modelContext.insert(video)
        try? modelContext.save()

        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)

        XCTAssertEqual(cache.imageGenerations.count, 1)
        XCTAssertEqual(cache.videoGenerations.count, 1)
        XCTAssertEqual(cache.imageGenerations.first?.contentType, .IMAGE_2D)
        XCTAssertEqual(cache.videoGenerations.first?.contentType, .VIDEO)
    }

    // MARK: - Skip/Force Reload

    func testLoadIfNeeded_skipIfAlreadyLoadedForSameProject() {
        let projectId = UUID()

        let gen = TestFixtures.makeGeneration(projectId: projectId, contentType: .IMAGE_2D)
        modelContext.insert(gen)
        try? modelContext.save()

        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)
        XCTAssertEqual(cache.imageGenerations.count, 1)

        // Add another generation directly to DB (bypassing cache)
        let gen2 = TestFixtures.makeGeneration(projectId: projectId, contentType: .IMAGE_2D)
        modelContext.insert(gen2)
        try? modelContext.save()

        // Should skip reload since same project and not stale
        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)
        XCTAssertEqual(cache.imageGenerations.count, 1, "Should not reload when already loaded and fresh")
    }

    func testLoadIfNeeded_reloadsForDifferentProject() {
        let projectA = UUID()
        let projectB = UUID()

        let genA = TestFixtures.makeGeneration(projectId: projectA, contentType: .IMAGE_2D)
        let genB = TestFixtures.makeGeneration(projectId: projectB, contentType: .IMAGE_2D)
        modelContext.insert(genA)
        modelContext.insert(genB)
        try? modelContext.save()

        cache.loadIfNeeded(projectId: projectA, modelContext: modelContext)
        XCTAssertEqual(cache.imageGenerations.count, 1)

        // Different project forces reload
        cache.loadIfNeeded(projectId: projectB, modelContext: modelContext)
        XCTAssertEqual(cache.imageGenerations.count, 1)
        XCTAssertEqual(cache.imageGenerations.first?.projectId, projectB)
    }

    // MARK: - Staleness

    func testNeedsRefresh_falseWhenFresh() {
        cache.loadIfNeeded(projectId: UUID(), modelContext: modelContext)
        XCTAssertFalse(cache.needsRefresh, "Just-loaded cache should not need refresh")
    }

    func testMarkNeedsRefresh_forcesNextLoad() {
        let projectId = UUID()
        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)
        XCTAssertFalse(cache.needsRefresh)

        cache.markNeedsRefresh()
        XCTAssertTrue(cache.needsRefresh, "After markNeedsRefresh, cache should report needing refresh")
    }

    // MARK: - Invalidation

    func testInvalidate_resetsState() {
        cache.loadIfNeeded(projectId: UUID(), modelContext: modelContext)
        XCTAssertTrue(cache.isLoaded)

        cache.invalidate()
        XCTAssertFalse(cache.isLoaded)
        XCTAssertFalse(cache.hasAnyGenerationsLoaded)
    }

    // MARK: - hasAnyGenerations

    func testHasAnyGenerations_trueWhenDataExists() {
        let projectId = UUID()
        let gen = TestFixtures.makeGeneration(projectId: projectId, contentType: .IMAGE_2D)
        modelContext.insert(gen)
        try? modelContext.save()

        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)
        XCTAssertTrue(cache.hasAnyGenerations)
    }

    func testHasAnyGenerations_falseWhenEmpty() {
        cache.loadIfNeeded(projectId: UUID(), modelContext: modelContext)
        XCTAssertFalse(cache.hasAnyGenerations)
    }

    // MARK: - Incremental Add

    func testAddGeneration_imageType_insertsAtFront() {
        let projectId = UUID()
        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)

        let gen = TestFixtures.makeGeneration(projectId: projectId, contentType: .IMAGE_2D)
        cache.addGeneration(gen)

        XCTAssertEqual(cache.imageGenerations.count, 1)
        XCTAssertEqual(cache.imageGenerations.first?.id, gen.id)
        XCTAssertTrue(cache.hasAnyGenerations)
    }

    func testAddGeneration_videoType_insertsAtFront() {
        let projectId = UUID()
        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)

        let gen = TestFixtures.makeGeneration(projectId: projectId, contentType: .VIDEO)
        cache.addGeneration(gen)

        XCTAssertEqual(cache.videoGenerations.count, 1)
        XCTAssertEqual(cache.videoGenerations.first?.id, gen.id)
    }

    func testAddGeneration_hiddenGeneration_rejected() {
        let projectId = UUID()
        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)

        let gen = TestFixtures.makeGeneration(projectId: projectId, contentType: .IMAGE_2D, isHidden: true)
        cache.addGeneration(gen)

        XCTAssertTrue(cache.imageGenerations.isEmpty, "Hidden generations should not be added to cache")
    }

    func testAddGeneration_duplicateRejected() {
        let projectId = UUID()
        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)

        let gen = TestFixtures.makeGeneration(projectId: projectId, contentType: .IMAGE_2D)
        cache.addGeneration(gen)
        cache.addGeneration(gen) // duplicate

        XCTAssertEqual(cache.imageGenerations.count, 1, "Duplicate should be rejected")
    }

    func testAddGeneration_wrongProject_rejected() {
        let projectA = UUID()
        let projectB = UUID()
        cache.loadIfNeeded(projectId: projectA, modelContext: modelContext)

        let gen = TestFixtures.makeGeneration(projectId: projectB, contentType: .IMAGE_2D)
        cache.addGeneration(gen)

        XCTAssertTrue(cache.imageGenerations.isEmpty, "Wrong project generations should be rejected")
    }

    // MARK: - Incremental Remove

    func testRemoveGenerations_removesById() {
        let projectId = UUID()
        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)

        let gen1 = TestFixtures.makeGeneration(projectId: projectId, contentType: .IMAGE_2D)
        let gen2 = TestFixtures.makeGeneration(projectId: projectId, contentType: .IMAGE_2D)
        let gen3 = TestFixtures.makeGeneration(projectId: projectId, contentType: .VIDEO)
        cache.addGeneration(gen1)
        cache.addGeneration(gen2)
        cache.addGeneration(gen3)

        cache.removeGenerations(ids: Set([gen1.id, gen3.id]))

        XCTAssertEqual(cache.imageGenerations.count, 1)
        XCTAssertEqual(cache.imageGenerations.first?.id, gen2.id)
        XCTAssertEqual(cache.videoGenerations.count, 0)
    }

    // MARK: - Add ImageSet

    func testAddImageSet_insertsAtFront() {
        let projectId = UUID()
        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)

        let set = TestFixtures.makeImageSet(projectId: projectId)
        cache.addImageSet(set)

        XCTAssertEqual(cache.imageSets.count, 1)
        XCTAssertEqual(cache.imageSets.first?.id, set.id)
    }

    func testAddImageSet_duplicateRejected() {
        let projectId = UUID()
        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)

        let set = TestFixtures.makeImageSet(projectId: projectId)
        cache.addImageSet(set)
        cache.addImageSet(set)

        XCTAssertEqual(cache.imageSets.count, 1)
    }

    func testAddImageSet_wrongProject_rejected() {
        let projectA = UUID()
        cache.loadIfNeeded(projectId: projectA, modelContext: modelContext)

        let set = TestFixtures.makeImageSet(projectId: UUID())
        cache.addImageSet(set)

        XCTAssertTrue(cache.imageSets.isEmpty)
    }

    // MARK: - Remove ImageSets

    func testRemoveImageSets_removesById() {
        let projectId = UUID()
        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)

        let set1 = TestFixtures.makeImageSet(projectId: projectId)
        let set2 = TestFixtures.makeImageSet(projectId: projectId)
        cache.addImageSet(set1)
        cache.addImageSet(set2)

        cache.removeImageSets(ids: Set([set1.id]))
        XCTAssertEqual(cache.imageSets.count, 1)
        XCTAssertEqual(cache.imageSets.first?.id, set2.id)
    }

    // MARK: - checkHasAnyGenerations

    func testCheckHasAnyGenerations_emptyDatabase_false() {
        let projectId = UUID()
        cache.checkHasAnyGenerations(projectId: projectId, modelContext: modelContext)
        XCTAssertFalse(cache.hasAnyGenerations)
        XCTAssertTrue(cache.hasAnyGenerationsLoaded)
    }

    func testCheckHasAnyGenerations_withData_true() {
        let projectId = UUID()
        let gen = TestFixtures.makeGeneration(projectId: projectId, contentType: .IMAGE_2D)
        modelContext.insert(gen)
        try? modelContext.save()

        cache.checkHasAnyGenerations(projectId: projectId, modelContext: modelContext)
        XCTAssertTrue(cache.hasAnyGenerations)
    }

    func testCheckHasAnyGenerations_hiddenOnly_false() {
        let projectId = UUID()
        let gen = TestFixtures.makeGeneration(projectId: projectId, contentType: .IMAGE_2D, isHidden: true)
        modelContext.insert(gen)
        try? modelContext.save()

        cache.checkHasAnyGenerations(projectId: projectId, modelContext: modelContext)
        XCTAssertFalse(cache.hasAnyGenerations, "Hidden-only generations should not count")
    }
}
