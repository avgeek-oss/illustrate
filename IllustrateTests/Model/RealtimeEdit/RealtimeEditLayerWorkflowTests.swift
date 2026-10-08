// MARK: - RealtimeEditLayerWorkflowTests.swift

// Workflow tests for RealtimeEditLayer manipulation scenarios.
//
// RealtimeEditLayerModelTests covers: init defaults, computed properties,
// Codable decodeIfPresent, type-specific content, CanvasPositionable.
//
// This file adds: layer type-specific setup workflows, visibility/locking
// toggle patterns, z-index ordering, position/resize workflows,
// multi-layer session scenarios, and content preservation across toggles.

import XCTest
@testable import Illustrate

final class RealtimeEditLayerWorkflowTests: XCTestCase {
    // MARK: - Helpers

    private func makeImageLayer(sessionId: UUID = UUID()) -> RealtimeEditLayer {
        RealtimeEditLayer(sessionId: sessionId, layerType: .image)
    }

    private func makeDrawingLayer(sessionId: UUID = UUID()) -> RealtimeEditLayer {
        RealtimeEditLayer(sessionId: sessionId, layerType: .drawing)
    }

    private func makeShapeLayer(sessionId: UUID = UUID()) -> RealtimeEditLayer {
        RealtimeEditLayer(sessionId: sessionId, layerType: .shape)
    }

    // MARK: - Image Layer Workflow

    func testImageLayer_setImagePath_roundTrip() throws {
        let layer = makeImageLayer()
        layer.imagePath = "/path/to/image.png"

        let data = try JSONEncoder().encode(layer)
        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: data)

