// MARK: - CacheProtocolTests.swift

// Unit tests for cache protocol definitions and conformance.
//
// Tests cover:
// - Protocol requirements and semantics
// - Default implementations
// - Mock implementations for verification

import XCTest
@testable import Illustrate

// MARK: - Mock Implementations

/// Mock implementation of CacheProtocol for testing.
@MainActor
private final class MockBasicCache: CacheProtocol {
    private(set) var isLoaded = false
    private(set) var invalidateCallCount = 0

    func load() {
        isLoaded = true
    }

    func invalidate() {
        isLoaded = false
        invalidateCallCount += 1
    }
}

/// Mock implementation of StalenessCheckingCache for testing.
@MainActor
private final class MockStalenessCache: StalenessCheckingCache {
    private(set) var isLoaded = false
    private(set) var invalidateCallCount = 0
    private(set) var markNeedsRefreshCallCount = 0

    private var lastLoadTime: Date?
    private let staleThreshold: TimeInterval = 300

    var needsRefresh: Bool {
        guard isLoaded, let lastLoad = lastLoadTime else { return true }
        return Date().timeIntervalSince(lastLoad) > staleThreshold
    }

    func load() {
        isLoaded = true
        lastLoadTime = Date()
    }

    func invalidate() {
        isLoaded = false
        lastLoadTime = nil
        invalidateCallCount += 1
    }

    func markNeedsRefresh() {
        lastLoadTime = nil
        markNeedsRefreshCallCount += 1
    }

    /// For testing: set a custom last load time
    func setLastLoadTime(_ time: Date?) {
        lastLoadTime = time
    }
}

/// Mock implementation of TTLCache for testing.
@MainActor
private final class MockTTLCache: TTLCache {
    private(set) var clearAllCallCount = 0
    private(set) var clearExpiredCallCount = 0
    private(set) var invalidateCallCount = 0
    var entries: [String: Date] = [:] // key -> expiresAt

    /// TTLCache default implementation provides isLoaded = true
    var isLoaded: Bool {
        true
    }

    func addEntry(key: String, ttl: TimeInterval) {
        entries[key] = Date().addingTimeInterval(ttl)
    }

    func clearAll() {
        entries.removeAll()
        clearAllCallCount += 1
    }

    func clearExpired() {
        let now = Date()
        entries = entries.filter { $0.value > now }
        clearExpiredCallCount += 1
    }

    func invalidate() {
        clearAll()
        invalidateCallCount += 1
    }
}

// MARK: - CacheProtocol Tests

@MainActor
final class CacheProtocolTests: XCTestCase {
    // MARK: - Basic Cache Protocol Tests

    func testBasicCache_initialState_isNotLoaded() {
        let cache = MockBasicCache()
        XCTAssertFalse(cache.isLoaded)
    }

    func testBasicCache_afterLoad_isLoaded() {
        let cache = MockBasicCache()
        cache.load()
        XCTAssertTrue(cache.isLoaded)
    }

    func testBasicCache_invalidate_resetsLoadState() {
        let cache = MockBasicCache()
        cache.load()
        XCTAssertTrue(cache.isLoaded)

        cache.invalidate()
        XCTAssertFalse(cache.isLoaded)
    }

    func testBasicCache_invalidate_tracksCallCount() {
        let cache = MockBasicCache()

        cache.invalidate()
        XCTAssertEqual(cache.invalidateCallCount, 1)

        cache.invalidate()
        XCTAssertEqual(cache.invalidateCallCount, 2)
    }

    func testBasicCache_multipleLoadsAndInvalidates() {
        let cache = MockBasicCache()

        cache.load()
        XCTAssertTrue(cache.isLoaded)

        cache.invalidate()
        XCTAssertFalse(cache.isLoaded)

        cache.load()
        XCTAssertTrue(cache.isLoaded)
    }

    // MARK: - Staleness Checking Cache Tests

    func testStalenessCache_initialState_needsRefresh() {
        let cache = MockStalenessCache()
        XCTAssertTrue(cache.needsRefresh)
    }

    func testStalenessCache_afterRecentLoad_doesNotNeedRefresh() {
        let cache = MockStalenessCache()
        cache.load()
        XCTAssertFalse(cache.needsRefresh)
    }

    func testStalenessCache_afterStaleLoad_needsRefresh() {
        let cache = MockStalenessCache()
        cache.load()

        // Set last load to 10 minutes ago (beyond 5-minute threshold)
        cache.setLastLoadTime(Date().addingTimeInterval(-600))

        XCTAssertTrue(cache.needsRefresh)
    }

    func testStalenessCache_atExactThreshold_doesNotNeedRefresh() {
        let cache = MockStalenessCache()
        cache.load()

        // Set last load to just under 5 minutes ago (299 seconds)
        // Using 299s instead of exactly 300s to avoid timing flakiness
        cache.setLastLoadTime(Date().addingTimeInterval(-299))

        // > not >= so at or under threshold is not stale
        XCTAssertFalse(cache.needsRefresh)
    }

    func testStalenessCache_markNeedsRefresh_keepsLoadedState() {
        let cache = MockStalenessCache()
        cache.load()
        XCTAssertTrue(cache.isLoaded)

        cache.markNeedsRefresh()

        // isLoaded stays true, but needsRefresh becomes true
        XCTAssertTrue(cache.isLoaded)
        XCTAssertTrue(cache.needsRefresh)
    }

