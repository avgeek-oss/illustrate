import AvgeekNetworking
import Foundation

/// An actor-isolated transport that records requests before invoking its handler.
public actor RecordingHTTPTransport: HTTPTransport {
    public typealias Handler = @Sendable (URLRequest, Int) async throws -> (Data, URLResponse)

    private let handler: Handler
    private var requests: [URLRequest] = []

    public init(handler: @escaping Handler) {
        self.handler = handler
    }

    public init(response fixture: HTTPResponseFixture) {
        handler = { request, _ in
            try (fixture.body, fixture.response(for: request))
        }
    }

    public func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let index = requests.count
        requests.append(request)
        return try await handler(request, index)
    }

    public func recordedRequests() -> [URLRequest] {
        requests
    }

    public func requestCount() -> Int {
        requests.count
    }

    public func reset() {
        requests.removeAll(keepingCapacity: true)
    }
}

/// One deterministic result consumed by ``SequencedHTTPTransport``.
public struct HTTPTransportStub: Sendable {
    private enum Outcome {
        case response(HTTPResponseFixture)
        case failure(any Error & Sendable)
    }

    private let outcome: Outcome

    public init(response: HTTPResponseFixture) {
        outcome = .response(response)
    }

    public init(
        statusCode: Int = 200,
        headers: [String: String] = [:],
        body: Data = Data(),
        url: URL? = nil,
        httpVersion: String? = "HTTP/1.1"
    ) {
        self.init(response: HTTPResponseFixture(
            statusCode: statusCode,
            headers: headers,
            body: body,
            url: url,
            httpVersion: httpVersion
        ))
    }

    public init(error: some Error & Sendable) {
        outcome = .failure(error)
    }

    fileprivate func resolve(for request: URLRequest) throws -> (Data, URLResponse) {
        switch outcome {
        case let .response(fixture):
            return try (fixture.body, fixture.response(for: request))
        case let .failure(error):
            throw error
        }
    }
}

/// An actor-isolated transport that consumes one stub per request.
public actor SequencedHTTPTransport: HTTPTransport {
    private var stubs: [HTTPTransportStub]
    private var nextStubIndex = 0
    private var requests: [URLRequest] = []

    public init(stubs: [HTTPTransportStub]) {
        self.stubs = stubs
    }

    public init(responses: [HTTPResponseFixture]) {
        stubs = responses.map(HTTPTransportStub.init(response:))
    }

    public func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let requestIndex = requests.count
        requests.append(request)
        guard nextStubIndex < stubs.count else {
            throw HTTPTransportSequenceExhaustedError(requestIndex: requestIndex)
        }
        let stub = stubs[nextStubIndex]
        nextStubIndex += 1
        return try stub.resolve(for: request)
    }

    public func append(_ stub: HTTPTransportStub) {
        stubs.append(stub)
    }

    public func recordedRequests() -> [URLRequest] {
        requests
    }

    public func requestCount() -> Int {
        requests.count
    }

    public func remainingStubCount() -> Int {
        stubs.count - nextStubIndex
    }
}

public struct HTTPTransportSequenceExhaustedError: Error, Equatable, Sendable {
    public let requestIndex: Int

    public init(requestIndex: Int) {
        self.requestIndex = requestIndex
    }
}
