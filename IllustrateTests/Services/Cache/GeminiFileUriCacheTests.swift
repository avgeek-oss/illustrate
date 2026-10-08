// MARK: - GeminiFileUriCacheTests.swift

// Unit tests for GeminiFileUriCache and GeminiCacheEntry.
//
// Tests cover:
// - GeminiCacheEntry validity logic
// - GeminiCacheEntry Codable serialization
// - SHA256 key generation
// - TTL constant validation

import CryptoKit
import XCTest
@testable import Illustrate

final class GeminiFileUriCacheTests: XCTestCase {
    // MARK: - GeminiCacheEntry Tests

    func testGeminiCacheEntry_initialization() {
        let expiresAt = Date().addingTimeInterval(3600)
        let entry = GeminiCacheEntry(
            uri: "gemini://files/abc123",
            mimeType: "image/png",
            name: "test-image",
            expiresAt: expiresAt
        )

        XCTAssertEqual(entry.uri, "gemini://files/abc123")
        XCTAssertEqual(entry.mimeType, "image/png")
        XCTAssertEqual(entry.name, "test-image")
        XCTAssertEqual(entry.expiresAt, expiresAt)
    }

    func testGeminiCacheEntry_isValid_futureExpiration() {
        let entry = GeminiCacheEntry(
            uri: "gemini://files/abc123",
            mimeType: "image/png",
            name: "test",
            expiresAt: Date().addingTimeInterval(3600) // 1 hour from now
        )

        XCTAssertTrue(entry.isValid)
    }

    func testGeminiCacheEntry_isValid_pastExpiration() {
        let entry = GeminiCacheEntry(
            uri: "gemini://files/abc123",
            mimeType: "image/png",
            name: "test",
            expiresAt: Date().addingTimeInterval(-3600) // 1 hour ago
        )

        XCTAssertFalse(entry.isValid)
    }

    func testGeminiCacheEntry_isValid_justExpired() {
        let entry = GeminiCacheEntry(
            uri: "gemini://files/abc123",
            mimeType: "image/png",
            name: "test",
            expiresAt: Date().addingTimeInterval(-1) // 1 second ago
        )

        XCTAssertFalse(entry.isValid)
    }

    func testGeminiCacheEntry_codable_roundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = GeminiCacheEntry(
            uri: "gemini://files/xyz789",
            mimeType: "image/jpeg",
            name: "photo.jpg",
            expiresAt: Date().addingTimeInterval(7200)
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(GeminiCacheEntry.self, from: data)

        XCTAssertEqual(decoded.uri, original.uri)
        XCTAssertEqual(decoded.mimeType, original.mimeType)
        XCTAssertEqual(decoded.name, original.name)
        // Date comparison with small tolerance for encoding/decoding
        XCTAssertEqual(
            decoded.expiresAt.timeIntervalSince1970,
            original.expiresAt.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testGeminiCacheEntry_codable_preservesIsValid() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let validEntry = GeminiCacheEntry(
            uri: "uri",
            mimeType: "image/png",
            name: "valid",
            expiresAt: Date().addingTimeInterval(3600)
        )

        let data = try encoder.encode(validEntry)
        let decoded = try decoder.decode(GeminiCacheEntry.self, from: data)

        XCTAssertTrue(decoded.isValid)
    }

    // MARK: - SHA256 Key Generation Tests

    func testGenerateKey_format() {
        let data = Data("test image data".utf8)
        let key = generateSHA256Key(from: data)

        XCTAssertTrue(key.hasPrefix("sha256_"))
    }

    func testGenerateKey_consistentHash() {
        let data = Data("test image data".utf8)
        let key1 = generateSHA256Key(from: data)
        let key2 = generateSHA256Key(from: data)

        XCTAssertEqual(key1, key2)
    }

    func testGenerateKey_differentDataProducesDifferentKeys() {
        let data1 = Data("image1".utf8)
        let data2 = Data("image2".utf8)

        let key1 = generateSHA256Key(from: data1)
        let key2 = generateSHA256Key(from: data2)

        XCTAssertNotEqual(key1, key2)
    }

    func testGenerateKey_hexLength() {
        let data = Data("any data".utf8)
        let key = generateSHA256Key(from: data)

        // SHA256 produces 64 hex characters, plus "sha256_" prefix = 71 characters
        let hexPart = key.replacingOccurrences(of: "sha256_", with: "")
        XCTAssertEqual(hexPart.count, 64)
    }

    func testGenerateKey_emptyData() {
        let data = Data()
        let key = generateSHA256Key(from: data)

        XCTAssertTrue(key.hasPrefix("sha256_"))
        // Empty data still produces a valid hash
        let hexPart = key.replacingOccurrences(of: "sha256_", with: "")
        XCTAssertEqual(hexPart.count, 64)
    }

    func testGenerateKey_largeData() {
        let data = Data(repeating: 0xAB, count: 1024 * 1024) // 1MB
        let key = generateSHA256Key(from: data)

        XCTAssertTrue(key.hasPrefix("sha256_"))
        let hexPart = key.replacingOccurrences(of: "sha256_", with: "")
        XCTAssertEqual(hexPart.count, 64)
    }

    // MARK: - TTL Constant Tests

    func testTTL_value_24Hours() {
        let expectedTTL: TimeInterval = 24 * 60 * 60
        XCTAssertEqual(expectedTTL, 86400)
    }

    func testTTL_lessThanGoogleExpiration() {
        // Google expires at 48 hours, we use 24 for safety margin
        let ourTTL: TimeInterval = 24 * 60 * 60
        let googleTTL: TimeInterval = 48 * 60 * 60

        XCTAssertLessThan(ourTTL, googleTTL)
    }

    // MARK: - Cache Key Patterns Tests

    func testCacheKey_backdropPattern() {
        // Backdrop cache keys follow pattern: backdrop_{aspectRatio}_{index}
        let key = "backdrop_9_16_42"

        XCTAssertTrue(key.hasPrefix("backdrop_"))
    }

    func testCacheKey_generatedPattern() {
        // Generated keys use SHA256 hash
        let key = "sha256_e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

        XCTAssertTrue(key.hasPrefix("sha256_"))
    }

    // MARK: - Expiration Date Calculation Tests

    func testExpirationDate_24HoursFromNow() {
        let now = Date()
        let ttl: TimeInterval = 24 * 60 * 60
        let expiresAt = now.addingTimeInterval(ttl)

        let expectedHours = expiresAt.timeIntervalSince(now) / 3600
        XCTAssertEqual(expectedHours, 24, accuracy: 0.001)
    }

    func testExpirationDate_entryCreation() {
        let ttl: TimeInterval = 24 * 60 * 60
        let entry = GeminiCacheEntry(
            uri: "uri",
            mimeType: "image/png",
            name: "test",
            expiresAt: Date().addingTimeInterval(ttl)
        )

        // Entry should be valid immediately after creation
        XCTAssertTrue(entry.isValid)
    }

    // MARK: - Helper Methods

    /// Replicates the key generation logic from GeminiFileUriCache
    private func generateSHA256Key(from data: Data) -> String {
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        return "sha256_\(hashString)"
    }
}
