// MARK: - NetworkResponseDataExtensionTests.swift

// Unit tests for NetworkResponseData.rawResponseString extension.
//
// Tests cover:
// - All three response cases (dictionary, array, image)
// - JSON serialization output format
// - HTTP status code inclusion
// - Edge cases (empty data, special characters)

import XCTest
@testable import Illustrate
@testable import IllustrateProviders

/// Typealias to use the package's NetworkResponseData type for testing
private typealias TestNetworkResponseData = IllustrateProviders.NetworkResponseData

final class NetworkResponseDataExtensionTests: XCTestCase {
    // MARK: - Dictionary Case Tests

    func testRawResponseString_dictionary_includesStatusCode() throws {
        let response = TestNetworkResponseData.dictionary(
            statusCode: 200,
            data: ["key": "value"]
        )

        let result = response.rawResponseString

        XCTAssertNotNil(result)
        XCTAssertTrue(try XCTUnwrap(result?.contains("HTTP Status: 200")))
    }

    func testRawResponseString_dictionary_includesJsonContent() throws {
        let response = TestNetworkResponseData.dictionary(
            statusCode: 200,
            data: ["name": "test", "count": 42]
        )

        let result = response.rawResponseString

        XCTAssertNotNil(result)
        XCTAssertTrue(try XCTUnwrap(result?.contains("\"name\"")))
        XCTAssertTrue(try XCTUnwrap(result?.contains("\"test\"")))
        XCTAssertTrue(try XCTUnwrap(result?.contains("\"count\"")))
        XCTAssertTrue(try XCTUnwrap(result?.contains("42")))
    }

    func testRawResponseString_dictionary_emptyData() throws {
        let response = TestNetworkResponseData.dictionary(
            statusCode: 204,
            data: [:]
        )

        let result = response.rawResponseString

        XCTAssertNotNil(result)
        XCTAssertTrue(try XCTUnwrap(result?.contains("HTTP Status: 204")))
        XCTAssertTrue(try XCTUnwrap(result?.contains("{\n\n}")) || result!.contains("{ }") || result!.contains("{}"))
    }

    func testRawResponseString_dictionary_nestedData() throws {
        let response = TestNetworkResponseData.dictionary(
            statusCode: 200,
            data: [
                "outer": [
                    "inner": "value",
                ],
            ]
        )

        let result = response.rawResponseString

        XCTAssertNotNil(result)
        XCTAssertTrue(try XCTUnwrap(result?.contains("\"outer\"")))
        XCTAssertTrue(try XCTUnwrap(result?.contains("\"inner\"")))
    }

    func testRawResponseString_dictionary_errorStatusCode() throws {
        let response = TestNetworkResponseData.dictionary(
            statusCode: 500,
            data: ["error": "Internal server error"]
        )

        let result = response.rawResponseString

        XCTAssertNotNil(result)
        XCTAssertTrue(try XCTUnwrap(result?.contains("HTTP Status: 500")))
        XCTAssertTrue(try XCTUnwrap(result?.contains("error")))
    }

    // MARK: - Array Case Tests

    func testRawResponseString_array_includesStatusCode() throws {
        let response = TestNetworkResponseData.array(
            statusCode: 200,
            data: [["id": 1], ["id": 2]]
        )

        let result = response.rawResponseString

        XCTAssertNotNil(result)
        XCTAssertTrue(try XCTUnwrap(result?.contains("HTTP Status: 200")))
    }

    func testRawResponseString_array_includesJsonContent() throws {
        let response = TestNetworkResponseData.array(
            statusCode: 200,
            data: [
                ["name": "first"],
                ["name": "second"],
            ]
        )

        let result = response.rawResponseString

        XCTAssertNotNil(result)
        XCTAssertTrue(try XCTUnwrap(result?.contains("\"name\"")))
        XCTAssertTrue(try XCTUnwrap(result?.contains("\"first\"")))
        XCTAssertTrue(try XCTUnwrap(result?.contains("\"second\"")))
    }

    func testRawResponseString_array_emptyArray() throws {
        let response = TestNetworkResponseData.array(
            statusCode: 200,
            data: []
        )

        let result = response.rawResponseString

        XCTAssertNotNil(result)
        XCTAssertTrue(try XCTUnwrap(result?.contains("HTTP Status: 200")))
        XCTAssertTrue(try XCTUnwrap(result?.contains("[\n\n]")) || result!.contains("[ ]") || result!.contains("[]"))
    }

    func testRawResponseString_array_singleElement() throws {
        let response = TestNetworkResponseData.array(
            statusCode: 201,
            data: [["created": true]]
        )

        let result = response.rawResponseString

        XCTAssertNotNil(result)
        XCTAssertTrue(try XCTUnwrap(result?.contains("HTTP Status: 201")))
        XCTAssertTrue(try XCTUnwrap(result?.contains("\"created\"")))
    }

    // MARK: - Image Case Tests

