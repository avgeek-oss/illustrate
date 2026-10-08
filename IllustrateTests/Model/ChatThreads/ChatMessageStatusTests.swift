// MARK: - ChatMessageStatusTests.swift

// Extended tests for ChatMessageStatus enum covering areas not in ChatThreadModelWorkflowTests.
//
// ChatThreadModelWorkflowTests already covers: raw values (3), lowercase decode (3),
// unknown value throws (1). This file adds: uppercase decode, empty string,
// Codable round-trips, equatable verification, and pattern matching.

import XCTest
@testable import Illustrate

final class ChatMessageStatusTests: XCTestCase {
    // MARK: - Uppercase Backward-Compatible Decoding

    func testDecode_UppercaseProcessing_ReturnsProcessing() throws {
        let data = Data("\"PROCESSING\"".utf8)
        let decoded = try JSONDecoder().decode(ChatMessageStatus.self, from: data)
        XCTAssertEqual(decoded, .PROCESSING)
    }

    func testDecode_UppercaseGenerated_ReturnsGenerated() throws {
        let data = Data("\"GENERATED\"".utf8)
        let decoded = try JSONDecoder().decode(ChatMessageStatus.self, from: data)
        XCTAssertEqual(decoded, .GENERATED)
    }

    func testDecode_UppercaseFailed_ReturnsFailed() throws {
        let data = Data("\"FAILED\"".utf8)
        let decoded = try JSONDecoder().decode(ChatMessageStatus.self, from: data)
        XCTAssertEqual(decoded, .FAILED)
    }

    // MARK: - Invalid Decode Cases

    func testDecode_EmptyString_Throws() {
        let data = Data("\"\"".utf8)
        XCTAssertThrowsError(
            try JSONDecoder().decode(ChatMessageStatus.self, from: data)
        ) { error in
            guard case DecodingError.dataCorrupted = error else {
                XCTFail("Expected DecodingError.dataCorrupted, got \(error)")
                return
            }
        }
    }

    func testDecode_MixedCase_Throws() {
        let data = Data("\"Processing\"".utf8)
        XCTAssertThrowsError(
            try JSONDecoder().decode(ChatMessageStatus.self, from: data)
        )
    }

    func testDecode_NumericString_Throws() {
        let data = Data("\"123\"".utf8)
        XCTAssertThrowsError(
            try JSONDecoder().decode(ChatMessageStatus.self, from: data)
        )
    }

    func testDecode_WhitespaceString_Throws() {
        let data = Data("\" \"".utf8)
        XCTAssertThrowsError(
            try JSONDecoder().decode(ChatMessageStatus.self, from: data)
        )
    }

    // MARK: - Codable Round-Trip Per Case

    func testCodableRoundTrip_Processing() throws {
        let original = ChatMessageStatus.PROCESSING
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatMessageStatus.self, from: data)
        XCTAssertEqual(decoded, .PROCESSING)
    }

    func testCodableRoundTrip_Generated() throws {
        let original = ChatMessageStatus.GENERATED
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatMessageStatus.self, from: data)
        XCTAssertEqual(decoded, .GENERATED)
    }

    func testCodableRoundTrip_Failed() throws {
        let original = ChatMessageStatus.FAILED
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatMessageStatus.self, from: data)
        XCTAssertEqual(decoded, .FAILED)
    }

    // MARK: - Equatable Verification

    func testEquatable_SameCase_AreEqual() {
        XCTAssertEqual(ChatMessageStatus.PROCESSING, ChatMessageStatus.PROCESSING)
        XCTAssertEqual(ChatMessageStatus.GENERATED, ChatMessageStatus.GENERATED)
        XCTAssertEqual(ChatMessageStatus.FAILED, ChatMessageStatus.FAILED)
    }

    func testEquatable_DifferentCases_AreNotEqual() {
        XCTAssertNotEqual(ChatMessageStatus.PROCESSING, ChatMessageStatus.GENERATED)
        XCTAssertNotEqual(ChatMessageStatus.PROCESSING, ChatMessageStatus.FAILED)
        XCTAssertNotEqual(ChatMessageStatus.GENERATED, ChatMessageStatus.FAILED)
    }

    func testEquatable_AcrossEncodeDecode_AreEqual() throws {
        for status: ChatMessageStatus in [.PROCESSING, .GENERATED, .FAILED] {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(ChatMessageStatus.self, from: data)
            XCTAssertEqual(status, decoded)
        }
    }

    // MARK: - Pattern Matching

    func testPatternMatching_ProcessingCase() {
        let status = ChatMessageStatus.PROCESSING
        switch status {
        case .PROCESSING:
            break // expected
        default:
            XCTFail("Expected .PROCESSING")
        }
    }

    func testPatternMatching_GeneratedCase() {
        let status = ChatMessageStatus.GENERATED
        switch status {
        case .GENERATED:
            break // expected
        default:
            XCTFail("Expected .GENERATED")
        }
    }

    func testPatternMatching_FailedCase() {
        let status = ChatMessageStatus.FAILED
        switch status {
        case .FAILED:
            break // expected
        default:
            XCTFail("Expected .FAILED")
        }
    }

    func testPatternMatching_AllCasesDistinguishable() {
        let statuses: [ChatMessageStatus] = [.PROCESSING, .GENERATED, .FAILED]
        var processingCount = 0
        var generatedCount = 0
        var failedCount = 0

        for status in statuses {
            switch status {
            case .PROCESSING: processingCount += 1
            case .GENERATED: generatedCount += 1
            case .FAILED: failedCount += 1
            }
        }

        XCTAssertEqual(processingCount, 1)
        XCTAssertEqual(generatedCount, 1)
        XCTAssertEqual(failedCount, 1)
    }

    // MARK: - Encoding Output Verification

    func testEncoding_ProducesExpectedRawValue() throws {
        let data = try JSONEncoder().encode(ChatMessageStatus.PROCESSING)
        let jsonString = String(data: data, encoding: .utf8)
        XCTAssertEqual(jsonString, "\"PROCESSING\"")
    }

    func testEncoding_GeneratedProducesExpectedRawValue() throws {
        let data = try JSONEncoder().encode(ChatMessageStatus.GENERATED)
        let jsonString = String(data: data, encoding: .utf8)
        XCTAssertEqual(jsonString, "\"GENERATED\"")
    }

    func testEncoding_FailedProducesExpectedRawValue() throws {
        let data = try JSONEncoder().encode(ChatMessageStatus.FAILED)
        let jsonString = String(data: data, encoding: .utf8)
        XCTAssertEqual(jsonString, "\"FAILED\"")
    }
}
