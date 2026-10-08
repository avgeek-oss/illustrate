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

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

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
public class GeminiFileUriCache: @unchecked Sendable {
    public static let shared = GeminiFileUriCache()

    /// TTL for cached entries (24 hours for safety, Google expires at 48h)
    private let fileTTL: TimeInterval = 24 * 60 * 60

    /// In-memory cache storage
    private var cache: [String: GeminiCacheEntry] = [:]

    /// Lock for thread-safe access
    private let lock = NSLock()

    private init() {}

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
    public func getOrUpload(
        cacheKey: String?,
        imageData: Data,
        mimeType: String,
        apiKey: String,
        displayName: String
    ) async throws -> GeminiUploadedFile {
        let key = cacheKey ?? generateKey(from: imageData)

        // Check cache first
        if let entry = getCachedEntry(for: key), entry.isValid {
            return GeminiUploadedFile(
                uri: entry.uri,
                mimeType: entry.mimeType,
                name: entry.name
            )
        }

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
    public func getOrUploadBase64(
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
    public func generateKey(from data: Data) -> String {
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        return "sha256_\(hashString)"
    }

    /// Clears all cached entries.
    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }

        cache.removeAll()
    }

    /// Clears expired entries from the cache.
    public func clearExpired() {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        cache = cache.filter { $0.value.expiresAt > now }
    }

    /// Invalidates a specific cache entry.
    ///
    /// - Parameter key: The cache key to invalidate
    public func invalidate(key: String) {
        lock.lock()
        defer { lock.unlock() }

        cache.removeValue(forKey: key)
    }

    /// Checks if a cache entry exists and is valid for the given key.
    ///
    /// - Parameter key: The cache key to check
    /// - Returns: True if the entry exists and is not expired
    public func hasValidEntry(for key: String) -> Bool {
        guard let entry = getCachedEntry(for: key) else { return false }
        return entry.isValid
    }

    /// Checks if a cache entry exists and is valid for image data.
    ///
    /// - Parameter imageData: Image data to generate cache key from
    /// - Returns: True if the entry exists and is not expired
    public func hasValidEntry(for imageData: Data) -> Bool {
        let key = generateKey(from: imageData)
        return hasValidEntry(for: key)
    }

    // MARK: - Private Methods

    private func getCachedEntry(for key: String) -> GeminiCacheEntry? {
        lock.lock()
        defer { lock.unlock() }

        guard let entry = cache[key] else { return nil }

        // Remove if expired
        if !entry.isValid {
            cache.removeValue(forKey: key)
            return nil
        }

        return entry
    }

    private func setCachedEntry(_ entry: GeminiCacheEntry, for key: String) {
        lock.lock()
        defer { lock.unlock() }

        cache[key] = entry
    }
}
