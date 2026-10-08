// MARK: - AspectRatioHelperTests.swift

// Workflow tests for AspectRatioHelpers: gcd(), convertToAspectRatio(),
// getAspectRatio(), and the AspectRatioResult-returning overload.
//
// Tests cover:
// - Euclidean GCD with standard, reversed, square, coprime, zero, and one inputs
// - Dimension-to-ratio conversion with passthrough, pixel parsing, and fallbacks
// - AspectRatioResult construction from both ratio and dimension inputs
// - Cross-function consistency and round-trip workflows

import XCTest
@testable import IllustrateProviders

final class AspectRatioHelperTests: XCTestCase {
    // MARK: - gcd() Tests

    func testGcd_StandardHD_1920x1080() {
        XCTAssertEqual(gcd(1920, 1080), 120)
    }

    func testGcd_ReversedArgs_1080x1920() {
        // Euclidean algorithm is commutative
        XCTAssertEqual(gcd(1080, 1920), 120)
    }

    func testGcd_Square_1024x1024() {
        XCTAssertEqual(gcd(1024, 1024), 1024)
    }

    func testGcd_CoprimeNumbers() {
        XCTAssertEqual(gcd(7, 13), 1)
    }

    func testGcd_ZeroEdgeCase() {
        XCTAssertEqual(gcd(0, 5), 5)
    }

    func testGcd_OneEdgeCase() {
        XCTAssertEqual(gcd(1, 1_000_000), 1)
    }

    func testGcd_BothZero() {
        // gcd(0, 0) — Euclidean algorithm returns 0 when both are zero
        XCTAssertEqual(gcd(0, 0), 0)
    }

    // MARK: - convertToAspectRatio() Tests

    func testConvert_StandardHD_1920x1080() {
        XCTAssertEqual(convertToAspectRatio("1920x1080"), "16:9")
    }

    func testConvert_Portrait_1080x1920() {
        XCTAssertEqual(convertToAspectRatio("1080x1920"), "9:16")
    }

    func testConvert_Square_1024x1024() {
        XCTAssertEqual(convertToAspectRatio("1024x1024"), "1:1")
    }

    func testConvert_SmallerSquare_512x512() {
        XCTAssertEqual(convertToAspectRatio("512x512"), "1:1")
    }

    func testConvert_DallE3Wide_1792x1024() {
        let ratio = convertToAspectRatio("1792x1024")
        XCTAssertTrue(ratio.contains(":"), "Should produce a valid ratio, got: \(ratio)")
    }

    func testConvert_DallE3Tall_1024x1792() {
        let ratio = convertToAspectRatio("1024x1792")
        XCTAssertTrue(ratio.contains(":"), "Should produce a valid ratio, got: \(ratio)")
    }

    func testConvert_Passthrough_16_9() {
        XCTAssertEqual(convertToAspectRatio("16:9"), "16:9")
    }

    func testConvert_Passthrough_9_16() {
        XCTAssertEqual(convertToAspectRatio("9:16"), "9:16")
    }

    func testConvert_Passthrough_1_1() {
        XCTAssertEqual(convertToAspectRatio("1:1"), "1:1")
    }

    func testConvert_InvalidInput_ReturnsDefault() {
        XCTAssertEqual(convertToAspectRatio("invalid"), "1:1")
    }

    func testConvert_EmptyString_ReturnsDefault() {
        XCTAssertEqual(convertToAspectRatio(""), "1:1")
    }

    func testConvert_CaseInsensitive_UppercaseX() {
        // "1920X1080" should also work since lowercased() is used
        XCTAssertEqual(convertToAspectRatio("1920X1080"), "16:9")
    }

    func testConvert_720p_1280x720() {
        XCTAssertEqual(convertToAspectRatio("1280x720"), "16:9")
    }

    func testConvert_4K_3840x2160() {
        XCTAssertEqual(convertToAspectRatio("3840x2160"), "16:9")
    }

    // MARK: - getAspectRatio(_:) Alias Tests

    func testGetAspectRatioAlias_MatchesConvert() {
        let dimensions = ["1920x1080", "1024x1024", "16:9", "", "invalid"]
        for dim in dimensions {
            XCTAssertEqual(
                getAspectRatio(dim),
                convertToAspectRatio(dim),
                "getAspectRatio and convertToAspectRatio should match for: \(dim)"
            )
        }
    }

    // MARK: - getAspectRatio(dimension:) → AspectRatioResult Tests

    func testResult_DimensionInput_1920x1080() {
        let result = getAspectRatio(dimension: "1920x1080")
        XCTAssertEqual(result.ratio, "16:9")
        XCTAssertEqual(result.width, 16)
        XCTAssertEqual(result.height, 9)
        XCTAssertEqual(result.actualWidth, 1920)
        XCTAssertEqual(result.actualHeight, 1080)
    }

