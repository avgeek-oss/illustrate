// MARK: - FalPricingHelperTests.swift

// Workflow tests for FalPricingHelpers: falParseMegapixels() and falCalculateCost().
//
// Tests cover:
// - Megapixel parsing from nil, empty, numeric, MP format, WxH, and Fal presets
// - Cost calculation with perImage, perMegapixel, and perComputeSecond pricing
// - End-to-end pricing workflows chaining parse → calculate
// - Edge cases: zero rates, large dimensions, minimum image count clamping

import XCTest
@testable import IllustrateProviders

final class FalPricingHelperTests: XCTestCase {
    // MARK: - falParseMegapixels() Tests — Nil/Empty/Numeric

    func testParseMegapixels_Nil_ReturnsDefault() {
        XCTAssertEqual(falParseMegapixels(from: nil), 1.0)
    }

    func testParseMegapixels_EmptyString_ReturnsDefault() {
        XCTAssertEqual(falParseMegapixels(from: ""), 1.0)
    }

    func testParseMegapixels_WhitespaceOnly_ReturnsDefault() {
        XCTAssertEqual(falParseMegapixels(from: "   "), 1.0)
    }

    func testParseMegapixels_PlainNumeric_2() {
        XCTAssertEqual(falParseMegapixels(from: "2.0"), 2.0)
    }

    func testParseMegapixels_PlainNumeric_SubOne() {
        XCTAssertEqual(falParseMegapixels(from: "0.5"), 0.5)
    }

    func testParseMegapixels_PlainNumeric_Zero() {
        XCTAssertEqual(falParseMegapixels(from: "0"), 0.0)
    }

    // MARK: - falParseMegapixels() Tests — MP Format

    func testParseMegapixels_MPFormat_1MP() {
        XCTAssertEqual(falParseMegapixels(from: "1.0MP"), 1.0)
    }

    func testParseMegapixels_MPFormat_2_5MP() {
        XCTAssertEqual(falParseMegapixels(from: "2.5MP"), 2.5)
    }

    func testParseMegapixels_MPFormat_WithSpace() {
        XCTAssertEqual(falParseMegapixels(from: "1 MP"), 1.0)
    }

    // MARK: - falParseMegapixels() Tests — WxH Pixel Calculation

    func testParseMegapixels_WxH_1024x1024() {
        let expected = (1024.0 * 1024.0) / 1_000_000.0
        XCTAssertEqual(falParseMegapixels(from: "1024x1024"), expected, accuracy: 0.0001)
    }

    func testParseMegapixels_WxH_1920x1080() {
        let expected = (1920.0 * 1080.0) / 1_000_000.0
        XCTAssertEqual(falParseMegapixels(from: "1920x1080"), expected, accuracy: 0.0001)
    }

    func testParseMegapixels_WxH_512x512() {
        let expected = (512.0 * 512.0) / 1_000_000.0
        XCTAssertEqual(falParseMegapixels(from: "512x512"), expected, accuracy: 0.0001)
    }

    func testParseMegapixels_WxH_1x1_TinyValue() {
        let expected = 1.0 / 1_000_000.0
        XCTAssertEqual(falParseMegapixels(from: "1x1"), expected, accuracy: 0.0000001)
    }

    func testParseMegapixels_WxH_LargeDimensions_NoCrash() {
        let result = falParseMegapixels(from: "999999x999999")
        XCTAssertGreaterThan(result, 0)
        XCTAssertFalse(result.isNaN)
        XCTAssertFalse(result.isInfinite)
    }

    // MARK: - falParseMegapixels() Tests — Fal Presets

    func testParseMegapixels_Preset_SquareHD() {
        XCTAssertEqual(falParseMegapixels(from: "square_hd"), 1.05)
    }

    func testParseMegapixels_Preset_Square() {
        XCTAssertEqual(falParseMegapixels(from: "square"), 0.26)
    }

    func testParseMegapixels_Preset_Portrait_4_3() {
        XCTAssertEqual(falParseMegapixels(from: "portrait_4_3"), 1.05)
    }

    func testParseMegapixels_Preset_Portrait_16_9() {
        XCTAssertEqual(falParseMegapixels(from: "portrait_16_9"), 1.05)
    }

    func testParseMegapixels_Preset_Portrait_9_16() {
        XCTAssertEqual(falParseMegapixels(from: "portrait_9_16"), 1.05)
    }

    func testParseMegapixels_Preset_Landscape_4_3() {
        XCTAssertEqual(falParseMegapixels(from: "landscape_4_3"), 1.05)
    }

