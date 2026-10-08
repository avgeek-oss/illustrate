// MARK: - HTTPErrorTests.swift

// Unit tests for HTTPError enum.
//
// Tests cover:
// - All status code mappings
// - User-friendly error descriptions
// - Retry configuration (isRetryable, retryDelayMultiplier)
// - NSError conversion
// - Factory method behavior

import XCTest
@testable import Illustrate

final class HTTPErrorTests: XCTestCase {
    // MARK: - Raw Value Tests

    func testRawValue_FORBIDDEN() {
        XCTAssertEqual(HTTPError.FORBIDDEN.rawValue, 403)
    }

    func testRawValue_NOT_FOUND() {
        XCTAssertEqual(HTTPError.NOT_FOUND.rawValue, 404)
    }

    func testRawValue_PAYLOAD_TOO_LARGE() {
        XCTAssertEqual(HTTPError.PAYLOAD_TOO_LARGE.rawValue, 413)
    }

    func testRawValue_TOO_MANY_REQUESTS() {
        XCTAssertEqual(HTTPError.TOO_MANY_REQUESTS.rawValue, 429)
    }

    func testRawValue_INTERNAL_SERVER_ERROR() {
        XCTAssertEqual(HTTPError.INTERNAL_SERVER_ERROR.rawValue, 500)
    }

    func testRawValue_SERVICE_UNAVAILABLE() {
        XCTAssertEqual(HTTPError.SERVICE_UNAVAILABLE.rawValue, 503)
    }

    func testRawValue_GATEWAY_TIMEOUT() {
        XCTAssertEqual(HTTPError.GATEWAY_TIMEOUT.rawValue, 504)
    }

    // MARK: - Error Description Tests

    func testErrorDescription_FORBIDDEN_containsPermissions() {
        let description = HTTPError.FORBIDDEN.errorDescription
        XCTAssertTrue(description.contains("Access denied"))
        XCTAssertTrue(description.contains("API key"))
    }

    func testErrorDescription_NOT_FOUND_containsEndpoint() {
        let description = HTTPError.NOT_FOUND.errorDescription
        XCTAssertTrue(description.contains("not found"))
        XCTAssertTrue(description.contains("endpoint"))
    }

    func testErrorDescription_PAYLOAD_TOO_LARGE_containsSize() {
        let description = HTTPError.PAYLOAD_TOO_LARGE.errorDescription
        XCTAssertTrue(description.contains("too large"))
        XCTAssertTrue(description.contains("reduce"))
    }

    func testErrorDescription_TOO_MANY_REQUESTS_containsRateLimit() {
        let description = HTTPError.TOO_MANY_REQUESTS.errorDescription
        XCTAssertTrue(description.contains("Rate limit"))
        XCTAssertTrue(description.contains("wait"))
    }

    func testErrorDescription_INTERNAL_SERVER_ERROR_containsServerError() {
        let description = HTTPError.INTERNAL_SERVER_ERROR.errorDescription
        XCTAssertTrue(description.contains("service"))
        XCTAssertTrue(description.contains("error"))
    }

    func testErrorDescription_SERVICE_UNAVAILABLE_containsTemporary() {
        let description = HTTPError.SERVICE_UNAVAILABLE.errorDescription
        XCTAssertTrue(description.contains("temporarily unavailable"))
    }

    func testErrorDescription_GATEWAY_TIMEOUT_containsTimeout() {
        let description = HTTPError.GATEWAY_TIMEOUT.errorDescription
        XCTAssertTrue(description.contains("timed out"))
        XCTAssertTrue(description.contains("connection"))
    }

    // MARK: - Log Description Tests

    func testLogDescription_FORBIDDEN() {
        XCTAssertEqual(HTTPError.FORBIDDEN.logDescription, "HTTP 403 Forbidden")
    }

    func testLogDescription_NOT_FOUND() {
        XCTAssertEqual(HTTPError.NOT_FOUND.logDescription, "HTTP 404 Not Found")
    }

    func testLogDescription_PAYLOAD_TOO_LARGE() {
        XCTAssertEqual(HTTPError.PAYLOAD_TOO_LARGE.logDescription, "HTTP 413 Payload Too Large")
    }

    func testLogDescription_TOO_MANY_REQUESTS() {
        XCTAssertEqual(HTTPError.TOO_MANY_REQUESTS.logDescription, "HTTP 429 Too Many Requests")
    }