    func testStalenessCache_markNeedsRefresh_tracksCallCount() {
        let cache = MockStalenessCache()

        cache.markNeedsRefresh()
        XCTAssertEqual(cache.markNeedsRefreshCallCount, 1)

        cache.markNeedsRefresh()
        XCTAssertEqual(cache.markNeedsRefreshCallCount, 2)
    }

    func testStalenessCache_invalidate_resetsEverything() {
        let cache = MockStalenessCache()
        cache.load()
        XCTAssertTrue(cache.isLoaded)
        XCTAssertFalse(cache.needsRefresh)

        cache.invalidate()

        XCTAssertFalse(cache.isLoaded)
        XCTAssertTrue(cache.needsRefresh)
    }

    // MARK: - TTL Cache Tests

    func testTTLCache_defaultIsLoaded_returnsTrue() {
        let cache = MockTTLCache()
        XCTAssertTrue(cache.isLoaded)
    }

    func testTTLCache_clearAll_removesAllEntries() {
        let cache = MockTTLCache()
        cache.addEntry(key: "key1", ttl: 3600)
        cache.addEntry(key: "key2", ttl: 3600)
        XCTAssertEqual(cache.entries.count, 2)

        cache.clearAll()
        XCTAssertTrue(cache.entries.isEmpty)
    }

    func testTTLCache_clearAll_tracksCallCount() {
        let cache = MockTTLCache()

        cache.clearAll()
        XCTAssertEqual(cache.clearAllCallCount, 1)

        cache.clearAll()
        XCTAssertEqual(cache.clearAllCallCount, 2)
    }

    func testTTLCache_clearExpired_keepsValidEntries() {
        let cache = MockTTLCache()
        cache.addEntry(key: "valid", ttl: 3600) // 1 hour from now
        cache.entries["expired"] = Date().addingTimeInterval(-60) // Already expired

        cache.clearExpired()

        XCTAssertEqual(cache.entries.count, 1)
        XCTAssertNotNil(cache.entries["valid"])
        XCTAssertNil(cache.entries["expired"])
    }

    func testTTLCache_clearExpired_removesAllExpired() {
        let cache = MockTTLCache()
        cache.entries["expired1"] = Date().addingTimeInterval(-60)
        cache.entries["expired2"] = Date().addingTimeInterval(-120)

        cache.clearExpired()

        XCTAssertTrue(cache.entries.isEmpty)
    }

    func testTTLCache_clearExpired_tracksCallCount() {
        let cache = MockTTLCache()

        cache.clearExpired()
        XCTAssertEqual(cache.clearExpiredCallCount, 1)

        cache.clearExpired()
        XCTAssertEqual(cache.clearExpiredCallCount, 2)
    }

    func testTTLCache_invalidate_callsClearAll() {
        let cache = MockTTLCache()
        cache.addEntry(key: "key1", ttl: 3600)

        cache.invalidate()

        XCTAssertTrue(cache.entries.isEmpty)
        XCTAssertEqual(cache.invalidateCallCount, 1)
        XCTAssertEqual(cache.clearAllCallCount, 1)
    }

    // MARK: - Protocol Casting Tests

    func testBasicCache_canBeCastToCacheProtocol() {
        let cache = MockBasicCache()
        let protocolRef: any CacheProtocol = cache

        XCTAssertFalse(protocolRef.isLoaded)
        protocolRef.invalidate()
        XCTAssertEqual(cache.invalidateCallCount, 1)
    }

    func testStalenessCache_canBeCastToStalenessCheckingCache() {
        let cache = MockStalenessCache()
        let protocolRef: any StalenessCheckingCache = cache

        XCTAssertTrue(protocolRef.needsRefresh)
        protocolRef.markNeedsRefresh()
        XCTAssertEqual(cache.markNeedsRefreshCallCount, 1)
    }

    func testStalenessCache_canBeCastToCacheProtocol() {
        let cache = MockStalenessCache()
        let protocolRef: any CacheProtocol = cache

        XCTAssertFalse(protocolRef.isLoaded)
        protocolRef.invalidate()
        XCTAssertEqual(cache.invalidateCallCount, 1)
    }

    func testTTLCache_canBeCastToTTLCache() {
        let cache = MockTTLCache()
        let protocolRef: any TTLCache = cache

        protocolRef.clearAll()
        protocolRef.clearExpired()

        XCTAssertEqual(cache.clearAllCallCount, 1)
        XCTAssertEqual(cache.clearExpiredCallCount, 1)
    }

    func testTTLCache_canBeCastToCacheProtocol() {
        let cache = MockTTLCache()
        let protocolRef: any CacheProtocol = cache

        XCTAssertTrue(protocolRef.isLoaded) // Default implementation
        protocolRef.invalidate()
        XCTAssertEqual(cache.invalidateCallCount, 1)
    }

    // MARK: - Array of Mixed Cache Types Tests

    func testMixedCacheTypes_canBeStoredInArray() {
        let basicCache = MockBasicCache()
        let stalenessCache = MockStalenessCache()
        let ttlCache = MockTTLCache()

        let caches: [any CacheProtocol] = [basicCache, stalenessCache, ttlCache]

        // All can be invalidated through protocol
        for cache in caches {
            cache.invalidate()
        }

        XCTAssertEqual(basicCache.invalidateCallCount, 1)
        XCTAssertEqual(stalenessCache.invalidateCallCount, 1)
        XCTAssertEqual(ttlCache.invalidateCallCount, 1)
    }
}
