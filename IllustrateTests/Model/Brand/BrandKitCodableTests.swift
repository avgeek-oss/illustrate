// MARK: - BrandKitCodableTests.swift

// Codable round-trip tests for BrandKit model.
//
// Existing BrandKitTests covers init, colors, images, modelAssets
// but has NO Codable round-trip tests. This fills that gap.
//
// Tests cover:
// - Full Codable round-trip preserving all fields
// - Decode with missing optional fields (all decodeIfPresent defaults)
// - Round-trip with non-empty brandColors, additionalColors
// - Round-trip with modelAssetsData and imageFileNames

import Foundation
import XCTest
@testable import Illustrate

final class BrandKitCodableTests: XCTestCase {
    // MARK: - Full Codable Round-Trip

    func testBrandKit_codableRoundTrip_preservesId() throws {
        let kit = BrandKit(brandName: "Test Brand")

        let data = try JSONEncoder().encode(kit)
        let restored = try JSONDecoder().decode(BrandKit.self, from: data)

        XCTAssertEqual(restored.id, kit.id)
    }

    func testBrandKit_codableRoundTrip_preservesProjectId() throws {
        let projectId = UUID()
        let kit = BrandKit(projectId: projectId)

        let data = try JSONEncoder().encode(kit)
        let restored = try JSONDecoder().decode(BrandKit.self, from: data)

        XCTAssertEqual(restored.projectId, projectId)
    }

    func testBrandKit_codableRoundTrip_preservesBrandDetails() throws {
        let kit = BrandKit(
            brandName: "Acme Corp",
            brandAbout: "We make everything",
            brandPersonality: "Bold and innovative"
        )

        let data = try JSONEncoder().encode(kit)
        let restored = try JSONDecoder().decode(BrandKit.self, from: data)

        XCTAssertEqual(restored.brandName, "Acme Corp")
        XCTAssertEqual(restored.brandAbout, "We make everything")
        XCTAssertEqual(restored.brandPersonality, "Bold and innovative")
    }

    func testBrandKit_codableRoundTrip_preservesBrandColors() throws {
        let colors: [String: String] = [
            BrandColorType.primary.rawValue: "#FF0000",
            BrandColorType.secondary.rawValue: "#00FF00",
            BrandColorType.accent.rawValue: "#0000FF",
            BrandColorType.background.rawValue: "#FFFFFF",
            BrandColorType.text.rawValue: "#000000",
        ]
        let kit = BrandKit(brandColors: colors)

        let data = try JSONEncoder().encode(kit)
        let restored = try JSONDecoder().decode(BrandKit.self, from: data)

        XCTAssertEqual(restored.brandColors, colors)
    }

    func testBrandKit_codableRoundTrip_preservesAdditionalColors() throws {
        let kit = BrandKit(additionalColors: ["#AABBCC", "#DDEEFF", "#112233"])

        let data = try JSONEncoder().encode(kit)
        let restored = try JSONDecoder().decode(BrandKit.self, from: data)

        XCTAssertEqual(restored.additionalColors, ["#AABBCC", "#DDEEFF", "#112233"])
    }

    func testBrandKit_codableRoundTrip_preservesFontFace() throws {
        let kit = BrandKit(fontFace: "Helvetica Neue")

        let data = try JSONEncoder().encode(kit)
        let restored = try JSONDecoder().decode(BrandKit.self, from: data)

        XCTAssertEqual(restored.fontFace, "Helvetica Neue")
    }

    func testBrandKit_codableRoundTrip_preservesImageFileNames() throws {
        let kit = BrandKit(imageFileNames: ["lightLogo": "light_abc", "darkLogo": "dark_xyz"])

        let data = try JSONEncoder().encode(kit)
        let restored = try JSONDecoder().decode(BrandKit.self, from: data)

        XCTAssertEqual(restored.imageFileNames["lightLogo"], "light_abc")
        XCTAssertEqual(restored.imageFileNames["darkLogo"], "dark_xyz")
    }

    func testBrandKit_codableRoundTrip_preservesModelAssets() throws {
        let assets = [
            ModelAsset(fileName: "ref_001"),
            ModelAsset(fileName: "ref_002"),
        ]
        let kit = BrandKit(modelAssets: assets)

        let data = try JSONEncoder().encode(kit)
        let restored = try JSONDecoder().decode(BrandKit.self, from: data)

        let restoredAssets = restored.modelAssets
        XCTAssertEqual(restoredAssets.count, 2)
        XCTAssertEqual(restoredAssets[0].fileName, "ref_001")
        XCTAssertEqual(restoredAssets[1].fileName, "ref_002")
    }

    // MARK: - Decode with Missing Optional Fields

    func testBrandKit_decode_missingProjectId_defaultsToDefault() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(BrandKit.self, from: data)
        XCTAssertEqual(restored.projectId, Project.defaultProjectId)
    }

    func testBrandKit_decode_missingBrandName_defaultsToEmpty() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(BrandKit.self, from: data)
        XCTAssertEqual(restored.brandName, "")
    }

    func testBrandKit_decode_missingBrandAbout_defaultsToEmpty() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(BrandKit.self, from: data)
        XCTAssertEqual(restored.brandAbout, "")
    }

    func testBrandKit_decode_missingBrandPersonality_defaultsToEmpty() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(BrandKit.self, from: data)
        XCTAssertEqual(restored.brandPersonality, "")
    }

    func testBrandKit_decode_missingBrandColors_defaultsToEmptyDict() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(BrandKit.self, from: data)
        XCTAssertTrue(restored.brandColors.isEmpty)
    }

    func testBrandKit_decode_missingFontFace_defaultsToNil() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(BrandKit.self, from: data)
        XCTAssertNil(restored.fontFace)
    }

    func testBrandKit_decode_missingImageFileNames_defaultsToEmptyDict() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(BrandKit.self, from: data)
        XCTAssertTrue(restored.imageFileNames.isEmpty)
    }

    func testBrandKit_decode_missingModelAssetsData_defaultsToEmptyData() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(BrandKit.self, from: data)
        XCTAssertTrue(restored.modelAssetsData.isEmpty)
    }

    func testBrandKit_decode_missingAdditionalColors_defaultsToEmptyArray() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(BrandKit.self, from: data)
        XCTAssertTrue(restored.additionalColors.isEmpty)
    }
}
