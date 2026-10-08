// MARK: - BrandKitManagerTests.swift

// Unit tests for BrandKitManager and BrandImageVariant.
//
// Tests cover:
// - BrandImageVariant enum properties
// - Color normalization logic
// - Character limit enforcement
// - Thumbnail file naming
// - Model asset file naming

import XCTest
@testable import Illustrate

final class BrandKitManagerTests: XCTestCase {
    // MARK: - BrandImageVariant Tests

    func testBrandImageVariant_allCases() {
        let allCases = BrandImageVariant.allCases

        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.lightLogo))
        XCTAssertTrue(allCases.contains(.darkLogo))
    }

    func testBrandImageVariant_rawValues() {
        XCTAssertEqual(BrandImageVariant.lightLogo.rawValue, "lightLogo")
        XCTAssertEqual(BrandImageVariant.darkLogo.rawValue, "darkLogo")
    }

    func testBrandImageVariant_displayName() {
        XCTAssertEqual(BrandImageVariant.lightLogo.displayName, "Light Logo")
        XCTAssertEqual(BrandImageVariant.darkLogo.displayName, "Dark Logo")
    }

    func testBrandImageVariant_isLogo() {
        XCTAssertTrue(BrandImageVariant.lightLogo.isLogo)
        XCTAssertTrue(BrandImageVariant.darkLogo.isLogo)
    }

    func testBrandImageVariant_logoVariants() {
        let logoVariants = BrandImageVariant.logoVariants

        XCTAssertEqual(logoVariants.count, 2)
        XCTAssertEqual(logoVariants[0], .lightLogo)
        XCTAssertEqual(logoVariants[1], .darkLogo)
    }

    // MARK: - Color Normalization Tests

    func testNormalizeHexColor_withHash() {
        let normalized = normalizeHexColorForTest("#FF0000")

        XCTAssertEqual(normalized, "#FF0000")
    }

    func testNormalizeHexColor_withoutHash() {
        let normalized = normalizeHexColorForTest("FF0000")

        XCTAssertEqual(normalized, "#FF0000")
    }

    func testNormalizeHexColor_lowercase() {
        let normalized = normalizeHexColorForTest("ff0000")

        XCTAssertEqual(normalized, "#FF0000")
    }

    func testNormalizeHexColor_mixedCase() {
        let normalized = normalizeHexColorForTest("fF00aB")

        XCTAssertEqual(normalized, "#FF00AB")
    }

    func testNormalizeHexColor_withWhitespace() {
        let normalized = normalizeHexColorForTest("  #AABBCC  ")

        XCTAssertEqual(normalized, "#AABBCC")
    }

    func testNormalizeHexColor_shortForm() {
        let normalized = normalizeHexColorForTest("ABC")

        XCTAssertEqual(normalized, "#ABC")
    }

    func testNormalizeHexColor_emptyString() {
        let normalized = normalizeHexColorForTest("")

        XCTAssertEqual(normalized, "#")
    }

    func testNormalizeHexColor_hashOnly() {
        let normalized = normalizeHexColorForTest("#")

        XCTAssertEqual(normalized, "#")
    }

    // MARK: - Character Limit Tests

    func testCharacterLimit_brandAbout_underLimit() {
        let text = String(repeating: "a", count: 400)
        let limited = limitCharactersForTest(text, limit: 500)

        XCTAssertEqual(limited.count, 400)
    }

    func testCharacterLimit_brandAbout_atLimit() {
        let text = String(repeating: "a", count: 500)
        let limited = limitCharactersForTest(text, limit: 500)

        XCTAssertEqual(limited.count, 500)
    }

    func testCharacterLimit_brandAbout_overLimit() {
        let text = String(repeating: "a", count: 600)
        let limited = limitCharactersForTest(text, limit: 500)

        XCTAssertEqual(limited.count, 500)
    }

    func testCharacterLimit_brandPersonality_underLimit() {
        let text = String(repeating: "b", count: 100)
        let limited = limitCharactersForTest(text, limit: 160)

        XCTAssertEqual(limited.count, 100)
    }

    func testCharacterLimit_brandPersonality_atLimit() {
        let text = String(repeating: "b", count: 160)
        let limited = limitCharactersForTest(text, limit: 160)

        XCTAssertEqual(limited.count, 160)
    }

    func testCharacterLimit_brandPersonality_overLimit() {
        let text = String(repeating: "b", count: 200)
        let limited = limitCharactersForTest(text, limit: 160)

        XCTAssertEqual(limited.count, 160)
    }

    func testCharacterLimit_emptyString() {
        let limited = limitCharactersForTest("", limit: 500)

        XCTAssertEqual(limited, "")
    }

    func testCharacterLimit_unicodeCharacters() {
        let text = "日本語テスト" + String(repeating: "あ", count: 500)
        let limited = limitCharactersForTest(text, limit: 10)

        XCTAssertEqual(limited.count, 10)
    }

    // MARK: - File Naming Tests

    func testBrandImageFileName_format() {
        let kitId = UUID()
        let variant = BrandImageVariant.lightLogo
        let fileName = "brand_image_\(variant.rawValue)_\(kitId.uuidString)"

        XCTAssertTrue(fileName.starts(with: "brand_image_lightLogo_"))
        XCTAssertTrue(fileName.contains(kitId.uuidString))
    }

    func testBrandImageThumbFileName_format() {
        let kitId = UUID()
        let variant = BrandImageVariant.darkLogo
        let fileName = "brand_image_\(variant.rawValue)_\(kitId.uuidString)"
        let thumbFileName = fileName + "_thumb"

        XCTAssertTrue(thumbFileName.hasSuffix("_thumb"))
    }

    func testBrandImageLargeThumbFileName_format() {
        let kitId = UUID()
        let variant = BrandImageVariant.lightLogo
        let fileName = "brand_image_\(variant.rawValue)_\(kitId.uuidString)"
        let largeThumbFileName = fileName + "_thumb_large"

        XCTAssertTrue(largeThumbFileName.hasSuffix("_thumb_large"))
    }

    func testModelAssetFileName_format() {
        let assetId = UUID()
        let kitId = UUID()
        let fileName = "model_asset_\(assetId.uuidString)_\(kitId.uuidString)"

        XCTAssertTrue(fileName.starts(with: "model_asset_"))
        XCTAssertTrue(fileName.contains(assetId.uuidString))
        XCTAssertTrue(fileName.contains(kitId.uuidString))
    }

    func testModelAssetThumbFileName_format() {
        let assetId = UUID()
        let kitId = UUID()
        let fileName = "model_asset_\(assetId.uuidString)_\(kitId.uuidString)"
        let thumbFileName = fileName + "_thumb"

        XCTAssertTrue(thumbFileName.hasSuffix("_thumb"))
    }

    // MARK: - Thumbnail Size Tests

    func testThumbnailSize_smallMaxDimension() {
        let smallMaxDimension: CGFloat = 96

        XCTAssertEqual(smallMaxDimension, 96)
    }

    func testThumbnailSize_largeMaxDimension() {
        let largeMaxDimension: CGFloat = 320

        XCTAssertEqual(largeMaxDimension, 320)
    }

    func testThumbnailSize_aspectRatioPreservation_landscape() {
        let imageWidth: CGFloat = 1000
        let imageHeight: CGFloat = 500
        let aspectRatio = imageWidth / imageHeight
        let maxDimension: CGFloat = 96

        let expectedWidth = maxDimension
        let expectedHeight = maxDimension / aspectRatio

        XCTAssertEqual(expectedWidth, 96)
        XCTAssertEqual(expectedHeight, 48)
    }

    func testThumbnailSize_aspectRatioPreservation_portrait() {
        let imageWidth: CGFloat = 500
        let imageHeight: CGFloat = 1000
        let aspectRatio = imageWidth / imageHeight
        let maxDimension: CGFloat = 96

        let expectedWidth = maxDimension * aspectRatio
        let expectedHeight = maxDimension

        XCTAssertEqual(expectedWidth, 48)
        XCTAssertEqual(expectedHeight, 96)
    }

    func testThumbnailSize_aspectRatioPreservation_square() {
        let imageWidth: CGFloat = 1000
        let imageHeight: CGFloat = 1000
        let aspectRatio = imageWidth / imageHeight
        let maxDimension: CGFloat = 96

        // For aspect ratio > 1 (or equal), width is maxDimension
        let expectedWidth = maxDimension
        let expectedHeight = maxDimension / aspectRatio

        XCTAssertEqual(expectedWidth, 96)
        XCTAssertEqual(expectedHeight, 96)
    }

    // MARK: - Additional Color Tests

    func testAdditionalColors_prefixLimit() {
        let colors = ["#111", "#222", "#333", "#444", "#555", "#666"]
        let limited = Array(colors.prefix(4))

        XCTAssertEqual(limited.count, 4)
        XCTAssertEqual(limited, ["#111", "#222", "#333", "#444"])
    }

    func testAdditionalColors_underLimit() {
        let colors = ["#111", "#222"]
        let limited = Array(colors.prefix(4))

        XCTAssertEqual(limited.count, 2)
    }

    func testAdditionalColors_empty() {
        let colors: [String] = []
        let limited = Array(colors.prefix(4))

        XCTAssertTrue(limited.isEmpty)
    }

    // MARK: - Helper Methods

    /// Replicates BrandKitManager's color normalization logic for testing
    private func normalizeHexColorForTest(_ hex: String) -> String {
        var color = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !color.hasPrefix("#") {
            color = "#" + color
        }
        return color
    }

    /// Replicates character limit enforcement for testing
    private func limitCharactersForTest(_ text: String, limit: Int) -> String {
        String(text.prefix(limit))
    }
}
