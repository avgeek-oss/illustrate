// MARK: - ImageAdapterColorWorkflowTests.swift

// Workflow-level tests for color utility functions in ImageAdapter.swift.
//
// Covers:
// - Hex round-trip workflows (NSColor → hexString → NSColor(hex:))
// - Color distance workflow scenarios
// - Cluster comparison workflow scenarios
// - getUniversalColorFromHex workflow
// - NSColor(hex:) alpha channel handling

import AppKit
import CoreGraphics
import XCTest
@testable import Illustrate

final class ImageAdapterColorWorkflowTests: XCTestCase {
    // MARK: - Hex Round-Trip Workflows

    func testHexRoundTrip_red() throws {
        let original = NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let hex = original.hexString
        let restored = try XCTUnwrap(NSColor(hex: hex))

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        restored.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0, accuracy: 0.01)
        XCTAssertEqual(g, 0.0, accuracy: 0.01)
        XCTAssertEqual(b, 0.0, accuracy: 0.01)
    }

    func testHexRoundTrip_green() throws {
        let original = NSColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        let hex = original.hexString
        let restored = try XCTUnwrap(NSColor(hex: hex))

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        restored.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0.0, accuracy: 0.01)
        XCTAssertEqual(g, 1.0, accuracy: 0.01)
    }

    func testHexRoundTrip_blue() throws {
        let original = NSColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
        let hex = original.hexString
        let restored = try XCTUnwrap(NSColor(hex: hex))

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        restored.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(b, 1.0, accuracy: 0.01)
    }

    func testHexRoundTrip_black() throws {
        let original = NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let hex = original.hexString
        XCTAssertEqual(hex, "#000000")
        let restored = try XCTUnwrap(NSColor(hex: hex))

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        restored.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0.0, accuracy: 0.01)
        XCTAssertEqual(g, 0.0, accuracy: 0.01)
        XCTAssertEqual(b, 0.0, accuracy: 0.01)
    }

    func testHexRoundTrip_white() throws {
        let original = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        let hex = original.hexString
        XCTAssertEqual(hex, "#FFFFFF")
        let restored = try XCTUnwrap(NSColor(hex: hex))

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        restored.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0, accuracy: 0.01)
    }

    func testHexRoundTrip_customColor() throws {
        let original = NSColor(red: 0.5, green: 0.25, blue: 0.75, alpha: 1.0)
        let hex = original.hexString
        let restored = try XCTUnwrap(NSColor(hex: hex))

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        original.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        restored.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        // Allow small rounding error from Int(r * 255) conversion
        XCTAssertEqual(r1, r2, accuracy: 0.01)
        XCTAssertEqual(g1, g2, accuracy: 0.01)
        XCTAssertEqual(b1, b2, accuracy: 0.01)
    }

    // MARK: - Color Distance Workflow

    func testDistanceWorkflow_blackToWhite_isMaximum() {
        let black = (r: CGFloat(0), g: CGFloat(0), b: CGFloat(0))
        let white = (r: CGFloat(1), g: CGFloat(1), b: CGFloat(1))
        let d = distance(black, white)
        XCTAssertEqual(d, sqrt(3.0), accuracy: 0.0001)
    }

    func testDistanceWorkflow_redToGreen_isSqrt2() {
        let red = (r: CGFloat(1), g: CGFloat(0), b: CGFloat(0))
        let green = (r: CGFloat(0), g: CGFloat(1), b: CGFloat(0))
        XCTAssertEqual(distance(red, green), sqrt(2.0), accuracy: 0.0001)
    }

    func testDistanceWorkflow_similarColors_smallDistance() {
        let a = (r: CGFloat(0.5), g: CGFloat(0.5), b: CGFloat(0.5))
        let b = (r: CGFloat(0.52), g: CGFloat(0.48), b: CGFloat(0.51))
        XCTAssertLessThan(distance(a, b), 0.1)
    }

    func testDistanceWorkflow_complementaryColors_largeDistance() {
        let red = (r: CGFloat(1), g: CGFloat(0), b: CGFloat(0))
        let cyan = (r: CGFloat(0), g: CGFloat(1), b: CGFloat(1))
        XCTAssertGreaterThan(distance(red, cyan), 1.0)
    }

    func testDistanceWorkflow_triangleInequality() {
        let a = (r: CGFloat(0.1), g: CGFloat(0.2), b: CGFloat(0.3))
        let b = (r: CGFloat(0.5), g: CGFloat(0.6), b: CGFloat(0.7))
        let c = (r: CGFloat(0.9), g: CGFloat(0.1), b: CGFloat(0.4))

        let dAB = distance(a, b)
        let dBC = distance(b, c)
        let dAC = distance(a, c)

        XCTAssertLessThanOrEqual(dAC, dAB + dBC + 0.0001)
    }

    // MARK: - Cluster Comparison Workflow

    func testClusterWorkflow_identicalPalettes_equal() {
        let palette: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [
            (r: 1, g: 0, b: 0),
            (r: 0, g: 1, b: 0),
            (r: 0, g: 0, b: 1),
            (r: 1, g: 1, b: 0),
            (r: 0, g: 1, b: 1),
        ]
        XCTAssertTrue(clustersEqual(palette, palette))
    }

    func testClusterWorkflow_slightlyDifferent_notEqual() {
        let a: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [
            (r: 1, g: 0, b: 0),
            (r: 0, g: 1, b: 0),
        ]
        let b: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [
            (r: 1, g: 0, b: 0),
            (r: 0, g: 1, b: 0.001),
        ]
        XCTAssertFalse(clustersEqual(a, b))
    }

    func testClusterWorkflow_emptyVsNonEmpty_notEqual() {
        let empty: [(r: CGFloat, g: CGFloat, b: CGFloat)] = []
        let nonEmpty: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [(r: 0, g: 0, b: 0)]
        XCTAssertFalse(clustersEqual(empty, nonEmpty))
    }

    func testClusterWorkflow_reversedOrder_notEqual() {
        let a: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [
            (r: 1, g: 0, b: 0),
            (r: 0, g: 0, b: 1),
        ]
        let b: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [
            (r: 0, g: 0, b: 1),
            (r: 1, g: 0, b: 0),
        ]
        XCTAssertFalse(clustersEqual(a, b))
    }

    // MARK: - getUniversalColorFromHex Workflow

    func testGetUniversalColorFromHex_validHex_nonClear() {
        let color = getUniversalColorFromHex(hexString: "FF0000")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0, accuracy: 0.01)
    }

    func testGetUniversalColorFromHex_withHash() {
        let color = getUniversalColorFromHex(hexString: "#00FF00")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(g, 1.0, accuracy: 0.01)
    }

    func testGetUniversalColorFromHex_lowercase() {
        let color = getUniversalColorFromHex(hexString: "ff0000")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0, accuracy: 0.01)
    }

    func testGetUniversalColorFromHex_mixedCase() {
        let color = getUniversalColorFromHex(hexString: "Ff00Ff")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0, accuracy: 0.01)
        XCTAssertEqual(b, 1.0, accuracy: 0.01)
    }

    // MARK: - NSColor(hex:) Alpha Channel

    func testNSColorHex_8digit_fullAlpha() throws {
        let color = try XCTUnwrap(NSColor(hex: "FF0000FF"))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(a, 1.0, accuracy: 0.01)
    }

    func testNSColorHex_8digit_halfAlpha() throws {
        let color = try XCTUnwrap(NSColor(hex: "FF000080"))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(a, 128.0 / 255.0, accuracy: 0.01)
    }

    func testNSColorHex_8digit_zeroAlpha() throws {
        let color = try XCTUnwrap(NSColor(hex: "FF000000"))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(a, 0.0, accuracy: 0.01)
    }
}
