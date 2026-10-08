// MARK: - VideoDimensionsTests.swift

// Tests for getVideoDimensions(resolution:aspectRatio:) pure function.
//
// Covers:
// - All 27 known resolution/aspect-ratio mappings (3 resolutions × 9 ratios)
// - Fallback calculations for unknown ratios
// - Default behaviors for unknown resolutions, empty inputs, invalid formats
// - Symmetry validation (16:9 mirrors 9:16, etc.)
// - Consistency checks (higher res → larger dimensions, square 1:1)

import XCTest
@testable import Illustrate

final class VideoDimensionsTests: XCTestCase {
    // MARK: - 480p Known Mappings

    func test480p_16by9() {
        let result = getVideoDimensions(resolution: "480p", aspectRatio: "16:9")
        XCTAssertEqual(result.width, 854)
        XCTAssertEqual(result.height, 480)
    }

    func test480p_9by16() {
        let result = getVideoDimensions(resolution: "480p", aspectRatio: "9:16")
        XCTAssertEqual(result.width, 480)
        XCTAssertEqual(result.height, 854)
    }

    func test480p_4by3() {
        let result = getVideoDimensions(resolution: "480p", aspectRatio: "4:3")
        XCTAssertEqual(result.width, 640)
        XCTAssertEqual(result.height, 480)
    }

    func test480p_3by4() {
        let result = getVideoDimensions(resolution: "480p", aspectRatio: "3:4")
        XCTAssertEqual(result.width, 480)
        XCTAssertEqual(result.height, 640)
    }

    func test480p_1by1() {
        let result = getVideoDimensions(resolution: "480p", aspectRatio: "1:1")
        XCTAssertEqual(result.width, 480)
        XCTAssertEqual(result.height, 480)
    }

    func test480p_21by9() {
        let result = getVideoDimensions(resolution: "480p", aspectRatio: "21:9")
        XCTAssertEqual(result.width, 1120)
        XCTAssertEqual(result.height, 480)
    }

    func test480p_9by21() {
        let result = getVideoDimensions(resolution: "480p", aspectRatio: "9:21")
        XCTAssertEqual(result.width, 480)
        XCTAssertEqual(result.height, 1120)
    }

    func test480p_3by2() {
        let result = getVideoDimensions(resolution: "480p", aspectRatio: "3:2")
        XCTAssertEqual(result.width, 720)
        XCTAssertEqual(result.height, 480)
    }

    func test480p_2by3() {
        let result = getVideoDimensions(resolution: "480p", aspectRatio: "2:3")
        XCTAssertEqual(result.width, 480)
        XCTAssertEqual(result.height, 720)
    }

    // MARK: - 720p Known Mappings

    func test720p_16by9() {
        let result = getVideoDimensions(resolution: "720p", aspectRatio: "16:9")
        XCTAssertEqual(result.width, 1280)
        XCTAssertEqual(result.height, 720)
    }

    func test720p_9by16() {
        let result = getVideoDimensions(resolution: "720p", aspectRatio: "9:16")
        XCTAssertEqual(result.width, 720)
        XCTAssertEqual(result.height, 1280)
    }

    func test720p_4by3() {
        let result = getVideoDimensions(resolution: "720p", aspectRatio: "4:3")
        XCTAssertEqual(result.width, 960)
        XCTAssertEqual(result.height, 720)
    }

    func test720p_3by4() {
        let result = getVideoDimensions(resolution: "720p", aspectRatio: "3:4")
        XCTAssertEqual(result.width, 720)
        XCTAssertEqual(result.height, 960)
    }

    func test720p_1by1() {
        let result = getVideoDimensions(resolution: "720p", aspectRatio: "1:1")
        XCTAssertEqual(result.width, 720)
        XCTAssertEqual(result.height, 720)
    }

    func test720p_21by9() {
        let result = getVideoDimensions(resolution: "720p", aspectRatio: "21:9")
        XCTAssertEqual(result.width, 1680)
        XCTAssertEqual(result.height, 720)
    }

    func test720p_9by21() {
        let result = getVideoDimensions(resolution: "720p", aspectRatio: "9:21")
        XCTAssertEqual(result.width, 720)
        XCTAssertEqual(result.height, 1680)
    }

    func test720p_3by2() {
        let result = getVideoDimensions(resolution: "720p", aspectRatio: "3:2")
        XCTAssertEqual(result.width, 1080)
        XCTAssertEqual(result.height, 720)
    }

    func test720p_2by3() {
        let result = getVideoDimensions(resolution: "720p", aspectRatio: "2:3")
        XCTAssertEqual(result.width, 720)
        XCTAssertEqual(result.height, 1080)
    }

    // MARK: - 1080p Known Mappings

    func test1080p_16by9() {
        let result = getVideoDimensions(resolution: "1080p", aspectRatio: "16:9")
        XCTAssertEqual(result.width, 1920)
        XCTAssertEqual(result.height, 1080)
    }

