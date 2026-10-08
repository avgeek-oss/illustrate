// MARK: - ProductPhotoshootEnumTests.swift

// Tests for ProductPhotoshoot enums: camera angles, product positions, and dimensions.
//
// Tests cover:
// - PhotoshootCameraAngle: 6 cases — displayName, icon, rawValue round-trip, Codable
// - PhotoshootProductPosition: 3 cases — displayName, icon, rawValue round-trip, Codable
// - PhotoshootDimension: 6 cases — displayName, assetPrefix, pixelDimensions,
//   aspectRatio, isPortrait, Codable, portrait/landscape partitioning
// - ProductPhotoshoot model: dimensionsEnum, cameraAngleEnum, productPositionEnum
//   computed property round-trips, Codable encode/decode

import XCTest
@testable import Illustrate

// MARK: - PhotoshootCameraAngle Tests

final class PhotoshootCameraAngleTests: XCTestCase {
    // MARK: - Display Names

    func testDisplayName_Left_ReturnsLeft() {
        XCTAssertEqual(PhotoshootCameraAngle.left.displayName, "Left")
    }

    func testDisplayName_Left45_ReturnsLeft45() {
        XCTAssertEqual(PhotoshootCameraAngle.left45.displayName, "Left 45°")
    }

    func testDisplayName_Center_ReturnsCenter() {
        XCTAssertEqual(PhotoshootCameraAngle.center.displayName, "Center")
    }

    func testDisplayName_Right45_ReturnsRight45() {
        XCTAssertEqual(PhotoshootCameraAngle.right45.displayName, "Right 45°")
    }

    func testDisplayName_Right_ReturnsRight() {
        XCTAssertEqual(PhotoshootCameraAngle.right.displayName, "Right")
    }

    func testDisplayName_Top_ReturnsTop() {
        XCTAssertEqual(PhotoshootCameraAngle.top.displayName, "Top")
    }

    // MARK: - Icons

    func testAllCases_HaveNonEmptyIcon() {
        for angle in PhotoshootCameraAngle.allCases {
            XCTAssertFalse(angle.icon.isEmpty, "\(angle) should have a non-empty icon")
        }
    }

    func testIcon_Left_ReturnsArrowLeft() {
        XCTAssertEqual(PhotoshootCameraAngle.left.icon, "arrow.left")
    }

    func testIcon_Center_ReturnsCircle() {
        XCTAssertEqual(PhotoshootCameraAngle.center.icon, "circle")
    }

    func testIcon_Top_ReturnsArrowUp() {
        XCTAssertEqual(PhotoshootCameraAngle.top.icon, "arrow.up")
    }

    // MARK: - RawValue & Identity

    func testRawValue_Left45_EqualsLeft45String() {
        XCTAssertEqual(PhotoshootCameraAngle.left45.rawValue, "left_45")
    }

    func testRawValue_RoundTrip_AllCases() {
        for angle in PhotoshootCameraAngle.allCases {
            let restored = PhotoshootCameraAngle(rawValue: angle.rawValue)
            XCTAssertEqual(restored, angle, "RawValue round-trip failed for \(angle)")
        }
    }

    func testId_MatchesRawValue_AllCases() {
        for angle in PhotoshootCameraAngle.allCases {
            XCTAssertEqual(angle.id, angle.rawValue, "id should match rawValue for \(angle)")
        }
    }

    func testAllCasesCount_IsSix() {
        XCTAssertEqual(PhotoshootCameraAngle.allCases.count, 6)
    }

    // MARK: - Codable

    func testCodable_RoundTrip_AllCases() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for angle in PhotoshootCameraAngle.allCases {
            let data = try encoder.encode(angle)
            let restored = try decoder.decode(PhotoshootCameraAngle.self, from: data)
            XCTAssertEqual(restored, angle, "Codable round-trip failed for \(angle)")
        }
    }

    // MARK: - All Display Names Unique

    func testAllDisplayNames_AreUnique() {
        let names = PhotoshootCameraAngle.allCases.map(\.displayName)
        XCTAssertEqual(Set(names).count, names.count, "All display names should be unique")
    }
}

// MARK: - PhotoshootProductPosition Tests

