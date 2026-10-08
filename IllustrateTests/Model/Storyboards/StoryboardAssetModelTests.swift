// MARK: - StoryboardAssetModelTests.swift

// Tests for StoryboardAsset model - reference images for storyboard scenes.
//
// Tests cover:
// - Initialization with default and custom values
// - dimensionsString computed property edge cases
// - aspectRatio computed property edge cases
// - Codable round-trip serialization
// - Decode with missing optional fields (width, height)

import CoreGraphics
import Foundation
import XCTest
@testable import Illustrate

final class StoryboardAssetModelTests: XCTestCase {
    // MARK: - Initialization

    func testStoryboardAsset_init_setsStoryboardId() {
        let storyboardId = UUID()
        let asset = StoryboardAsset(storyboardId: storyboardId)
        XCTAssertEqual(asset.storyboardId, storyboardId)
    }

    func testStoryboardAsset_init_defaultNameIsUntitledAsset() {
        let asset = StoryboardAsset(storyboardId: UUID())
        XCTAssertEqual(asset.name, "Untitled Asset")
    }

    func testStoryboardAsset_init_customName() {
        let asset = StoryboardAsset(storyboardId: UUID(), name: "Hero Image")
        XCTAssertEqual(asset.name, "Hero Image")
    }

    func testStoryboardAsset_init_defaultWidthIs0() {
        let asset = StoryboardAsset(storyboardId: UUID())
        XCTAssertEqual(asset.width, 0)
    }

    func testStoryboardAsset_init_defaultHeightIs0() {
        let asset = StoryboardAsset(storyboardId: UUID())
        XCTAssertEqual(asset.height, 0)
    }

    func testStoryboardAsset_init_customDimensions() {
        let asset = StoryboardAsset(storyboardId: UUID(), width: 1920, height: 1080)
        XCTAssertEqual(asset.width, 1920)
        XCTAssertEqual(asset.height, 1080)
    }

    func testStoryboardAsset_init_createdAtIsSet() {
        let before = Date()
        let asset = StoryboardAsset(storyboardId: UUID())
        let after = Date()
        XCTAssertGreaterThanOrEqual(asset.createdAt, before)
        XCTAssertLessThanOrEqual(asset.createdAt, after)
    }

    // MARK: - dimensionsString Computed Property

    func testStoryboardAsset_dimensionsString_bothPositive_returnsFormatted() {
        let asset = StoryboardAsset(storyboardId: UUID(), width: 1024, height: 768)
        // Uses multiplication sign (×, U+00D7), not letter x
        XCTAssertEqual(asset.dimensionsString, "1024\u{00D7}768")
    }

    func testStoryboardAsset_dimensionsString_widthZero_returnsEmpty() {
        let asset = StoryboardAsset(storyboardId: UUID(), width: 0, height: 768)
        XCTAssertEqual(asset.dimensionsString, "")
    }

    func testStoryboardAsset_dimensionsString_heightZero_returnsEmpty() {
        let asset = StoryboardAsset(storyboardId: UUID(), width: 1024, height: 0)
        XCTAssertEqual(asset.dimensionsString, "")
    }

    func testStoryboardAsset_dimensionsString_bothZero_returnsEmpty() {
        let asset = StoryboardAsset(storyboardId: UUID())
        XCTAssertEqual(asset.dimensionsString, "")
    }

    func testStoryboardAsset_dimensionsString_largeDimensions() {
        let asset = StoryboardAsset(storyboardId: UUID(), width: 3840, height: 2160)
        XCTAssertEqual(asset.dimensionsString, "3840\u{00D7}2160")
    }

    // MARK: - aspectRatio Computed Property

    func testStoryboardAsset_aspectRatio_validDimensions_returnsRatio() {
        let asset = StoryboardAsset(storyboardId: UUID(), width: 1920, height: 1080)
        let expected: CGFloat = 1920.0 / 1080.0
        XCTAssertEqual(asset.aspectRatio, expected, accuracy: 0.001)
    }

