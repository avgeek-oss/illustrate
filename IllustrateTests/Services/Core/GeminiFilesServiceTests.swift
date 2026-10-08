// MARK: - GeminiFilesServiceTests.swift

// Unit tests for GeminiFilesError and GeminiUploadedFile.
//
// Tests cover:
// - All GeminiFilesError cases have non-empty errorDescription
// - GeminiFilesError specific error descriptions
// - GeminiUploadedFile initialization and property access

import XCTest
@testable import Illustrate

final class GeminiFilesServiceTests: XCTestCase {
    // MARK: - GeminiFilesError errorDescription Tests

    func testGeminiFilesError_InvalidURL_HasDescription() {
        let error = GeminiFilesError.invalidURL
        let description = error.errorDescription

        XCTAssertNotNil(description)
        XCTAssertFalse(description?.isEmpty == true)
        XCTAssertTrue(description?.contains("URL") == true)
    }

    func testGeminiFilesError_InvalidBase64Data_HasDescription() {
        let error = GeminiFilesError.invalidBase64Data
        let description = error.errorDescription

        XCTAssertNotNil(description)
        XCTAssertFalse(description?.isEmpty == true)
        XCTAssertTrue(description?.contains("base64") == true)
    }

    func testGeminiFilesError_InvalidResponse_HasDescription() {
        let error = GeminiFilesError.invalidResponse
        let description = error.errorDescription

        XCTAssertNotNil(description)
        XCTAssertFalse(description?.isEmpty == true)
        XCTAssertTrue(description?.contains("response") == true)
    }

    func testGeminiFilesError_UploadStartFailed_HasDescription() {
        let error = GeminiFilesError.uploadStartFailed(statusCode: 403)
        let description = error.errorDescription

        XCTAssertNotNil(description)
        XCTAssertFalse(description?.isEmpty == true)
        XCTAssertTrue(description?.contains("403") == true)
    }

    func testGeminiFilesError_MissingUploadURL_HasDescription() {
        let error = GeminiFilesError.missingUploadURL
        let description = error.errorDescription

        XCTAssertNotNil(description)
        XCTAssertFalse(description?.isEmpty == true)
        XCTAssertTrue(description?.contains("URL") == true)
    }

    func testGeminiFilesError_UploadFailed_HasDescription() {
        let error = GeminiFilesError.uploadFailed(statusCode: 500)
        let description = error.errorDescription

        XCTAssertNotNil(description)
        XCTAssertFalse(description?.isEmpty == true)
        XCTAssertTrue(description?.contains("500") == true)
    }

    func testGeminiFilesError_InvalidFileResponse_HasDescription() {
        let error = GeminiFilesError.invalidFileResponse
        let description = error.errorDescription

        XCTAssertNotNil(description)
        XCTAssertFalse(description?.isEmpty == true)
        XCTAssertTrue(description?.contains("file") == true)
    }

    // MARK: - GeminiUploadedFile Tests

    func testGeminiUploadedFile_Init_SetsAllProperties() {
        let file = GeminiUploadedFile(
            uri: "files/abc123",
            mimeType: "image/png",
            name: "test-image"
        )

        XCTAssertEqual(file.uri, "files/abc123")
        XCTAssertEqual(file.mimeType, "image/png")
        XCTAssertEqual(file.name, "test-image")
    }
}
