// MARK: - RealtimeEditConstantsTests.swift

import XCTest
@testable import Illustrate

final class RealtimeEditConstantsTests: XCTestCase {
    // MARK: - Color Constants Tests

    func testDefaultBrushColorIsValidHex() {
        let hex = RealtimeEditColors.defaultBrush
        XCTAssertEqual(hex.count, 6, "Hex color should be exactly 6 characters")
        XCTAssertTrue(
            hex.allSatisfy(\.isHexDigit),
            "All characters should be valid hex digits"
        )
    }

    func testDefaultShapeColorIsValidHex() {
        let hex = RealtimeEditColors.defaultShape
        XCTAssertEqual(hex.count, 6, "Hex color should be exactly 6 characters")
        XCTAssertTrue(
            hex.allSatisfy(\.isHexDigit),
            "All characters should be valid hex digits"
        )
    }

    func testDefaultBrushColorIsRed() {
        XCTAssertEqual(RealtimeEditColors.defaultBrush, "73353D")
    }

    func testDefaultShapeColorIsBlue() {
        XCTAssertEqual(RealtimeEditColors.defaultShape, "73353D")
    }

    func testColorsAreNonTrivial() {
        XCTAssertFalse(
            RealtimeEditColors.defaultBrush.isEmpty,
            "Default brush color should not be empty"
        )
        XCTAssertFalse(
            RealtimeEditColors.defaultShape.isEmpty,
            "Default shape color should not be empty"
        )
    }

    // MARK: - Brush Settings Tests

    func testBrushSizeConstraints() {
        XCTAssertLessThan(
            BrushSettings.minSize,
            BrushSettings.defaultSize,
            "Min size should be less than default size"
        )
        XCTAssertLessThan(
            BrushSettings.defaultSize,
            BrushSettings.maxSize,
            "Default size should be less than max size"
        )
    }

    func testBrushSizesArePositive() {
        XCTAssertGreaterThan(BrushSettings.minSize, 0, "Min size should be positive")
        XCTAssertGreaterThan(BrushSettings.defaultSize, 0, "Default size should be positive")
        XCTAssertGreaterThan(BrushSettings.maxSize, 0, "Max size should be positive")
    }

    func testBrushDefaultSize() {
        XCTAssertEqual(BrushSettings.defaultSize, 24.0)
    }

    func testBrushMinSize() {
        XCTAssertEqual(BrushSettings.minSize, 16.0)
    }

    func testBrushMaxSize() {
        XCTAssertEqual(BrushSettings.maxSize, 48.0)
    }

    func testBrushSizeRange() {
        let range = BrushSettings.minSize ... BrushSettings.maxSize
        XCTAssertTrue(range.contains(BrushSettings.defaultSize))
    }

    // MARK: - Image Processing Tests

    func testImageProcessingDimensionsArePositive() {
        XCTAssertGreaterThan(ImageProcessing.maxSaveDimension, 0)
        XCTAssertGreaterThan(ImageProcessing.maxDisplayDimension, 0)
        XCTAssertGreaterThan(ImageProcessing.defaultLayerSize, 0)
    }

    func testImageProcessingMaxSaveDimension() {
        XCTAssertEqual(ImageProcessing.maxSaveDimension, 1024)
    }

    func testImageProcessingMaxDisplayDimension() {
        XCTAssertEqual(ImageProcessing.maxDisplayDimension, 300)
    }

    func testImageProcessingDefaultLayerSize() {
        XCTAssertEqual(ImageProcessing.defaultLayerSize, 512)
    }

    func testDisplayDimensionLessThanSaveDimension() {
        XCTAssertLessThan(
            ImageProcessing.maxDisplayDimension,
            ImageProcessing.maxSaveDimension,
            "Display dimension should be smaller than save dimension for performance"
        )
    }

    func testDefaultLayerSizeReasonable() {
        // Default layer size should be reasonable (between 100 and 2048)
        XCTAssertGreaterThanOrEqual(ImageProcessing.defaultLayerSize, 100)
        XCTAssertLessThanOrEqual(ImageProcessing.defaultLayerSize, 2048)
    }

    func testImageDimensionsArePowersOfTwo() {
        // Common image sizes are powers of 2 for GPU optimization
        let saveDimension = Int(ImageProcessing.maxSaveDimension)
        let defaultSize = Int(ImageProcessing.defaultLayerSize)

        // Check if power of 2 (bitwise AND with (n-1) should be 0)
        XCTAssertTrue(saveDimension > 0 && (saveDimension & (saveDimension - 1)) == 0)
        XCTAssertTrue(defaultSize > 0 && (defaultSize & (defaultSize - 1)) == 0)
    }

