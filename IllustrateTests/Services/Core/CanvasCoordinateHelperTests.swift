// MARK: - CanvasCoordinateHelperTests.swift

// Tests for CanvasCoordinateHelper pure math functions.
//
// Validates screenToWorld, worldToScreen coordinate transformations,
// connection point calculations (output, input, bottom, top),
// and round-trip inverse correctness.

import XCTest
@testable import Illustrate

final class CanvasCoordinateHelperTests: XCTestCase {
    private let viewSize = CGSize(width: 1000, height: 800)
    private let center = CGPoint(x: 500, y: 400)

    // MARK: - screenToWorld

    func testScreenToWorld_centerOfScreen_atOrigin() {
        let result = CanvasCoordinateHelper.screenToWorld(
            screenPosition: center,
            viewSize: viewSize,
            offset: .zero,
            scale: 1.0
        )
        XCTAssertEqual(result.x, 0, accuracy: 0.001)
        XCTAssertEqual(result.y, 0, accuracy: 0.001)
    }

    func testScreenToWorld_topLeftCorner() {
        let result = CanvasCoordinateHelper.screenToWorld(
            screenPosition: .zero,
            viewSize: viewSize,
            offset: .zero,
            scale: 1.0
        )
        XCTAssertEqual(result.x, -500, accuracy: 0.001)
        XCTAssertEqual(result.y, -400, accuracy: 0.001)
    }

    func testScreenToWorld_bottomRightCorner() {
        let result = CanvasCoordinateHelper.screenToWorld(
            screenPosition: CGPoint(x: 1000, y: 800),
            viewSize: viewSize,
            offset: .zero,
            scale: 1.0
        )
        XCTAssertEqual(result.x, 500, accuracy: 0.001)
        XCTAssertEqual(result.y, 400, accuracy: 0.001)
    }

    func testScreenToWorld_withOffset_shiftsWorldPosition() {
        let result = CanvasCoordinateHelper.screenToWorld(
            screenPosition: center,
            viewSize: viewSize,
            offset: CGPoint(x: 100, y: 50),
            scale: 1.0
        )
        // center - center - offset = 0 - 100 = -100, 0 - 50 = -50
        XCTAssertEqual(result.x, -100, accuracy: 0.001)
        XCTAssertEqual(result.y, -50, accuracy: 0.001)
    }

    func testScreenToWorld_withScale_dividesCoordinates() {
        let result = CanvasCoordinateHelper.screenToWorld(
            screenPosition: CGPoint(x: 700, y: 600),
            viewSize: viewSize,
            offset: .zero,
            scale: 2.0
        )
        // (700 - 500) / 2 = 100, (600 - 400) / 2 = 100
        XCTAssertEqual(result.x, 100, accuracy: 0.001)
        XCTAssertEqual(result.y, 100, accuracy: 0.001)
    }

    func testScreenToWorld_smallScale_magnifiesWorld() {
        let result = CanvasCoordinateHelper.screenToWorld(
            screenPosition: CGPoint(x: 600, y: 500),
            viewSize: viewSize,
            offset: .zero,
            scale: 0.5
        )
        // (600 - 500) / 0.5 = 200, (500 - 400) / 0.5 = 200
        XCTAssertEqual(result.x, 200, accuracy: 0.001)
        XCTAssertEqual(result.y, 200, accuracy: 0.001)
    }

    func testScreenToWorld_negativeOffset() {
        let result = CanvasCoordinateHelper.screenToWorld(
            screenPosition: center,
            viewSize: viewSize,
            offset: CGPoint(x: -200, y: -100),
            scale: 1.0
        )
        XCTAssertEqual(result.x, 200, accuracy: 0.001)
        XCTAssertEqual(result.y, 100, accuracy: 0.001)
    }

    func testScreenToWorld_combinedOffsetAndScale() {
        let result = CanvasCoordinateHelper.screenToWorld(
            screenPosition: CGPoint(x: 600, y: 500),
            viewSize: viewSize,
            offset: CGPoint(x: 50, y: 25),
            scale: 2.0
        )
        // (600 - 500 - 50) / 2 = 25, (500 - 400 - 25) / 2 = 37.5
        XCTAssertEqual(result.x, 25, accuracy: 0.001)
        XCTAssertEqual(result.y, 37.5, accuracy: 0.001)
    }

    // MARK: - worldToScreen

    func testWorldToScreen_origin_toCenterOfScreen() {
        let result = CanvasCoordinateHelper.worldToScreen(
            worldPosition: .zero,
            viewSize: viewSize,
            offset: .zero,
            scale: 1.0
        )
        XCTAssertEqual(result.x, 500, accuracy: 0.001)
        XCTAssertEqual(result.y, 400, accuracy: 0.001)
    }

