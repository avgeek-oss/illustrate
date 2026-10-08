// MARK: - GeminiFileUriCache.swift

// Cache for Google Gemini file URIs to avoid redundant uploads.
//
// When uploading images to Google's Files API, the returned file URIs
// can be reused within their validity period (48 hours). This cache
// stores URIs with a 24-hour safety margin to avoid edge cases.
//
// ## Caching Strategy
// - Explicit keys for known static resources (e.g., backdrops)
// - SHA256 content hash for dynamic images (e.g., product objects)
// - 24-hour TTL with automatic expiration checks
// - Persists to UserDefaults for app restart survival
//
// ## Cache Invalidation
// The cache is cleared when Google provider API keys change
// (via .providerKeysChanged notification).

import CryptoKit
import Foundation
import OSLog

// MARK: - Cache Entry

/// A cached Gemini file URI with expiration metadata.
struct GeminiCacheEntry: Codable {
    let uri: String
    let mimeType: String
    let name: String
    let expiresAt: Date

    /// Whether this cache entry is still valid (not expired).
    var isValid: Bool {
        Date() < expiresAt
    }
}

// MARK: - GeminiFileUriCache

/// Caches Gemini file URIs to avoid redundant uploads for static resources.
///
/// Conforms to `TTLCache` for entry-level TTL expiration (24 hours).
/// Listens for provider key changes and clears the cache when Google
/// API keys are added or removed.
class GeminiFileUriCache {
    static let shared = GeminiFileUriCache()

    /// TTL for cached entries (24 hours for safety, Google expires at 48h)
    private let fileTTL: TimeInterval = 24 * 60 * 60

    /// UserDefaults key for persisted cache
    private let persistenceKey = "GeminiFileUriCache"

    /// In-memory cache storage
    private var cache: [String: GeminiCacheEntry] = [:]

    /// Lock for thread-safe access
    private let lock = NSLock()

    /// Notification observer for provider key changes
    private var notificationObserver: Any?

    private init() {
        loadFromDisk()

        // Listen for provider key changes to invalidate cache
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .providerKeysChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearAll()
        }
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    /// Gets a cached file URI or uploads the image and caches the result.
    ///
    /// - Parameters:
    ///   - cacheKey: Explicit cache key (e.g., "backdrop_9_16_42"). If nil, generates SHA256 hash from image data.
    ///   - imageData: Raw image data to upload if not cached
    ///   - mimeType: MIME type of the image
    ///   - apiKey: Google API key for upload
    ///   - displayName: Display name for the uploaded file
    /// - Returns: GeminiUploadedFile with URI and metadata
    func getOrUpload(
        cacheKey: String?,
        imageData: Data,
        mimeType: String,
        apiKey: String,
        displayName: String
    ) async throws -> GeminiUploadedFile {
        let key = cacheKey ?? generateKey(from: imageData)

        // Check cache first
        if let entry = getCachedEntry(for: key), entry.isValid {
            AppLogger.cache.debug("GeminiUriCache: Cache hit for key: \(key, privacy: .public)")
            return GeminiUploadedFile(
                uri: entry.uri,
                mimeType: entry.mimeType,
                name: entry.name
            )
        }

        AppLogger.cache.debug("GeminiUriCache: Cache miss for key: \(key, privacy: .public), uploading...")
        // Upload and cache
        let uploaded = try await GeminiFilesService.shared.uploadImage(
            imageData: imageData,
            mimeType: mimeType,
            apiKey: apiKey,
            displayName: displayName
        )

        let entry = GeminiCacheEntry(
            uri: uploaded.uri,
            mimeType: uploaded.mimeType,
            name: uploaded.name,
            expiresAt: Date().addingTimeInterval(fileTTL)
        )
        setCachedEntry(entry, for: key)

        return uploaded
    }

    /// Gets a cached file URI or uploads from base64 and caches the result.
    ///
    /// - Parameters:
    ///   - cacheKey: Explicit cache key. If nil, generates SHA256 hash from decoded image data.
    ///   - base64Image: Base64-encoded image (with or without data URI prefix)
    ///   - mimeType: MIME type of the image
    ///   - apiKey: Google API key for upload
    ///   - displayName: Display name for the uploaded file
    /// - Returns: GeminiUploadedFile with URI and metadata
    func getOrUploadBase64(
        cacheKey: String?,
        base64Image: String,
        mimeType: String,
        apiKey: String,
        displayName: String
    ) async throws -> GeminiUploadedFile {
        let cleanBase64 = base64Image.replacingOccurrences(
            of: "^data:.*;base64,",
            with: "",
            options: .regularExpression
        )

        guard let imageData = Data(base64Encoded: cleanBase64) else {
            throw GeminiFilesError.invalidBase64Data
        }

        return try await getOrUpload(
            cacheKey: cacheKey,
            imageData: imageData,
            mimeType: mimeType,
            apiKey: apiKey,
            displayName: displayName
        )
    }

    /// Generates a cache key from image data using SHA256 hash.
    ///
    /// - Parameter data: Image data to hash
    /// - Returns: Cache key in format "sha256_<hex>"
    func generateKey(from data: Data) -> String {
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        return "sha256_\(hashString)"
    }