    // MARK: - Canvas Settings Tests

    func testCanvasDefaultScale() {
        XCTAssertEqual(CanvasSettings.defaultScale, 1.0)
    }

    func testCanvasDefaultOffset() {
        XCTAssertEqual(CanvasSettings.defaultOffset, 0.0)
    }

    func testCanvasDefaultWidth() {
        XCTAssertEqual(CanvasSettings.defaultWidth, 1024)
    }

    func testCanvasDefaultHeight() {
        XCTAssertEqual(CanvasSettings.defaultHeight, 1024)
    }

    func testCanvasScaleIsPositive() {
        XCTAssertGreaterThan(CanvasSettings.defaultScale, 0)
    }

    func testCanvasScaleIsReasonable() {
        // Default scale should be 1.0 (100% zoom)
        XCTAssertEqual(CanvasSettings.defaultScale, 1.0, accuracy: 0.01)
    }

    func testCanvasDimensionsArePositive() {
        XCTAssertGreaterThan(CanvasSettings.defaultWidth, 0)
        XCTAssertGreaterThan(CanvasSettings.defaultHeight, 0)
    }

    func testCanvasDimensionsAreSquare() {
        XCTAssertEqual(
            CanvasSettings.defaultWidth,
            CanvasSettings.defaultHeight,
            "Default canvas should be square"
        )
    }

    func testCanvasDimensionsMatchImageProcessing() {
        XCTAssertEqual(
            CanvasSettings.defaultWidth,
            ImageProcessing.maxSaveDimension,
            "Canvas width should match max save dimension"
        )
        XCTAssertEqual(
            CanvasSettings.defaultHeight,
            ImageProcessing.maxSaveDimension,
            "Canvas height should match max save dimension"
        )
    }

    // MARK: - History Settings Tests

    func testHistoryMaxSizeIsPositive() {
        XCTAssertGreaterThan(HistorySettings.maxHistorySize, 0)
    }

    func testHistoryMaxSize() {
        XCTAssertEqual(HistorySettings.maxHistorySize, 50)
    }

    func testHistoryMaxSizeIsReasonable() {
        // History size should be between 10 and 500 for reasonable memory usage
        XCTAssertGreaterThanOrEqual(HistorySettings.maxHistorySize, 10)
        XCTAssertLessThanOrEqual(HistorySettings.maxHistorySize, 500)
    }

    // MARK: - Generation Settings Tests

    func testDefaultDimensionsFormat() {
        let dimensions = GenerationSettings.defaultDimensions
        let components = dimensions.split(separator: "x")

        XCTAssertEqual(components.count, 2, "Dimensions should be in format 'WIDTHxHEIGHT'")

        if components.count == 2 {
            XCTAssertNotNil(Int(components[0]), "Width should be a valid integer")
            XCTAssertNotNil(Int(components[1]), "Height should be a valid integer")
        }
    }

    func testDefaultDimensions() {
        XCTAssertEqual(GenerationSettings.defaultDimensions, "1024x1024")
    }

    func testDefaultDimensionsAreSquare() {
        let components = GenerationSettings.defaultDimensions.split(separator: "x")
        if components.count == 2 {
            XCTAssertEqual(components[0], components[1], "Default dimensions should be square")
        }
    }

    func testSeedRangeIsValid() {
        XCTAssertEqual(GenerationSettings.seedRange.lowerBound, 0)
        XCTAssertEqual(GenerationSettings.seedRange.upperBound, 999_999_999)
    }

    func testSeedRangeContainsZero() {
        XCTAssertTrue(GenerationSettings.seedRange.contains(0))
    }

    func testSeedRangeContainsMaxValue() {
        XCTAssertTrue(GenerationSettings.seedRange.contains(999_999_999))
    }

    func testSeedRangeIsReasonablyLarge() {
        let rangeSize = GenerationSettings.seedRange.upperBound - GenerationSettings.seedRange.lowerBound
        XCTAssertGreaterThan(rangeSize, 1_000_000, "Seed range should be large enough for variety")
    }

    func testRandomSeedWithinRange() {
        // Test that generating random seeds stays within range
        for _ in 0 ..< 100 {
            let seed = Int.random(in: GenerationSettings.seedRange)
            XCTAssertTrue(GenerationSettings.seedRange.contains(seed))
        }
    }
}