    func test1080p_9by16() {
        let result = getVideoDimensions(resolution: "1080p", aspectRatio: "9:16")
        XCTAssertEqual(result.width, 1080)
        XCTAssertEqual(result.height, 1920)
    }

    func test1080p_4by3() {
        let result = getVideoDimensions(resolution: "1080p", aspectRatio: "4:3")
        XCTAssertEqual(result.width, 1440)
        XCTAssertEqual(result.height, 1080)
    }

    func test1080p_3by4() {
        let result = getVideoDimensions(resolution: "1080p", aspectRatio: "3:4")
        XCTAssertEqual(result.width, 1080)
        XCTAssertEqual(result.height, 1440)
    }

    func test1080p_1by1() {
        let result = getVideoDimensions(resolution: "1080p", aspectRatio: "1:1")
        XCTAssertEqual(result.width, 1080)
        XCTAssertEqual(result.height, 1080)
    }

    func test1080p_21by9() {
        let result = getVideoDimensions(resolution: "1080p", aspectRatio: "21:9")
        XCTAssertEqual(result.width, 2520)
        XCTAssertEqual(result.height, 1080)
    }

    func test1080p_9by21() {
        let result = getVideoDimensions(resolution: "1080p", aspectRatio: "9:21")
        XCTAssertEqual(result.width, 1080)
        XCTAssertEqual(result.height, 2520)
    }

    func test1080p_3by2() {
        let result = getVideoDimensions(resolution: "1080p", aspectRatio: "3:2")
        XCTAssertEqual(result.width, 1620)
        XCTAssertEqual(result.height, 1080)
    }

    func test1080p_2by3() {
        let result = getVideoDimensions(resolution: "1080p", aspectRatio: "2:3")
        XCTAssertEqual(result.width, 1080)
        XCTAssertEqual(result.height, 1620)
    }

    // MARK: - Fallback: Unknown Aspect Ratio, Known Resolution

    func testFallback_5by4_at480p() {
        let result = getVideoDimensions(resolution: "480p", aspectRatio: "5:4")
        // ratio = 5/4 = 1.25, >=1, width = 480 * 1.25 = 600
        XCTAssertEqual(result.width, 600)
        XCTAssertEqual(result.height, 480)
    }

    func testFallback_5by4_at720p() {
        let result = getVideoDimensions(resolution: "720p", aspectRatio: "5:4")
        // width = 720 * 1.25 = 900
        XCTAssertEqual(result.width, 900)
        XCTAssertEqual(result.height, 720)
    }

    func testFallback_5by4_at1080p() {
        let result = getVideoDimensions(resolution: "1080p", aspectRatio: "5:4")
        // width = 1080 * 1.25 = 1350
        XCTAssertEqual(result.width, 1350)
        XCTAssertEqual(result.height, 1080)
    }

    func testFallback_2by1_at1080p() {
        let result = getVideoDimensions(resolution: "1080p", aspectRatio: "2:1")
        // ratio = 2.0, >=1, width = 1080 * 2 = 2160
        XCTAssertEqual(result.width, 2160)
        XCTAssertEqual(result.height, 1080)
    }

    func testFallback_1by2_at1080p() {
        let result = getVideoDimensions(resolution: "1080p", aspectRatio: "1:2")
        // ratio = 0.5, <1, height = 1080 / 0.5 = 2160
        XCTAssertEqual(result.width, 1080)
        XCTAssertEqual(result.height, 2160)
    }

    // MARK: - Fallback: Unknown Resolution

    func testFallback_unknownResolution_4K_defaultsTo1080Base() {
        let result = getVideoDimensions(resolution: "4K", aspectRatio: "16:9")
        // Unknown resolution defaults to 1080 base
        // But "16:9" is a known ratio in 1080p map... wait, the lookup first checks
        // dimensionMap["4K"] which is nil, so it falls through to calculation
        // baseHeight = 1080, ratio = 16/9 = 1.777..., width = 1080 * 1.777 = 1920
        XCTAssertEqual(result.width, 1920)
        XCTAssertEqual(result.height, 1080)
    }

    func testFallback_emptyResolution_defaultsTo1080Base() {
        let result = getVideoDimensions(resolution: "", aspectRatio: "16:9")
        // baseHeight defaults to 1080
        XCTAssertEqual(result.width, 1920)
        XCTAssertEqual(result.height, 1080)
    }

    // MARK: - Fallback: Invalid Aspect Ratios → Default (1920, 1080)

    func testFallback_emptyAspectRatio_returnsDefault() {
        let result = getVideoDimensions(resolution: "1080p", aspectRatio: "")
        XCTAssertEqual(result.width, 1920)
        XCTAssertEqual(result.height, 1080)
    }