    func testParseMegapixels_Preset_Landscape_16_9() {
        XCTAssertEqual(falParseMegapixels(from: "landscape_16_9"), 1.05)
    }

    func testParseMegapixels_Preset_Ratio_1_1() {
        XCTAssertEqual(falParseMegapixels(from: "1:1"), 1.05)
    }

    func testParseMegapixels_Preset_Ratio_16_9() {
        XCTAssertEqual(falParseMegapixels(from: "16:9"), 1.05)
    }

    func testParseMegapixels_Preset_Ratio_21_9() {
        XCTAssertEqual(falParseMegapixels(from: "21:9"), 1.2)
    }

    func testParseMegapixels_CaseInsensitive_Presets() {
        // Presets use lowercased() switch, so uppercase should also work
        XCTAssertEqual(falParseMegapixels(from: "SQUARE_HD"), 1.05)
        XCTAssertEqual(falParseMegapixels(from: "Square"), 0.26)
    }

    func testParseMegapixels_UnknownString_ReturnsDefault() {
        XCTAssertEqual(falParseMegapixels(from: "unknown_preset"), 1.0)
    }

    // MARK: - falCalculateCost() Tests — perImage

    func testCalcCost_PerImage_SingleImage() {
        let cost = falCalculateCost(
            pricing: .perImage(0.04),
            dimensions: "1024x1024",
            numberOfImages: 1
        )
        XCTAssertEqual(cost, 0.04, accuracy: 0.001)
    }

    func testCalcCost_PerImage_MultipleImages() {
        let cost = falCalculateCost(
            pricing: .perImage(0.04),
            dimensions: "1024x1024",
            numberOfImages: 3
        )
        XCTAssertEqual(cost, 0.12, accuracy: 0.001)
    }

    func testCalcCost_PerImage_ZeroRate() {
        let cost = falCalculateCost(
            pricing: .perImage(0.0),
            dimensions: "1024x1024",
            numberOfImages: 5
        )
        XCTAssertEqual(cost, 0.0)
    }

    func testCalcCost_PerImage_IgnoresDimensions() {
        // perImage pricing should produce the same cost regardless of dimensions
        let small = falCalculateCost(pricing: .perImage(0.04), dimensions: "512x512", numberOfImages: 1)
        let large = falCalculateCost(pricing: .perImage(0.04), dimensions: "4096x4096", numberOfImages: 1)
        XCTAssertEqual(small, large, "perImage cost should not vary with dimensions")
    }

    func testCalcCost_PerImage_ZeroImages_ClampsToOne() {
        // max(1, numberOfImages) means 0 images → 1 image
        let cost = falCalculateCost(
            pricing: .perImage(0.04),
            dimensions: nil,
            numberOfImages: 0
        )
        XCTAssertEqual(cost, 0.04, accuracy: 0.001)
    }

    // MARK: - falCalculateCost() Tests — perMegapixel

    func testCalcCost_PerMegapixel_WithPixelDimensions() {
        let megapixels = falParseMegapixels(from: "1024x1024")
        let cost = falCalculateCost(
            pricing: .perMegapixel(0.03),
            dimensions: "1024x1024",
            numberOfImages: 1
        )
        XCTAssertEqual(cost, 0.03 * megapixels, accuracy: 0.001)
    }

    func testCalcCost_PerMegapixel_WithPreset() {
        let cost = falCalculateCost(
            pricing: .perMegapixel(0.03),
            dimensions: "square_hd",
            numberOfImages: 1
        )
        XCTAssertEqual(cost, 0.03 * 1.05, accuracy: 0.001)
    }

    func testCalcCost_PerMegapixel_NilDimensions_UsesDefault() {
        // nil → 1.0 megapixel default
        let cost = falCalculateCost(
            pricing: .perMegapixel(0.03),
            dimensions: nil,
            numberOfImages: 1
        )
        XCTAssertEqual(cost, 0.03 * 1.0, accuracy: 0.001)
    }

    func testCalcCost_PerMegapixel_MultipleImages() {
        let cost = falCalculateCost(
            pricing: .perMegapixel(0.03),
            dimensions: "square_hd",
            numberOfImages: 2
        )
        XCTAssertEqual(cost, 0.03 * 1.05 * 2, accuracy: 0.001)
    }

    // MARK: - falCalculateCost() Tests — perComputeSecond