    /// Invalidates the entire cache, clearing all entries.
    ///
    /// Conforms to `CacheProtocol.invalidate()`. Equivalent to `clearAll()`.
    func invalidate() {
        clearAll()
    }

    /// Clears all cached entries.
    func clearAll() {
        lock.lock()
        defer { lock.unlock() }

        cache.removeAll()
        saveToDisk()
    }

    /// Clears expired entries from the cache.
    func clearExpired() {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        cache = cache.filter { $0.value.expiresAt > now }
        saveToDisk()
    }

    /// Invalidates a specific cache entry.
    ///
    /// - Parameter key: The cache key to invalidate
    func invalidate(key: String) {
        lock.lock()
        defer { lock.unlock() }

        cache.removeValue(forKey: key)
        saveToDisk()
    }

    /// Checks if a cache entry exists and is valid for the given key.
    ///
    /// - Parameter key: The cache key to check
    /// - Returns: True if the entry exists and is not expired
    func hasValidEntry(for key: String) -> Bool {
        guard let entry = getCachedEntry(for: key) else { return false }
        return entry.isValid
    }

    /// Checks if a cache entry exists and is valid for image data.
    ///
    /// - Parameter imageData: Image data to generate cache key from
    /// - Returns: True if the entry exists and is not expired
    func hasValidEntry(for imageData: Data) -> Bool {
        let key = generateKey(from: imageData)
        return hasValidEntry(for: key)
    }

    // MARK: - Pre-warming

    /// Pre-warms the cache by uploading an image in the background.
    ///
    /// This is a fire-and-forget method that uploads the image to Google's Files API
    /// and caches the result. Use this to pre-upload images before they're needed
    /// (e.g., when user selects a backdrop or uploads an object).
    ///
    /// - Parameters:
    ///   - cacheKey: Explicit cache key. If nil, generates SHA256 hash from image data.
    ///   - imageData: Raw image data to upload
    ///   - mimeType: MIME type of the image (defaults to "image/png")
    ///   - apiKey: Google API key for upload
    ///   - displayName: Display name for the uploaded file
    func prewarm(
        cacheKey: String?,
        imageData: Data,
        mimeType: String = "image/png",
        apiKey: String,
        displayName: String
    ) {
        let key = cacheKey ?? generateKey(from: imageData)

        // Skip if already cached and valid
        if hasValidEntry(for: key) {
            return
        }

        // Upload in background, fire-and-forget
        Task.detached(priority: .utility) { [weak self] in
            do {
                _ = try await self?.getOrUpload(
                    cacheKey: cacheKey,
                    imageData: imageData,
                    mimeType: mimeType,
                    apiKey: apiKey,
                    displayName: displayName
                )
            } catch {
                // Silently fail - pre-warming is best-effort
            }
        }
    }

    /// Pre-warms the cache by uploading a base64 image in the background.
    ///
    /// - Parameters:
    ///   - cacheKey: Explicit cache key. If nil, generates SHA256 hash from decoded image data.
    ///   - base64Image: Base64-encoded image (with or without data URI prefix)
    ///   - mimeType: MIME type of the image (defaults to "image/png")
    ///   - apiKey: Google API key for upload
    ///   - displayName: Display name for the uploaded file
    func prewarmBase64(
        cacheKey: String?,
        base64Image: String,
        mimeType: String = "image/png",
        apiKey: String,
        displayName: String
    ) {
        let cleanBase64 = base64Image.replacingOccurrences(
            of: "^data:.*;base64,",
            with: "",
            options: .regularExpression
        )

        guard let imageData = Data(base64Encoded: cleanBase64) else {
            return // Silently fail for invalid base64
        }

        prewarm(
            cacheKey: cacheKey,
            imageData: imageData,
            mimeType: mimeType,
            apiKey: apiKey,
            displayName: displayName
        )
    }

    // MARK: - Private Methods

    private func getCachedEntry(for key: String) -> GeminiCacheEntry? {
        lock.lock()
        defer { lock.unlock() }

        guard let entry = cache[key] else { return nil }

        // Remove if expired
        if !entry.isValid {
            cache.removeValue(forKey: key)
            saveToDisk()
            return nil
        }

        return entry
    }

    private func setCachedEntry(_ entry: GeminiCacheEntry, for key: String) {
        lock.lock()
        defer { lock.unlock() }

        cache[key] = entry
        saveToDisk()
    }

    private func loadFromDisk() {
        lock.lock()
        defer { lock.unlock() }

        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else {
            return
        }

        do {
            let decoded = try JSONDecoder().decode([String: GeminiCacheEntry].self, from: data)
            // Filter out expired entries on load
            let now = Date()
            cache = decoded.filter { $0.value.expiresAt > now }
        } catch {
            // If decoding fails, start fresh
            cache = [:]
        }
    }

    private func saveToDisk() {
        // Note: lock should already be held by caller
        do {
            let data = try JSONEncoder().encode(cache)
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            // Silently fail - cache is best-effort
        }
    }
}