final class PhotoshootProductPositionTests: XCTestCase {
    // MARK: - Display Names

    func testDisplayName_OnGround_ReturnsOnGround() {
        XCTAssertEqual(PhotoshootProductPosition.onGround.displayName, "On Ground")
    }

    func testDisplayName_FloatingStraight_ReturnsFloatingStraight() {
        XCTAssertEqual(PhotoshootProductPosition.floatingStraight.displayName, "Floating (Straight)")
    }

    func testDisplayName_FloatingTilted_ReturnsFloatingTilted() {
        XCTAssertEqual(PhotoshootProductPosition.floatingTilted.displayName, "Floating (Tilted)")
    }

    // MARK: - Icons

    func testAllCases_HaveNonEmptyIcon() {
        for position in PhotoshootProductPosition.allCases {
            XCTAssertFalse(position.icon.isEmpty, "\(position) should have a non-empty icon")
        }
    }

    func testIcon_OnGround_ReturnsSquareOnSquare() {
        XCTAssertEqual(PhotoshootProductPosition.onGround.icon, "square.on.square")
    }

    // MARK: - RawValue & Identity

    func testRawValue_FloatingTilted_EqualsFloatingTiltedString() {
        XCTAssertEqual(PhotoshootProductPosition.floatingTilted.rawValue, "floating_tilted")
    }

    func testRawValue_RoundTrip_AllCases() {
        for position in PhotoshootProductPosition.allCases {
            let restored = PhotoshootProductPosition(rawValue: position.rawValue)
            XCTAssertEqual(restored, position, "RawValue round-trip failed for \(position)")
        }
    }

    func testId_MatchesRawValue_AllCases() {
        for position in PhotoshootProductPosition.allCases {
            XCTAssertEqual(position.id, position.rawValue, "id should match rawValue for \(position)")
        }
    }

    func testAllCasesCount_IsThree() {
        XCTAssertEqual(PhotoshootProductPosition.allCases.count, 3)
    }

    // MARK: - Codable

    func testCodable_RoundTrip_AllCases() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for position in PhotoshootProductPosition.allCases {
            let data = try encoder.encode(position)
            let restored = try decoder.decode(PhotoshootProductPosition.self, from: data)
            XCTAssertEqual(restored, position, "Codable round-trip failed for \(position)")
        }
    }
}

// MARK: - PhotoshootDimension Tests

final class PhotoshootDimensionTests: XCTestCase {
    // MARK: - Display Names

    func testDisplayName_Portrait9x16() {
        XCTAssertEqual(PhotoshootDimension.portrait9x16.displayName, "9:16 Portrait")
    }

    func testDisplayName_Landscape16x9() {
        XCTAssertEqual(PhotoshootDimension.landscape16x9.displayName, "16:9 Landscape")
    }

    func testDisplayName_Portrait3x4() {
        XCTAssertEqual(PhotoshootDimension.portrait3x4.displayName, "3:4 Portrait")
    }

    func testDisplayName_Landscape4x3() {
        XCTAssertEqual(PhotoshootDimension.landscape4x3.displayName, "4:3 Landscape")
    }

    func testAllCases_HaveNonEmptyDisplayName() {
        for dim in PhotoshootDimension.allCases {
            XCTAssertFalse(dim.displayName.isEmpty, "\(dim) should have a non-empty display name")
        }
    }

    // MARK: - Asset Prefix

    func testAssetPrefix_Portrait9x16_ReturnsCorrectPrefix() {
        XCTAssertEqual(PhotoshootDimension.portrait9x16.assetPrefix, "shoots_bg_9_16")
    }

    func testAssetPrefix_Portrait3x4_ReturnsCorrectPrefix() {
        XCTAssertEqual(PhotoshootDimension.portrait3x4.assetPrefix, "shoots_bg_3_4")
    }

    func testAssetPrefix_Landscape3x2_ReturnsCorrectPrefix() {
        XCTAssertEqual(PhotoshootDimension.landscape3x2.assetPrefix, "shoots_bg_3_2")
    }

    func testAssetPrefix_AllCases_StartWithShootsBg() {
        for dim in PhotoshootDimension.allCases {
            XCTAssertTrue(
                dim.assetPrefix.hasPrefix("shoots_bg_"),
                "\(dim) assetPrefix should start with 'shoots_bg_'"
            )
        }
    }