    func testCalcCost_PerComputeSecond_SingleImage() {
        let cost = falCalculateCost(
            pricing: .perComputeSecond(0.01, avgSeconds: 10),
            dimensions: nil,
            numberOfImages: 1
        )
        XCTAssertEqual(cost, 0.01 * 10, accuracy: 0.001)
    }

    func testCalcCost_PerComputeSecond_MultipleImages() {
        let cost = falCalculateCost(
            pricing: .perComputeSecond(0.01, avgSeconds: 10),
            dimensions: nil,
            numberOfImages: 3
        )
        XCTAssertEqual(cost, 0.01 * 10 * 3, accuracy: 0.001)
    }

    func testCalcCost_PerComputeSecond_ZeroSeconds() {
        let cost = falCalculateCost(
            pricing: .perComputeSecond(0.01, avgSeconds: 0),
            dimensions: nil,
            numberOfImages: 1
        )
        XCTAssertEqual(cost, 0.0)
    }

    func testCalcCost_PerComputeSecond_ZeroRate() {
        let cost = falCalculateCost(
            pricing: .perComputeSecond(0.0, avgSeconds: 100),
            dimensions: nil,
            numberOfImages: 5
        )
        XCTAssertEqual(cost, 0.0)
    }

    // MARK: - Workflow Tests — End-to-End Pricing

    func testWorkflow_ParseThenCalculate_FullChain() {
        // Parse megapixels from pixel dimensions, then calculate cost
        let megapixels = falParseMegapixels(from: "1920x1080")
        let cost = falCalculateCost(
            pricing: .perMegapixel(0.03),
            dimensions: "1920x1080",
            numberOfImages: 1
        )
        XCTAssertEqual(cost, 0.03 * megapixels, accuracy: 0.0001)
    }

    func testWorkflow_SquareVsSquareHD_CostComparison() {
        // square (0.26 MP) should cost less than square_hd (1.05 MP) at same rate
        let squareCost = falCalculateCost(
            pricing: .perMegapixel(0.03),
            dimensions: "square",
            numberOfImages: 1
        )
        let squareHDCost = falCalculateCost(
            pricing: .perMegapixel(0.03),
            dimensions: "square_hd",
            numberOfImages: 1
        )
        XCTAssertGreaterThan(squareHDCost, squareCost)
    }

    func testWorkflow_DoublingImages_DoublesCost_AllPricingUnits() {
        let dims = "1024x1024"

        let perImage1 = falCalculateCost(pricing: .perImage(0.04), dimensions: dims, numberOfImages: 1)
        let perImage2 = falCalculateCost(pricing: .perImage(0.04), dimensions: dims, numberOfImages: 2)
        XCTAssertEqual(perImage2, perImage1 * 2, accuracy: 0.001)

        let perMP1 = falCalculateCost(pricing: .perMegapixel(0.03), dimensions: dims, numberOfImages: 1)
        let perMP2 = falCalculateCost(pricing: .perMegapixel(0.03), dimensions: dims, numberOfImages: 2)
        XCTAssertEqual(perMP2, perMP1 * 2, accuracy: 0.001)

        let perCS1 = falCalculateCost(
            pricing: .perComputeSecond(0.01, avgSeconds: 10),
            dimensions: dims,
            numberOfImages: 1
        )
        let perCS2 = falCalculateCost(
            pricing: .perComputeSecond(0.01, avgSeconds: 10),
            dimensions: dims,
            numberOfImages: 2
        )
        XCTAssertEqual(perCS2, perCS1 * 2, accuracy: 0.001)
    }

    func testWorkflow_AllPresetsPositiveMegapixels() {
        // Every known preset should parse to a positive megapixel value
        let presets = [
            "square_hd", "square", "portrait_4_3", "portrait_16_9",
            "portrait_9_16", "landscape_4_3", "landscape_16_9",
        ]
        for preset in presets {
            let mp = falParseMegapixels(from: preset)
            XCTAssertGreaterThan(mp, 0, "Preset '\(preset)' should have positive megapixels")
        }
    }

    func testWorkflow_PresetMegapixels_WithinReasonableRange() {
        // All presets should be between 0.1 and 5.0 MP
        let presets = [
            "square_hd", "square", "portrait_4_3", "portrait_16_9",
            "landscape_4_3", "landscape_16_9", "1:1", "16:9", "21:9",
        ]
        for preset in presets {
            let mp = falParseMegapixels(from: preset)
            XCTAssertGreaterThan(mp, 0.1, "Preset '\(preset)' MP too low: \(mp)")
            XCTAssertLessThan(mp, 5.0, "Preset '\(preset)' MP too high: \(mp)")
        }
    }
}
