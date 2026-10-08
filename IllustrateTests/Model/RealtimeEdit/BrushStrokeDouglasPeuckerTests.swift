// MARK: - BrushStrokeDouglasPeuckerTests.swift

// Tests for the Douglas-Peucker line simplification algorithm in BrushStroke.
//
// Tests cover:
// - Guard clauses (0, 1, 2 points — no change)
// - Collinear points reduction to endpoints
// - Non-collinear points with varying epsilon
// - Complex curves (sine wave, zigzag)
// - Epsilon comparison (high vs low)
// - First/last point preservation
// - Idempotence (calling twice yields same result)
// - Degenerate cases (identical points, start equals end)
// - Default epsilon behavior
// - Large input performance
// - Mutation verification (preserves id, colorHex, size)

import CoreGraphics
import Foundation
import XCTest
@testable import Illustrate

final class BrushStrokeDouglasPeuckerTests: XCTestCase {
    // MARK: - Helper

    private func makeStroke(points: [CGPoint]) -> BrushStroke {
        BrushStroke(points: points, colorHex: "FF0000", size: 3.0)
    }

    // MARK: - Guard Clauses (0, 1, 2 points)

    func testSimplify_emptyPoints_noChange() {
        var stroke = makeStroke(points: [])
        stroke.simplify(epsilon: 1.0)
        XCTAssertEqual(stroke.points.count, 0)
    }

    func testSimplify_singlePoint_noChange() {
        let point = CGPoint(x: 10, y: 20)
        var stroke = makeStroke(points: [point])
        stroke.simplify(epsilon: 1.0)
        XCTAssertEqual(stroke.points.count, 1)
        XCTAssertEqual(stroke.points[0], point)
    }