    func testLogDescription_INTERNAL_SERVER_ERROR() {
        XCTAssertEqual(HTTPError.INTERNAL_SERVER_ERROR.logDescription, "HTTP 500 Internal Server Error")
    }

    func testLogDescription_SERVICE_UNAVAILABLE() {
        XCTAssertEqual(HTTPError.SERVICE_UNAVAILABLE.logDescription, "HTTP 503 Service Unavailable")
    }

    func testLogDescription_GATEWAY_TIMEOUT() {
        XCTAssertEqual(HTTPError.GATEWAY_TIMEOUT.logDescription, "HTTP 504 Gateway Timeout")
    }

    // MARK: - Retry Configuration Tests

    func testIsRetryable_retryableErrors() {
        XCTAssertTrue(HTTPError.TOO_MANY_REQUESTS.isRetryable)
        XCTAssertTrue(HTTPError.SERVICE_UNAVAILABLE.isRetryable)
        XCTAssertTrue(HTTPError.GATEWAY_TIMEOUT.isRetryable)
    }

    func testIsRetryable_nonRetryableErrors() {
        XCTAssertFalse(HTTPError.FORBIDDEN.isRetryable)
        XCTAssertFalse(HTTPError.NOT_FOUND.isRetryable)
        XCTAssertFalse(HTTPError.PAYLOAD_TOO_LARGE.isRetryable)
        XCTAssertFalse(HTTPError.INTERNAL_SERVER_ERROR.isRetryable)
    }

    func testRetryDelayMultiplier_TOO_MANY_REQUESTS_hasDoubleMultiplier() {
        XCTAssertEqual(HTTPError.TOO_MANY_REQUESTS.retryDelayMultiplier, 2.0)
    }

    func testRetryDelayMultiplier_SERVICE_UNAVAILABLE_hasStandardMultiplier() {
        XCTAssertEqual(HTTPError.SERVICE_UNAVAILABLE.retryDelayMultiplier, 1.0)
    }

    func testRetryDelayMultiplier_GATEWAY_TIMEOUT_hasStandardMultiplier() {
        XCTAssertEqual(HTTPError.GATEWAY_TIMEOUT.retryDelayMultiplier, 1.0)
    }

    func testRetryDelayMultiplier_nonRetryableErrors_haveZeroMultiplier() {
        XCTAssertEqual(HTTPError.FORBIDDEN.retryDelayMultiplier, 0.0)
        XCTAssertEqual(HTTPError.NOT_FOUND.retryDelayMultiplier, 0.0)
        XCTAssertEqual(HTTPError.PAYLOAD_TOO_LARGE.retryDelayMultiplier, 0.0)
        XCTAssertEqual(HTTPError.INTERNAL_SERVER_ERROR.retryDelayMultiplier, 0.0)
    }

    // MARK: - NSError Conversion Tests

    func testToNSError_domain() {
        let nsError = HTTPError.FORBIDDEN.toNSError()
        XCTAssertEqual(nsError.domain, "API Error")
    }

    func testToNSError_code_matchesRawValue() {
        XCTAssertEqual(HTTPError.FORBIDDEN.toNSError().code, 403)
        XCTAssertEqual(HTTPError.NOT_FOUND.toNSError().code, 404)
        XCTAssertEqual(HTTPError.PAYLOAD_TOO_LARGE.toNSError().code, 413)
        XCTAssertEqual(HTTPError.TOO_MANY_REQUESTS.toNSError().code, 429)
        XCTAssertEqual(HTTPError.INTERNAL_SERVER_ERROR.toNSError().code, 500)
        XCTAssertEqual(HTTPError.SERVICE_UNAVAILABLE.toNSError().code, 503)
        XCTAssertEqual(HTTPError.GATEWAY_TIMEOUT.toNSError().code, 504)
    }

    func testToNSError_localizedDescription_matchesErrorDescription() {
        for error in [
            HTTPError.FORBIDDEN,
            .NOT_FOUND,
            .PAYLOAD_TOO_LARGE,
            .TOO_MANY_REQUESTS,
            .INTERNAL_SERVER_ERROR,
            .SERVICE_UNAVAILABLE,
            .GATEWAY_TIMEOUT,
        ] {
            let nsError = error.toNSError()
            XCTAssertEqual(nsError.localizedDescription, error.errorDescription)
        }
    }

    // MARK: - Factory Method Tests

