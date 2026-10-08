// MARK: - RealtimeEditModelTests.swift

import XCTest
@testable import Illustrate

final class RealtimeEditModelTests: XCTestCase {
    // MARK: - RealtimeEditSession Tests

    func testRealtimeEditSessionInitialization() {
        let session = RealtimeEditSession(name: "Test Session")

        XCTAssertEqual(session.name, "Test Session")
        XCTAssertEqual(session.canvasScale, CanvasSettings.defaultScale)
        XCTAssertEqual(session.canvasOffsetX, CanvasSettings.defaultOffset)
        XCTAssertEqual(session.canvasOffsetY, CanvasSettings.defaultOffset)
        XCTAssertFalse(session.isLocked)
        XCTAssertFalse(session.isPinned)
        XCTAssertEqual(session.selectedDimensions, GenerationSettings.defaultDimensions)
        XCTAssertEqual(session.brushColorHex, RealtimeEditColors.defaultBrush)
        XCTAssertEqual(session.brushSize, BrushSettings.defaultSize)
        XCTAssertEqual(session.shapeColorHex, RealtimeEditColors.defaultShape)
    }

    func testRealtimeEditSessionDefaultName() {
        let session = RealtimeEditSession()

        XCTAssertEqual(session.name, "Untitled Edit")
    }

    func testRealtimeEditSessionSeedInValidRange() {
        let session = RealtimeEditSession()

        XCTAssertTrue(GenerationSettings.seedRange.contains(session.seed))
    }