    // MARK: - Pixel Dimensions

    func testPixelDimensions_Portrait9x16_Returns1080x1920() {
        XCTAssertEqual(PhotoshootDimension.portrait9x16.pixelDimensions, "1080x1920")
    }

    func testPixelDimensions_Landscape16x9_Returns1920x1080() {
        XCTAssertEqual(PhotoshootDimension.landscape16x9.pixelDimensions, "1920x1080")
    }

    func testPixelDimensions_Portrait2x3_Returns1024x1536() {
        XCTAssertEqual(PhotoshootDimension.portrait2x3.pixelDimensions, "1024x1536")
    }

    func testPixelDimensions_AllCases_MatchWidthxHeightFormat() throws {
        let regex = try NSRegularExpression(pattern: "^\\d+x\\d+$")
        for dim in PhotoshootDimension.allCases {
            let pixels = dim.pixelDimensions
            let range = NSRange(pixels.startIndex ..< pixels.endIndex, in: pixels)
            XCTAssertNotNil(
                regex.firstMatch(in: pixels, range: range),
                "\(dim).pixelDimensions '\(pixels)' should match WIDTHxHEIGHT format"
            )
        }
    }

    func testGenerationDimension_prefersSupportedAspectRatio() {
        XCTAssertEqual(
            PhotoshootDimension.portrait9x16.generationDimension(supportedDimensions: ["9:16"]),
            "9:16"
        )
    }

    func testGenerationDimension_fallsBackToPixelDimensions() {
        XCTAssertEqual(
            PhotoshootDimension.portrait9x16.generationDimension(supportedDimensions: ["1080x1920"]),
            "1080x1920"
        )
    }

    // MARK: - Aspect Ratio

    func testAspectRatio_Landscape16x9_ApproximatelyCorrect() {
        XCTAssertEqual(PhotoshootDimension.landscape16x9.aspectRatio, 16.0 / 9.0, accuracy: 0.001)
    }

    func testAspectRatio_Portrait9x16_ApproximatelyCorrect() {
        XCTAssertEqual(PhotoshootDimension.portrait9x16.aspectRatio, 9.0 / 16.0, accuracy: 0.001)
    }

    func testAspectRatio_Landscape4x3_ApproximatelyCorrect() {
        XCTAssertEqual(PhotoshootDimension.landscape4x3.aspectRatio, 4.0 / 3.0, accuracy: 0.001)
    }

    func testAspectRatio_PortraitCases_LessThanOne() {
        let portraitCases: [PhotoshootDimension] = [.portrait9x16, .portrait3x4, .portrait2x3]
        for dim in portraitCases {
            XCTAssertLessThan(dim.aspectRatio, 1.0, "\(dim) aspect ratio should be < 1.0 (portrait)")
        }
    }

    func testAspectRatio_LandscapeCases_GreaterThanOne() {
        let landscapeCases: [PhotoshootDimension] = [.landscape16x9, .landscape4x3, .landscape3x2]
        for dim in landscapeCases {
            XCTAssertGreaterThan(dim.aspectRatio, 1.0, "\(dim) aspect ratio should be > 1.0 (landscape)")
        }
    }

    // MARK: - isPortrait

    func testIsPortrait_PortraitCases_ReturnTrue() {
        XCTAssertTrue(PhotoshootDimension.portrait9x16.isPortrait)
        XCTAssertTrue(PhotoshootDimension.portrait3x4.isPortrait)
        XCTAssertTrue(PhotoshootDimension.portrait2x3.isPortrait)
    }

    func testIsPortrait_LandscapeCases_ReturnFalse() {
        XCTAssertFalse(PhotoshootDimension.landscape16x9.isPortrait)
        XCTAssertFalse(PhotoshootDimension.landscape4x3.isPortrait)
        XCTAssertFalse(PhotoshootDimension.landscape3x2.isPortrait)
    }

    func testIsPortrait_ExactlyThreePortrait_ThreeLandscape() {
        let portraitCount = PhotoshootDimension.allCases.filter(\.isPortrait).count
        let landscapeCount = PhotoshootDimension.allCases.filter { !$0.isPortrait }.count
        XCTAssertEqual(portraitCount, 3, "Should have exactly 3 portrait cases")
        XCTAssertEqual(landscapeCount, 3, "Should have exactly 3 landscape cases")
    }

