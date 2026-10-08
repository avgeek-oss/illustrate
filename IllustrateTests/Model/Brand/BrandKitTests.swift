// MARK: - BrandKitTests.swift

// Unit tests for BrandKit model and related types.
//
// Tests cover:
// - BrandColorType enum properties and defaults
// - ModelAsset struct and computed properties
// - BrandKit initialization and serialization
// - Brand color helper methods
// - Image file name helper methods
// - Model assets computed property

import XCTest
@testable import Illustrate

final class BrandKitTests: XCTestCase {
    // MARK: - BrandColorType Tests

    func testBrandColorType_allCases() {
        let allCases = BrandColorType.allCases

        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.primary))
        XCTAssertTrue(allCases.contains(.secondary))
        XCTAssertTrue(allCases.contains(.accent))
        XCTAssertTrue(allCases.contains(.background))
        XCTAssertTrue(allCases.contains(.text))
    }

    func testBrandColorType_rawValues() {
        XCTAssertEqual(BrandColorType.primary.rawValue, "primary")
        XCTAssertEqual(BrandColorType.secondary.rawValue, "secondary")
        XCTAssertEqual(BrandColorType.accent.rawValue, "accent")
        XCTAssertEqual(BrandColorType.background.rawValue, "background")
        XCTAssertEqual(BrandColorType.text.rawValue, "text")
    }

    func testBrandColorType_displayName() {
        XCTAssertEqual(BrandColorType.primary.displayName, "Primary")
        XCTAssertEqual(BrandColorType.secondary.displayName, "Secondary")
        XCTAssertEqual(BrandColorType.accent.displayName, "Accent")
        XCTAssertEqual(BrandColorType.background.displayName, "Background")
        XCTAssertEqual(BrandColorType.text.displayName, "Text/Label")
    }

    func testBrandColorType_defaultColor() {
        XCTAssertEqual(BrandColorType.primary.defaultColor, "#007AFF")
        XCTAssertEqual(BrandColorType.secondary.defaultColor, "#5856D6")
        XCTAssertEqual(BrandColorType.accent.defaultColor, "#FF9500")
        XCTAssertEqual(BrandColorType.background.defaultColor, "#FFFFFF")
        XCTAssertEqual(BrandColorType.text.defaultColor, "#000000")
    }

    func testBrandColorType_codable() throws {
        let types: [BrandColorType] = BrandColorType.allCases

        let data = try JSONEncoder().encode(types)
        let decoded = try JSONDecoder().decode([BrandColorType].self, from: data)

        XCTAssertEqual(decoded, types)
    }

    // MARK: - ModelAsset Tests

    func testModelAsset_initialization() {
        let id = UUID()
        let asset = ModelAsset(id: id, fileName: "test_asset")

        XCTAssertEqual(asset.id, id)
        XCTAssertEqual(asset.fileName, "test_asset")
    }

    func testModelAsset_initializationWithDefaultId() {
        let asset = ModelAsset(fileName: "auto_id_asset")

        XCTAssertNotEqual(asset.id, UUID())
        XCTAssertEqual(asset.fileName, "auto_id_asset")
    }

    func testModelAsset_thumbFileName() {
        let asset = ModelAsset(fileName: "my_image")

        XCTAssertEqual(asset.thumbFileName, "my_image_thumb")
    }

    func testModelAsset_largeThumbFileName() {
        let asset = ModelAsset(fileName: "my_image")

        XCTAssertEqual(asset.largeThumbFileName, "my_image_thumb_large")
    }

    func testModelAsset_codableRoundTrip() throws {
        let original = ModelAsset(id: UUID(), fileName: "test_file")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModelAsset.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.fileName, original.fileName)
    }

    func testModelAsset_equatable() {
        let id = UUID()
        let asset1 = ModelAsset(id: id, fileName: "same")
        let asset2 = ModelAsset(id: id, fileName: "same")
        let asset3 = ModelAsset(fileName: "different")

        XCTAssertEqual(asset1, asset2)
        XCTAssertNotEqual(asset1, asset3)
    }

    func testModelAsset_hashable() {
        let asset1 = ModelAsset(fileName: "file1")
        let asset2 = ModelAsset(fileName: "file2")

        var set = Set<ModelAsset>()
        set.insert(asset1)
        set.insert(asset2)
        set.insert(asset1) // Duplicate

        XCTAssertEqual(set.count, 2)
    }

    // MARK: - BrandKit Initialization Tests

    func testBrandKit_defaultInitialization() {
        let brandKit = BrandKit()

        XCTAssertNotEqual(brandKit.id, UUID())
        XCTAssertEqual(brandKit.brandName, "")
        XCTAssertEqual(brandKit.brandAbout, "")
        XCTAssertEqual(brandKit.brandPersonality, "")
        XCTAssertTrue(brandKit.brandColors.isEmpty)
        XCTAssertTrue(brandKit.additionalColors.isEmpty)
        XCTAssertNil(brandKit.fontFace)
        XCTAssertTrue(brandKit.imageFileNames.isEmpty)
        XCTAssertTrue(brandKit.modelAssets.isEmpty)
    }

    func testBrandKit_fullInitialization() {
        let id = UUID()
        let projectId = UUID()
        let assets = [ModelAsset(fileName: "asset1"), ModelAsset(fileName: "asset2")]

        let brandKit = BrandKit(
            id: id,
            projectId: projectId,
            brandName: "Test Brand",
            brandAbout: "About the brand",
            brandPersonality: "Friendly and professional",
            brandColors: ["primary": "#FF0000"],
            additionalColors: ["#00FF00", "#0000FF"],
            fontFace: "Helvetica",
            imageFileNames: ["lightLogo": "logo_light"],
            modelAssets: assets
        )

        XCTAssertEqual(brandKit.id, id)
        XCTAssertEqual(brandKit.projectId, projectId)
        XCTAssertEqual(brandKit.brandName, "Test Brand")
        XCTAssertEqual(brandKit.brandAbout, "About the brand")
        XCTAssertEqual(brandKit.brandPersonality, "Friendly and professional")
        XCTAssertEqual(brandKit.brandColors["primary"], "#FF0000")
        XCTAssertEqual(brandKit.additionalColors, ["#00FF00", "#0000FF"])
        XCTAssertEqual(brandKit.fontFace, "Helvetica")
        XCTAssertEqual(brandKit.imageFileNames["lightLogo"], "logo_light")
        XCTAssertEqual(brandKit.modelAssets.count, 2)
    }

    // MARK: - BrandKit Color Helper Tests

    func testBrandKit_colorForType_withSetColor() {
        let brandKit = BrandKit(brandColors: ["primary": "#123456"])

        let color = brandKit.color(for: .primary)

        XCTAssertEqual(color, "#123456")
    }

    func testBrandKit_colorForType_withDefault() {
        let brandKit = BrandKit()

        let color = brandKit.color(for: .primary)

        XCTAssertEqual(color, BrandColorType.primary.defaultColor)
    }

    func testBrandKit_setColor() {
        let brandKit = BrandKit()

        brandKit.setColor("#ABCDEF", for: .secondary)

        XCTAssertEqual(brandKit.brandColors["secondary"], "#ABCDEF")
        XCTAssertEqual(brandKit.color(for: .secondary), "#ABCDEF")
    }

    func testBrandKit_setColor_overwrite() {
        let brandKit = BrandKit(brandColors: ["accent": "#111111"])

        brandKit.setColor("#222222", for: .accent)

        XCTAssertEqual(brandKit.color(for: .accent), "#222222")
    }

    func testBrandKit_allColorTypes() {
        let brandKit = BrandKit()

        for colorType in BrandColorType.allCases {
            brandKit.setColor("#FFFFFF", for: colorType)
        }

        XCTAssertEqual(brandKit.brandColors.count, 5)

        for colorType in BrandColorType.allCases {
            XCTAssertEqual(brandKit.color(for: colorType), "#FFFFFF")
        }
    }

    // MARK: - BrandKit Image File Name Helper Tests

    func testBrandKit_imageFileName_whenSet() {
        let brandKit = BrandKit(imageFileNames: ["lightLogo": "brand_logo_light"])

        let fileName = brandKit.imageFileName(for: .lightLogo)

        XCTAssertEqual(fileName, "brand_logo_light")
    }

    func testBrandKit_imageFileName_whenNotSet() {
        let brandKit = BrandKit()

        let fileName = brandKit.imageFileName(for: .lightLogo)

        XCTAssertNil(fileName)
    }

    func testBrandKit_thumbFileName_whenSet() {
        let brandKit = BrandKit(imageFileNames: ["darkLogo": "dark_logo"])

        let thumbName = brandKit.thumbFileName(for: .darkLogo)

        XCTAssertEqual(thumbName, "dark_logo_thumb")
    }

    func testBrandKit_thumbFileName_whenNotSet() {
        let brandKit = BrandKit()

        let thumbName = brandKit.thumbFileName(for: .darkLogo)

        XCTAssertNil(thumbName)
    }

    func testBrandKit_largeThumbFileName_whenSet() {
        let brandKit = BrandKit(imageFileNames: ["lightLogo": "light"])

        let largeThumbName = brandKit.largeThumbFileName(for: .lightLogo)

        XCTAssertEqual(largeThumbName, "light_thumb_large")
    }

    func testBrandKit_largeThumbFileName_whenNotSet() {
        let brandKit = BrandKit()

        let largeThumbName = brandKit.largeThumbFileName(for: .lightLogo)

        XCTAssertNil(largeThumbName)
    }

    func testBrandKit_setImageFileName() {
        let brandKit = BrandKit()

        brandKit.setImageFileName("new_logo", for: .lightLogo)

        XCTAssertEqual(brandKit.imageFileName(for: .lightLogo), "new_logo")
    }

    func testBrandKit_setImageFileName_remove() {
        let brandKit = BrandKit(imageFileNames: ["lightLogo": "old_logo"])

        brandKit.setImageFileName(nil, for: .lightLogo)

        XCTAssertNil(brandKit.imageFileName(for: .lightLogo))
    }

    // MARK: - BrandKit Model Assets Tests

    func testBrandKit_modelAssets_empty() {
        let brandKit = BrandKit()

        XCTAssertTrue(brandKit.modelAssets.isEmpty)
    }

    func testBrandKit_modelAssets_getAndSet() {
        let brandKit = BrandKit()
        let assets = [
            ModelAsset(fileName: "model1"),
            ModelAsset(fileName: "model2"),
            ModelAsset(fileName: "model3"),
        ]

        brandKit.modelAssets = assets

        XCTAssertEqual(brandKit.modelAssets.count, 3)
        XCTAssertEqual(brandKit.modelAssets[0].fileName, "model1")
        XCTAssertEqual(brandKit.modelAssets[1].fileName, "model2")
        XCTAssertEqual(brandKit.modelAssets[2].fileName, "model3")
    }

    func testBrandKit_modelAssets_preservesIds() {
        let brandKit = BrandKit()
        let id1 = UUID()
        let id2 = UUID()
        let assets = [
            ModelAsset(id: id1, fileName: "file1"),
            ModelAsset(id: id2, fileName: "file2"),
        ]

        brandKit.modelAssets = assets
        let retrieved = brandKit.modelAssets

        XCTAssertEqual(retrieved[0].id, id1)
        XCTAssertEqual(retrieved[1].id, id2)
    }

    func testBrandKit_modelAssets_updateExisting() {
        let brandKit = BrandKit()
        brandKit.modelAssets = [ModelAsset(fileName: "old")]

        brandKit.modelAssets = [ModelAsset(fileName: "new1"), ModelAsset(fileName: "new2")]

        XCTAssertEqual(brandKit.modelAssets.count, 2)
        XCTAssertEqual(brandKit.modelAssets[0].fileName, "new1")
    }

    // MARK: - BrandKit Codable Tests

    func testBrandKit_codableRoundTrip_minimal() throws {
        let original = BrandKit()

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BrandKit.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.brandName, "")
        XCTAssertTrue(decoded.brandColors.isEmpty)
    }

    func testBrandKit_codableRoundTrip_full() throws {
        let id = UUID()
        let projectId = UUID()

        let original = BrandKit(
            id: id,
            projectId: projectId,
            brandName: "Encoded Brand",
            brandAbout: "Brand description for encoding",
            brandPersonality: "Bold and innovative",
            brandColors: [
                "primary": "#FF0000",
                "secondary": "#00FF00",
            ],
            additionalColors: ["#111111", "#222222", "#333333"],
            fontFace: "Roboto",
            imageFileNames: [
                "lightLogo": "light_logo_file",
                "darkLogo": "dark_logo_file",
            ],
            modelAssets: [
                ModelAsset(fileName: "asset_1"),
                ModelAsset(fileName: "asset_2"),
            ]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BrandKit.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.projectId, projectId)
        XCTAssertEqual(decoded.brandName, "Encoded Brand")
        XCTAssertEqual(decoded.brandAbout, "Brand description for encoding")
        XCTAssertEqual(decoded.brandPersonality, "Bold and innovative")
        XCTAssertEqual(decoded.brandColors["primary"], "#FF0000")
        XCTAssertEqual(decoded.brandColors["secondary"], "#00FF00")
        XCTAssertEqual(decoded.additionalColors.count, 3)
        XCTAssertEqual(decoded.fontFace, "Roboto")
        XCTAssertEqual(decoded.imageFileNames["lightLogo"], "light_logo_file")
        XCTAssertEqual(decoded.modelAssets.count, 2)
        XCTAssertEqual(decoded.modelAssets[0].fileName, "asset_1")
    }

    func testBrandKit_codable_withNilFontFace() throws {
        let original = BrandKit(fontFace: nil)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BrandKit.self, from: data)

        XCTAssertNil(decoded.fontFace)
    }

    func testBrandKit_codable_emptyCollections() throws {
        let original = BrandKit(
            brandColors: [:],
            additionalColors: [],
            imageFileNames: [:],
            modelAssets: []
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BrandKit.self, from: data)

        XCTAssertTrue(decoded.brandColors.isEmpty)
        XCTAssertTrue(decoded.additionalColors.isEmpty)
        XCTAssertTrue(decoded.imageFileNames.isEmpty)
        XCTAssertTrue(decoded.modelAssets.isEmpty)
    }

    // MARK: - Edge Cases

    func testBrandKit_specialCharactersInBrandName() throws {
        let original = BrandKit(brandName: "Café & Co. \"Premium\" <Best>")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BrandKit.self, from: data)

        XCTAssertEqual(decoded.brandName, "Café & Co. \"Premium\" <Best>")
    }

    func testBrandKit_unicodeInBrandAbout() throws {
        let original = BrandKit(brandAbout: "日本語 한국어 العربية 🎨🖼️")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BrandKit.self, from: data)

        XCTAssertEqual(decoded.brandAbout, "日本語 한국어 العربية 🎨🖼️")
    }

    func testBrandKit_longBrandAbout() throws {
        let longText = String(repeating: "a", count: 500)
        let original = BrandKit(brandAbout: longText)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BrandKit.self, from: data)

        XCTAssertEqual(decoded.brandAbout.count, 500)
    }

    func testBrandKit_manyAdditionalColors() throws {
        let colors = (0 ..< 50).map { "#\(String(format: "%06X", $0 * 5000))" }
        let original = BrandKit(additionalColors: colors)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BrandKit.self, from: data)

        XCTAssertEqual(decoded.additionalColors.count, 50)
    }

    func testBrandKit_manyModelAssets() throws {
        let assets = (0 ..< 100).map { ModelAsset(fileName: "asset_\($0)") }
        let original = BrandKit(modelAssets: assets)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BrandKit.self, from: data)

        XCTAssertEqual(decoded.modelAssets.count, 100)
        XCTAssertEqual(decoded.modelAssets[99].fileName, "asset_99")
    }
}