    func testResult_DimensionInput_1024x1024() {
        let result = getAspectRatio(dimension: "1024x1024")
        XCTAssertEqual(result.ratio, "1:1")
        XCTAssertEqual(result.width, 1)
        XCTAssertEqual(result.height, 1)
        XCTAssertEqual(result.actualWidth, 1024)
        XCTAssertEqual(result.actualHeight, 1024)
    }

    func testResult_RatioInput_16_9_Calculates1080pBase() {
        let result = getAspectRatio(dimension: "16:9")
        XCTAssertEqual(result.ratio, "16:9")
        XCTAssertEqual(result.width, 16)
        XCTAssertEqual(result.height, 9)
        // w(16) >= h(9): actualHeight=1080, actualWidth=1080*16/9=1920
        XCTAssertEqual(result.actualWidth, 1920)
        XCTAssertEqual(result.actualHeight, 1080)
    }

    func testResult_RatioInput_9_16_Calculates1080pBase() {
        let result = getAspectRatio(dimension: "9:16")
        XCTAssertEqual(result.ratio, "9:16")
        XCTAssertEqual(result.width, 9)
        XCTAssertEqual(result.height, 16)
        // w(9) < h(16): actualWidth=1080, actualHeight=1080*16/9=1920
        XCTAssertEqual(result.actualWidth, 1080)
        XCTAssertEqual(result.actualHeight, 1920)
    }

    func testResult_RatioInput_1_1_Calculates1080pBase() {
        let result = getAspectRatio(dimension: "1:1")
        XCTAssertEqual(result.ratio, "1:1")
        XCTAssertEqual(result.width, 1)
        XCTAssertEqual(result.height, 1)
        // w(1) >= h(1): actualHeight=1080, actualWidth=1080*1/1=1080
        XCTAssertEqual(result.actualWidth, 1080)
        XCTAssertEqual(result.actualHeight, 1080)
    }

    func testResult_RatioInput_4_3() {
        let result = getAspectRatio(dimension: "4:3")
        XCTAssertEqual(result.ratio, "4:3")
        XCTAssertEqual(result.width, 4)
        XCTAssertEqual(result.height, 3)
        // w(4) >= h(3): actualHeight=1080, actualWidth=1080*4/3=1440
        XCTAssertEqual(result.actualWidth, 1440)
        XCTAssertEqual(result.actualHeight, 1080)
    }

    func testResult_RatioComponents_FromDimensionInput() {
        // For "1920x1080", ratio components should be 16 and 9
        let result = getAspectRatio(dimension: "1920x1080")
        XCTAssertEqual(result.width, 16)
        XCTAssertEqual(result.height, 9)
    }

    func testResult_ActualDimensions_FromDimensionInput() {
        let result = getAspectRatio(dimension: "1536x640")
        XCTAssertEqual(result.actualWidth, 1536)
        XCTAssertEqual(result.actualHeight, 640)
        // Ratio should simplify: gcd(1536, 640) = 128 → 12:5
        XCTAssertEqual(result.ratio, "12:5")
    }

    func testResult_LargeDimensions_4096x4096() {
        let result = getAspectRatio(dimension: "4096x4096")
        XCTAssertEqual(result.ratio, "1:1")
        XCTAssertEqual(result.actualWidth, 4096)
        XCTAssertEqual(result.actualHeight, 4096)
    }

    // MARK: - Cross-Function Workflow Tests

    func testWorkflow_RoundTrip_DimensionToRatioAndBack() {
        // Take actual dimensions from result, feed back to convertToAspectRatio
        let result = getAspectRatio(dimension: "1920x1080")
        let roundTripped = convertToAspectRatio("\(result.actualWidth)x\(result.actualHeight)")
        XCTAssertEqual(roundTripped, result.ratio)
    }

    func testWorkflow_ConsistentRatios_DifferentResolutions() {
        // HD and 4K should both produce 16:9
        let hd = convertToAspectRatio("1920x1080")
        let uhd = convertToAspectRatio("3840x2160")
        XCTAssertEqual(hd, uhd)
    }

    func testWorkflow_ConvertAndResultAgree() {
        let dimensions = ["1920x1080", "1024x1024", "1280x720", "512x512"]
        for dim in dimensions {
            let converted = convertToAspectRatio(dim)
            let result = getAspectRatio(dimension: dim)
            XCTAssertEqual(converted, result.ratio, "Mismatch for \(dim)")
        }
    }

    func testWorkflow_RatioInput_CalculatedDimensions_RoundTrip() {
        // 16:9 → result → actualWidth/actualHeight → convertToAspectRatio → should be 16:9
        let result = getAspectRatio(dimension: "16:9")
        let backToRatio = convertToAspectRatio("\(result.actualWidth)x\(result.actualHeight)")
        XCTAssertEqual(backToRatio, "16:9")
    }

    func testWorkflow_MultipleStandardResolutions_Same16_9() {
        let resolutions = ["1920x1080", "1280x720", "3840x2160", "2560x1440"]
        for res in resolutions {
            XCTAssertEqual(convertToAspectRatio(res), "16:9", "\(res) should be 16:9")
        }
    }
}