    // MARK: - Consistency: isPortrait matches aspectRatio

    func testIsPortrait_ConsistentWithAspectRatio() {
        for dim in PhotoshootDimension.allCases {
            if dim.isPortrait {
                XCTAssertLessThan(dim.aspectRatio, 1.0, "\(dim) isPortrait=true but aspectRatio >= 1.0")
            } else {
                XCTAssertGreaterThan(dim.aspectRatio, 1.0, "\(dim) isPortrait=false but aspectRatio <= 1.0")
            }
        }
    }

    // MARK: - RawValue & Identity

    func testRawValue_Portrait9x16_Equals9Colon16() {
        XCTAssertEqual(PhotoshootDimension.portrait9x16.rawValue, "9:16")
    }

    func testRawValue_RoundTrip_AllCases() {
        for dim in PhotoshootDimension.allCases {
            let restored = PhotoshootDimension(rawValue: dim.rawValue)
            XCTAssertEqual(restored, dim, "RawValue round-trip failed for \(dim)")
        }
    }

    func testId_MatchesRawValue_AllCases() {
        for dim in PhotoshootDimension.allCases {
            XCTAssertEqual(dim.id, dim.rawValue, "id should match rawValue for \(dim)")
        }
    }

    func testAllCasesCount_IsSix() {
        XCTAssertEqual(PhotoshootDimension.allCases.count, 6)
    }

    // MARK: - Codable

    func testCodable_RoundTrip_AllCases() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for dim in PhotoshootDimension.allCases {
            let data = try encoder.encode(dim)
            let restored = try decoder.decode(PhotoshootDimension.self, from: data)
            XCTAssertEqual(restored, dim, "Codable round-trip failed for \(dim)")
        }
    }

    // MARK: - Pixel Dimension Consistency

    func testPixelDimensions_PortraitWidth_LessThanHeight() {
        let portraitCases: [PhotoshootDimension] = [.portrait9x16, .portrait3x4, .portrait2x3]
        for dim in portraitCases {
            let parts = dim.pixelDimensions.split(separator: "x").compactMap { Int($0) }
            XCTAssertEqual(parts.count, 2, "\(dim) should have WxH format")
            XCTAssertLessThan(parts[0], parts[1], "\(dim) portrait width should be < height")
        }
    }

    func testPixelDimensions_LandscapeWidth_GreaterThanOrEqualHeight() {
        let landscapeCases: [PhotoshootDimension] = [.landscape16x9, .landscape4x3, .landscape3x2]
        for dim in landscapeCases {
            let parts = dim.pixelDimensions.split(separator: "x").compactMap { Int($0) }
            XCTAssertEqual(parts.count, 2, "\(dim) should have WxH format")
            XCTAssertGreaterThan(parts[0], parts[1], "\(dim) landscape width should be > height")
        }
    }
}

// MARK: - ProductPhotoshoot Model Tests

final class ProductPhotoshootModelTests: XCTestCase {
    // MARK: - Enum Property Round-Trips

    func testDimensionsEnum_DefaultsToPortrait9x16() {
        let photoshoot = ProductPhotoshoot()
        XCTAssertEqual(photoshoot.dimensionsEnum, .portrait9x16)
    }

    func testCameraAngleEnum_GetSet_RoundTrip() {
        let photoshoot = ProductPhotoshoot()
        photoshoot.cameraAngleEnum = .left45
        XCTAssertEqual(photoshoot.cameraAngleEnum, .left45)
        XCTAssertEqual(photoshoot.cameraAngle, "left_45")
    }

    func testProductPositionEnum_GetSet_RoundTrip() {
        let photoshoot = ProductPhotoshoot()
        photoshoot.productPositionEnum = .floatingTilted
        XCTAssertEqual(photoshoot.productPositionEnum, .floatingTilted)
        XCTAssertEqual(photoshoot.productPosition, "floating_tilted")
    }

