// MARK: - VideoExportResultTests.swift

// Tests for VideoExportResult struct.
//
// Covers:
// - Initialization with success/failure states
// - Field access patterns
// - Field combination scenarios
// - Workflow patterns (URL path access, struct independence)

import XCTest
@testable import Illustrate

final class VideoExportResultTests: XCTestCase {
    // MARK: - Initialization

    func testInit_success_hasURL() {
        let url = URL(fileURLWithPath: "/tmp/video.mp4")
        let result = VideoExportResult(success: true, outputURL: url, errorMessage: nil)
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.outputURL)
    }

    func testInit_failure_hasErrorMessage() {
        let result = VideoExportResult(success: false, outputURL: nil, errorMessage: "Export failed")
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.errorMessage, "Export failed")
    }

    func testInit_failure_outputURLIsNil() {
        let result = VideoExportResult(success: false, outputURL: nil, errorMessage: "Error")
        XCTAssertNil(result.outputURL)
    }

    func testInit_success_errorMessageIsNil() {
        let url = URL(fileURLWithPath: "/tmp/video.mp4")
        let result = VideoExportResult(success: true, outputURL: url, errorMessage: nil)
        XCTAssertNil(result.errorMessage)
    }

    func testInit_success_outputURLIsValid() throws {
        let url = URL(fileURLWithPath: "/tmp/output/video.mp4")
        let result = VideoExportResult(success: true, outputURL: url, errorMessage: nil)
        XCTAssertTrue(try XCTUnwrap(result.outputURL?.path.contains("video.mp4")))
    }

    // MARK: - Field Access

    func testFieldAccess_successField_isAccessible() {
        let result = VideoExportResult(success: true, outputURL: nil, errorMessage: nil)
        XCTAssertTrue(result.success)
    }

    func testFieldAccess_outputURLField_isOptionalURL() {
        let result = VideoExportResult(success: true, outputURL: nil, errorMessage: nil)
        let _: URL? = result.outputURL
        XCTAssertNil(result.outputURL)
    }

    func testFieldAccess_errorMessageField_isOptionalString() {
        let result = VideoExportResult(success: false, outputURL: nil, errorMessage: "test")
        let _: String? = result.errorMessage
        XCTAssertNotNil(result.errorMessage)
    }

    // MARK: - Field Combination Patterns

    func testPattern_successWithAllFields() {
        let url = URL(fileURLWithPath: "/tmp/video.mp4")
        let result = VideoExportResult(success: true, outputURL: url, errorMessage: "warning")
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.outputURL)
        XCTAssertNotNil(result.errorMessage)
    }

    func testPattern_failureWithAllFields() {
        let url = URL(fileURLWithPath: "/tmp/partial.mp4")
        let result = VideoExportResult(success: false, outputURL: url, errorMessage: "partial failure")
        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.outputURL)
        XCTAssertNotNil(result.errorMessage)
    }

    func testPattern_emptyErrorMessage() {
        let result = VideoExportResult(success: false, outputURL: nil, errorMessage: "")
        XCTAssertEqual(result.errorMessage, "")
    }

    func testPattern_nilURL_nilError() {
        let result = VideoExportResult(success: false, outputURL: nil, errorMessage: nil)
        XCTAssertNil(result.outputURL)
        XCTAssertNil(result.errorMessage)
    }

    // MARK: - Workflow Patterns

    func testWorkflow_successResult_canAccessURLPath() {
        let url = URL(fileURLWithPath: "/tmp/output/exported.mp4")
        let result = VideoExportResult(success: true, outputURL: url, errorMessage: nil)
        XCTAssertEqual(result.outputURL?.lastPathComponent, "exported.mp4")
    }

    func testWorkflow_multipleResults_independent() {
        let result1 = VideoExportResult(
            success: true,
            outputURL: URL(fileURLWithPath: "/tmp/a.mp4"),
            errorMessage: nil
        )
        let result2 = VideoExportResult(
            success: false,
            outputURL: nil,
            errorMessage: "Failed"
        )
        // Struct semantics: independent copies
        XCTAssertTrue(result1.success)
        XCTAssertFalse(result2.success)
        XCTAssertNotNil(result1.outputURL)
        XCTAssertNil(result2.outputURL)
    }

    func testWorkflow_failureResult_patternMatch() throws {
        let result = VideoExportResult(success: false, outputURL: nil, errorMessage: "codec error")
        if result.success {
            XCTFail("Should not be success")
        } else {
            XCTAssertNotNil(result.errorMessage)
            XCTAssertTrue(try XCTUnwrap(result.errorMessage?.contains("codec")))
        }
    }
}
