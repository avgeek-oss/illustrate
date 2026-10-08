// MARK: - ProviderKeysCacheWorkflowTests.swift

// Tests for ProviderKeysCache lifecycle and query operations.
//
// Tests cover:
// - loadIfNeeded() with project scoping
// - Deduplication (keeps most recent key per provider)
// - hasProvider() query
// - keys(for:) retrieval
// - Skip reload behavior
// - Invalidation and notification-driven refresh

import Foundation
import SwiftData
import XCTest
@testable import Illustrate

@MainActor
final class ProviderKeysCacheWorkflowTests: XCTestCase {
    private var container: ModelContainer!
    private var modelContext: ModelContext!
    private var cache: ProviderKeysCache!

    override func setUp() async throws {
        try await super.setUp()
        container = try makeTestModelContainer()
        modelContext = container.mainContext
        cache = ProviderKeysCache()
    }

    override func tearDown() async throws {
        cache = nil
        container = nil
        modelContext = nil
        try await super.tearDown()
    }

    // MARK: - Load If Needed

    func testLoadIfNeeded_emptyDatabase_loadsEmptyArray() {
        let projectId = UUID()
        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)

        XCTAssertTrue(cache.isLoaded)
        XCTAssertTrue(cache.providerKeys.isEmpty)
    }

    func testLoadIfNeeded_withKeys_loadsForProject() {
        let projectId = UUID()
        let key = TestFixtures.makeProviderKey(projectId: projectId)
        modelContext.insert(key)
        try? modelContext.save()

        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)

        XCTAssertEqual(cache.providerKeys.count, 1)
        XCTAssertEqual(cache.providerKeys.first?.projectId, projectId)
    }

    func testLoadIfNeeded_setsIsLoadedTrue() {
        XCTAssertFalse(cache.isLoaded)
        cache.loadIfNeeded(projectId: UUID(), modelContext: modelContext)
        XCTAssertTrue(cache.isLoaded)
    }

    // MARK: - Project Scoping

    func testLoadIfNeeded_projectScoping_onlyCurrentProject() {
        let projectA = UUID()
        let projectB = UUID()

        let keyA = TestFixtures.makeProviderKey(projectId: projectA)
        let keyB = TestFixtures.makeProviderKey(projectId: projectB)
        modelContext.insert(keyA)
        modelContext.insert(keyB)
        try? modelContext.save()

        cache.loadIfNeeded(projectId: projectA, modelContext: modelContext)

        XCTAssertEqual(cache.providerKeys.count, 1)
        XCTAssertEqual(cache.providerKeys.first?.projectId, projectA)
    }

    // MARK: - Deduplication

    func testLoadIfNeeded_deduplicates_keepsMostRecent() {
        let projectId = UUID()
        let providerId = UUID()

        // Insert two keys for the same provider — the one with later createdAt should win
        let olderKey = ProviderKey(providerId: providerId, projectId: projectId)
        olderKey.createdAt = Date(timeIntervalSinceNow: -100)

        let newerKey = ProviderKey(providerId: providerId, projectId: projectId)
        newerKey.createdAt = Date()

        modelContext.insert(olderKey)
        modelContext.insert(newerKey)
        try? modelContext.save()

        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)

        // Deduplication keeps only 1 key per provider
        XCTAssertEqual(cache.providerKeys.count, 1, "Should deduplicate to one key per provider")
        // Since sorted by createdAt descending, the newer key should be kept
        XCTAssertEqual(cache.providerKeys.first?.id, newerKey.id)
    }

    // MARK: - Skip Reload

    func testLoadIfNeeded_skipIfAlreadyLoaded() {
        let projectId = UUID()
        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)
        XCTAssertEqual(cache.providerKeys.count, 0)

        // Add a key after initial load
        let key = TestFixtures.makeProviderKey(projectId: projectId)
        modelContext.insert(key)
        try? modelContext.save()

        // Should skip since already loaded for this project
        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)
        XCTAssertEqual(cache.providerKeys.count, 0, "Should not reload when already loaded")
    }

    func testLoadIfNeeded_differentProject_reloads() {
        let projectA = UUID()
        let projectB = UUID()

        let keyB = TestFixtures.makeProviderKey(projectId: projectB)
        modelContext.insert(keyB)
        try? modelContext.save()

        cache.loadIfNeeded(projectId: projectA, modelContext: modelContext)
        XCTAssertEqual(cache.providerKeys.count, 0)

        cache.loadIfNeeded(projectId: projectB, modelContext: modelContext)
        XCTAssertEqual(cache.providerKeys.count, 1, "Should reload for different project")
    }

    // MARK: - hasProvider

    func testHasProvider_true_whenKeyExists() {
        let projectId = UUID()
        let providerId = UUID()

        let key = TestFixtures.makeProviderKey(providerId: providerId, projectId: projectId)
        modelContext.insert(key)
        try? modelContext.save()

        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)

        XCTAssertTrue(cache.hasProvider(providerId))
    }

    func testHasProvider_false_whenKeyMissing() {
        let projectId = UUID()
        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)
        XCTAssertFalse(cache.hasProvider(UUID()))
    }

    // MARK: - keys(for:)

    func testKeys_forCorrectProject_returnsKeys() {
        let projectId = UUID()
        let key = TestFixtures.makeProviderKey(projectId: projectId)
        modelContext.insert(key)
        try? modelContext.save()

        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)
        let keys = cache.keys(for: projectId)
        XCTAssertEqual(keys.count, 1)
    }

    func testKeys_forWrongProject_returnsEmpty() {
        let projectId = UUID()
        let key = TestFixtures.makeProviderKey(projectId: projectId)
        modelContext.insert(key)
        try? modelContext.save()

        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)
        let keys = cache.keys(for: UUID()) // different project
        XCTAssertTrue(keys.isEmpty)
    }

    // MARK: - Invalidation

    func testInvalidate_resetsLoadedState() {
        cache.loadIfNeeded(projectId: UUID(), modelContext: modelContext)
        XCTAssertTrue(cache.isLoaded)

        cache.invalidate()
        XCTAssertFalse(cache.isLoaded)
    }

    func testInvalidate_allowsReload() {
        let projectId = UUID()
        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)
        XCTAssertEqual(cache.providerKeys.count, 0)

        // Add a key
        let key = TestFixtures.makeProviderKey(projectId: projectId)
        modelContext.insert(key)
        try? modelContext.save()

        // Invalidate and reload
        cache.invalidate()
        cache.loadIfNeeded(projectId: projectId, modelContext: modelContext)
        XCTAssertEqual(cache.providerKeys.count, 1, "After invalidation, should reload fresh data")
    }

    // MARK: - Notification-Driven Invalidation

    func testNotification_providerKeysChanged_invalidatesCache() {
        // Use the shared instance for notification testing since the observer
        // is set up in init()
        let sharedCache = ProviderKeysCache.shared
        sharedCache.loadIfNeeded(projectId: UUID(), modelContext: modelContext)
        XCTAssertTrue(sharedCache.isLoaded)

        NotificationCenter.default.post(name: .providerKeysChanged, object: nil)

        // Notification is processed synchronously on main queue
        XCTAssertFalse(sharedCache.isLoaded, "Cache should be invalidated after notification")
    }
}