    func testCameraAngleEnum_InvalidRawValue_DefaultsToCenter() {
        let photoshoot = ProductPhotoshoot()
        photoshoot.cameraAngle = "invalid_angle"
        XCTAssertEqual(photoshoot.cameraAngleEnum, .center)
    }

    func testProductPositionEnum_InvalidRawValue_DefaultsToOnGround() {
        let photoshoot = ProductPhotoshoot()
        photoshoot.productPosition = "invalid_position"
        XCTAssertEqual(photoshoot.productPositionEnum, .onGround)
    }

    func testDimensionsEnum_InvalidRawValue_DefaultsToPortrait9x16() {
        let photoshoot = ProductPhotoshoot()
        photoshoot.dimensions = "invalid_dimensions"
        XCTAssertEqual(photoshoot.dimensionsEnum, .portrait9x16)
    }

    // MARK: - Initialization

    func testInit_CustomValues_PreservesAllFields() {
        let projectId = UUID()
        let photoshoot = ProductPhotoshoot(
            name: "My Shoot",
            projectId: projectId,
            modelId: "model-1",
            providerId: "provider-1",
            dimensions: .landscape16x9,
            productDescription: "A red shoe"
        )
        XCTAssertEqual(photoshoot.name, "My Shoot")
        XCTAssertEqual(photoshoot.projectId, projectId)
        XCTAssertEqual(photoshoot.modelId, "model-1")
        XCTAssertEqual(photoshoot.providerId, "provider-1")
        XCTAssertEqual(photoshoot.dimensionsEnum, .landscape16x9)
        XCTAssertEqual(photoshoot.productDescription, "A red shoe")
        XCTAssertFalse(photoshoot.isPinned)
    }

    func testInit_DefaultValues() {
        let photoshoot = ProductPhotoshoot()
        XCTAssertEqual(photoshoot.name, "Untitled Photoshoot")
        XCTAssertEqual(photoshoot.modelId, "")
        XCTAssertEqual(photoshoot.providerId, "")
        XCTAssertEqual(photoshoot.dimensionsEnum, .portrait9x16)
        XCTAssertEqual(photoshoot.productDescription, "")
        XCTAssertFalse(photoshoot.isPinned)
        XCTAssertNil(photoshoot.selectedBackdropIndex)
        XCTAssertNil(photoshoot.customBackdropData)
        XCTAssertTrue(photoshoot.productObjectsData.isEmpty)
    }

    // MARK: - Codable

    func testCodable_RoundTrip_PreservesAllFields() throws {
        let photoshoot = ProductPhotoshoot(
            name: "Test Shoot",
            modelId: "m1",
            providerId: "p1",
            dimensions: .landscape4x3,
            productDescription: "Widget"
        )
        photoshoot.cameraAngleEnum = .right45
        photoshoot.productPositionEnum = .floatingStraight
        photoshoot.selectedBackdropIndex = 3
        photoshoot.isPinned = true

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(photoshoot)
        let restored = try decoder.decode(ProductPhotoshoot.self, from: data)

        XCTAssertEqual(restored.id, photoshoot.id)
        XCTAssertEqual(restored.name, "Test Shoot")
        XCTAssertEqual(restored.modelId, "m1")
        XCTAssertEqual(restored.providerId, "p1")
        XCTAssertEqual(restored.dimensionsEnum, .landscape4x3)
        XCTAssertEqual(restored.productDescription, "Widget")
        XCTAssertEqual(restored.cameraAngleEnum, .right45)
        XCTAssertEqual(restored.productPositionEnum, .floatingStraight)
        XCTAssertEqual(restored.selectedBackdropIndex, 3)
        XCTAssertTrue(restored.isPinned)
    }

    func testCodable_MissingOptionalFields_DefaultsCorrectly() throws {
        // Minimal JSON with only required fields
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "name": "Minimal",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        let restored = try decoder.decode(ProductPhotoshoot.self, from: data)

        XCTAssertEqual(restored.name, "Minimal")
        XCTAssertFalse(restored.isPinned)
        XCTAssertEqual(restored.modelId, "")
        XCTAssertEqual(restored.dimensionsEnum, .portrait9x16)
        XCTAssertEqual(restored.cameraAngleEnum, .center)
        XCTAssertEqual(restored.productPositionEnum, .onGround)
    }
}
