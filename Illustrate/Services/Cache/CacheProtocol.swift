// MARK: - CacheProtocol.swift

// Common protocol definitions for cache implementations.
//
// This file defines a protocol hierarchy for the app's caching layer:
// - CacheProtocol: Basic cache with load state and invalidation
// - StalenessCheckingCache: Time-based staleness detection
// - TTLCache: Entry-level TTL expiration
//
// ## Cache Implementations
// - GalleryCache: StalenessCheckingCache (5-minute staleness)
// - ProviderKeysCache: CacheProtocol (notification-based invalidation only)
// - GeminiFileUriCache: TTLCache (24-hour entry TTL)

import Foundation

// MARK: - Base Cache Protocol

/// Common interface for cache implementations.
///
/// All caches in the app implement this protocol, which provides:
/// - `isLoaded`: Whether the cache has been populated
/// - `invalidate()`: Clear the cache and reset state
///
/// ## Usage
/// ```swift
/// if !cache.isLoaded {
///     cache.loadIfNeeded(...)
/// }
///
/// // When underlying data changes
/// cache.invalidate()
/// ```
@MainActor
protocol CacheProtocol {
    /// Whether the cache has been loaded with data.
    ///
    /// This is `false` after initialization and after `invalidate()` is called.
    var isLoaded: Bool { get }

    /// Invalidates the cache, clearing all data and resetting load state.
    ///
    /// After calling this method:
    /// - `isLoaded` returns `false`
    /// - Next access should trigger a reload
    func invalidate()
}

// MARK: - Staleness Checking Cache

/// Protocol for caches with time-based staleness detection.
///
/// Extends `CacheProtocol` with the ability to check if cached data
/// is stale (too old) and should be refreshed. This is useful for
/// data that changes over time but doesn't have explicit change notifications.
///
/// ## Example: GalleryCache
/// The gallery cache marks data as stale after 5 minutes, triggering
/// a background refresh on next access while still showing cached data.
///
/// ```swift
/// if cache.needsRefresh {
///     cache.markNeedsRefresh()
///     // Background refresh while showing cached data
/// }
/// ```
@MainActor
protocol StalenessCheckingCache: CacheProtocol {
    /// Whether the cached data is stale and should be refreshed.
    ///
    /// Returns `true` if:
    /// - The cache is not loaded
    /// - The time since last load exceeds the staleness threshold
    var needsRefresh: Bool { get }

    /// Marks the cache as needing refresh without clearing data.
    ///
    /// Unlike `invalidate()`, this keeps existing data visible while
    /// signaling that a refresh should occur on next opportunity.
    /// This provides a better UX by avoiding loading states.
    func markNeedsRefresh()
}

// MARK: - TTL Cache

/// Protocol for caches with entry-level TTL (time-to-live) expiration.
///
/// Unlike `StalenessCheckingCache` which tracks staleness for the entire
/// cache, `TTLCache` manages expiration on a per-entry basis. Each cached
/// item has its own expiration time.
///
/// ## Example: GeminiFileUriCache
/// Gemini file URIs expire after 48 hours (Google's limit). The cache
/// uses a 24-hour TTL for safety margin, automatically removing expired
/// entries on access.
///
/// ```swift
/// // Clear all entries when API key changes
/// cache.clearAll()
///
/// // Periodic cleanup of expired entries
/// cache.clearExpired()
/// ```
@MainActor
protocol TTLCache: CacheProtocol {
    /// Clears all cached entries regardless of expiration.
    ///
    /// Use this when the underlying data source changes entirely
    /// (e.g., API key rotation).
    func clearAll()

    /// Clears only expired entries from the cache.
    ///
    /// This is a maintenance operation that can be called periodically
    /// to free memory without affecting valid entries.
    func clearExpired()
}

// MARK: - Extension for TTLCache isLoaded

/// Default implementation for TTL caches that are always "loaded"
/// since they manage entries individually rather than bulk loading.
extension TTLCache {
    /// TTL caches don't have a bulk load phase - they're always ready.
    ///
    /// Individual entries are loaded on-demand and expire based on TTL.
    /// This default returns `true` unless the conforming type overrides it.
    var isLoaded: Bool {
        true
    }
}
