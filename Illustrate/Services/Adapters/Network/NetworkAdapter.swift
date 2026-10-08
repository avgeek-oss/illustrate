// MARK: - NetworkAdapter.swift

// Core HTTP networking layer for all API communications.
//
// NetworkAdapter provides a unified interface for making HTTP requests to
// AI provider APIs. It handles JSON and multipart requests, generates
// and normalizes responses.
//
// ## Features
// - JSON and multipart/form-data request bodies
// - Binary image response handling
// - Configurable timeout (600 seconds default)
// - HTTP error code handling
// - Automatic retry with exponential backoff for transient failures (429, 503, 504)
//
// ## Response Types
// - `.dictionary`: JSON object response
// - `.array`: JSON array response
// - `.image`: Binary image response (base64 encoded)

import AvgeekNetworking
import Foundation
import IllustrateProviders
import OSLog

/// Singleton HTTP client for AI provider API requests.
///
/// Provides `performRequest()` for making HTTP calls with automatic
/// response parsing and retry logic for transient failures.
class NetworkAdapter {
    /// Shared singleton instance
    static let shared = NetworkAdapter()

    /// Maximum number of retry attempts for retryable errors
    private let maxRetries: Int

    private let transport: any HTTPTransport
    private let retryScheduler: RetryScheduler
    private let retryDelays: RetryDelayPolicy

    private static func makeSession() -> URLSession {
        let configuration = HTTPSessionConfiguration.make(options: HTTPSessionOptions(
            storagePolicy: .ephemeral,
            requestTimeout: 600,
            maximumConnectionsPerHost: 6
        ))
        return URLSession(configuration: configuration)
    }

    private convenience init() {
        self.init(session: Self.makeSession())
    }

    /// Internal initializer used by deterministic URLProtocol-backed tests.
    init(
        session: URLSession,
        maxRetries: Int = 3,
        baseRetryDelay: TimeInterval = 1.0
    ) {
        transport = session
        self.maxRetries = maxRetries
        retryScheduler = .live
        retryDelays = RetryDelayPolicy(
            baseDelay: baseRetryDelay,
            multiplier: 2,
            maximumBackoffDelay: 60,
            maximumServerDelay: 60
        )
    }

    /// Internal initializer for deterministic transport and retry contract tests.
    init(
        transport: any HTTPTransport,
        maxRetries: Int = 3,
        baseRetryDelay: TimeInterval = 1.0,
        retryScheduler: RetryScheduler
    ) {
        self.transport = transport
        self.maxRetries = maxRetries
        self.retryScheduler = retryScheduler
        retryDelays = RetryDelayPolicy(
            baseDelay: baseRetryDelay,
            multiplier: 2,
            maximumBackoffDelay: 60,
            maximumServerDelay: 60
        )
    }

    /// Performs an HTTP request with automatic retry logic for transient failures.
    ///
    /// Retries are automatically performed for:
    /// - 429 (Too Many Requests) - with exponential backoff
    /// - 503 (Service Unavailable) - with exponential backoff
    /// - 504 (Gateway Timeout) - with exponential backoff
    ///
    /// - Parameters:
    ///   - url: The request URL
    ///   - method: HTTP method (GET, POST, etc.)
    ///   - body: Optional request body (must conform to Codable)
    ///   - headers: Optional HTTP headers
    ///   - attachments: Optional file attachments for multipart requests
    /// - Returns: NetworkResponseData containing the parsed response
    /// - Throws: Network errors or errors after max retries
    func performRequest(
        url: URL,
        method: String,
        body: (some Codable)?,
        headers: [String: String]? = nil,
        attachments: [NetworkRequestAttachment]? = nil
    ) async throws -> NetworkResponseData {
        try await performRequestWithRetry(
            url: url,
            method: method,
            body: body,
            headers: headers,
            attachments: attachments,
            attempt: 0
        )
    }

