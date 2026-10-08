// MARK: - NetworkAdapterWorkflowTests.swift

// Workflow tests for HTTP error classification, NetworkResponseData,
// and NetworkRequestAttachment.
//
// Tests cover:
// - HTTPError.from(statusCode:) mapping for known codes
// - HTTPError.isRetryable classification
// - NetworkResponseData statusCode and rawResponseString
// - NetworkRequestAttachment initialization

import XCTest
@testable import Illustrate
@testable import IllustrateProviders

/// Use the package's NetworkResponseData to avoid module ambiguity
private typealias TestNetworkResponseData = IllustrateProviders.NetworkResponseData

final class NetworkAdapterWorkflowTests: XCTestCase {
    // MARK: - HTTPError.from(statusCode:) Mapping Tests

    func testHTTPErrorFrom_400_ReturnsNil() {
        XCTAssertNil(HTTPError.from(statusCode: 400))
    }

    func testHTTPErrorFrom_401_ReturnsNil() {
        XCTAssertNil(HTTPError.from(statusCode: 401))
    }

    func testHTTPErrorFrom_403_ReturnsForbidden() {
        XCTAssertEqual(HTTPError.from(statusCode: 403), .FORBIDDEN)
    }

    func testHTTPErrorFrom_404_ReturnsNotFound() {
        XCTAssertEqual(HTTPError.from(statusCode: 404), .NOT_FOUND)
    }

    func testHTTPErrorFrom_413_ReturnsPayloadTooLarge() {
        XCTAssertEqual(HTTPError.from(statusCode: 413), .PAYLOAD_TOO_LARGE)
    }

    func testHTTPErrorFrom_429_ReturnsTooManyRequests() {
        XCTAssertEqual(HTTPError.from(statusCode: 429), .TOO_MANY_REQUESTS)
    }

    func testHTTPErrorFrom_500_ReturnsInternalServerError() {
        XCTAssertEqual(HTTPError.from(statusCode: 500), .INTERNAL_SERVER_ERROR)
    }

    func testHTTPErrorFrom_503_ReturnsServiceUnavailable() {
        XCTAssertEqual(HTTPError.from(statusCode: 503), .SERVICE_UNAVAILABLE)
    }

    func testHTTPErrorFrom_504_ReturnsGatewayTimeout() {
        XCTAssertEqual(HTTPError.from(statusCode: 504), .GATEWAY_TIMEOUT)
    }

    // MARK: - HTTPError.isRetryable Tests

    func testIsRetryable_TooManyRequests_ReturnsTrue() {
        XCTAssertTrue(HTTPError.TOO_MANY_REQUESTS.isRetryable)
    }

    func testIsRetryable_ServiceUnavailable_ReturnsTrue() {
        XCTAssertTrue(HTTPError.SERVICE_UNAVAILABLE.isRetryable)
    }

    func testIsRetryable_GatewayTimeout_ReturnsTrue() {
        XCTAssertTrue(HTTPError.GATEWAY_TIMEOUT.isRetryable)
    }

    func testIsRetryable_NonRetryableErrors_ReturnsFalse() {
        let nonRetryable: [HTTPError] = [
            .FORBIDDEN,
            .NOT_FOUND,
            .PAYLOAD_TOO_LARGE,
            .INTERNAL_SERVER_ERROR,
        ]

        for error in nonRetryable {
            XCTAssertFalse(error.isRetryable, "\(error) should not be retryable")
        }
    }

    // MARK: - NetworkResponseData.dictionary Tests

    func testNetworkResponseData_Dictionary_RawResponseString_ContainsStatusCode() {
        let response = TestNetworkResponseData.dictionary(
            statusCode: 200,
            data: ["result": "ok"]
        )

        let raw = response.rawResponseString
        XCTAssertNotNil(raw)
        XCTAssertTrue(raw?.contains("HTTP Status: 200") == true)
    }

    func testNetworkResponseData_Dictionary_RawResponseString_ContainsJsonKeys() {
        let response = TestNetworkResponseData.dictionary(
            statusCode: 201,
            data: ["name": "test-value"]
        )

        let raw = response.rawResponseString
        XCTAssertNotNil(raw)
        XCTAssertTrue(raw?.contains("\"name\"") == true)
        XCTAssertTrue(raw?.contains("test-value") == true)
    }

    // MARK: - NetworkResponseData.array Tests

    func testNetworkResponseData_Array_RawResponseString_ContainsStatusCode() {
        let response = TestNetworkResponseData.array(
            statusCode: 200,
            data: [["id": 1], ["id": 2]]
        )

        let raw = response.rawResponseString
        XCTAssertNotNil(raw)
        XCTAssertTrue(raw?.contains("HTTP Status: 200") == true)
    }

    func testNetworkResponseData_Array_RawResponseString_ContainsArrayElements() {
        let response = TestNetworkResponseData.array(
            statusCode: 200,
            data: [["key": "alpha"], ["key": "beta"]]
        )

        let raw = response.rawResponseString
        XCTAssertNotNil(raw)
        XCTAssertTrue(raw?.contains("alpha") == true)
        XCTAssertTrue(raw?.contains("beta") == true)
    }

    // MARK: - NetworkResponseData.image Tests

    func testNetworkResponseData_Image_RawResponseString_ContainsMimeType() {
        let response = TestNetworkResponseData.image(
            statusCode: 200,
            base64: "dGVzdA==",
            mimeType: "image/png"
        )

        let raw = response.rawResponseString
        XCTAssertNotNil(raw)
        XCTAssertTrue(raw?.contains("image/png") == true)
        XCTAssertTrue(raw?.contains("Binary image response") == true)
    }

    func testNetworkResponseData_Image_RawResponseString_DoesNotExposeBase64() {
        let longBase64 = String(repeating: "A", count: 500)
        let response = TestNetworkResponseData.image(
            statusCode: 200,
            base64: longBase64,
            mimeType: "image/jpeg"
        )

        let raw = response.rawResponseString
        XCTAssertNotNil(raw)
        XCTAssertFalse(raw?.contains(longBase64) == true)
    }

    // MARK: - NetworkRequestAttachment Tests

    func testNetworkRequestAttachment_Init_SetsAllProperties() {
        let testData = Data([0x89, 0x50, 0x4E, 0x47])
        let attachment = NetworkRequestAttachment(
            name: "file",
            mimeType: "image/png",
            data: testData
        )

        XCTAssertEqual(attachment.name, "file")
        XCTAssertEqual(attachment.mimeType, "image/png")
        XCTAssertEqual(attachment.data, testData)
    }

    func testNetworkRequestAttachment_EmptyData() {
        let attachment = NetworkRequestAttachment(
            name: "empty",
            mimeType: "application/octet-stream",
            data: Data()
        )

        XCTAssertEqual(attachment.name, "empty")
        XCTAssertTrue(attachment.data.isEmpty)
    }
}
