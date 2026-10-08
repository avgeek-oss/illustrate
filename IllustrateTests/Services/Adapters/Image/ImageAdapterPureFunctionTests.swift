// MARK: - ImageAdapterPureFunctionTests.swift

// Tests for pure functions in ImageAdapter.swift:
// - distance() — Euclidean RGB distance
// - clustersEqual() — cluster array comparison
// - UniversalColor.hexString — color to hex conversion
// - NSColor(hex:) — hex to color initializer
// - getUniversalColorFromHex — hex to color function

import AppKit
import CoreGraphics
import XCTest
@testable import Illustrate

final class ImageAdapterPureFunctionTests: XCTestCase {
    // MARK: - distance() Function

    func testDistance_samePoint_isZero() {
        let point = (r: CGFloat(0.5), g: CGFloat(0.3), b: CGFloat(0.7))
        let result = distance(point, point)
        XCTAssertEqual(result, 0, accuracy: 0.0001)
    }

    func testDistance_origin_to_unitR() {
        let a = (r: CGFloat(0), g: CGFloat(0), b: CGFloat(0))
        let b = (r: CGFloat(1), g: CGFloat(0), b: CGFloat(0))
        XCTAssertEqual(distance(a, b), 1.0, accuracy: 0.0001)
    }

    func testDistance_origin_to_unitG() {
        let a = (r: CGFloat(0), g: CGFloat(0), b: CGFloat(0))
        let b = (r: CGFloat(0), g: CGFloat(1), b: CGFloat(0))
        XCTAssertEqual(distance(a, b), 1.0, accuracy: 0.0001)
    }

    func testDistance_origin_to_unitB() {
        let a = (r: CGFloat(0), g: CGFloat(0), b: CGFloat(0))
        let b = (r: CGFloat(0), g: CGFloat(0), b: CGFloat(1))
        XCTAssertEqual(distance(a, b), 1.0, accuracy: 0.0001)
    }

    func testDistance_diagonal_1_1_1() {
        let a = (r: CGFloat(0), g: CGFloat(0), b: CGFloat(0))
        let b = (r: CGFloat(1), g: CGFloat(1), b: CGFloat(1))
        let expected = sqrt(3.0)
        XCTAssertEqual(distance(a, b), expected, accuracy: 0.0001)
    }

    func testDistance_isCommutative() {
        let a = (r: CGFloat(0.1), g: CGFloat(0.5), b: CGFloat(0.9))
        let b = (r: CGFloat(0.8), g: CGFloat(0.2), b: CGFloat(0.3))
        XCTAssertEqual(distance(a, b), distance(b, a), accuracy: 0.0001)
    }

    func testDistance_largeValues() {
        let a = (r: CGFloat(10), g: CGFloat(20), b: CGFloat(30))
        let b = (r: CGFloat(40), g: CGFloat(50), b: CGFloat(60))
        let expected = sqrt(CGFloat(900 + 900 + 900))
        XCTAssertEqual(distance(a, b), expected, accuracy: 0.01)
    }

    func testDistance_smallDifference() {
        let a = (r: CGFloat(0.5), g: CGFloat(0.5), b: CGFloat(0.5))
        let b = (r: CGFloat(0.51), g: CGFloat(0.51), b: CGFloat(0.51))
        XCTAssertLessThan(distance(a, b), 0.02)
    }

    // MARK: - clustersEqual() Function

    func testClustersEqual_emptyArrays_isTrue() {
        let a: [(r: CGFloat, g: CGFloat, b: CGFloat)] = []
        let b: [(r: CGFloat, g: CGFloat, b: CGFloat)] = []
        XCTAssertTrue(clustersEqual(a, b))
    }

    func testClustersEqual_sameElements_isTrue() {
        let a = [(r: CGFloat(1), g: CGFloat(0), b: CGFloat(0))]
        let b = [(r: CGFloat(1), g: CGFloat(0), b: CGFloat(0))]
        XCTAssertTrue(clustersEqual(a, b))
    }

