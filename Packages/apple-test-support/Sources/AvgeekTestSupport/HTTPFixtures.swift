import Foundation

/// Product-neutral values for constructing a URL request in tests.
public struct HTTPRequestFixture: Equatable, Sendable {
    public static let defaultURL = URL(string: "https://example.invalid/")!

    public let url: URL
    public let method: String
    public let headers: [String: String]
    public let body: Data?

    public init(
        url: URL = Self.defaultURL,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }

    public var request: URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        return request
    }

    public static func json(
        url: URL = Self.defaultURL,
        method: String = "POST",
        headers: [String: String] = [:],
        body: some Encodable,
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> Self {
        try Self(
            url: url,
            method: method,
            headers: headers.addingJSONContentTypeIfNeeded(),
            body: encoder.encode(body)
        )
    }
}

/// Product-neutral values for constructing an HTTP response in tests.
public struct HTTPResponseFixture: Equatable, Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data
    public let url: URL?
    public let httpVersion: String?

    public init(
        statusCode: Int = 200,
        headers: [String: String] = [:],
        body: Data = Data(),
        url: URL? = nil,
        httpVersion: String? = "HTTP/1.1"
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.url = url
        self.httpVersion = httpVersion
    }

    public init(
        statusCode: Int = 200,
        headers: [String: String] = [:],
        body: String,
        url: URL? = nil,
        httpVersion: String? = "HTTP/1.1"
    ) {
        self.init(
            statusCode: statusCode,
            headers: headers,
            body: Data(body.utf8),
            url: url,
            httpVersion: httpVersion
        )
    }

    public func response(for request: URLRequest? = nil) throws -> HTTPURLResponse {
        guard let responseURL = url ?? request?.url else {
            throw HTTPFixtureError.missingResponseURL
        }
        guard let response = HTTPURLResponse(
            url: responseURL,
            statusCode: statusCode,
            httpVersion: httpVersion,
            headerFields: headers
        ) else {
            throw HTTPFixtureError.invalidResponse(statusCode: statusCode, url: responseURL)
        }
        return response
    }

    public static func json(
        statusCode: Int = 200,
        headers: [String: String] = [:],
        body: some Encodable,
        url: URL? = nil,
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> Self {
        try Self(
            statusCode: statusCode,
            headers: headers.addingJSONContentTypeIfNeeded(),
            body: encoder.encode(body),
            url: url
        )
    }
}

public enum HTTPFixtureError: Error, Equatable, Sendable {
    case missingResponseURL
    case invalidResponse(statusCode: Int, url: URL)
}

private extension [String: String] {
    func addingJSONContentTypeIfNeeded() -> Self {
        guard !keys.contains(where: { $0.caseInsensitiveCompare("Content-Type") == .orderedSame }) else {
            return self
        }
        var copy = self
        copy["Content-Type"] = "application/json"
        return copy
    }
}