    func testFrom_validStatusCodes_returnCorrectError() {
        XCTAssertEqual(HTTPError.from(statusCode: 403), .FORBIDDEN)
        XCTAssertEqual(HTTPError.from(statusCode: 404), .NOT_FOUND)
        XCTAssertEqual(HTTPError.from(statusCode: 413), .PAYLOAD_TOO_LARGE)
        XCTAssertEqual(HTTPError.from(statusCode: 429), .TOO_MANY_REQUESTS)
        XCTAssertEqual(HTTPError.from(statusCode: 500), .INTERNAL_SERVER_ERROR)
        XCTAssertEqual(HTTPError.from(statusCode: 503), .SERVICE_UNAVAILABLE)
        XCTAssertEqual(HTTPError.from(statusCode: 504), .GATEWAY_TIMEOUT)
    }

    func testFrom_unknownStatusCodes_returnsNil() {
        XCTAssertNil(HTTPError.from(statusCode: 200))
        XCTAssertNil(HTTPError.from(statusCode: 201))
        XCTAssertNil(HTTPError.from(statusCode: 400))
        XCTAssertNil(HTTPError.from(statusCode: 401))
        XCTAssertNil(HTTPError.from(statusCode: 502))
        XCTAssertNil(HTTPError.from(statusCode: 0))
        XCTAssertNil(HTTPError.from(statusCode: -1))
    }

    func testFrom_negativeStatusCode_returnsNil() {
        XCTAssertNil(HTTPError.from(statusCode: -403))
    }

    // MARK: - Error Protocol Conformance Tests

    func testErrorConformance_canBeThrownAndCaught() {
        func throwError() throws {
            throw HTTPError.FORBIDDEN
        }

        XCTAssertThrowsError(try throwError()) { error in
            XCTAssertTrue(error is HTTPError)
            XCTAssertEqual(error as? HTTPError, .FORBIDDEN)
        }
    }

    func testErrorConformance_canBeUsedInDoTryCatch() {
        var caughtError: HTTPError?

        do {
            throw HTTPError.TOO_MANY_REQUESTS
        } catch let error as HTTPError {
            caughtError = error
        } catch {
            XCTFail("Expected HTTPError but got \(error)")
        }

        XCTAssertEqual(caughtError, .TOO_MANY_REQUESTS)
    }

    // MARK: - Retry Logic Integration Tests

    func testRetryLogic_calculatesCorrectDelay() {
        let baseDelay: TimeInterval = 1.0

        // Standard retryable error (503, 504): delay = base * 2^attempt
        let serviceUnavailableDelay0 = baseDelay * HTTPError.SERVICE_UNAVAILABLE.retryDelayMultiplier * pow(2.0, 0)
        let serviceUnavailableDelay1 = baseDelay * HTTPError.SERVICE_UNAVAILABLE.retryDelayMultiplier * pow(2.0, 1)
        let serviceUnavailableDelay2 = baseDelay * HTTPError.SERVICE_UNAVAILABLE.retryDelayMultiplier * pow(2.0, 2)

        XCTAssertEqual(serviceUnavailableDelay0, 1.0)
        XCTAssertEqual(serviceUnavailableDelay1, 2.0)
        XCTAssertEqual(serviceUnavailableDelay2, 4.0)

        // Rate limit error (429): delay = base * multiplier * 2^attempt
        let rateLimitDelay0 = baseDelay * HTTPError.TOO_MANY_REQUESTS.retryDelayMultiplier * pow(2.0, 0)
        let rateLimitDelay1 = baseDelay * HTTPError.TOO_MANY_REQUESTS.retryDelayMultiplier * pow(2.0, 1)
        let rateLimitDelay2 = baseDelay * HTTPError.TOO_MANY_REQUESTS.retryDelayMultiplier * pow(2.0, 2)

        XCTAssertEqual(rateLimitDelay0, 2.0) // 2x base delay
        XCTAssertEqual(rateLimitDelay1, 4.0)
        XCTAssertEqual(rateLimitDelay2, 8.0)
    }

    // MARK: - Sendable Conformance Tests

    func testSendable_canBeSentAcrossConcurrencyBoundaries() async {
        let error = HTTPError.FORBIDDEN

        // Test that it can be captured in a Task (requires Sendable)
        let result = await Task {
            error.rawValue
        }.value

        XCTAssertEqual(result, 403)
    }
}