    func testFallback_singleNumber_returnsDefault() {
        let result = getVideoDimensions(resolution: "1080p", aspectRatio: "16")
        XCTAssertEqual(result.width, 1920)
        XCTAssertEqual(result.height, 1080)
    }

    func testFallback_nonNumeric_returnsDefault() {
        let result = getVideoDimensions(resolution: "1080p", aspectRatio: "sixteen")
        XCTAssertEqual(result.width, 1920)
        XCTAssertEqual(result.height, 1080)
    }

    func testFallback_zeroWidth_returnsDefault() {
        let result = getVideoDimensions(resolution: "1080p", aspectRatio: "0:9")
        XCTAssertEqual(result.width, 1920)
        XCTAssertEqual(result.height, 1080)
    }

    func testFallback_zeroHeight_returnsDefault() {
        let result = getVideoDimensions(resolution: "1080p", aspectRatio: "16:0")
        XCTAssertEqual(result.width, 1920)
        XCTAssertEqual(result.height, 1080)
    }

    func testFallback_negativeRatio_returnsDefault() {
        let result = getVideoDimensions(resolution: "1080p", aspectRatio: "-16:9")
        XCTAssertEqual(result.width, 1920)
        XCTAssertEqual(result.height, 1080)
    }

    func testFallback_multipleColons_returnsDefault() {
        let result = getVideoDimensions(resolution: "1080p", aspectRatio: "16:9:4")
        // split(separator: ":") produces 3 parts, count != 2
        XCTAssertEqual(result.width, 1920)
        XCTAssertEqual(result.height, 1080)
    }

    func testFallback_doubleColon_returnsDefault() {
        let result = getVideoDimensions(resolution: "1080p", aspectRatio: "16::9")
        // split(separator: ":") with double colon may produce empty elements
        // but the split won't produce exactly 2 valid doubles
        XCTAssertEqual(result.width, 1920)
        XCTAssertEqual(result.height, 1080)
    }

    // MARK: - Symmetry Checks

    func testSymmetry_16by9_vs_9by16_at480p() {
        let wide = getVideoDimensions(resolution: "480p", aspectRatio: "16:9")
        let tall = getVideoDimensions(resolution: "480p", aspectRatio: "9:16")
        XCTAssertEqual(wide.width, tall.height)
        XCTAssertEqual(wide.height, tall.width)
    }

    func testSymmetry_4by3_vs_3by4_at720p() {
        let wide = getVideoDimensions(resolution: "720p", aspectRatio: "4:3")
        let tall = getVideoDimensions(resolution: "720p", aspectRatio: "3:4")
        XCTAssertEqual(wide.width, tall.height)
        XCTAssertEqual(wide.height, tall.width)
    }

    func testSymmetry_21by9_vs_9by21_at1080p() {
        let wide = getVideoDimensions(resolution: "1080p", aspectRatio: "21:9")
        let tall = getVideoDimensions(resolution: "1080p", aspectRatio: "9:21")
        XCTAssertEqual(wide.width, tall.height)
        XCTAssertEqual(wide.height, tall.width)
    }

    func testSymmetry_3by2_vs_2by3_at1080p() {
        let wide = getVideoDimensions(resolution: "1080p", aspectRatio: "3:2")
        let tall = getVideoDimensions(resolution: "1080p", aspectRatio: "2:3")
        XCTAssertEqual(wide.width, tall.height)
        XCTAssertEqual(wide.height, tall.width)
    }

    // MARK: - Consistency Checks

    func testSquare1by1_allResolutions_widthEqualsHeight() {
        for res in ["480p", "720p", "1080p"] {
            let result = getVideoDimensions(resolution: res, aspectRatio: "1:1")
            XCTAssertEqual(result.width, result.height, "1:1 at \(res) should be square")
        }
    }

    func testHigherResolution_largerDimensions_16by9() {
        let r480 = getVideoDimensions(resolution: "480p", aspectRatio: "16:9")
        let r720 = getVideoDimensions(resolution: "720p", aspectRatio: "16:9")
        let r1080 = getVideoDimensions(resolution: "1080p", aspectRatio: "16:9")

        XCTAssertLessThan(r480.width, r720.width)
        XCTAssertLessThan(r720.width, r1080.width)
        XCTAssertLessThan(r480.height, r720.height)
        XCTAssertLessThan(r720.height, r1080.height)
    }

    func testAllKnownEntries_positiveWidthAndHeight() {
        let resolutions = ["480p", "720p", "1080p"]
        let ratios = ["16:9", "9:16", "4:3", "3:4", "1:1", "21:9", "9:21", "3:2", "2:3"]

        for res in resolutions {
            for ratio in ratios {
                let result = getVideoDimensions(resolution: res, aspectRatio: ratio)
                XCTAssertGreaterThan(result.width, 0, "\(res) \(ratio) width should be positive")
                XCTAssertGreaterThan(result.height, 0, "\(res) \(ratio) height should be positive")
            }
        }
    }
}
