import AvgeekNetworking
import Foundation
import XCTest
@testable import AvgeekTestSupport

final class HTTPTransportsTests: XCTestCase {
    func testRecordingTransportPassesStableIndicesAndRecordsRequests() async throws {
        let transport = RecordingHTTPTransport { request, index in
            let fixture = HTTPResponseFixture(statusCode: 200 + index, body: "response-\(index)")
            return try (fixture.body, fixture.response(for: request))
        }

        let first = try await transport.send(HTTPRequestFixture(
            url: XCTUnwrap(URL(string: "https://api.example.test/first"))
        ).request)
        let second = try await transport.send(HTTPRequestFixture(
            url: XCTUnwrap(URL(string: "https://api.example.test/second"))
        ).request)
        let requestCount = await transport.requestCount()
        let requests = await transport.recordedRequests()

        XCTAssertEqual((first.1 as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual((second.1 as? HTTPURLResponse)?.statusCode, 201)
        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(requests.map(\.url?.lastPathComponent), ["first", "second"])
    }

    func testRecordingTransportSerializesConcurrentRecording() async throws {
        let transport = RecordingHTTPTransport(response: HTTPResponseFixture(statusCode: 204))

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0 ..< 50 {
                group.addTask {
                    let request = HTTPRequestFixture(
                        url: URL(string: "https://api.example.test/items/\(index)")!
                    ).request
                    _ = try await transport.send(request)
                }
            }
            try await group.waitForAll()
        }
        let requestCount = await transport.requestCount()
        let paths = await transport.recordedRequests().compactMap(\.url?.path)

        XCTAssertEqual(requestCount, 50)
        XCTAssertEqual(Set(paths).count, 50)
    }

    func testRecordingTransportResetOnlyClearsHistory() async throws {
        let transport = RecordingHTTPTransport(response: HTTPResponseFixture(statusCode: 200))
        _ = try await transport.send(HTTPRequestFixture().request)

        await transport.reset()
        let result = try await transport.send(HTTPRequestFixture().request)
        let requestCount = await transport.requestCount()

        XCTAssertEqual((result.1 as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(requestCount, 1)
    }

    func testSequencedTransportConsumesResponsesInOrder() async throws {
        let transport = SequencedHTTPTransport(stubs: [
            HTTPTransportStub(statusCode: 429, headers: ["Retry-After": "5"]),
            HTTPTransportStub(statusCode: 200, body: Data("done".utf8)),
        ])
        let request = HTTPRequestFixture().request

        let first = try await transport.send(request)
        let second = try await transport.send(request)
        let requestCount = await transport.requestCount()
        let remainingStubCount = await transport.remainingStubCount()

        XCTAssertEqual((first.1 as? HTTPURLResponse)?.statusCode, 429)
        XCTAssertEqual((second.1 as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(second.0, Data("done".utf8))
        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(remainingStubCount, 0)
    }

    func testSequencedTransportThrowsConfiguredFailure() async throws {
        let transport = SequencedHTTPTransport(stubs: [HTTPTransportStub(error: URLError(.timedOut))])

        do {
            _ = try await transport.send(HTTPRequestFixture().request)
            XCTFail("Expected the configured failure")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
        }
    }

    func testSequencedTransportReportsExhaustedRequestIndex() async throws {
        let transport = SequencedHTTPTransport(stubs: [])

        do {
            _ = try await transport.send(HTTPRequestFixture().request)
            XCTFail("Expected sequence exhaustion")
        } catch let error as HTTPTransportSequenceExhaustedError {
            XCTAssertEqual(error, HTTPTransportSequenceExhaustedError(requestIndex: 0))
        }
        let requestCount = await transport.requestCount()
        XCTAssertEqual(requestCount, 1)
    }

    func testSequencedTransportCanAppendAResponse() async throws {
        let transport = SequencedHTTPTransport(stubs: [])
        await transport.append(HTTPTransportStub(statusCode: 201))

        let result = try await transport.send(HTTPRequestFixture().request)

        XCTAssertEqual((result.1 as? HTTPURLResponse)?.statusCode, 201)
    }
}
