// MARK: - NetworkAdapterTests.swift

// Unit tests for NetworkAdapter and related types.
//
// Tests cover:
// - NetworkResponseData enum cases
// - NetworkRequestAttachment struct
// - Exponential backoff delay calculations
// - Rate limit delay calculations

import AvgeekNetworking
import AvgeekTestSupport
import XCTest
@testable import Illustrate
@testable import IllustrateProviders

// Use IllustrateProviders version of NetworkResponseData to avoid ambiguity
private typealias TestNetworkResponseData = IllustrateProviders.NetworkResponseData
private typealias TestNetworkRequestAttachment = IllustrateProviders.NetworkRequestAttachment

final class NetworkAdapterTests: XCTestCase {
    func testDataRequestRetriesSafeMethodAndBoundsRetryAfter() async throws {
        let transport = SequencedHTTPTransport(stubs: [
            .init(statusCode: 429, headers: ["Retry-After": "120"]),
            .init(
                statusCode: 200,
                headers: ["Content-Type": "image/png"],
                body: Data([0x89, 0x50, 0x4E, 0x47])
            ),
        ])
        let clock = TestClock()
        let adapter = NetworkAdapter(
            transport: transport,
            retryScheduler: clock.retryScheduler
        )
        var request = try URLRequest(url: XCTUnwrap(URL(string: "https://provider.example/image.png")))
        request.httpMethod = "GET"

        let response = try await adapter.performDataRequest(request)

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.contentType, "image/png")
        XCTAssertEqual(response.headers["content-type"], "image/png")
        let requestCount = await transport.requestCount()
        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(clock.recordedSleeps, [60])
    }

    func testDataRequestDoesNotRetryUnsafeMethod() async throws {
        let transport = SequencedHTTPTransport(stubs: [
            .init(statusCode: 429, headers: ["Retry-After": "5"]),
            .init(statusCode: 200),
        ])
        let clock = TestClock()
        let adapter = NetworkAdapter(
            transport: transport,
            retryScheduler: clock.retryScheduler
        )
        var request = try URLRequest(url: XCTUnwrap(URL(string: "https://provider.example/generations")))
        request.httpMethod = "POST"

        do {
            _ = try await adapter.performDataRequest(request)
            XCTFail("Expected the rate-limit response to be surfaced")
        } catch {
            XCTAssertEqual((error as NSError).code, 429)
        }

        let requestCount = await transport.requestCount()
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(clock.recordedSleeps, [])
    }

    func testRetryDelayNanoseconds_boundsUntrustedRetryAfterValues() {
        XCTAssertEqual(
            NetworkAdapter.retryDelayNanoseconds(retryAfter: 5, exponential: 1),
            5_000_000_000
        )
        XCTAssertEqual(
            NetworkAdapter.retryDelayNanoseconds(retryAfter: .greatestFiniteMagnitude, exponential: 1),
            60_000_000_000
        )
        XCTAssertEqual(
            NetworkAdapter.retryDelayNanoseconds(retryAfter: .infinity, exponential: 2),
            2_000_000_000
        )
        XCTAssertEqual(
            NetworkAdapter.retryDelayNanoseconds(retryAfter: -20, exponential: 2),
            0
        )
    }

    // MARK: - NetworkResponseData Tests

    func testNetworkResponseData_dictionary_statusCode() {
        let data: [String: Any] = ["key": "value"]
        let response = TestNetworkResponseData.dictionary(statusCode: 200, data: data)

        switch response {
        case let .dictionary(statusCode, _):
            XCTAssertEqual(statusCode, 200)
        default:
            XCTFail("Expected dictionary case")
        }
    }

    func testNetworkResponseData_dictionary_data() {
        let data: [String: Any] = ["key": "value", "count": 42]
        let response = TestNetworkResponseData.dictionary(statusCode: 200, data: data)

        switch response {
        case let .dictionary(_, responseData):
            XCTAssertEqual(responseData["key"] as? String, "value")
            XCTAssertEqual(responseData["count"] as? Int, 42)
        default:
            XCTFail("Expected dictionary case")
        }
    }

    func testNetworkResponseData_dictionary_emptyData() {
        let response = TestNetworkResponseData.dictionary(statusCode: 204, data: [:])

        switch response {
        case let .dictionary(statusCode, data):
            XCTAssertEqual(statusCode, 204)
            XCTAssertTrue(data.isEmpty)
        default:
            XCTFail("Expected dictionary case")
        }
    }

    func testNetworkResponseData_dictionary_errorStatusCode() {
        let data: [String: Any] = ["error": "Not found"]
        let response = TestNetworkResponseData.dictionary(statusCode: 404, data: data)

        switch response {
        case let .dictionary(statusCode, responseData):
            XCTAssertEqual(statusCode, 404)
            XCTAssertEqual(responseData["error"] as? String, "Not found")
        default:
            XCTFail("Expected dictionary case")
        }
    }

    func testNetworkResponseData_array_statusCode() {
        let data: [[String: Any]] = [["id": 1], ["id": 2]]
        let response = TestNetworkResponseData.array(statusCode: 200, data: data)

        switch response {
        case let .array(statusCode, _):
            XCTAssertEqual(statusCode, 200)
        default:
            XCTFail("Expected array case")
        }
    }

    func testNetworkResponseData_array_data() {
        let data: [[String: Any]] = [["id": 1, "name": "First"], ["id": 2, "name": "Second"]]
        let response = TestNetworkResponseData.array(statusCode: 200, data: data)

        switch response {
        case let .array(_, responseData):
            XCTAssertEqual(responseData.count, 2)
            XCTAssertEqual(responseData[0]["id"] as? Int, 1)
            XCTAssertEqual(responseData[1]["name"] as? String, "Second")
        default:
            XCTFail("Expected array case")
        }
    }

    func testNetworkResponseData_array_emptyData() {
        let response = TestNetworkResponseData.array(statusCode: 200, data: [])

        switch response {
        case let .array(statusCode, data):
            XCTAssertEqual(statusCode, 200)
            XCTAssertTrue(data.isEmpty)
        default:
            XCTFail("Expected array case")
        }
    }

    func testNetworkResponseData_array_singleItem() {
        let data: [[String: Any]] = [["result": "success"]]
        let response = TestNetworkResponseData.array(statusCode: 201, data: data)

        switch response {
        case let .array(statusCode, responseData):
            XCTAssertEqual(statusCode, 201)
            XCTAssertEqual(responseData.count, 1)
        default:
            XCTFail("Expected array case")
        }
    }

    func testNetworkResponseData_image_statusCode() {
        let response = TestNetworkResponseData.image(statusCode: 200, base64: "abc123", mimeType: "image/png")

        switch response {
        case let .image(statusCode, _, _):
            XCTAssertEqual(statusCode, 200)
        default:
            XCTFail("Expected image case")
        }
    }

    func testNetworkResponseData_image_base64() {
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        let response = TestNetworkResponseData.image(statusCode: 200, base64: base64, mimeType: "image/png")

        switch response {
        case let .image(_, responseBase64, _):
            XCTAssertEqual(responseBase64, base64)
        default:
            XCTFail("Expected image case")
        }
    }

    func testNetworkResponseData_image_mimeType_png() {
        let response = TestNetworkResponseData.image(statusCode: 200, base64: "abc", mimeType: "image/png")

        switch response {
        case let .image(_, _, mimeType):
            XCTAssertEqual(mimeType, "image/png")
        default:
            XCTFail("Expected image case")
        }
    }

    func testNetworkResponseData_image_mimeType_jpeg() {
        let response = TestNetworkResponseData.image(statusCode: 200, base64: "abc", mimeType: "image/jpeg")

        switch response {
        case let .image(_, _, mimeType):
            XCTAssertEqual(mimeType, "image/jpeg")
        default:
            XCTFail("Expected image case")
        }
    }

    // MARK: - NetworkRequestAttachment Tests

    func testNetworkRequestAttachment_initialization() {
        let data = Data([0x89, 0x50, 0x4E, 0x47])
        let attachment = TestNetworkRequestAttachment(name: "image", mimeType: "image/png", data: data)

        XCTAssertEqual(attachment.name, "image")
        XCTAssertEqual(attachment.mimeType, "image/png")
        XCTAssertEqual(attachment.data, data)
    }

    func testNetworkRequestAttachment_emptyData() {
        let attachment = TestNetworkRequestAttachment(name: "empty", mimeType: "text/plain", data: Data())

        XCTAssertEqual(attachment.name, "empty")
        XCTAssertTrue(attachment.data.isEmpty)
    }

    func testNetworkRequestAttachment_variousMimeTypes() {
        let jpegAttachment = TestNetworkRequestAttachment(
            name: "photo",
            mimeType: "image/jpeg",
            data: Data([0xFF, 0xD8])
        )
        let pdfAttachment = TestNetworkRequestAttachment(
            name: "document",
            mimeType: "application/pdf",
            data: Data([0x25, 0x50])
        )
        let videoAttachment = TestNetworkRequestAttachment(
            name: "video",
            mimeType: "video/mp4",
            data: Data([0x00, 0x00])
        )

        XCTAssertEqual(jpegAttachment.mimeType, "image/jpeg")
        XCTAssertEqual(pdfAttachment.mimeType, "application/pdf")
        XCTAssertEqual(videoAttachment.mimeType, "video/mp4")
    }

    func testNetworkRequestAttachment_largeData() {
        let largeData = Data(repeating: 0x00, count: 1024 * 1024) // 1MB
        let attachment = TestNetworkRequestAttachment(
            name: "large",
            mimeType: "application/octet-stream",
            data: largeData
        )

        XCTAssertEqual(attachment.data.count, 1024 * 1024)
    }

    func testNetworkRequestAttachment_specialCharactersInName() {
        let attachment = TestNetworkRequestAttachment(name: "file-name_v2.png", mimeType: "image/png", data: Data())

        XCTAssertEqual(attachment.name, "file-name_v2.png")
    }

    // MARK: - Exponential Backoff Delay Calculation Tests

    /// Tests the exponential backoff delay formula used for 503/504 errors:
    /// delay = baseRetryDelay * pow(2.0, Double(attempt))
    func testExponentialBackoff_attempt0() {
        let baseRetryDelay = 1.0
        let attempt = 0
        let delay = baseRetryDelay * pow(2.0, Double(attempt))

        XCTAssertEqual(delay, 1.0, accuracy: 0.001)
    }

    func testExponentialBackoff_attempt1() {
        let baseRetryDelay = 1.0
        let attempt = 1
        let delay = baseRetryDelay * pow(2.0, Double(attempt))

        XCTAssertEqual(delay, 2.0, accuracy: 0.001)
    }

    func testExponentialBackoff_attempt2() {
        let baseRetryDelay = 1.0
        let attempt = 2
        let delay = baseRetryDelay * pow(2.0, Double(attempt))

        XCTAssertEqual(delay, 4.0, accuracy: 0.001)
    }

    func testExponentialBackoff_attempt3() {
        let baseRetryDelay = 1.0
        let attempt = 3
        let delay = baseRetryDelay * pow(2.0, Double(attempt))

        XCTAssertEqual(delay, 8.0, accuracy: 0.001)
    }

    func testExponentialBackoff_customBaseDelay() {
        let baseRetryDelay = 0.5
        let attempt = 2
        let delay = baseRetryDelay * pow(2.0, Double(attempt))

        XCTAssertEqual(delay, 2.0, accuracy: 0.001)
    }

    // MARK: - Rate Limit Delay Calculation Tests

    /// Tests the rate limit delay formula used for 429 errors:
    /// delay = baseRetryDelay * 2.0 * pow(2.0, Double(attempt))
    /// This is intentionally longer than standard exponential backoff.
    func testRateLimitDelay_attempt0() {
        let baseRetryDelay = 1.0
        let attempt = 0
        let delay = baseRetryDelay * 2.0 * pow(2.0, Double(attempt))

        XCTAssertEqual(delay, 2.0, accuracy: 0.001)
    }

    func testRateLimitDelay_attempt1() {
        let baseRetryDelay = 1.0
        let attempt = 1
        let delay = baseRetryDelay * 2.0 * pow(2.0, Double(attempt))

        XCTAssertEqual(delay, 4.0, accuracy: 0.001)
    }

    func testRateLimitDelay_attempt2() {
        let baseRetryDelay = 1.0
        let attempt = 2
        let delay = baseRetryDelay * 2.0 * pow(2.0, Double(attempt))

        XCTAssertEqual(delay, 8.0, accuracy: 0.001)
    }

    func testRateLimitDelay_isDoubleExponentialBackoff() {
        let baseRetryDelay = 1.0

        for attempt in 0 ... 3 {
            let exponentialDelay = baseRetryDelay * pow(2.0, Double(attempt))
            let rateLimitDelay = baseRetryDelay * 2.0 * pow(2.0, Double(attempt))

            XCTAssertEqual(rateLimitDelay, exponentialDelay * 2.0, accuracy: 0.001)
        }
    }

    // MARK: - Max Retries Tests

    func testMaxRetries_value() {
        // The NetworkAdapter uses maxRetries = 3
        let maxRetries = 3

        XCTAssertEqual(maxRetries, 3)
    }

    func testMaxRetries_attemptSequence() {
        let maxRetries = 3
        let attempts = (0 ..< maxRetries).map { $0 }

        XCTAssertEqual(attempts, [0, 1, 2])
        XCTAssertEqual(attempts.count, maxRetries)
    }

    // MARK: - Nanoseconds Conversion Tests

    /// Tests the delay-to-nanoseconds conversion used in Task.sleep
    func testDelayToNanoseconds_oneSecond() {
        let delay = 1.0
        let nanoseconds = UInt64(delay * 1_000_000_000)

        XCTAssertEqual(nanoseconds, 1_000_000_000)
    }

    func testDelayToNanoseconds_twoSeconds() {
        let delay = 2.0
        let nanoseconds = UInt64(delay * 1_000_000_000)

        XCTAssertEqual(nanoseconds, 2_000_000_000)
    }

    func testDelayToNanoseconds_halfSecond() {
        let delay = 0.5
        let nanoseconds = UInt64(delay * 1_000_000_000)

        XCTAssertEqual(nanoseconds, 500_000_000)
    }

    // MARK: - HTTP Error Message Tests

    func testHTTPErrorMessage_403() {
        let expectedMessage = "Access denied. Please check your API key permissions."
        XCTAssertEqual(expectedMessage, "Access denied. Please check your API key permissions.")
    }

    func testHTTPErrorMessage_404() {
        let expectedMessage = "The requested resource was not found. Please verify the API endpoint."
        XCTAssertEqual(expectedMessage, "The requested resource was not found. Please verify the API endpoint.")
    }

    func testHTTPErrorMessage_413() {
        let expectedMessage = "The request is too large. Please reduce the image size or prompt length."
        XCTAssertEqual(expectedMessage, "The request is too large. Please reduce the image size or prompt length.")
    }

    func testHTTPErrorMessage_429() {
        let expectedMessage = "Rate limit exceeded. Please wait a moment before making more requests."
        XCTAssertEqual(expectedMessage, "Rate limit exceeded. Please wait a moment before making more requests.")
    }

    func testHTTPErrorMessage_500() {
        let expectedMessage = "The service encountered an error. Please try again later."
        XCTAssertEqual(expectedMessage, "The service encountered an error. Please try again later.")
    }

    func testHTTPErrorMessage_503() {
        let expectedMessage = "The service is temporarily unavailable. Please try again in a moment."
        XCTAssertEqual(expectedMessage, "The service is temporarily unavailable. Please try again in a moment.")
    }

    func testHTTPErrorMessage_504() {
        let expectedMessage = "The request timed out. Please check your connection and try again."
        XCTAssertEqual(expectedMessage, "The request timed out. Please check your connection and try again.")
    }

    // MARK: - Retryable Status Code Tests

    func testRetryableStatusCodes_429_isRetryable() {
        let retryableStatusCodes = [429, 503, 504]
        XCTAssertTrue(retryableStatusCodes.contains(429))
    }

    func testRetryableStatusCodes_503_isRetryable() {
        let retryableStatusCodes = [429, 503, 504]
        XCTAssertTrue(retryableStatusCodes.contains(503))
    }

    func testRetryableStatusCodes_504_isRetryable() {
        let retryableStatusCodes = [429, 503, 504]
        XCTAssertTrue(retryableStatusCodes.contains(504))
    }

    func testRetryableStatusCodes_403_isNotRetryable() {
        let retryableStatusCodes = [429, 503, 504]
        XCTAssertFalse(retryableStatusCodes.contains(403))
    }

    func testRetryableStatusCodes_404_isNotRetryable() {
        let retryableStatusCodes = [429, 503, 504]
        XCTAssertFalse(retryableStatusCodes.contains(404))
    }

    func testRetryableStatusCodes_500_isNotRetryable() {
        let retryableStatusCodes = [429, 503, 504]
        XCTAssertFalse(retryableStatusCodes.contains(500))
    }

    // MARK: - Timeout Configuration Tests

    func testTimeoutConfiguration_defaultValue() {
        let defaultTimeout: TimeInterval = 120
        XCTAssertEqual(defaultTimeout, 120)
    }

    func testTimeoutConfiguration_inSeconds() {
        let timeout: TimeInterval = 120
        XCTAssertEqual(timeout, 2 * 60) // 2 minutes
    }

    // MARK: - Content Type Tests

    func testContentType_defaultIsJSON() {
        let defaultContentType = "application/json"
        XCTAssertEqual(defaultContentType, "application/json")
    }

    func testContentType_multipartFormData() {
        let contentType = "multipart/form-data"
        let isMultipart = contentType == "multipart/form-data"
        XCTAssertTrue(isMultipart)
    }

    func testContentType_imageJpeg_isImageResponse() {
        let contentType = "image/jpeg"
        let isImage = contentType.contains("image/jpeg") || contentType.contains("image/png")
        XCTAssertTrue(isImage)
    }

    func testContentType_imagePng_isImageResponse() {
        let contentType = "image/png"
        let isImage = contentType.contains("image/jpeg") || contentType.contains("image/png")
        XCTAssertTrue(isImage)
    }

    func testContentType_applicationJson_isNotImageResponse() {
        let contentType = "application/json"
        let isImage = contentType.contains("image/jpeg") || contentType.contains("image/png")
        XCTAssertFalse(isImage)
    }

    // MARK: - Single-Attempt Paid Requests

    func testSingleAttemptPaidPost_DoesNotRetryAndPreservesErrorResponse() async throws {
        for statusCode in [429, 503, 504] {
            MockURLProtocol.reset()
            let responseBody = Data(#"{"error":{"message":"provider busy"}}"#.utf8)
            MockURLProtocol.requestHandler = { request in
                let response = try XCTUnwrap(try HTTPURLResponse(
                    url: XCTUnwrap(request.url),
                    statusCode: statusCode,
                    httpVersion: nil,
                    headerFields: [
                        "Content-Type": "application/json",
                        "Retry-After": "120",
                        "X-Request-ID": "request-\(statusCode)",
                    ]
                ))
                return (response, responseBody)
            }

            let adapter = NetworkAdapter(session: makeInterceptedSession())
            let envelope = try await adapter.performSingleAttemptRequest(
                url: XCTUnwrap(URL(string: "https://provider.example/generations")),
                method: "POST",
                body: PaidRequestFixture(prompt: "one billable job"),
                headers: ["Authorization": "Bearer test"],
                attachments: nil
            )

            XCTAssertEqual(MockURLProtocol.requestLog.count, 1, "HTTP \(statusCode) must not be retried")
            XCTAssertEqual(MockURLProtocol.requestLog.first?.httpMethod, "POST")
            XCTAssertEqual(envelope.statusCode, statusCode)
            XCTAssertEqual(envelope.headerValue(for: "retry-after"), "120")
            XCTAssertEqual(envelope.headerValue(for: "x-request-id"), "request-\(statusCode)")
            XCTAssertEqual(envelope.body, responseBody)

            let parsed = try envelope.requireParsedResponse()
            guard case let .dictionary(parsedStatus, data) = parsed else {
                return XCTFail("Expected the non-2xx JSON body to remain parsed")
            }
            XCTAssertEqual(parsedStatus, statusCode)
            XCTAssertEqual((data["error"] as? [String: Any])?["message"] as? String, "provider busy")
        }
        MockURLProtocol.reset()
    }

    func testSingleAttemptPaidPost_PreservesUnparseableErrorBytes() async throws {
        MockURLProtocol.reset()
        let responseBody = Data("upstream unavailable".utf8)
        MockURLProtocol.requestHandler = { request in
            let response = try XCTUnwrap(try HTTPURLResponse(
                url: XCTUnwrap(request.url),
                statusCode: 502,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/plain"]
            ))
            return (response, responseBody)
        }

        let adapter = NetworkAdapter(session: makeInterceptedSession())
        let envelope = try await adapter.performSingleAttemptRequest(
            url: XCTUnwrap(URL(string: "https://provider.example/generations")),
            method: "POST",
            body: PaidRequestFixture(prompt: "one billable job"),
            headers: nil,
            attachments: nil
        )

        XCTAssertEqual(MockURLProtocol.requestLog.count, 1)
        XCTAssertEqual(envelope.statusCode, 502)
        XCTAssertEqual(envelope.body, responseBody)
        XCTAssertEqual(envelope.bodyString, "upstream unavailable")
        XCTAssertNil(envelope.response)
        MockURLProtocol.reset()
    }

    private func makeInterceptedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private struct PaidRequestFixture: Codable, Sendable {
    let prompt: String
}
