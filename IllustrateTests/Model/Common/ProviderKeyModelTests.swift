// MARK: - ProviderKeyModelTests.swift

// Tests for the ProviderKey model - provider-to-project associations.
//
// Tests cover:
// - ProviderKey initialization with default and custom project IDs
// - Codable round-trip serialization
// - Decode with missing projectId defaults to Project.defaultProjectId
// - Multiple instance consistency

import Foundation
import XCTest
@testable import Illustrate

final class ProviderKeyModelTests: XCTestCase {
    // MARK: - Initialization

    func testProviderKey_init_setsProviderId() {
        let providerId = UUID()
        let key = ProviderKey(providerId: providerId)
        XCTAssertEqual(key.providerId, providerId)
    }

    func testProviderKey_init_defaultProjectId() {
        let key = ProviderKey(providerId: UUID())
        XCTAssertEqual(key.projectId, Project.defaultProjectId)
    }

    func testProviderKey_init_customProjectId() {
        let projectId = UUID()
        let key = ProviderKey(providerId: UUID(), projectId: projectId)
        XCTAssertEqual(key.projectId, projectId)
    }

    func testProviderKey_init_createdAtIsSet() {
        let before = Date()
        let key = ProviderKey(providerId: UUID())
        let after = Date()
        XCTAssertGreaterThanOrEqual(key.createdAt, before)
        XCTAssertLessThanOrEqual(key.createdAt, after)
    }

    // MARK: - Codable Round-Trip

    func testProviderKey_codableRoundTrip_preservesAllFields() throws {
        let providerId = UUID()
        let projectId = UUID()
        let key = ProviderKey(providerId: providerId, projectId: projectId)

        let data = try JSONEncoder().encode(key)
        let restored = try JSONDecoder().decode(ProviderKey.self, from: data)

        XCTAssertEqual(restored.providerId, providerId)
        XCTAssertEqual(restored.projectId, projectId)
    }

    func testProviderKey_codableRoundTrip_preservesProviderId() throws {
        let providerId = UUID()
        let key = ProviderKey(providerId: providerId)

        let data = try JSONEncoder().encode(key)
        let restored = try JSONDecoder().decode(ProviderKey.self, from: data)

        XCTAssertEqual(restored.providerId, providerId)
    }

    func testProviderKey_codableRoundTrip_preservesProjectId() throws {
        let projectId = UUID()
        let key = ProviderKey(providerId: UUID(), projectId: projectId)

        let data = try JSONEncoder().encode(key)
        let restored = try JSONDecoder().decode(ProviderKey.self, from: data)

        XCTAssertEqual(restored.projectId, projectId)
    }

    func testProviderKey_codableRoundTrip_preservesCreatedAt() throws {
        let key = ProviderKey(providerId: UUID())

        let data = try JSONEncoder().encode(key)
        let restored = try JSONDecoder().decode(ProviderKey.self, from: data)

        XCTAssertEqual(
            restored.createdAt.timeIntervalSinceReferenceDate,
            key.createdAt.timeIntervalSinceReferenceDate,
            accuracy: 0.001
        )
    }

    // MARK: - Decode with Missing Optional Fields

    func testProviderKey_decode_missingProjectId_defaultsToDefaultProjectId() throws {
        let providerId = UUID()
        let json: [String: Any] = [
            "providerId": providerId.uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(ProviderKey.self, from: data)

        XCTAssertEqual(restored.providerId, providerId)
        XCTAssertEqual(restored.projectId, Project.defaultProjectId)
    }

    func testProviderKey_decode_withProjectId_usesProvided() throws {
        let providerId = UUID()
        let projectId = UUID()
        let json: [String: Any] = [
            "providerId": providerId.uuidString,
            "projectId": projectId.uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(ProviderKey.self, from: data)

        XCTAssertEqual(restored.projectId, projectId)
    }

    // MARK: - Multiple Instances

    func testProviderKey_twoKeys_sameProvider_differentCreatedAt() {
        let providerId = UUID()
        let key1 = ProviderKey(providerId: providerId, createdAt: Date(timeIntervalSince1970: 1000))
        let key2 = ProviderKey(providerId: providerId, createdAt: Date(timeIntervalSince1970: 2000))

        XCTAssertEqual(key1.providerId, key2.providerId)
        XCTAssertNotEqual(key1.createdAt, key2.createdAt)
    }

    func testProviderKey_defaultProjectId_matchesProjectDefault() {
        let key = ProviderKey(providerId: UUID())
        XCTAssertEqual(key.projectId, Project.defaultProjectId)
    }

    func testProviderKey_codableRoundTrip_afterModifyingProjectId() throws {
        let key = ProviderKey(providerId: UUID())
        let newProjectId = UUID()
        key.projectId = newProjectId

        let data = try JSONEncoder().encode(key)
        let restored = try JSONDecoder().decode(ProviderKey.self, from: data)

        XCTAssertEqual(restored.projectId, newProjectId)
    }

    func testProviderKey_multipleEncodes_consistent() throws {
        let key = ProviderKey(providerId: UUID())
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data1 = try encoder.encode(key)
        let restored1 = try decoder.decode(ProviderKey.self, from: data1)
        let data2 = try encoder.encode(restored1)
        let restored2 = try decoder.decode(ProviderKey.self, from: data2)

        XCTAssertEqual(restored1.providerId, restored2.providerId)
        XCTAssertEqual(restored1.projectId, restored2.projectId)
    }

    func testProviderKey_decode_explicitDefaultProjectId_matches() throws {
        let providerId = UUID()
        let json: [String: Any] = [
            "providerId": providerId.uuidString,
            "projectId": Project.defaultProjectId.uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(ProviderKey.self, from: data)

        XCTAssertEqual(restored.projectId, Project.defaultProjectId)
    }

    func testProviderKey_customCreatedAt() {
        let specificDate = Date(timeIntervalSince1970: 1_700_000_000)
        let key = ProviderKey(providerId: UUID(), createdAt: specificDate)
        XCTAssertEqual(key.createdAt, specificDate)
    }
}