    func testRealtimeEditSessionCodableRoundTrip() throws {
        let original = RealtimeEditSession(name: "Test Session")
        original.canvasScale = 1.5
        original.canvasOffsetX = 100
        original.canvasOffsetY = 200
        original.isLocked = true
        original.isPinned = true
        original.brushSize = 32.0
        original.seed = 12345

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RealtimeEditSession.self, from: data)

        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.canvasScale, original.canvasScale)
        XCTAssertEqual(decoded.canvasOffsetX, original.canvasOffsetX)
        XCTAssertEqual(decoded.canvasOffsetY, original.canvasOffsetY)
        XCTAssertEqual(decoded.isLocked, original.isLocked)
        XCTAssertEqual(decoded.isPinned, original.isPinned)
        XCTAssertEqual(decoded.brushSize, original.brushSize)
        XCTAssertEqual(decoded.seed, original.seed)
    }

    func testRealtimeEditSessionConfigurationAccess() {
        let session = RealtimeEditSession()
        var config = session.configuration

        // Modify configuration
        config.selectedProviderId = "test-provider"
        session.configuration = config

        // Retrieve and verify
        let retrieved = session.configuration
        XCTAssertEqual(retrieved.selectedProviderId, "test-provider")
    }

    // MARK: - RealtimeEditLayer Tests

    func testRealtimeEditLayerInitialization() {
        let sessionId = UUID()
        let layer = RealtimeEditLayer(
            sessionId: sessionId,
            layerType: .image,
            name: "Test Layer",
            position: CGPoint(x: 100, y: 200),
            size: CGSize(width: 300, height: 400),
            zIndex: 5
        )

        XCTAssertEqual(layer.sessionId, sessionId)
        XCTAssertEqual(layer.layerType, .image)
        XCTAssertEqual(layer.name, "Test Layer")
        XCTAssertEqual(layer.positionX, 100)
        XCTAssertEqual(layer.positionY, 200)
        XCTAssertEqual(layer.width, 300)
        XCTAssertEqual(layer.height, 400)
        XCTAssertEqual(layer.zIndex, 5)
        XCTAssertTrue(layer.isVisible)
        XCTAssertFalse(layer.isLocked)
    }

    func testRealtimeEditLayerDefaultValues() {
        let sessionId = UUID()
        let layer = RealtimeEditLayer(
            sessionId: sessionId,
            layerType: .drawing
        )

        XCTAssertEqual(layer.name, "Layer")
        XCTAssertEqual(layer.positionX, 0)
        XCTAssertEqual(layer.positionY, 0)
        XCTAssertEqual(layer.width, ImageProcessing.defaultLayerSize)
        XCTAssertEqual(layer.height, ImageProcessing.defaultLayerSize)
        XCTAssertEqual(layer.zIndex, 0)
    }

    func testRealtimeEditLayerPositionProperty() {
        let sessionId = UUID()
        let layer = RealtimeEditLayer(
            sessionId: sessionId,
            layerType: .shape
        )

        layer.position = CGPoint(x: 50, y: 75)

        XCTAssertEqual(layer.positionX, 50)
        XCTAssertEqual(layer.positionY, 75)
        XCTAssertEqual(layer.position.x, 50)
        XCTAssertEqual(layer.position.y, 75)
    }

    func testRealtimeEditLayerSizeProperty() {
        let sessionId = UUID()
        let layer = RealtimeEditLayer(
            sessionId: sessionId,
            layerType: .image
        )

        layer.size = CGSize(width: 640, height: 480)

        XCTAssertEqual(layer.width, 640)
        XCTAssertEqual(layer.height, 480)
        XCTAssertEqual(layer.size.width, 640)
        XCTAssertEqual(layer.size.height, 480)
    }

    func testRealtimeEditLayerBoundsProperty() {
        let sessionId = UUID()
        let layer = RealtimeEditLayer(
            sessionId: sessionId,
            layerType: .drawing,
            position: CGPoint(x: 10, y: 20),
            size: CGSize(width: 100, height: 150)
        )

        let bounds = layer.bounds

        XCTAssertEqual(bounds.origin.x, 10)
        XCTAssertEqual(bounds.origin.y, 20)
        XCTAssertEqual(bounds.size.width, 100)
        XCTAssertEqual(bounds.size.height, 150)
    }

    func testRealtimeEditLayerCodableRoundTrip() throws {
        let sessionId = UUID()
        let original = RealtimeEditLayer(
            sessionId: sessionId,
            layerType: .shape,
            name: "Test Shape Layer",
            position: CGPoint(x: 123, y: 456),
            size: CGSize(width: 789, height: 321),
            zIndex: 3
        )
        original.isVisible = false
        original.isLocked = true
        original.shapeType = .circle
        original.fillColor = "#FF0000"
        original.strokeColor = "#0000FF"

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RealtimeEditLayer.self, from: data)

        XCTAssertEqual(decoded.sessionId, original.sessionId)
        XCTAssertEqual(decoded.layerType, original.layerType)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.positionX, original.positionX)
        XCTAssertEqual(decoded.positionY, original.positionY)
        XCTAssertEqual(decoded.width, original.width)
        XCTAssertEqual(decoded.height, original.height)
        XCTAssertEqual(decoded.zIndex, original.zIndex)
        XCTAssertEqual(decoded.isVisible, original.isVisible)
        XCTAssertEqual(decoded.isLocked, original.isLocked)
        XCTAssertEqual(decoded.shapeType, original.shapeType)
        XCTAssertEqual(decoded.fillColor, original.fillColor)
        XCTAssertEqual(decoded.strokeColor, original.strokeColor)
    }

    // MARK: - Layer Type Tests

    func testLayerTypeDisplayNames() {
        XCTAssertEqual(LayerType.image.displayName, "Image")
        XCTAssertEqual(LayerType.drawing.displayName, "Drawing")
        XCTAssertEqual(LayerType.shape.displayName, "Shape")
    }

    func testLayerTypeIcons() {
        XCTAssertEqual(LayerType.image.icon, "photo.fill")
        XCTAssertEqual(LayerType.drawing.icon, "paintbrush.fill")
        XCTAssertEqual(LayerType.shape.icon, "square.on.circle")
    }

    func testLayerTypeCaseIterable() {
        let allTypes = LayerType.allCases
        XCTAssertEqual(allTypes.count, 3)
        XCTAssertTrue(allTypes.contains(.image))
        XCTAssertTrue(allTypes.contains(.drawing))
        XCTAssertTrue(allTypes.contains(.shape))
    }

    // MARK: - Shape Type Tests

    func testShapeTypeDisplayNames() {
        XCTAssertEqual(ShapeType.triangle.displayName, "Triangle")
        XCTAssertEqual(ShapeType.square.displayName, "Square")
        XCTAssertEqual(ShapeType.circle.displayName, "Circle")
    }

    func testShapeTypeIcons() {
        XCTAssertEqual(ShapeType.triangle.icon, "triangle")
        XCTAssertEqual(ShapeType.square.icon, "square")
        XCTAssertEqual(ShapeType.circle.icon, "circle")
    }

    func testShapeTypeFilledIcons() {
        XCTAssertEqual(ShapeType.triangle.filledIcon, "triangle.fill")
        XCTAssertEqual(ShapeType.square.filledIcon, "square.fill")
        XCTAssertEqual(ShapeType.circle.filledIcon, "circle.fill")
    }

    func testShapeTypeCaseIterable() {
        let allShapes = ShapeType.allCases
        XCTAssertEqual(allShapes.count, 3)
        XCTAssertTrue(allShapes.contains(.triangle))
        XCTAssertTrue(allShapes.contains(.square))
        XCTAssertTrue(allShapes.contains(.circle))
    }

    // MARK: - BrushStroke Tests

    func testBrushStrokeInitialization() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10), CGPoint(x: 20, y: 20)]
        let stroke = BrushStroke(points: points, colorHex: "FF0000", size: 24)

        XCTAssertEqual(stroke.points.count, 3)
        XCTAssertEqual(stroke.colorHex, "FF0000")
        XCTAssertEqual(stroke.size, 24)
    }

    func testBrushStrokeCodableRoundTrip() throws {
        let points = [CGPoint(x: 5, y: 10), CGPoint(x: 15, y: 20)]
        let original = BrushStroke(points: points, colorHex: "00FF00", size: 32)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BrushStroke.self, from: data)

        XCTAssertEqual(decoded.points.count, original.points.count)
        XCTAssertEqual(decoded.colorHex, original.colorHex)
        XCTAssertEqual(decoded.size, original.size)
    }

    // MARK: - DrawingData Tests

    func testDrawingDataInitialization() {
        let drawingData = DrawingData()

        XCTAssertEqual(drawingData.strokes.count, 0)
    }

    func testDrawingDataWithStrokes() {
        let stroke1 = BrushStroke(points: [CGPoint(x: 0, y: 0)], colorHex: "FF0000", size: 24)
        let stroke2 = BrushStroke(points: [CGPoint(x: 10, y: 10)], colorHex: "00FF00", size: 32)
        let drawingData = DrawingData(strokes: [stroke1, stroke2])

        XCTAssertEqual(drawingData.strokes.count, 2)
    }

    func testDrawingDataEncoding() {
        let stroke = BrushStroke(points: [CGPoint(x: 5, y: 10)], colorHex: "0000FF", size: 16)
        let drawingData = DrawingData(strokes: [stroke])

        let encoded = drawingData.encode()

        XCTAssertNotNil(encoded)
    }

    func testDrawingDataDecoding() {
        let stroke = BrushStroke(points: [CGPoint(x: 5, y: 10)], colorHex: "0000FF", size: 16)
        let original = DrawingData(strokes: [stroke])

        let encoded = original.encode()
        let decoded = DrawingData.decode(from: encoded)

        XCTAssertEqual(decoded.strokes.count, 1)
        XCTAssertEqual(decoded.strokes[0].colorHex, "0000FF")
        XCTAssertEqual(decoded.strokes[0].size, 16)
    }

    func testDrawingDataDecodeFromNil() {
        let decoded = DrawingData.decode(from: nil)

        XCTAssertEqual(decoded.strokes.count, 0)
    }

    func testDrawingDataDecodeFromInvalidData() {
        let invalidData = "invalid".data(using: .utf8)
        let decoded = DrawingData.decode(from: invalidData)

        XCTAssertEqual(decoded.strokes.count, 0)
    }

    func testDrawingDataRoundTrip() {
        let stroke1 = BrushStroke(points: [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)], colorHex: "FF0000", size: 24)
        let stroke2 = BrushStroke(points: [CGPoint(x: 20, y: 20), CGPoint(x: 30, y: 30)], colorHex: "00FF00", size: 32)
        let original = DrawingData(strokes: [stroke1, stroke2])

        let encoded = original.encode()
        let decoded = DrawingData.decode(from: encoded)

        XCTAssertEqual(decoded.strokes.count, 2)
        XCTAssertEqual(decoded.strokes[0].points.count, 2)
        XCTAssertEqual(decoded.strokes[1].points.count, 2)
    }

    // MARK: - RealtimeEditConfiguration Tests

    func testRealtimeEditConfigurationInitialization() {
        let config = RealtimeEditConfiguration()

        XCTAssertEqual(config.selectedProviderId, "")
        XCTAssertEqual(config.selectedModelId, "")
    }

    func testRealtimeEditConfigurationCodableRoundTrip() throws {
        var original = RealtimeEditConfiguration()
        original.selectedProviderId = "provider-123"
        original.selectedModelId = "model-456"

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RealtimeEditConfiguration.self, from: data)

        XCTAssertEqual(decoded.selectedProviderId, original.selectedProviderId)
        XCTAssertEqual(decoded.selectedModelId, original.selectedModelId)
    }
}
