import Foundation
import XCTest
@testable import AvgeekTestSupport

final class HTTPFixturesTests: XCTestCase {
    func testRequestFixtureBuildsMethodHeadersAndBody() throws {
        let body = Data("payload".utf8)
        let fixture = try HTTPRequestFixture(
            url: XCTUnwrap(URL(string: "https://api.example.test/items")),
            method: "PATCH",
            headers: ["Authorization": "Bearer test"],
            body: body
        )

        let request = fixture.request

        XCTAssertEqual(request.url, fixture.url)
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test")
        XCTAssertEqual(request.httpBody, body)
    }

    func testJSONRequestEncodesBodyAndAddsContentType() throws {
        let fixture = try HTTPRequestFixture.json(body: Payload(value: "test"))

        XCTAssertEqual(fixture.headers["Content-Type"], "application/json")
        XCTAssertEqual(try JSONDecoder().decode(Payload.self, from: XCTUnwrap(fixture.body)), Payload(value: "test"))
    }

    func testJSONRequestPreservesCallerContentType() throws {
        let fixture = try HTTPRequestFixture.json(
            headers: ["content-type": "application/problem+json"],
            body: Payload(value: "test")
        )

        XCTAssertEqual(fixture.headers, ["content-type": "application/problem+json"])
    }

    func testResponseFixtureUsesRequestURLAndReturnsBody() throws {
        let request = HTTPRequestFixture().request
        let fixture = HTTPResponseFixture(
            statusCode: 202,
            headers: ["X-Request-ID": "request-1"],
            body: "accepted"
        )

        let response = try fixture.response(for: request)

        XCTAssertEqual(response.url, request.url)
        XCTAssertEqual(response.statusCode, 202)
        XCTAssertEqual(response.value(forHTTPHeaderField: "X-Request-ID"), "request-1")
        XCTAssertEqual(fixture.body, Data("accepted".utf8))
    }

    func testResponseFixtureRequiresAURL() {
        let fixture = HTTPResponseFixture()

        XCTAssertThrowsError(try fixture.response()) { error in
            XCTAssertEqual(error as? HTTPFixtureError, .missingResponseURL)
        }
    }

    func testJSONResponseEncodesBodyAndAddsContentType() throws {
        let fixture = try HTTPResponseFixture.json(body: Payload(value: "ok"))

        XCTAssertEqual(fixture.headers["Content-Type"], "application/json")
        XCTAssertEqual(try JSONDecoder().decode(Payload.self, from: fixture.body), Payload(value: "ok"))
    }
}

private struct Payload: Codable, Equatable {
    let value: String
}