    /// Performs one URLSession operation without application-level retry or
    /// throwing for HTTP status codes. The complete response is retained so
    /// provider adapters can parse non-2xx error payloads without risking an
    /// explicit duplicate billable operation.
    func performSingleAttemptRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]? = nil,
        attachments: [NetworkRequestAttachment]? = nil
    ) async throws -> NetworkResponseEnvelope {
        AppLogger.network.debug(
            "Single-attempt request: \(method, privacy: .public) \(url.absoluteString, privacy: .public)"
        )

        let request = try makeRequest(
            url: url,
            method: method,
            body: body,
            headers: headers,
            attachments: attachments
        )
        let (data, response) = try await transport.send(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Invalid Response", code: -1, userInfo: nil)
        }

        let responseHeaders = HTTPHeaders(httpResponse.allHeaderFields).dictionary
        return NetworkResponseEnvelope(
            statusCode: httpResponse.statusCode,
            headers: responseHeaders,
            body: data,
            response: parsedResponse(data: data, response: httpResponse)
        )
    }

    /// Performs a request whose headers and body bytes have already been built.
    /// This path is used by signature-sensitive and form-encoded provider APIs.
    func performRawRequest(_ request: URLRequest) async throws -> NetworkResponseData {
        let redactedRequest = RedactedHTTPRequest(request: request)
        AppLogger.network.debug(
            "Raw request: \(redactedRequest.description, privacy: .public)"
        )

        let (data, response) = try await transport.send(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Invalid Response", code: -1, userInfo: nil)
        }

        if let httpError = HTTPError.from(statusCode: httpResponse.statusCode) {
            throw httpError.toNSError()
        }

        if data.isEmpty {
            return .dictionary(statusCode: httpResponse.statusCode, data: [:])
        }

        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
           contentType.contains("image/jpeg") || contentType.contains("image/png")
        {
            return .image(
                statusCode: httpResponse.statusCode,
                base64: data.base64EncodedString(),
                mimeType: contentType
            )
        }

        let json = try JSONSerialization.jsonObject(with: data)
        if let dictionary = json as? [String: Any] {
            return .dictionary(statusCode: httpResponse.statusCode, data: dictionary)
        }
        if let array = json as? [[String: Any]] {
            return .array(statusCode: httpResponse.statusCode, data: array)
        }
        throw NSError(domain: "Invalid JSON", code: httpResponse.statusCode, userInfo: nil)
    }

    /// Downloads response bytes without attempting JSON or image decoding.
    /// Safe GET/HEAD requests retain the existing retry behavior and honor a
    /// numeric Retry-After header when providers return transient failures.
    func performDataRequest(_ request: URLRequest) async throws -> NetworkDataResponse {
        try await performDataRequestWithRetry(request, attempt: 0)
    }

    private func performDataRequestWithRetry(
        _ request: URLRequest,
        attempt: Int
    ) async throws -> NetworkDataResponse {
        let redactedRequest = RedactedHTTPRequest(request: request)
        AppLogger.network.debug(
            "Data request: \(redactedRequest.description, privacy: .public)"
        )

        let (data, response) = try await transport.send(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Invalid Response", code: -1, userInfo: nil)
        }

        if let httpError = HTTPError.from(statusCode: httpResponse.statusCode) {
            let method = HTTPMethod(request.httpMethod)
            let canRetry = method == .get || method == .head
            if httpError.isRetryable, canRetry, attempt < maxRetries {
                let retryAfter = ServerRetryDelay.parse(
                    headers: HTTPHeaders(httpResponse.allHeaderFields),
                    now: retryScheduler.now()
                )
                let delay = retryDelays.delay(
                    retryNumber: attempt,
                    delayMultiplier: httpError.retryDelayMultiplier,
                    serverSuggestedDelay: retryAfter
                )
                try await retryScheduler.sleep(delay)
                return try await performDataRequestWithRetry(request, attempt: attempt + 1)
            }
            throw httpError.toNSError()
        }

        return NetworkDataResponse(
            statusCode: httpResponse.statusCode,
            data: data,
            headers: HTTPHeaders(httpResponse.allHeaderFields).dictionary
        )
    }

    static func retryDelayNanoseconds(
        retryAfter: TimeInterval?,
        exponential: TimeInterval
    ) -> UInt64 {
        RetryDelayPolicy(
            baseDelay: exponential,
            multiplier: 1,
            maximumBackoffDelay: 60,
            maximumServerDelay: 60
        ).nanoseconds(retryNumber: 0, serverSuggestedDelay: retryAfter)
    }

    /// Internal method that implements retry logic with exponential backoff.
    private func performRequestWithRetry(
        url: URL,
        method: String,
        body: (some Codable)?,
        headers: [String: String]?,
        attachments: [NetworkRequestAttachment]?,
        attempt: Int
    ) async throws -> NetworkResponseData {
        let redactedRequest = RedactedHTTPRequest(method: HTTPMethod(method), url: url)
        AppLogger.network.debug("Request: \(redactedRequest.description, privacy: .public)")

        let request = try makeRequest(
            url: url,
            method: method,
            body: body,
            headers: headers,
            attachments: attachments
        )

        let (data, response) = try await transport.send(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            AppLogger.network.error("Invalid response type received")
            throw NSError(domain: "Invalid Response", code: -1, userInfo: nil)
        }

        AppLogger.network
            .debug("Response: \(httpResponse.statusCode, privacy: .public) - \(data.count, privacy: .public) bytes")

        // Handle HTTP errors using centralized HTTPError enum
        if let httpError = HTTPError.from(statusCode: httpResponse.statusCode) {
            let responseBodyForLogging: () -> String = {
                let body = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                return String(body.prefix(1000))
            }

            AppLogger.network
                .error(
                    "\(httpError.logDescription, privacy: .public): \(url.absoluteString, privacy: .public) - body: \(responseBodyForLogging(), privacy: .private)"
                )

            // Handle retryable errors with exponential backoff
            if httpError.isRetryable, attempt < maxRetries {
                let delay = retryDelays.exponentialDelay(
                    retryNumber: attempt,
                    delayMultiplier: httpError.retryDelayMultiplier
                )
                let maxRetriesLog = maxRetries
                AppLogger.network
                    .info(
                        "Retrying after \(delay, privacy: .public)s (attempt \(attempt + 1, privacy: .public)/\(maxRetriesLog, privacy: .public))"
                    )
                try await retryScheduler.sleep(delay)
                return try await performRequestWithRetry(
                    url: url,
                    method: method,
                    body: body,
                    headers: headers,
                    attachments: attachments,
                    attempt: attempt + 1
                )
            }

            throw httpError.toNSError()
        }

        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") {
            if contentType.contains("image/jpeg") || contentType.contains("image/png") {
                let base64String = data.base64EncodedString()
                AppLogger.network.info("Received image response: \(contentType, privacy: .public)")
                return .image(
                    statusCode: httpResponse.statusCode,
                    base64: base64String,
                    mimeType: contentType
                )
            }
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])

            if let dict = json as? [String: Any] {
                return .dictionary(
                    statusCode: httpResponse.statusCode,
                    data: dict
                )
            } else if let array = json as? [[String: Any]] {
                return .array(
                    statusCode: httpResponse.statusCode,
                    data: array
                )
            } else {
                AppLogger.network.error("Invalid JSON structure in response")
                throw NSError(domain: "Invalid JSON", code: -1, userInfo: nil)
            }
        } catch {
            if let responseString = String(data: data, encoding: .utf8) {
                let truncated = String(responseString.prefix(500))
                AppLogger.network
                    .error(
                        "Failed to parse response (status \(httpResponse.statusCode, privacy: .public)): \(truncated, privacy: .public)"
                    )
                throw NSError(
                    domain: "Failed to parse response: \(truncated)",
                    code: httpResponse.statusCode,
                    userInfo: nil
                )
            }
            AppLogger.network.error("Failed to parse response: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    private func makeRequest(
        url: URL,
        method: String,
        body: (some Codable)?,
        headers: [String: String]?,
        attachments: [NetworkRequestAttachment]?
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method

        if let headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        let isMultipart = request.value(forHTTPHeaderField: "Content-Type") == "multipart/form-data"
        if request.httpMethod?.uppercased() != "GET", let body {
            if isMultipart {
                let boundary = UUID().uuidString
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                let multipartBody = try createMultipartBody(
                    from: body,
                    boundary: boundary,
                    attachments: attachments
                )
                request.httpBody = multipartBody
                AppLogger.network.debug("Multipart body size: \(multipartBody.count, privacy: .public) bytes")
            } else {
                do {
                    request.httpBody = try JSONEncoder().encode(body)
                } catch {
                    AppLogger.network
                        .error("Failed to encode request body: \(error.localizedDescription, privacy: .public)")
                    throw error
                }
            }
        }

        if request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func parsedResponse(
        data: Data,
        response: HTTPURLResponse
    ) -> NetworkResponseData? {
        if data.isEmpty {
            return .dictionary(statusCode: response.statusCode, data: [:])
        }

        if let contentType = response.value(forHTTPHeaderField: "Content-Type"),
           contentType.contains("image/jpeg") || contentType.contains("image/png")
        {
            return .image(
                statusCode: response.statusCode,
                base64: data.base64EncodedString(),
                mimeType: contentType
            )
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        if let dictionary = json as? [String: Any] {
            return .dictionary(statusCode: response.statusCode, data: dictionary)
        }
        if let array = json as? [[String: Any]] {
            return .array(statusCode: response.statusCode, data: array)
        }
        return nil
    }

    private func createMultipartBody(
        from body: some Codable,
        boundary: String,
        attachments: [NetworkRequestAttachment]?
    ) throws -> Data {
        var bodyData = Data()
        let mirror = Mirror(reflecting: body)

        for child in mirror.children {
            guard let key = child.label else { continue }

            let unwrappedValue = unwrapOptional(child.value)

            if let value = unwrappedValue as? String {
                bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
                bodyData.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                bodyData.append("\(value)\r\n".data(using: .utf8)!)
            } else if let value = unwrappedValue as? Int {
                bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
                bodyData.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                bodyData.append("\(String(value))\r\n".data(using: .utf8)!)
            } else if let value = unwrappedValue as? Double {
                bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
                bodyData.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                bodyData.append("\(String(value))\r\n".data(using: .utf8)!)
            } else if let value = unwrappedValue as? Bool {
                bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
                bodyData.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                bodyData.append("\(String(value))\r\n".data(using: .utf8)!)
            }
        }

        if let attachments {
            for attachment in attachments {
                bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
                bodyData
                    .append(
                        "Content-Disposition: form-data; name=\"\(attachment.name)\"; filename=\"\(attachment.name)\"\r\n"
                            .data(using: .utf8)!
                    )
                bodyData.append("Content-Type: \(attachment.mimeType)\r\n\r\n".data(using: .utf8)!)
                bodyData.append(attachment.data)
                bodyData.append("\r\n".data(using: .utf8)!)
            }
        }

        bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return bodyData
    }

    private func unwrapOptional(_ value: Any) -> Any? {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            if let child = mirror.children.first {
                return child.value
            }
            return nil
        }
        return value
    }
}
