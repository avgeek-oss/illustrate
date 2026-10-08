// MARK: - DrawingDataTests.swift

// Extended tests for DrawingData and BrushStroke beyond RealtimeEditModelTests.
//
// RealtimeEditModelTests covers: DrawingData init (1), with strokes (1), encoding (1),
// decoding (1), decodeFromNil (1), decodeFromInvalidData (1), roundTrip (1),
// BrushStroke init (1), BrushStroke Codable (1).
// This file adds: edge cases for points precision, empty points, BrushStroke ID
// uniqueness, multi-stroke encoding, and DrawingData decode edge cases.

import XCTest
@testable import Illustrate

final class DrawingDataTests: XCTestCase {
    // MARK: - BrushStroke ID Uniqueness

    func testBrushStroke_DefaultId_IsUnique() {
        let stroke1 = BrushStroke(points: [], colorHex: "FF0000", size: 5)
        let stroke2 = BrushStroke(points: [], colorHex: "FF0000", size: 5)
        XCTAssertNotEqual(stroke1.id, stroke2.id)
    }

    func testBrushStroke_CustomId_IsPreserved() {
        let customId = UUID()
        let stroke = BrushStroke(id: customId, points: [], colorHex: "000000", size: 1)
        XCTAssertEqual(stroke.id, customId)
    }

    // MARK: - BrushStroke Points Edge Cases

    func testBrushStroke_EmptyPoints_RoundTrip() throws {
        let stroke = BrushStroke(points: [], colorHex: "FFFFFF", size: 2)
        let data = try JSONEncoder().encode(stroke)
        let decoded = try JSONDecoder().decode(BrushStroke.self, from: data)
        XCTAssertTrue(decoded.points.isEmpty)
    }

    func testBrushStroke_SinglePoint_RoundTrip() throws {
        let stroke = BrushStroke(points: [CGPoint(x: 10.5, y: 20.3)], colorHex: "AABBCC", size: 3)
        let data = try JSONEncoder().encode(stroke)
        let decoded = try JSONDecoder().decode(BrushStroke.self, from: data)
        XCTAssertEqual(decoded.points.count, 1)
        XCTAssertEqual(decoded.points[0].x, 10.5, accuracy: 0.001)
        XCTAssertEqual(decoded.points[0].y, 20.3, accuracy: 0.001)
    }

