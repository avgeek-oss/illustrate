// MARK: - RealtimeEditLayerModelTests.swift

// Extended tests for RealtimeEditLayer model covering areas not in RealtimeEditModelTests.
//
// RealtimeEditModelTests covers: init with params (1), defaults (1), position computed (1),
// size computed (1), bounds computed (1), full Codable round-trip (1).
// This file adds: decodeIfPresent defaults, edge cases, CanvasPositionable conformance,
// position/size independence, bounds updates, and type-specific content round-trips.

import XCTest
@testable import Illustrate

final class RealtimeEditLayerModelTests: XCTestCase {
    // MARK: - Initialization Details

    func testInit_IdIsUnique() {
        let id = UUID()
        let layer1 = RealtimeEditLayer(sessionId: id, layerType: .image)
        let layer2 = RealtimeEditLayer(sessionId: id, layerType: .image)
        XCTAssertNotEqual(layer1.id, layer2.id)
    }

    func testInit_SessionIdPreserved() {
        let sessionId = UUID()
        let layer = RealtimeEditLayer(sessionId: sessionId, layerType: .drawing)
        XCTAssertEqual(layer.sessionId, sessionId)
    }

    func testInit_LayerTypePreserved() {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .shape)
        XCTAssertEqual(layer.layerType, .shape)
    }

    func testInit_CustomName() {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image, name: "Background")
        XCTAssertEqual(layer.name, "Background")
    }

    func testInit_CustomPosition() {
        let layer = RealtimeEditLayer(
            sessionId: UUID(),
            layerType: .image,
            position: CGPoint(x: 100, y: 200)
        )
        XCTAssertEqual(layer.positionX, 100)
        XCTAssertEqual(layer.positionY, 200)
    }

    func testInit_CustomSize() {
        let layer = RealtimeEditLayer(
            sessionId: UUID(),
            layerType: .image,
            size: CGSize(width: 300, height: 400)
        )
        XCTAssertEqual(layer.width, 300)
        XCTAssertEqual(layer.height, 400)
    }

    func testInit_DefaultOptionalFieldsNil() {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image)
        XCTAssertNil(layer.imagePath)
        XCTAssertNil(layer.drawingData)
        XCTAssertNil(layer.shapeType)
        XCTAssertNil(layer.shapePathData)
        XCTAssertNil(layer.strokeColor)
        XCTAssertNil(layer.fillColor)
    }

    func testInit_IsVisibleTrue() {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image)
        XCTAssertTrue(layer.isVisible)
    }

    func testInit_IsLockedFalse() {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image)
        XCTAssertFalse(layer.isLocked)
    }

    // MARK: - Computed Properties Edge Cases

    func testPosition_NegativeValues() {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image)
        layer.position = CGPoint(x: -50, y: -100)
        XCTAssertEqual(layer.positionX, -50)
        XCTAssertEqual(layer.positionY, -100)
        XCTAssertEqual(layer.position, CGPoint(x: -50, y: -100))
    }

    func testPosition_VeryLargeValues() {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image)
        layer.position = CGPoint(x: 10000, y: 10000)
        XCTAssertEqual(layer.position.x, 10000)
        XCTAssertEqual(layer.position.y, 10000)
    }

    func testSize_ZeroWidth() {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image)
        layer.size = CGSize(width: 0, height: 200)
        XCTAssertEqual(layer.width, 0)
        XCTAssertEqual(layer.height, 200)
    }

    func testSize_ZeroHeight() {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image)
        layer.size = CGSize(width: 300, height: 0)
        XCTAssertEqual(layer.width, 300)
        XCTAssertEqual(layer.height, 0)
    }

    func testPosition_SetDoesNotAffectSize() {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image)
        let originalSize = layer.size
        layer.position = CGPoint(x: 500, y: 600)
        XCTAssertEqual(layer.size, originalSize)
    }

    func testSize_SetDoesNotAffectPosition() {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image)
        layer.position = CGPoint(x: 100, y: 200)
        layer.size = CGSize(width: 50, height: 60)
        XCTAssertEqual(layer.position, CGPoint(x: 100, y: 200))
    }

    func testBounds_AtNonZeroPosition() {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image)
        layer.position = CGPoint(x: 100, y: 200)
        layer.size = CGSize(width: 300, height: 400)
        let bounds = layer.bounds
        XCTAssertEqual(bounds.origin.x, 100)
        XCTAssertEqual(bounds.origin.y, 200)
        XCTAssertEqual(bounds.size.width, 300)
        XCTAssertEqual(bounds.size.height, 400)
    }

    func testBounds_UpdatesWhenPositionChanges() {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image)
        layer.size = CGSize(width: 100, height: 100)
        layer.position = CGPoint(x: 50, y: 50)
        XCTAssertEqual(layer.bounds.origin.x, 50)

        layer.position = CGPoint(x: 200, y: 300)
        XCTAssertEqual(layer.bounds.origin.x, 200)
        XCTAssertEqual(layer.bounds.origin.y, 300)
        XCTAssertEqual(layer.bounds.size.width, 100) // unchanged
    }

    func testBounds_UpdatesWhenSizeChanges() {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image)
        layer.position = CGPoint(x: 10, y: 20)
        layer.size = CGSize(width: 100, height: 100)
        XCTAssertEqual(layer.bounds.size.width, 100)

        layer.size = CGSize(width: 500, height: 600)
        XCTAssertEqual(layer.bounds.size.width, 500)
        XCTAssertEqual(layer.bounds.size.height, 600)
        XCTAssertEqual(layer.bounds.origin.x, 10) // unchanged
    }

    func testBounds_WithNonIntegerPosition() {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image)
        layer.position = CGPoint(x: 10.5, y: 20.7)
        layer.size = CGSize(width: 100.3, height: 200.9)
        XCTAssertEqual(layer.bounds.origin.x, 10.5, accuracy: 0.001)
        XCTAssertEqual(layer.bounds.origin.y, 20.7, accuracy: 0.001)
        XCTAssertEqual(layer.bounds.size.width, 100.3, accuracy: 0.001)
        XCTAssertEqual(layer.bounds.size.height, 200.9, accuracy: 0.001)
    }

    // MARK: - Codable decodeIfPresent Defaults

    func testCodable_MissingIsVisible_DefaultsToTrue() throws {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image)
        layer.isVisible = false
        let data = try JSONEncoder().encode(layer)

        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "isVisible")
        let modifiedData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: modifiedData)
        XCTAssertTrue(decoded.isVisible)
    }

    func testCodable_MissingIsLocked_DefaultsToFalse() throws {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image)
        layer.isLocked = true
        let data = try JSONEncoder().encode(layer)

        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "isLocked")
        let modifiedData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: modifiedData)
        XCTAssertFalse(decoded.isLocked)
    }

    func testCodable_MissingImagePath_DefaultsToNil() throws {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image)
        let data = try JSONEncoder().encode(layer)

        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "imagePath")
        let modifiedData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: modifiedData)
        XCTAssertNil(decoded.imagePath)
    }

    func testCodable_MissingDrawingData_DefaultsToNil() throws {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .drawing)
        let data = try JSONEncoder().encode(layer)

        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "drawingData")
        let modifiedData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: modifiedData)
        XCTAssertNil(decoded.drawingData)
    }

    func testCodable_MissingShapeType_DefaultsToNil() throws {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .shape)
        let data = try JSONEncoder().encode(layer)

        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "shapeType")
        let modifiedData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: modifiedData)
        XCTAssertNil(decoded.shapeType)
    }

    func testCodable_MissingStrokeColor_DefaultsToNil() throws {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .shape)
        let data = try JSONEncoder().encode(layer)

        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "strokeColor")
        let modifiedData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: modifiedData)
        XCTAssertNil(decoded.strokeColor)
    }

    func testCodable_MissingFillColor_DefaultsToNil() throws {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .shape)
        let data = try JSONEncoder().encode(layer)

        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "fillColor")
        let modifiedData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: modifiedData)
        XCTAssertNil(decoded.fillColor)
    }

    func testCodable_MissingShapePathData_DefaultsToNil() throws {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .shape)
        let data = try JSONEncoder().encode(layer)

        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "shapePathData")
        let modifiedData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: modifiedData)
        XCTAssertNil(decoded.shapePathData)
    }

    func testCodable_AllOptionalsMissing_AllDefaults() throws {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image)
        let data = try JSONEncoder().encode(layer)

        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "isVisible")
        json.removeValue(forKey: "isLocked")
        json.removeValue(forKey: "imagePath")
        json.removeValue(forKey: "drawingData")
        json.removeValue(forKey: "shapeType")
        json.removeValue(forKey: "shapePathData")
        json.removeValue(forKey: "strokeColor")
        json.removeValue(forKey: "fillColor")
        let modifiedData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: modifiedData)
        XCTAssertTrue(decoded.isVisible)
        XCTAssertFalse(decoded.isLocked)
        XCTAssertNil(decoded.imagePath)
        XCTAssertNil(decoded.drawingData)
        XCTAssertNil(decoded.shapeType)
        XCTAssertNil(decoded.shapePathData)
        XCTAssertNil(decoded.strokeColor)
        XCTAssertNil(decoded.fillColor)
    }

    // MARK: - Type-Specific Content Round-Trip

    func testCodable_ImageLayerWithImagePath() throws {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image)
        layer.imagePath = "images/photo_001.png"

        let data = try JSONEncoder().encode(layer)
        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: data)

        XCTAssertEqual(decoded.layerType, .image)
        XCTAssertEqual(decoded.imagePath, "images/photo_001.png")
    }

    func testCodable_DrawingLayerWithDrawingData() throws {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .drawing)
        layer.drawingData = Data("drawing-bytes".utf8)

        let data = try JSONEncoder().encode(layer)
        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: data)

        XCTAssertEqual(decoded.layerType, .drawing)
        XCTAssertEqual(decoded.drawingData, Data("drawing-bytes".utf8))
    }

    func testCodable_ShapeLayerWithAllShapeFields() throws {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .shape)
        layer.shapeType = .circle
        layer.fillColor = "#FF0000"
        layer.strokeColor = "#0000FF"
        layer.shapePathData = Data("path-data".utf8)

        let data = try JSONEncoder().encode(layer)
        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: data)

        XCTAssertEqual(decoded.layerType, .shape)
        XCTAssertEqual(decoded.shapeType, .circle)
        XCTAssertEqual(decoded.fillColor, "#FF0000")
        XCTAssertEqual(decoded.strokeColor, "#0000FF")
        XCTAssertEqual(decoded.shapePathData, Data("path-data".utf8))
    }

    // MARK: - Codable Full Round-Trip With Non-Default Values

    func testCodable_AllFieldsNonDefault() throws {
        let sessionId = UUID()
        let layer = RealtimeEditLayer(
            sessionId: sessionId,
            layerType: .shape,
            name: "Custom Shape",
            position: CGPoint(x: 150, y: 250),
            size: CGSize(width: 300, height: 400),
            zIndex: 5
        )
        layer.isVisible = false
        layer.isLocked = true
        layer.shapeType = .triangle
        layer.fillColor = "#00FF00"
        layer.strokeColor = "#FF00FF"

        let data = try JSONEncoder().encode(layer)
        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: data)

        XCTAssertEqual(decoded.id, layer.id)
        XCTAssertEqual(decoded.sessionId, sessionId)
        XCTAssertEqual(decoded.layerType, .shape)
        XCTAssertEqual(decoded.name, "Custom Shape")
        XCTAssertEqual(decoded.positionX, 150)
        XCTAssertEqual(decoded.positionY, 250)
        XCTAssertEqual(decoded.width, 300)
        XCTAssertEqual(decoded.height, 400)
        XCTAssertEqual(decoded.zIndex, 5)
        XCTAssertFalse(decoded.isVisible)
        XCTAssertTrue(decoded.isLocked)
        XCTAssertEqual(decoded.shapeType, .triangle)
        XCTAssertEqual(decoded.fillColor, "#00FF00")
        XCTAssertEqual(decoded.strokeColor, "#FF00FF")
    }

    // MARK: - CanvasPositionable Conformance

    func testCanvasPositionable_HasRequiredProperties() {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image)
        // CanvasPositionable requires id, positionX, positionY
        let _: UUID = layer.id
        let _: CGFloat = layer.positionX
        let _: CGFloat = layer.positionY
        // If this compiles, conformance is satisfied
    }

    // MARK: - LayerType Preserved Through Codable

    func testLayerType_ImagePreservedThroughCodable() throws {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image)
        let data = try JSONEncoder().encode(layer)
        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: data)
        XCTAssertEqual(decoded.layerType, .image)
    }

    func testLayerType_DrawingPreservedThroughCodable() throws {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .drawing)
        let data = try JSONEncoder().encode(layer)
        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: data)
        XCTAssertEqual(decoded.layerType, .drawing)
    }

    func testLayerType_ShapePreservedThroughCodable() throws {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .shape)
        let data = try JSONEncoder().encode(layer)
        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: data)
        XCTAssertEqual(decoded.layerType, .shape)
    }

    // MARK: - ZIndex Edge Cases

    func testZIndex_NegativeValue() {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image, zIndex: -1)
        XCTAssertEqual(layer.zIndex, -1)
    }

    func testZIndex_LargeValue() {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image, zIndex: 9999)
        XCTAssertEqual(layer.zIndex, 9999)
    }

    func testZIndex_PreservedThroughCodable() throws {
        let layer = RealtimeEditLayer(sessionId: UUID(), layerType: .image, zIndex: 42)
        let data = try JSONEncoder().encode(layer)
        let decoded = try JSONDecoder().decode(RealtimeEditLayer.self, from: data)
        XCTAssertEqual(decoded.zIndex, 42)
    }
}