    func testStoryboardAsset_aspectRatio_heightZero_defaults16by9() {
        let asset = StoryboardAsset(storyboardId: UUID(), width: 1024, height: 0)
        XCTAssertEqual(asset.aspectRatio, 16.0 / 9.0, accuracy: 0.001)
    }

    func testStoryboardAsset_aspectRatio_widthZero_defaults16by9() {
        let asset = StoryboardAsset(storyboardId: UUID(), width: 0, height: 768)
        XCTAssertEqual(asset.aspectRatio, 16.0 / 9.0, accuracy: 0.001)
    }

    func testStoryboardAsset_aspectRatio_bothZero_defaults16by9() {
        let asset = StoryboardAsset(storyboardId: UUID())
        XCTAssertEqual(asset.aspectRatio, 16.0 / 9.0, accuracy: 0.001)
    }

    func testStoryboardAsset_aspectRatio_squareImage_returns1() {
        let asset = StoryboardAsset(storyboardId: UUID(), width: 1024, height: 1024)
        XCTAssertEqual(asset.aspectRatio, 1.0, accuracy: 0.001)
    }

    func testStoryboardAsset_aspectRatio_tallImage_returnsLessThan1() {
        let asset = StoryboardAsset(storyboardId: UUID(), width: 768, height: 1024)
        XCTAssertLessThan(asset.aspectRatio, 1.0)
    }

    // MARK: - Codable Round-Trip

    func testStoryboardAsset_codableRoundTrip_preservesAllFields() throws {
        let storyboardId = UUID()
        let asset = StoryboardAsset(storyboardId: storyboardId, name: "Test Asset", width: 1920, height: 1080)

        let data = try JSONEncoder().encode(asset)
        let restored = try JSONDecoder().decode(StoryboardAsset.self, from: data)

        XCTAssertEqual(restored.id, asset.id)
        XCTAssertEqual(restored.storyboardId, storyboardId)
        XCTAssertEqual(restored.name, "Test Asset")
        XCTAssertEqual(restored.width, 1920)
        XCTAssertEqual(restored.height, 1080)
    }

    func testStoryboardAsset_decode_missingWidth_defaultsTo0() throws {
        let id = UUID()
        let storyboardId = UUID()
        let json: [String: Any] = [
            "id": id.uuidString,
            "storyboardId": storyboardId.uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "No Width",
            "height": 1080,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(StoryboardAsset.self, from: data)
        XCTAssertEqual(restored.width, 0)
        XCTAssertEqual(restored.height, 1080)
    }

    func testStoryboardAsset_decode_missingHeight_defaultsTo0() throws {
        let id = UUID()
        let storyboardId = UUID()
        let json: [String: Any] = [
            "id": id.uuidString,
            "storyboardId": storyboardId.uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "No Height",
            "width": 1920,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(StoryboardAsset.self, from: data)
        XCTAssertEqual(restored.width, 1920)
        XCTAssertEqual(restored.height, 0)
    }

    func testStoryboardAsset_decode_missingBothDimensions_defaultsTo0() throws {
        let id = UUID()
        let storyboardId = UUID()
        let json: [String: Any] = [
            "id": id.uuidString,
            "storyboardId": storyboardId.uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "No Dimensions",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(StoryboardAsset.self, from: data)
        XCTAssertEqual(restored.width, 0)
        XCTAssertEqual(restored.height, 0)
    }

    // MARK: - Identifiable

    func testStoryboardAsset_twoInstances_haveDifferentIds() {
        let storyboardId = UUID()
        let a1 = StoryboardAsset(storyboardId: storyboardId)
        let a2 = StoryboardAsset(storyboardId: storyboardId)
        XCTAssertNotEqual(a1.id, a2.id)
    }

    func testStoryboardAsset_identifiable_idIsStable() {
        let asset = StoryboardAsset(storyboardId: UUID())
        let first = asset.id
        let second = asset.id
        XCTAssertEqual(first, second)
    }
}
