// MARK: - ShapeTypeEnumTests.swift

// Extended tests for ShapeType enum covering areas not in RealtimeEditModelTests.
//
// RealtimeEditModelTests covers: displayNames (1), icons (1), filledIcons (1), CaseIterable (1).
// This file adds: raw values, Identifiable, Codable per case, decode from raw strings,
// array round-trip, and encoding output verification.

import XCTest
@testable import Illustrate

final class ShapeTypeEnumTests: XCTestCase {
    // MARK: - Raw Values

    func testRawValue_Triangle() {
        XCTAssertEqual(ShapeType.triangle.rawValue, "triangle")
    }

    func testRawValue_Square() {
        XCTAssertEqual(ShapeType.square.rawValue, "square")
    }

    func testRawValue_Circle() {
        XCTAssertEqual(ShapeType.circle.rawValue, "circle")
    }

    // MARK: - Init From RawValue

    func testInitFromRawValue_Triangle() {
        XCTAssertEqual(ShapeType(rawValue: "triangle"), .triangle)
    }

    func testInitFromRawValue_Square() {
        XCTAssertEqual(ShapeType(rawValue: "square"), .square)
    }

    func testInitFromRawValue_Circle() {
        XCTAssertEqual(ShapeType(rawValue: "circle"), .circle)
    }

    func testInitFromRawValue_Invalid_ReturnsNil() {
        XCTAssertNil(ShapeType(rawValue: "rectangle"))
        XCTAssertNil(ShapeType(rawValue: ""))
        XCTAssertNil(ShapeType(rawValue: "Triangle"))
    }

    // MARK: - Display Names

    func testDisplayName_Triangle() {
        XCTAssertEqual(ShapeType.triangle.displayName, "Triangle")
    }

    func testDisplayName_Square() {
        XCTAssertEqual(ShapeType.square.displayName, "Square")
    }

    func testDisplayName_Circle() {
        XCTAssertEqual(ShapeType.circle.displayName, "Circle")
    }

    // MARK: - Icons

    func testIcon_Triangle() {
        XCTAssertEqual(ShapeType.triangle.icon, "triangle")
    }

    func testIcon_Square() {
        XCTAssertEqual(ShapeType.square.icon, "square")
    }

    func testIcon_Circle() {
        XCTAssertEqual(ShapeType.circle.icon, "circle")
    }

    // MARK: - Filled Icons

    func testFilledIcon_Triangle() {
        XCTAssertEqual(ShapeType.triangle.filledIcon, "triangle.fill")
    }

    func testFilledIcon_Square() {
        XCTAssertEqual(ShapeType.square.filledIcon, "square.fill")
    }

    func testFilledIcon_Circle() {
        XCTAssertEqual(ShapeType.circle.filledIcon, "circle.fill")
    }

    // MARK: - Identifiable

    func testIdentifiable_TriangleId() {
        XCTAssertEqual(ShapeType.triangle.id, "triangle")
    }

    func testIdentifiable_SquareId() {
        XCTAssertEqual(ShapeType.square.id, "square")
    }

    func testIdentifiable_CircleId() {
        XCTAssertEqual(ShapeType.circle.id, "circle")
    }

    func testIdentifiable_IdMatchesRawValue() {
        for shape in ShapeType.allCases {
            XCTAssertEqual(shape.id, shape.rawValue)
        }
    }

    // MARK: - CaseIterable

    func testAllCases_Count() {
        XCTAssertEqual(ShapeType.allCases.count, 3)
    }

    func testAllCases_ContainsAllExpected() {
        let cases = Set(ShapeType.allCases)
        XCTAssertTrue(cases.contains(.triangle))
        XCTAssertTrue(cases.contains(.square))
        XCTAssertTrue(cases.contains(.circle))
    }

    // MARK: - Codable Round-Trip

    func testCodableRoundTrip_Triangle() throws {
        let data = try JSONEncoder().encode(ShapeType.triangle)
        let decoded = try JSONDecoder().decode(ShapeType.self, from: data)
        XCTAssertEqual(decoded, .triangle)
    }

    func testCodableRoundTrip_Square() throws {
        let data = try JSONEncoder().encode(ShapeType.square)
        let decoded = try JSONDecoder().decode(ShapeType.self, from: data)
        XCTAssertEqual(decoded, .square)
    }

    func testCodableRoundTrip_Circle() throws {
        let data = try JSONEncoder().encode(ShapeType.circle)
        let decoded = try JSONDecoder().decode(ShapeType.self, from: data)
        XCTAssertEqual(decoded, .circle)
    }

    // MARK: - Decode From Raw Strings

    func testDecodeFromRawString_Triangle() throws {
        let data = Data("\"triangle\"".utf8)
        let decoded = try JSONDecoder().decode(ShapeType.self, from: data)
        XCTAssertEqual(decoded, .triangle)
    }

    func testDecodeFromRawString_Square() throws {
        let data = Data("\"square\"".utf8)
        let decoded = try JSONDecoder().decode(ShapeType.self, from: data)
        XCTAssertEqual(decoded, .square)
    }

    func testDecodeFromRawString_Circle() throws {
        let data = Data("\"circle\"".utf8)
        let decoded = try JSONDecoder().decode(ShapeType.self, from: data)
        XCTAssertEqual(decoded, .circle)
    }

    func testDecodeFromRawString_Invalid_Throws() {
        let data = Data("\"hexagon\"".utf8)
        XCTAssertThrowsError(
            try JSONDecoder().decode(ShapeType.self, from: data)
        )
    }

    // MARK: - Array Codable

    func testArrayCodableRoundTrip() throws {
        let array: [ShapeType] = [.triangle, .square, .circle, .triangle]
        let data = try JSONEncoder().encode(array)
        let decoded = try JSONDecoder().decode([ShapeType].self, from: data)
        XCTAssertEqual(decoded, array)
    }

    func testEmptyArrayCodableRoundTrip() throws {
        let array: [ShapeType] = []
        let data = try JSONEncoder().encode(array)
        let decoded = try JSONDecoder().decode([ShapeType].self, from: data)
        XCTAssertTrue(decoded.isEmpty)
    }

    // MARK: - Icon Consistency

    func testFilledIcon_MatchesIconWithFillSuffix() {
        for shape in ShapeType.allCases {
            XCTAssertEqual(shape.filledIcon, "\(shape.icon).fill")
        }
    }

    // MARK: - Encoding Output

    func testEncoding_ProducesRawValue() throws {
        for shape in ShapeType.allCases {
            let data = try JSONEncoder().encode(shape)
            let jsonString = String(data: data, encoding: .utf8)
            XCTAssertEqual(jsonString, "\"\(shape.rawValue)\"")
        }
    }
}