    func testBrushStroke_MultiplePoints_PreservesOrder() throws {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 20),
            CGPoint(x: 30, y: 40),
            CGPoint(x: 50, y: 60),
        ]
        let stroke = BrushStroke(points: points, colorHex: "123456", size: 5)
        let data = try JSONEncoder().encode(stroke)
        let decoded = try JSONDecoder().decode(BrushStroke.self, from: data)

        XCTAssertEqual(decoded.points.count, 4)
        for (i, point) in points.enumerated() {
            XCTAssertEqual(decoded.points[i].x, point.x, accuracy: 0.001)
            XCTAssertEqual(decoded.points[i].y, point.y, accuracy: 0.001)
        }
    }

    func testBrushStroke_FloatingPointPrecision() throws {
        let points = [CGPoint(x: 0.123456789, y: 0.987654321)]
        let stroke = BrushStroke(points: points, colorHex: "FF0000", size: 1)
        let data = try JSONEncoder().encode(stroke)
        let decoded = try JSONDecoder().decode(BrushStroke.self, from: data)
        XCTAssertEqual(decoded.points[0].x, 0.123456789, accuracy: 0.0001)
        XCTAssertEqual(decoded.points[0].y, 0.987654321, accuracy: 0.0001)
    }

    func testBrushStroke_NegativeCoordinates() throws {
        let points = [CGPoint(x: -100, y: -200)]
        let stroke = BrushStroke(points: points, colorHex: "FF0000", size: 1)
        let data = try JSONEncoder().encode(stroke)
        let decoded = try JSONDecoder().decode(BrushStroke.self, from: data)
        XCTAssertEqual(decoded.points[0].x, -100, accuracy: 0.001)
        XCTAssertEqual(decoded.points[0].y, -200, accuracy: 0.001)
    }

    // MARK: - BrushStroke Properties Preserved

    func testBrushStroke_ColorHex_Preserved() throws {
        let stroke = BrushStroke(points: [], colorHex: "AABB11", size: 1)
        let data = try JSONEncoder().encode(stroke)
        let decoded = try JSONDecoder().decode(BrushStroke.self, from: data)
        XCTAssertEqual(decoded.colorHex, "AABB11")
    }

    func testBrushStroke_Size_Preserved() throws {
        let stroke = BrushStroke(points: [], colorHex: "000000", size: 42.5)
        let data = try JSONEncoder().encode(stroke)
        let decoded = try JSONDecoder().decode(BrushStroke.self, from: data)
        XCTAssertEqual(decoded.size, 42.5, accuracy: 0.001)
    }

    func testBrushStroke_Id_PreservedThroughCodable() throws {
        let id = UUID()
        let stroke = BrushStroke(id: id, points: [], colorHex: "000000", size: 1)
        let data = try JSONEncoder().encode(stroke)
        let decoded = try JSONDecoder().decode(BrushStroke.self, from: data)
        XCTAssertEqual(decoded.id, id)
    }

    // MARK: - DrawingData Multi-Stroke

    func testDrawingData_MultipleStrokes_AllPreserved() {
        let strokes = [
            BrushStroke(points: [CGPoint(x: 0, y: 0)], colorHex: "FF0000", size: 1),
            BrushStroke(points: [CGPoint(x: 10, y: 10)], colorHex: "00FF00", size: 2),
            BrushStroke(points: [CGPoint(x: 20, y: 20)], colorHex: "0000FF", size: 3),
        ]
        let drawing = DrawingData(strokes: strokes)
        let encoded = drawing.encode()
        XCTAssertNotNil(encoded)

        let decoded = DrawingData.decode(from: encoded)
        XCTAssertEqual(decoded.strokes.count, 3)
        XCTAssertEqual(decoded.strokes[0].colorHex, "FF0000")
        XCTAssertEqual(decoded.strokes[1].colorHex, "00FF00")
        XCTAssertEqual(decoded.strokes[2].colorHex, "0000FF")
    }

    func testDrawingData_StrokeOrder_Preserved() {
        let strokes = (0 ..< 10).map { i in
            BrushStroke(points: [CGPoint(x: CGFloat(i), y: 0)], colorHex: "000000", size: 1)
        }
        let drawing = DrawingData(strokes: strokes)
        let decoded = DrawingData.decode(from: drawing.encode())

        XCTAssertEqual(decoded.strokes.count, 10)
        for (i, stroke) in decoded.strokes.enumerated() {
            XCTAssertEqual(stroke.points[0].x, CGFloat(i), accuracy: 0.001)
        }
    }

    // MARK: - DrawingData Decode Edge Cases

    func testDrawingData_DecodeFromEmptyData_ReturnsEmptyStrokes() {
        let emptyData = Data()
        let decoded = DrawingData.decode(from: emptyData)
        XCTAssertTrue(decoded.strokes.isEmpty)
    }

    func testDrawingData_DecodeFromRandomBytes_ReturnsEmptyStrokes() {
        let randomData = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let decoded = DrawingData.decode(from: randomData)
        XCTAssertTrue(decoded.strokes.isEmpty)
    }

    func testDrawingData_DecodeFromJsonObject_ReturnsEmptyStrokes() {
        let jsonData = Data("{\"key\": \"value\"}".utf8)
        let decoded = DrawingData.decode(from: jsonData)
        XCTAssertTrue(decoded.strokes.isEmpty)
    }

    func testDrawingData_Encode_EmptyStrokes_ProducesValidJSON() throws {
        let drawing = DrawingData()
        let encoded = drawing.encode()
        XCTAssertNotNil(encoded)

        let json = try JSONSerialization.jsonObject(with: XCTUnwrap(encoded)) as? [String: Any]
        XCTAssertNotNil(json)
        let strokesArray = json?["strokes"] as? [Any]
        XCTAssertNotNil(strokesArray)
        XCTAssertEqual(strokesArray?.count, 0)
    }

    // MARK: - DrawingData Round-Trip Extended

    func testDrawingData_RoundTrip_PreservesStrokeDetails() {
        let stroke = BrushStroke(
            points: [CGPoint(x: 1, y: 2), CGPoint(x: 3, y: 4)],
            colorHex: "AABBCC",
            size: 15.5
        )
        let drawing = DrawingData(strokes: [stroke])
        let decoded = DrawingData.decode(from: drawing.encode())

        XCTAssertEqual(decoded.strokes.count, 1)
        let decodedStroke = decoded.strokes[0]
        XCTAssertEqual(decodedStroke.points.count, 2)
        XCTAssertEqual(decodedStroke.colorHex, "AABBCC")
        XCTAssertEqual(decodedStroke.size, 15.5, accuracy: 0.001)
    }

    func testDrawingData_RoundTrip_EmptyStrokes() {
        let drawing = DrawingData()
        let decoded = DrawingData.decode(from: drawing.encode())
        XCTAssertTrue(decoded.strokes.isEmpty)
    }
}