    func testWorldToScreen_withOffset() {
        let result = CanvasCoordinateHelper.worldToScreen(
            worldPosition: .zero,
            viewSize: viewSize,
            offset: CGPoint(x: 100, y: 50),
            scale: 1.0
        )
        XCTAssertEqual(result.x, 600, accuracy: 0.001)
        XCTAssertEqual(result.y, 450, accuracy: 0.001)
    }

    func testWorldToScreen_withScale() {
        let result = CanvasCoordinateHelper.worldToScreen(
            worldPosition: CGPoint(x: 100, y: 100),
            viewSize: viewSize,
            offset: .zero,
            scale: 2.0
        )
        // 100 * 2 + 500 = 700, 100 * 2 + 400 = 600
        XCTAssertEqual(result.x, 700, accuracy: 0.001)
        XCTAssertEqual(result.y, 600, accuracy: 0.001)
    }

    func testWorldToScreen_negativeWorldPosition() {
        let result = CanvasCoordinateHelper.worldToScreen(
            worldPosition: CGPoint(x: -200, y: -150),
            viewSize: viewSize,
            offset: .zero,
            scale: 1.0
        )
        XCTAssertEqual(result.x, 300, accuracy: 0.001)
        XCTAssertEqual(result.y, 250, accuracy: 0.001)
    }

    // MARK: - Round-Trip (Inverse Correctness)

    func testRoundTrip_screenToWorldToScreen() {
        let original = CGPoint(x: 350, y: 250)
        let offset = CGPoint(x: 30, y: 20)
        let scale: CGFloat = 1.5

        let world = CanvasCoordinateHelper.screenToWorld(
            screenPosition: original, viewSize: viewSize, offset: offset, scale: scale
        )
        let screen = CanvasCoordinateHelper.worldToScreen(
            worldPosition: world, viewSize: viewSize, offset: offset, scale: scale
        )

        XCTAssertEqual(screen.x, original.x, accuracy: 0.001)
        XCTAssertEqual(screen.y, original.y, accuracy: 0.001)
    }

    func testRoundTrip_worldToScreenToWorld() {
        let original = CGPoint(x: 150, y: -75)
        let offset = CGPoint(x: -50, y: 100)
        let scale: CGFloat = 0.75

        let screen = CanvasCoordinateHelper.worldToScreen(
            worldPosition: original, viewSize: viewSize, offset: offset, scale: scale
        )
        let world = CanvasCoordinateHelper.screenToWorld(
            screenPosition: screen, viewSize: viewSize, offset: offset, scale: scale
        )

        XCTAssertEqual(world.x, original.x, accuracy: 0.001)
        XCTAssertEqual(world.y, original.y, accuracy: 0.001)
    }

    func testRoundTrip_withLargeScale() {
        let original = CGPoint(x: 999, y: 1)
        let scale: CGFloat = 5.0

        let world = CanvasCoordinateHelper.screenToWorld(
            screenPosition: original, viewSize: viewSize, offset: .zero, scale: scale
        )
        let screen = CanvasCoordinateHelper.worldToScreen(
            worldPosition: world, viewSize: viewSize, offset: .zero, scale: scale
        )

        XCTAssertEqual(screen.x, original.x, accuracy: 0.001)
        XCTAssertEqual(screen.y, original.y, accuracy: 0.001)
    }

    // MARK: - getOutputPosition (Right Side)

    func testGetOutputPosition_centered_rightEdge() {
        let result = CanvasCoordinateHelper.getOutputPosition(
            for: 0, positionY: 0,
            centerOffset: center,
            scale: 1.0,
            cardWidth: 200
        )
        // 0 * 1 + 500 + (200/2 * 1) = 600
        XCTAssertEqual(result.x, 600, accuracy: 0.001)
        XCTAssertEqual(result.y, 400, accuracy: 0.001)
    }

    func testGetOutputPosition_withScale() {
        let result = CanvasCoordinateHelper.getOutputPosition(
            for: 100, positionY: 50,
            centerOffset: center,
            scale: 2.0,
            cardWidth: 200
        )
        // 100 * 2 + 500 + (200/2 * 2) = 200 + 500 + 200 = 900
        XCTAssertEqual(result.x, 900, accuracy: 0.001)
        // 50 * 2 + 400 = 500
        XCTAssertEqual(result.y, 500, accuracy: 0.001)
    }