        XCTAssertEqual(decoded.imagePath, "/path/to/image.png")
        XCTAssertEqual(decoded.layerType, .image)
    }

    func testImageLayer_positionAndResize() {
        let layer = makeImageLayer()
        layer.position = CGPoint(x: 100, y: 200)
        layer.size = CGSize(width: 400, height: 300)

        XCTAssertEqual(layer.bounds, CGRect(x: 100, y: 200, width: 400, height: 300))
    }

    func testImageLayer_moveAfterCreation() {
        let layer = makeImageLayer()
        XCTAssertEqual(layer.position, .zero)

        layer.position = CGPoint(x: 50, y: 75)
        XCTAssertEqual(layer.position, CGPoint(x: 50, y: 75))

        layer.position = CGPoint(x: 200, y: 300)
        XCTAssertEqual(layer.position, CGPoint(x: 200, y: 300))
    }

    // MARK: - Drawing Layer Workflow

    func testDrawingLayer_setDrawingData_roundTrip() throws {
        let layer = makeDrawingLayer()
        let drawing = DrawingData(strokes: [
            BrushStroke(
                points: [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)],
                colorHex: "FF0000",
                size: 3
            ),
        ])
        layer.drawingData = drawing.encode()

        let data = try JSONEncoder().encode(layer)
        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: data)

        XCTAssertNotNil(decoded.drawingData)
        let decodedDrawing = DrawingData.decode(from: decoded.drawingData)
        XCTAssertEqual(decodedDrawing.strokes.count, 1)
        XCTAssertEqual(decodedDrawing.strokes[0].colorHex, "FF0000")
    }

    func testDrawingLayer_emptyDrawingData_roundTrip() throws {
        let layer = makeDrawingLayer()
        let drawing = DrawingData()
        layer.drawingData = drawing.encode()

        let data = try JSONEncoder().encode(layer)
        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: data)

        let decodedDrawing = DrawingData.decode(from: decoded.drawingData)
        XCTAssertTrue(decodedDrawing.strokes.isEmpty)
    }

    // MARK: - Shape Layer Workflow

    func testShapeLayer_fullSetup_roundTrip() throws {
        let layer = makeShapeLayer()
        layer.shapeType = .circle
        layer.fillColor = "#FF0000"
        layer.strokeColor = "#0000FF"

        let data = try JSONEncoder().encode(layer)
        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: data)

        XCTAssertEqual(decoded.shapeType, .circle)
        XCTAssertEqual(decoded.fillColor, "#FF0000")
        XCTAssertEqual(decoded.strokeColor, "#0000FF")
    }

    func testShapeLayer_fillOnly_noStroke() throws {
        let layer = makeShapeLayer()
        layer.shapeType = .square
        layer.fillColor = "#00FF00"
        // strokeColor intentionally nil

        let data = try JSONEncoder().encode(layer)
        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: data)

        XCTAssertEqual(decoded.fillColor, "#00FF00")
        XCTAssertNil(decoded.strokeColor)
    }

    func testShapeLayer_strokeOnly_noFill() throws {
        let layer = makeShapeLayer()
        layer.shapeType = .triangle
        layer.strokeColor = "#AABBCC"
        // fillColor intentionally nil

        let data = try JSONEncoder().encode(layer)
        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: data)

        XCTAssertNil(decoded.fillColor)
        XCTAssertEqual(decoded.strokeColor, "#AABBCC")
    }

    // MARK: - Visibility Toggle Workflow

    func testVisibility_toggleHideShow_preservesContent() {
        let layer = makeImageLayer()
        layer.imagePath = "/images/photo.jpg"
        layer.position = CGPoint(x: 100, y: 200)

        layer.isVisible = false
        XCTAssertFalse(layer.isVisible)
        XCTAssertEqual(layer.imagePath, "/images/photo.jpg")

        layer.isVisible = true
        XCTAssertTrue(layer.isVisible)
        XCTAssertEqual(layer.imagePath, "/images/photo.jpg")
        XCTAssertEqual(layer.position, CGPoint(x: 100, y: 200))
    }

    func testVisibility_multipleLayersSameSession_differentStates() {
        let sessionId = UUID()
        let layer1 = RealtimeEditLayer(sessionId: sessionId, layerType: .image)
        let layer2 = RealtimeEditLayer(sessionId: sessionId, layerType: .drawing)
        let layer3 = RealtimeEditLayer(sessionId: sessionId, layerType: .shape)

        layer1.isVisible = true
        layer2.isVisible = false
        layer3.isVisible = true

        XCTAssertTrue(layer1.isVisible)
        XCTAssertFalse(layer2.isVisible)
        XCTAssertTrue(layer3.isVisible)
    }

    // MARK: - Locking Workflow

    func testLocked_positionStillMutable() {
        let layer = makeImageLayer()
        layer.isLocked = true

        // Model-level: position is still mutable (locking is UI-level)
        layer.position = CGPoint(x: 500, y: 600)
        XCTAssertEqual(layer.position, CGPoint(x: 500, y: 600))
    }

    func testLocked_sizeStillMutable() {
        let layer = makeImageLayer()
        layer.isLocked = true

        layer.size = CGSize(width: 800, height: 600)
        XCTAssertEqual(layer.size, CGSize(width: 800, height: 600))
    }

    // MARK: - Z-Index Ordering

    func testZIndex_sortByZIndex_producesCorrectOrder() {
        let layer1 = makeImageLayer()
        layer1.zIndex = 3
        layer1.name = "Top"

        let layer2 = makeDrawingLayer()
        layer2.zIndex = 1
        layer2.name = "Bottom"

        let layer3 = makeShapeLayer()
        layer3.zIndex = 2
        layer3.name = "Middle"

        let sorted = [layer1, layer2, layer3].sorted { $0.zIndex < $1.zIndex }

        XCTAssertEqual(sorted[0].name, "Bottom")
        XCTAssertEqual(sorted[1].name, "Middle")
        XCTAssertEqual(sorted[2].name, "Top")
    }

    func testZIndex_negativeValues_handled() {
        let layer = makeImageLayer()
        layer.zIndex = -5
        XCTAssertEqual(layer.zIndex, -5)
    }

    func testZIndex_sameValueForDifferentLayers_valid() {
        let layer1 = makeImageLayer()
        let layer2 = makeDrawingLayer()
        layer1.zIndex = 5
        layer2.zIndex = 5
        XCTAssertEqual(layer1.zIndex, layer2.zIndex)
    }

    func testZIndex_updateChangesOrder() {
        let layer1 = makeImageLayer()
        layer1.zIndex = 1
        let layer2 = makeDrawingLayer()
        layer2.zIndex = 2

        var sorted = [layer1, layer2].sorted { $0.zIndex < $1.zIndex }
        XCTAssertEqual(sorted[0].id, layer1.id)

        layer1.zIndex = 10
        sorted = [layer1, layer2].sorted { $0.zIndex < $1.zIndex }
        XCTAssertEqual(sorted[0].id, layer2.id)
    }

    // MARK: - Position/Size Edge Cases

    func testPosition_atOrigin() {
        let layer = makeImageLayer()
        layer.position = .zero
        XCTAssertEqual(layer.position, .zero)
        XCTAssertEqual(layer.bounds.origin, .zero)
    }

    func testPosition_veryLargeValues() {
        let layer = makeImageLayer()
        layer.position = CGPoint(x: 10000, y: 10000)
        XCTAssertEqual(layer.position, CGPoint(x: 10000, y: 10000))
    }

    func testSize_zeroWidth() {
        let layer = makeImageLayer()
        layer.size = CGSize(width: 0, height: 100)
        XCTAssertEqual(layer.size.width, 0)
        XCTAssertEqual(layer.size.height, 100)
    }

    func testSize_zeroHeight() {
        let layer = makeImageLayer()
        layer.size = CGSize(width: 200, height: 0)
        XCTAssertEqual(layer.size.width, 200)
        XCTAssertEqual(layer.size.height, 0)
    }

    func testBounds_nonIntegerPosition() {
        let layer = makeImageLayer()
        layer.position = CGPoint(x: 10.5, y: 20.7)
        layer.size = CGSize(width: 100.3, height: 200.9)

        let bounds = layer.bounds
        XCTAssertEqual(bounds.origin.x, 10.5, accuracy: 0.001)
        XCTAssertEqual(bounds.origin.y, 20.7, accuracy: 0.001)
        XCTAssertEqual(bounds.size.width, 100.3, accuracy: 0.001)
        XCTAssertEqual(bounds.size.height, 200.9, accuracy: 0.001)
    }
}
