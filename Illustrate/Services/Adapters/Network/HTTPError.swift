// MARK: - HTTPError.swift

// Centralized HTTP error handling for API requests.
//
// This enum provides a type-safe way to handle HTTP errors with:
// - User-friendly error messages
// - Retry logic configuration
// - NSError conversion for compatibility

import Foundation

/// HTTP error codes with associated user-friendly messages and retry behavior.
///
/// ## Retryable Errors
/// - `TOO_MANY_REQUESTS` (429): Rate limited, uses 2x delay multiplier
/// - `SERVICE_UNAVAILABLE` (503): Server temporarily down
/// - `GATEWAY_TIMEOUT` (504): Request timed out upstream
///
/// ## Non-Retryable Errors
/// - `FORBIDDEN` (403): Permission denied
/// - `NOT_FOUND` (404): Resource doesn't exist
/// - `PAYLOAD_TOO_LARGE` (413): Request body too large
/// - `INTERNAL_SERVER_ERROR` (500): Server-side failure
enum HTTPError: Int, Error {
    case FORBIDDEN = 403
    case NOT_FOUND = 404
    case PAYLOAD_TOO_LARGE = 413
    case TOO_MANY_REQUESTS = 429
    case INTERNAL_SERVER_ERROR = 500
    case SERVICE_UNAVAILABLE = 503
    case GATEWAY_TIMEOUT = 504

    /// User-friendly error description suitable for display in UI.
    var errorDescription: String {
        switch self {
        case .FORBIDDEN:
            AppLocalization.string("Access denied. Please check your API key permissions.")
        case .NOT_FOUND:
            AppLocalization.string("The requested resource was not found. Please verify the API endpoint.")
        case .PAYLOAD_TOO_LARGE:
            AppLocalization.string("The request is too large. Please reduce the image size or prompt length.")
        case .TOO_MANY_REQUESTS:
            AppLocalization.string("Rate limit exceeded. Please wait a moment before making more requests.")
        case .INTERNAL_SERVER_ERROR:
            AppLocalization.string("The service encountered an error. Please try again later.")
        case .SERVICE_UNAVAILABLE:
            AppLocalization.string("The service is temporarily unavailable. Please try again in a moment.")
        case .GATEWAY_TIMEOUT:
            AppLocalization.string("The request timed out. Please check your connection and try again.")
        }
    }

    /// Short log-friendly description of the HTTP error.
    var logDescription: String {
        switch self {
        case .FORBIDDEN:
            "HTTP 403 Forbidden"
        case .NOT_FOUND:
            "HTTP 404 Not Found"
        case .PAYLOAD_TOO_LARGE:
            "HTTP 413 Payload Too Large"
        case .TOO_MANY_REQUESTS:
            "HTTP 429 Too Many Requests"
        case .INTERNAL_SERVER_ERROR:
            "HTTP 500 Internal Server Error"
        case .SERVICE_UNAVAILABLE:
            "HTTP 503 Service Unavailable"
        case .GATEWAY_TIMEOUT:
            "HTTP 504 Gateway Timeout"
        }
    }

    /// Whether this error type supports automatic retry with backoff.
    var isRetryable: Bool {
        switch self {
        case .TOO_MANY_REQUESTS, .SERVICE_UNAVAILABLE, .GATEWAY_TIMEOUT:
            true
        case .FORBIDDEN, .NOT_FOUND, .PAYLOAD_TOO_LARGE, .INTERNAL_SERVER_ERROR:
            false
        }
    }

    /// Multiplier for exponential backoff delay.
    ///
    /// Rate limit errors (429) use a higher multiplier to avoid
    /// hitting the limit again immediately.
    var retryDelayMultiplier: Double {
        switch self {
        case .TOO_MANY_REQUESTS:
            2.0 // Longer delay for rate limits
        case .SERVICE_UNAVAILABLE, .GATEWAY_TIMEOUT:
            1.0
        case .FORBIDDEN, .NOT_FOUND, .PAYLOAD_TOO_LARGE, .INTERNAL_SERVER_ERROR:
            0.0 // Not retryable
        }
    }

    /// Converts to NSError for compatibility with existing error handling.
    ///
    /// Uses "API Error" domain to match existing error patterns.
    func toNSError() -> NSError {
        NSError(
            domain: "API Error",
            code: rawValue,
            userInfo: [NSLocalizedDescriptionKey: errorDescription]
        )
    }

    /// Creates an HTTPError from an HTTP status code, if it's a known error.
    ///
    /// - Parameter statusCode: The HTTP status code from the response
    /// - Returns: The corresponding HTTPError, or nil if the code isn't handled
    static func from(statusCode: Int) -> HTTPError? {
        HTTPError(rawValue: statusCode)
    }
}
