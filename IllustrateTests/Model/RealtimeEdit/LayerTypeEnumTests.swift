// MARK: - LayerTypeEnumTests.swift

// Extended tests for LayerType enum covering areas not in RealtimeEditModelTests.
//
// RealtimeEditModelTests covers: displayNames (1), icons (1), CaseIterable (1).
// This file adds: raw values, Identifiable (id property), Codable round-trips,
// decode from raw strings, and array encoding.

import XCTest
@testable import Illustrate

final class LayerTypeEnumTests: XCTestCase {
    // MARK: - Raw Values

    func testRawValue_Image() {
        XCTAssertEqual(LayerType.image.rawValue, "image")
    }

    func testRawValue_Drawing() {
        XCTAssertEqual(LayerType.drawing.rawValue, "drawing")
    }

    func testRawValue_Shape() {
        XCTAssertEqual(LayerType.shape.rawValue, "shape")
    }

    // MARK: - Init From RawValue

    func testInitFromRawValue_Image() {
        XCTAssertEqual(LayerType(rawValue: "image"), .image)
    }

    func testInitFromRawValue_Drawing() {
        XCTAssertEqual(LayerType(rawValue: "drawing"), .drawing)
    }

    func testInitFromRawValue_Shape() {
        XCTAssertEqual(LayerType(rawValue: "shape"), .shape)
    }

    func testInitFromRawValue_Invalid_ReturnsNil() {
        XCTAssertNil(LayerType(rawValue: "video"))
        XCTAssertNil(LayerType(rawValue: ""))
        XCTAssertNil(LayerType(rawValue: "Image"))
    }

    // MARK: - Identifiable

    func testIdentifiable_ImageId() {
        XCTAssertEqual(LayerType.image.id, "image")
    }

    func testIdentifiable_DrawingId() {
        XCTAssertEqual(LayerType.drawing.id, "drawing")
    }

    func testIdentifiable_ShapeId() {
        XCTAssertEqual(LayerType.shape.id, "shape")
    }

    func testIdentifiable_IdMatchesRawValue() {
        for layerType in LayerType.allCases {
            XCTAssertEqual(layerType.id, layerType.rawValue)
        }
    }

    // MARK: - CaseIterable

    func testAllCases_Count() {
        XCTAssertEqual(LayerType.allCases.count, 3)
    }

    func testAllCases_ContainsAllExpected() {
        let cases = Set(LayerType.allCases)
        XCTAssertTrue(cases.contains(.image))
        XCTAssertTrue(cases.contains(.drawing))
        XCTAssertTrue(cases.contains(.shape))
    }

    // MARK: - Codable Round-Trip

    func testCodableRoundTrip_Image() throws {
        let data = try JSONEncoder().encode(LayerType.image)
        let decoded = try JSONDecoder().decode(LayerType.self, from: data)
        XCTAssertEqual(decoded, .image)
    }

    func testCodableRoundTrip_Drawing() throws {
        let data = try JSONEncoder().encode(LayerType.drawing)
        let decoded = try JSONDecoder().decode(LayerType.self, from: data)
        XCTAssertEqual(decoded, .drawing)
    }

    func testCodableRoundTrip_Shape() throws {
        let data = try JSONEncoder().encode(LayerType.shape)
        let decoded = try JSONDecoder().decode(LayerType.self, from: data)
        XCTAssertEqual(decoded, .shape)
    }

    // MARK: - Decode From Raw Strings

    func testDecodeFromRawString_Image() throws {
        let data = Data("\"image\"".utf8)
        let decoded = try JSONDecoder().decode(LayerType.self, from: data)
        XCTAssertEqual(decoded, .image)
    }

    func testDecodeFromRawString_Drawing() throws {
        let data = Data("\"drawing\"".utf8)
        let decoded = try JSONDecoder().decode(LayerType.self, from: data)
        XCTAssertEqual(decoded, .drawing)
    }

    func testDecodeFromRawString_Shape() throws {
        let data = Data("\"shape\"".utf8)
        let decoded = try JSONDecoder().decode(LayerType.self, from: data)
        XCTAssertEqual(decoded, .shape)
    }

    func testDecodeFromRawString_Invalid_Throws() {
        let data = Data("\"unknown\"".utf8)
        XCTAssertThrowsError(
            try JSONDecoder().decode(LayerType.self, from: data)
        )
    }

    // MARK: - Array Codable

    func testArrayCodableRoundTrip() throws {
        let array: [LayerType] = [.image, .drawing, .shape, .image]
        let data = try JSONEncoder().encode(array)
        let decoded = try JSONDecoder().decode([LayerType].self, from: data)
        XCTAssertEqual(decoded, array)
    }

    // MARK: - Encoding Output

    func testEncoding_ProducesRawValue() throws {
        let data = try JSONEncoder().encode(LayerType.image)
        let jsonString = String(data: data, encoding: .utf8)
        XCTAssertEqual(jsonString, "\"image\"")
    }
}