    func testClustersEqual_differentElements_isFalse() {
        let a = [(r: CGFloat(1), g: CGFloat(0), b: CGFloat(0))]
        let b = [(r: CGFloat(0), g: CGFloat(1), b: CGFloat(0))]
        XCTAssertFalse(clustersEqual(a, b))
    }

    func testClustersEqual_differentLengths_isFalse() {
        let a = [(r: CGFloat(1), g: CGFloat(0), b: CGFloat(0))]
        let b: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [
            (r: 1, g: 0, b: 0),
            (r: 0, g: 1, b: 0),
        ]
        XCTAssertFalse(clustersEqual(a, b))
    }

    func testClustersEqual_singleElementEqual() {
        let a = [(r: CGFloat(0.5), g: CGFloat(0.5), b: CGFloat(0.5))]
        let b = [(r: CGFloat(0.5), g: CGFloat(0.5), b: CGFloat(0.5))]
        XCTAssertTrue(clustersEqual(a, b))
    }

    func testClustersEqual_singleElementDifferent() {
        let a = [(r: CGFloat(0.5), g: CGFloat(0.5), b: CGFloat(0.5))]
        let b = [(r: CGFloat(0.5), g: CGFloat(0.5), b: CGFloat(0.6))]
        XCTAssertFalse(clustersEqual(a, b))
    }

    func testClustersEqual_orderMatters() {
        let red = (r: CGFloat(1), g: CGFloat(0), b: CGFloat(0))
        let blue = (r: CGFloat(0), g: CGFloat(0), b: CGFloat(1))
        XCTAssertFalse(clustersEqual([red, blue], [blue, red]))
    }

    func testClustersEqual_multipleAllSame() {
        let color = (r: CGFloat(0.3), g: CGFloat(0.6), b: CGFloat(0.9))
        let a = [color, color, color]
        let b = [color, color, color]
        XCTAssertTrue(clustersEqual(a, b))
    }

    // MARK: - UniversalColor.hexString

    func testHexString_red() {
        let color = NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        XCTAssertEqual(color.hexString, "#FF0000")
    }

    func testHexString_green() {
        let color = NSColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        XCTAssertEqual(color.hexString, "#00FF00")
    }

    func testHexString_blue() {
        let color = NSColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
        XCTAssertEqual(color.hexString, "#0000FF")
    }

    func testHexString_white() {
        let color = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        XCTAssertEqual(color.hexString, "#FFFFFF")
    }

    func testHexString_black() {
        let color = NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        XCTAssertEqual(color.hexString, "#000000")
    }

    func testHexString_startsWithHash_7Chars() {
        let color = NSColor(red: 0.5, green: 0.3, blue: 0.8, alpha: 1.0)
        XCTAssertTrue(color.hexString.hasPrefix("#"))
        XCTAssertEqual(color.hexString.count, 7)
    }

    // MARK: - NSColor(hex:) Initializer

    func testNSColorHex_valid6Digit_returnsNonNil() {
        XCTAssertNotNil(NSColor(hex: "FF0000"))
    }

    func testNSColorHex_valid8Digit_returnsNonNil() {
        XCTAssertNotNil(NSColor(hex: "FF0000FF"))
    }

    func testNSColorHex_withHash_returnsNonNil() {
        XCTAssertNotNil(NSColor(hex: "#FF0000"))
    }

    func testNSColorHex_tooShort_returnsNil() {
        XCTAssertNil(NSColor(hex: "FFF"))
    }

    func testNSColorHex_tooLong_returnsNil() {
        XCTAssertNil(NSColor(hex: "FF0000FF00"))
    }

    func testNSColorHex_emptyString_returnsNil() {
        XCTAssertNil(NSColor(hex: ""))
    }

    func testNSColorHex_whitespace_trimmed() {
        XCTAssertNotNil(NSColor(hex: " FF0000 "))
    }

    // MARK: - getUniversalColorFromHex

    func testGetUniversalColorFromHex_invalidHex_returnsClear() {
        let color = getUniversalColorFromHex(hexString: "invalid")
        XCTAssertEqual(color, NSColor.clear)
    }
}