    func testRawResponseString_image_includesStatusCode() throws {
        let response = TestNetworkResponseData.image(
            statusCode: 200,
            base64: "SGVsbG8gV29ybGQ=",
            mimeType: "image/png"
        )

        let result = response.rawResponseString

        XCTAssertNotNil(result)
        XCTAssertTrue(try XCTUnwrap(result?.contains("HTTP Status: 200")))
    }

    func testRawResponseString_image_includesMimeType() throws {
        let response = TestNetworkResponseData.image(
            statusCode: 200,
            base64: "SGVsbG8gV29ybGQ=",
            mimeType: "image/jpeg"
        )

        let result = response.rawResponseString

        XCTAssertNotNil(result)
        XCTAssertTrue(try XCTUnwrap(result?.contains("image/jpeg")))
    }

    func testRawResponseString_image_describesBinaryContent() throws {
        let response = TestNetworkResponseData.image(
            statusCode: 200,
            base64: "SGVsbG8gV29ybGQ=",
            mimeType: "image/png"
        )

        let result = response.rawResponseString

        XCTAssertNotNil(result)
        XCTAssertTrue(try XCTUnwrap(result?.contains("Binary image response")))
    }

    func testRawResponseString_image_doesNotIncludeBase64Data() throws {
        let base64 = "SGVsbG8gV29ybGQ=" // "Hello World" in base64
        let response = TestNetworkResponseData.image(
            statusCode: 200,
            base64: base64,
            mimeType: "image/png"
        )

        let result = response.rawResponseString

        // Should NOT contain the actual base64 data (security/brevity)
        XCTAssertNotNil(result)
        XCTAssertFalse(try XCTUnwrap(result?.contains(base64)))
    }

    func testRawResponseString_image_pngMimeType() throws {
        let response = TestNetworkResponseData.image(
            statusCode: 200,
            base64: "data",
            mimeType: "image/png"
        )

        let result = response.rawResponseString

        XCTAssertNotNil(result)
        XCTAssertTrue(try XCTUnwrap(result?.contains("mimeType: image/png")))
    }

    func testRawResponseString_image_jpegMimeType() throws {
        let response = TestNetworkResponseData.image(
            statusCode: 200,
            base64: "data",
            mimeType: "image/jpeg"
        )

        let result = response.rawResponseString

        XCTAssertNotNil(result)
        XCTAssertTrue(try XCTUnwrap(result?.contains("mimeType: image/jpeg")))
    }

    // MARK: - Format Consistency Tests

    func testRawResponseString_allCases_startWithHTTPStatus() throws {
        let cases: [TestNetworkResponseData] = [
            .dictionary(statusCode: 200, data: [:]),
            .array(statusCode: 200, data: []),
            .image(statusCode: 200, base64: "", mimeType: "image/png"),
        ]

        for response in cases {
            let result = response.rawResponseString
            XCTAssertNotNil(result)
            XCTAssertTrue(try XCTUnwrap(result?.hasPrefix("HTTP Status:")))
        }
    }

    func testRawResponseString_allCases_containDoubleNewline() throws {
        let cases: [TestNetworkResponseData] = [
            .dictionary(statusCode: 200, data: ["key": "value"]),
            .array(statusCode: 200, data: [["key": "value"]]),
            .image(statusCode: 200, base64: "data", mimeType: "image/png"),
        ]

        for response in cases {
            let result = response.rawResponseString
            XCTAssertNotNil(result)
            XCTAssertTrue(try XCTUnwrap(result?.contains("\n\n")))
        }
    }

    // MARK: - Status Code Range Tests

    func testRawResponseString_variousStatusCodes() throws {
        let statusCodes = [200, 201, 204, 400, 401, 403, 404, 500, 502, 503]

        for code in statusCodes {
            let response = TestNetworkResponseData.dictionary(
                statusCode: code,
                data: ["status": code]
            )

            let result = response.rawResponseString
            XCTAssertNotNil(result)
            XCTAssertTrue(try XCTUnwrap(result?.contains("HTTP Status: \(code)")))
        }
    }

    // MARK: - Special Characters Tests

    func testRawResponseString_dictionary_specialCharacters() throws {
        let response = TestNetworkResponseData.dictionary(
            statusCode: 200,
            data: [
                "message": "Hello \"World\"!",
                "path": "/users/test@example.com",
            ]
        )

        let result = response.rawResponseString

        XCTAssertNotNil(result)
        // JSON should properly escape special characters
        XCTAssertTrue(try XCTUnwrap(result?.contains("Hello")))
        XCTAssertTrue(try XCTUnwrap(result?.contains("World")))
    }

    func testRawResponseString_dictionary_unicodeCharacters() throws {
        let response = TestNetworkResponseData.dictionary(
            statusCode: 200,
            data: [
                "greeting": "Hello 世界",
                "emoji": "🎨",
            ]
        )

        let result = response.rawResponseString

        XCTAssertNotNil(result)
        XCTAssertTrue(try XCTUnwrap(result?.contains("Hello")))
    }
}