    func testSimplify_twoPoints_noChange() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 100)]
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 1.0)
        XCTAssertEqual(stroke.points.count, 2)
    }

    // MARK: - Collinear Points

    func testSimplify_threeCollinearPoints_highEpsilon_reducesToTwo() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 50), CGPoint(x: 100, y: 100)]
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 10.0)
        XCTAssertEqual(stroke.points.count, 2)
    }

    func testSimplify_manyCollinearPoints_reducesToEndpoints() {
        let points = (0 ... 10).map { i in CGPoint(x: Double(i * 10), y: Double(i * 10)) }
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 1.0)
        XCTAssertEqual(stroke.points.count, 2)
    }

    func testSimplify_horizontalLine_reducesToEndpoints() {
        let points = (0 ... 9).map { i in CGPoint(x: Double(i * 10), y: 50) }
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 1.0)
        XCTAssertEqual(stroke.points.count, 2)
    }

    func testSimplify_verticalLine_reducesToEndpoints() {
        let points = (0 ... 9).map { i in CGPoint(x: 50, y: Double(i * 10)) }
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 1.0)
        XCTAssertEqual(stroke.points.count, 2)
    }

    // MARK: - Non-Collinear Points

    func testSimplify_threeNonCollinear_lowEpsilon_keepsAll() {
        // L-shaped: the middle point is far from the line between start and end
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 100), CGPoint(x: 100, y: 100)]
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 0.1)
        XCTAssertEqual(stroke.points.count, 3)
    }

    func testSimplify_threeNonCollinear_highEpsilon_reducesToTwo() {
        // L-shaped path with very high epsilon should simplify to endpoints
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 100), CGPoint(x: 100, y: 100)]
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 1000.0)
        XCTAssertEqual(stroke.points.count, 2)
    }

    func testSimplify_lShapedPath_lowEpsilon_preservesCorner() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 100), CGPoint(x: 100, y: 100)]
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 1.0)
        XCTAssertEqual(stroke.points.count, 3)
        XCTAssertEqual(stroke.points[1], CGPoint(x: 0, y: 100))
    }

    // MARK: - Complex Curves

    func testSimplify_sineWave_reducesPointCount() {
        let points = (0 ..< 100).map { i -> CGPoint in
            let x = Double(i) * 2.0
            let y = sin(Double(i) * 0.1) * 50.0
            return CGPoint(x: x, y: y)
        }
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 2.0)
        XCTAssertLessThan(stroke.points.count, 100)
        XCTAssertGreaterThan(stroke.points.count, 2)
    }

    func testSimplify_zigzag_lowEpsilon_preservesMostPoints() {
        let points = (0 ..< 20).map { i -> CGPoint in
            let y: Double = i % 2 == 0 ? 0.0 : 50.0
            return CGPoint(x: Double(i * 10), y: y)
        }
        var stroke = makeStroke(points: points)
        let originalCount = stroke.points.count
        stroke.simplify(epsilon: 1.0)
        // With low epsilon, most zigzag points should be preserved
        XCTAssertGreaterThan(stroke.points.count, originalCount / 2)
    }

    func testSimplify_zigzag_highEpsilon_reducesSignificantly() {
        let points = (0 ..< 20).map { i -> CGPoint in
            let y: Double = i % 2 == 0 ? 0.0 : 50.0
            return CGPoint(x: Double(i * 10), y: y)
        }
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 100.0)
        XCTAssertLessThan(stroke.points.count, 10)
    }

    // MARK: - Epsilon Comparison

    func testSimplify_highEpsilon_fewerPointsThanLowEpsilon() {
        let points = (0 ..< 50).map { i -> CGPoint in
            let x = Double(i) * 5.0
            let y = sin(Double(i) * 0.2) * 30.0
            return CGPoint(x: x, y: y)
        }

        var lowEps = makeStroke(points: points)
        lowEps.simplify(epsilon: 0.5)

        var highEps = makeStroke(points: points)
        highEps.simplify(epsilon: 10.0)

        XCTAssertLessThanOrEqual(highEps.points.count, lowEps.points.count)
    }

    func testSimplify_zeroEpsilon_keepsAllPoints() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 5),
            CGPoint(x: 20, y: 0),
            CGPoint(x: 30, y: 5),
        ]
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 0.0)
        XCTAssertEqual(stroke.points.count, points.count)
    }

    func testSimplify_veryHighEpsilon_reducesToEndpoints() {
        let points = (0 ..< 20).map { i -> CGPoint in
            CGPoint(x: Double(i * 10), y: sin(Double(i)) * 50)
        }
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 10000.0)
        XCTAssertEqual(stroke.points.count, 2)
    }

    // MARK: - First/Last Point Preservation

    func testSimplify_alwaysPreservesFirstPoint() {
        let points = (0 ..< 20).map { i -> CGPoint in
            CGPoint(x: Double(i * 10), y: sin(Double(i)) * 30)
        }
        let firstPoint = points[0]
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 5.0)
        XCTAssertEqual(stroke.points.first, firstPoint)
    }

    func testSimplify_alwaysPreservesLastPoint() throws {
        let points = (0 ..< 20).map { i -> CGPoint in
            CGPoint(x: Double(i * 10), y: sin(Double(i)) * 30)
        }
        let lastPoint = try XCTUnwrap(points.last)
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 5.0)
        XCTAssertEqual(stroke.points.last, lastPoint)
    }

    // MARK: - Idempotence

    func testSimplify_calledTwice_sameResult() {
        let points = (0 ..< 50).map { i -> CGPoint in
            CGPoint(x: Double(i * 5), y: sin(Double(i) * 0.3) * 40)
        }
        var stroke1 = makeStroke(points: points)
        stroke1.simplify(epsilon: 3.0)
        let afterFirst = stroke1.points

        stroke1.simplify(epsilon: 3.0)
        XCTAssertEqual(stroke1.points.count, afterFirst.count)
    }

    func testSimplify_calledTwice_samePointCount() {
        let points = (0 ..< 30).map { i -> CGPoint in
            CGPoint(x: Double(i * 10), y: Double(i % 3) * 20)
        }
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 5.0)
        let count1 = stroke.points.count
        stroke.simplify(epsilon: 5.0)
        XCTAssertEqual(stroke.points.count, count1)
    }

    // MARK: - Degenerate Cases

    func testSimplify_startEqualsEnd_handlesGracefully() {
        let points = [
            CGPoint(x: 50, y: 50),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 50, y: 50),
        ]
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 1.0)
        XCTAssertGreaterThanOrEqual(stroke.points.count, 2)
    }

    func testSimplify_allPointsIdentical_reducesToTwo() {
        let point = CGPoint(x: 50, y: 50)
        let points = Array(repeating: point, count: 10)
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 1.0)
        XCTAssertEqual(stroke.points.count, 2)
    }

    func testSimplify_veryClosePoints_highEpsilon_reduces() {
        let points = (0 ..< 10).map { i in
            CGPoint(x: Double(i) * 0.01, y: Double(i) * 0.01)
        }
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 1.0)
        XCTAssertLessThan(stroke.points.count, 10)
    }

    // MARK: - Default Epsilon

    func testSimplify_defaultEpsilon_reducesComplexStroke() {
        let points = (0 ..< 100).map { i -> CGPoint in
            CGPoint(x: Double(i * 3), y: sin(Double(i) * 0.15) * 40)
        }
        var stroke = makeStroke(points: points)
        stroke.simplify()
        XCTAssertLessThan(stroke.points.count, 100)
    }

    // MARK: - Point Count Validation

    func testSimplify_resultNeverExceedsOriginalCount() {
        // Use deterministic pseudo-random points to avoid flaky tests
        let points = (0 ..< 50).map { i -> CGPoint in
            let pseudoY = Double((i * 37 + 13) % 100)
            return CGPoint(x: Double(i * 5), y: pseudoY)
        }
        let originalCount = points.count
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 2.0)
        XCTAssertLessThanOrEqual(stroke.points.count, originalCount)
    }

    func testSimplify_resultHasAtLeast2Points_whenInputHas3OrMore() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 50), CGPoint(x: 100, y: 0)]
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 1000.0)
        XCTAssertGreaterThanOrEqual(stroke.points.count, 2)
    }

    // MARK: - Specific Geometry

    func testSimplify_rightAngleTriangle_preservesVertices() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 100),
        ]
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 1.0)
        XCTAssertEqual(stroke.points.count, 3)
    }

    func testSimplify_squarePath_preservesCorners() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 0, y: 100),
        ]
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 1.0)
        // All corners should be preserved since they deviate significantly
        XCTAssertEqual(stroke.points.count, 4)
    }

    func testSimplify_pointFarFromLine_alwaysKept() {
        // Middle point is very far from the start→end line
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 500),
            CGPoint(x: 100, y: 0),
        ]
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 100.0)
        XCTAssertEqual(stroke.points.count, 3)
    }

    func testSimplify_pointOnLine_removed() {
        // Middle point is exactly on the line between start and end
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 50),
            CGPoint(x: 100, y: 100),
        ]
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 1.0)
        XCTAssertEqual(stroke.points.count, 2)
    }

    // MARK: - Large Input

    func testSimplify_1000CollinearPoints_reducesToTwo() {
        let points = (0 ..< 1000).map { i in CGPoint(x: Double(i), y: Double(i)) }
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 1.0)
        XCTAssertEqual(stroke.points.count, 2)
    }

    func testSimplify_100ScatteredPoints_reducesCount() {
        // Use deterministic pseudo-random points to ensure reproducible results.
        // Previously used Double.random which caused flaky CI failures when random
        // zigzag patterns happened to deviate > epsilon at every point.
        let points = (0 ..< 100).map { i -> CGPoint in
            let x = Double((i * 197 + 53) % 500)
            let y = Double((i * 131 + 97) % 500)
            return CGPoint(x: x, y: y)
        }
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 10.0)
        XCTAssertLessThan(stroke.points.count, 100)
    }

    func testSimplify_negativeCoordinates_handled() {
        let points = [
            CGPoint(x: -100, y: -100),
            CGPoint(x: 0, y: 50),
            CGPoint(x: 100, y: -100),
        ]
        var stroke = makeStroke(points: points)
        stroke.simplify(epsilon: 1.0)
        XCTAssertGreaterThanOrEqual(stroke.points.count, 2)
    }

    // MARK: - Mutation Preservation

    func testSimplify_preservesColorHex() {
        let points = (0 ..< 10).map { i in CGPoint(x: Double(i * 10), y: Double(i * 10)) }
        var stroke = BrushStroke(points: points, colorHex: "00FF00", size: 5.0)
        stroke.simplify(epsilon: 1.0)
        XCTAssertEqual(stroke.colorHex, "00FF00")
    }

    func testSimplify_preservesSize() {
        let points = (0 ..< 10).map { i in CGPoint(x: Double(i * 10), y: Double(i * 10)) }
        var stroke = BrushStroke(points: points, colorHex: "FF0000", size: 7.5)
        stroke.simplify(epsilon: 1.0)
        XCTAssertEqual(stroke.size, 7.5)
    }

    func testSimplify_preservesId() {
        let points = (0 ..< 10).map { i in CGPoint(x: Double(i * 10), y: Double(i * 10)) }
        var stroke = BrushStroke(points: points, colorHex: "FF0000", size: 3.0)
        let originalId = stroke.id
        stroke.simplify(epsilon: 1.0)
        XCTAssertEqual(stroke.id, originalId)
    }
}
