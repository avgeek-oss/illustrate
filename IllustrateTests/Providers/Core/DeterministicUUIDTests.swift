// MARK: - DeterministicUUIDTests.swift

// Workflow tests for UUID.deterministicUUID(from:) which uses SHA256 hashing
// to generate consistent UUIDs from string inputs.
//
// Tests cover:
// - Determinism: same input always produces same UUID
// - Uniqueness: different inputs produce different UUIDs
// - Edge cases: empty strings, very long strings, unicode
// - Real-world workflows: provider key generation, batch uniqueness

import XCTest
@testable import IllustrateProviders

final class DeterministicUUIDTests: XCTestCase {
    // MARK: - Determinism Tests

    func testDeterministic_SameInput_SameOutput() {
        let uuid1 = UUID.deterministicUUID(from: "test-string")
        let uuid2 = UUID.deterministicUUID(from: "test-string")
        XCTAssertEqual(uuid1, uuid2)
    }

    func testDeterministic_DifferentInputs_DifferentOutputs() {
        let uuid1 = UUID.deterministicUUID(from: "input-a")
        let uuid2 = UUID.deterministicUUID(from: "input-b")
        XCTAssertNotEqual(uuid1, uuid2)
    }

    func testDeterministic_EmptyString_ProducesValidUUID() {
        let uuid = UUID.deterministicUUID(from: "")
        XCTAssertNotEqual(uuid.uuidString, "00000000-0000-0000-0000-000000000000")
    }

    func testDeterministic_LongString_ProducesValidUUID() {
        let longString = String(repeating: "a", count: 10000)
        let uuid = UUID.deterministicUUID(from: longString)
        // Verify it's a valid UUID by round-tripping through string
        XCTAssertNotNil(UUID(uuidString: uuid.uuidString))
    }

    func testDeterministic_UnicodeString_ProducesValidUUID() {
        let uuid = UUID.deterministicUUID(from: "Hello")
        XCTAssertNotNil(UUID(uuidString: uuid.uuidString))
    }

    // MARK: - UUID Format Tests

    func testFormat_ValidUUID_RoundTrip() {
        let uuid = UUID.deterministicUUID(from: "format-test")
        let uuidString = uuid.uuidString
        let parsed = UUID(uuidString: uuidString)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed, uuid)
    }

    func testFormat_MatchesStandardFormat() {
        let uuid = UUID.deterministicUUID(from: "format-check")
        let uuidString = uuid.uuidString
        // UUID format: 8-4-4-4-12 hex characters
        let pattern = #"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$"#
        XCTAssertTrue(
            uuidString.range(of: pattern, options: .regularExpression) != nil,
            "UUID '\(uuidString)' doesn't match standard format"
        )
    }

    func testFormat_NotAllZeros() {
        let inputs = ["a", "b", "test", "provider-openai", ""]
        for input in inputs {
            let uuid = UUID.deterministicUUID(from: input)
            XCTAssertNotEqual(
                uuid.uuidString,
                "00000000-0000-0000-0000-000000000000",
                "UUID from '\(input)' should not be all zeros"
            )
        }
    }

    func testFormat_ConsistentCasing() {
        // Same input should always produce the same UUID string
        let uuid1 = UUID.deterministicUUID(from: "casing-test")
        let uuid2 = UUID.deterministicUUID(from: "casing-test")
        XCTAssertEqual(uuid1.uuidString, uuid2.uuidString)
    }

    // MARK: - Workflow Tests

    func testWorkflow_ProviderKeyGeneration() {
        // Simulate real-world provider identification
        let providerKey = UUID.deterministicUUID(from: "provider-openai-dalle3")
        XCTAssertNotNil(UUID(uuidString: providerKey.uuidString))
        // Calling again with same key should be identical (idempotent)
        let sameKey = UUID.deterministicUUID(from: "provider-openai-dalle3")
        XCTAssertEqual(providerKey, sameKey)
    }

    func testWorkflow_MultipleProviders_UniqueStableIds() {
        let providers = [
            "provider-openai-dalle3",
            "provider-stability-core",
            "provider-google-gemini",
            "provider-fal-flux",
            "provider-replicate-sdxl",
        ]
        var uuids: [UUID] = []
        for provider in providers {
            let uuid = UUID.deterministicUUID(from: provider)
            uuids.append(uuid)
        }
        // All UUIDs should be unique
        let uniqueSet = Set(uuids)
        XCTAssertEqual(uniqueSet.count, providers.count, "Each provider should have a unique UUID")

        // Each should be stable across calls
        for (index, provider) in providers.enumerated() {
            let uuid = UUID.deterministicUUID(from: provider)
            XCTAssertEqual(uuid, uuids[index], "UUID for '\(provider)' should be stable")
        }
    }

    func testWorkflow_BatchUniqueness_100Strings() {
        var uuids = Set<UUID>()
        for i in 0 ..< 100 {
            let uuid = UUID.deterministicUUID(from: "batch-item-\(i)")
            uuids.insert(uuid)
        }
        XCTAssertEqual(uuids.count, 100, "All 100 UUIDs should be unique")
    }

    func testWorkflow_SimilarStrings_DifferentUUIDs() {
        // Even very similar strings should produce completely different UUIDs
        let uuid1 = UUID.deterministicUUID(from: "model-v1")
        let uuid2 = UUID.deterministicUUID(from: "model-v2")
        XCTAssertNotEqual(uuid1, uuid2)
    }
}