    func testGetOutputPosition_withDragOffset() {
        let result = CanvasCoordinateHelper.getOutputPosition(
            for: 0, positionY: 0,
            centerOffset: center,
            scale: 1.0,
            cardWidth: 200,
            dragOffset: CGSize(width: 10, height: 20)
        )
        // 0 + 500 + 10 + 100 = 610
        XCTAssertEqual(result.x, 610, accuracy: 0.001)
        // 0 + 400 + 20 = 420
        XCTAssertEqual(result.y, 420, accuracy: 0.001)
    }

    // MARK: - getInputPosition (Left Side)

    func testGetInputPosition_centered_leftEdge() {
        let result = CanvasCoordinateHelper.getInputPosition(
            for: 0, positionY: 0,
            centerOffset: center,
            scale: 1.0,
            cardWidth: 200
        )
        // 0 + 500 - 100 = 400
        XCTAssertEqual(result.x, 400, accuracy: 0.001)
        XCTAssertEqual(result.y, 400, accuracy: 0.001)
    }

    func testGetInputPosition_withScale() {
        let result = CanvasCoordinateHelper.getInputPosition(
            for: 100, positionY: 50,
            centerOffset: center,
            scale: 2.0,
            cardWidth: 200
        )
        // 100 * 2 + 500 - (100 * 2) = 500
        XCTAssertEqual(result.x, 500, accuracy: 0.001)
        XCTAssertEqual(result.y, 500, accuracy: 0.001)
    }

    // MARK: - getBottomPosition

    func testGetBottomPosition_centered_bottomEdge() {
        let result = CanvasCoordinateHelper.getBottomPosition(
            for: 0, positionY: 0,
            centerOffset: center,
            scale: 1.0,
            cardHeight: 280
        )
        XCTAssertEqual(result.x, 500, accuracy: 0.001)
        // 0 + 400 + 140 = 540
        XCTAssertEqual(result.y, 540, accuracy: 0.001)
    }

    func testGetBottomPosition_withDragOffset() {
        let result = CanvasCoordinateHelper.getBottomPosition(
            for: 0, positionY: 0,
            centerOffset: center,
            scale: 1.0,
            cardHeight: 280,
            dragOffset: CGSize(width: 5, height: 10)
        )
        XCTAssertEqual(result.x, 505, accuracy: 0.001)
        XCTAssertEqual(result.y, 550, accuracy: 0.001)
    }

    // MARK: - getTopPosition

    func testGetTopPosition_centered_topEdge() {
        let result = CanvasCoordinateHelper.getTopPosition(
            for: 0, positionY: 0,
            centerOffset: center,
            scale: 1.0,
            cardHeight: 280
        )
        XCTAssertEqual(result.x, 500, accuracy: 0.001)
        // 0 + 400 - 140 = 260
        XCTAssertEqual(result.y, 260, accuracy: 0.001)
    }

    func testGetTopPosition_withScale() {
        let result = CanvasCoordinateHelper.getTopPosition(
            for: 50, positionY: 30,
            centerOffset: center,
            scale: 2.0,
            cardHeight: 280
        )
        // 50 * 2 + 500 = 600
        XCTAssertEqual(result.x, 600, accuracy: 0.001)
        // 30 * 2 + 400 - (140 * 2) = 60 + 400 - 280 = 180
        XCTAssertEqual(result.y, 180, accuracy: 0.001)
    }

    // MARK: - Output/Input Symmetry

    func testOutputInput_symmetricAroundCenter() {
        let output = CanvasCoordinateHelper.getOutputPosition(
            for: 0, positionY: 0,
            centerOffset: center,
            scale: 1.0,
            cardWidth: 200
        )
        let input = CanvasCoordinateHelper.getInputPosition(
            for: 0, positionY: 0,
            centerOffset: center,
            scale: 1.0,
            cardWidth: 200
        )
        // Midpoint of output.x and input.x should be the card center (500)
        XCTAssertEqual((output.x + input.x) / 2, 500, accuracy: 0.001)
        // Y should be the same
        XCTAssertEqual(output.y, input.y)
    }

    // MARK: - Top/Bottom Symmetry

    func testTopBottom_symmetricAroundCenter() {
        let top = CanvasCoordinateHelper.getTopPosition(
            for: 0, positionY: 0,
            centerOffset: center,
            scale: 1.0,
            cardHeight: 280
        )
        let bottom = CanvasCoordinateHelper.getBottomPosition(
            for: 0, positionY: 0,
            centerOffset: center,
            scale: 1.0,
            cardHeight: 280
        )
        // Midpoint should be 400
        XCTAssertEqual((top.y + bottom.y) / 2, 400, accuracy: 0.001)
        // X should be the same
        XCTAssertEqual(top.x, bottom.x)
    }
}
