import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import IllustrateProviders

@Suite("Provider integration foundation")
struct ProviderFoundationTests {
    @Test("Simple API keys are normalized without JSON parsing")
    func simpleAPIKey() throws {
        let credentials = try ProviderCredentialConfiguration(secret: "  provider-key  ")

        #expect(try credentials.requireAPIKey() == "provider-key")
        #expect(credentials.values.isEmpty)
    }

    @Test("Structured credentials preserve strings and embedded JSON")
    func structuredCredentials() throws {
        let credentials = try ProviderCredentialConfiguration(
            secret: #"{"region":"us-east-1","optional":null,"service_account":{"project_id":"demo"}}"#
        )

        #expect(try credentials.require("region") == "us-east-1")
        #expect(credentials.value(for: "optional") == nil)
        let embedded = try credentials.decodeEmbeddedJSON(ServiceAccount.self, from: "service_account")
        #expect(embedded.projectId == "demo")
    }

    @Test("Missing and malformed credentials fail deterministically")
    func invalidCredentials() {
        #expect(throws: ProviderCredentialError.empty) {
            try ProviderCredentialConfiguration(secret: "   ")
        }
        #expect(throws: ProviderCredentialError.invalidJSON) {
            try ProviderCredentialConfiguration(secret: "{not-json}")
        }
        #expect(throws: ProviderCredentialError.missingField("secret")) {
            let credentials = try ProviderCredentialConfiguration(secret: #"{"key":"value"}"#)
            _ = try credentials.require("secret")
        }
    }

    @Test("Async jobs stop on success")
    func asyncJobSuccess() async throws {
        let sequence = StatusSequence(["queued", "running", "succeeded"])

        let result = try await ProviderAsyncJobPoller.poll(
            policy: ProviderPollingPolicy(maxAttempts: 3, intervalNanoseconds: 0),
            fetch: { await sequence.next() },
            classify: { status in
                status == "succeeded" ? .succeeded : .pending
            }
        )

        #expect(result == "succeeded")
        #expect(await sequence.requestCount == 3)
    }

    @Test("Async jobs surface provider failure and timeout")
    func asyncJobFailureAndTimeout() async {
        await #expect(throws: ProviderAsyncJobError.failed("blocked")) {
            try await ProviderAsyncJobPoller.poll(
                policy: ProviderPollingPolicy(maxAttempts: 1, intervalNanoseconds: 0),
                fetch: { "failed" },
                classify: { _ in .failed("blocked") }
            )
        }

        await #expect(throws: ProviderAsyncJobError.timedOut(maxAttempts: 2)) {
            try await ProviderAsyncJobPoller.poll(
                policy: ProviderPollingPolicy(maxAttempts: 2, intervalNanoseconds: 0),
                fetch: { "pending" },
                classify: { _ in .pending }
            )
        }
    }

    @Test("Pricing provenance survives Codable round trip")
    func pricingMetadataRoundTrip() throws {
        let metadata = ProviderPricingMetadata(
            unit: .second,
            sourceURL: "https://provider.example/pricing",
            verifiedAt: Date(timeIntervalSince1970: 1_788_000_000),
            notes: "720p with audio"
        )

        let data = try JSONEncoder().encode(metadata)
        #expect(try JSONDecoder().decode(ProviderPricingMetadata.self, from: data) == metadata)
    }

    @Test("Single-attempt response envelope preserves status headers and raw body")
    func responseEnvelope() throws {
        let body = Data(#"{"error":{"message":"busy"}}"#.utf8)
        let parsed = NetworkResponseData.dictionary(
            statusCode: 429,
            data: ["error": ["message": "busy"]]
        )
        let envelope = NetworkResponseEnvelope(
            statusCode: 429,
            headers: ["Retry-After": "30", "X-Request-ID": "request-123"],
            body: body,
            response: parsed
        )

        #expect(envelope.statusCode == 429)
        #expect(envelope.headerValue(for: "retry-after") == "30")
        #expect(envelope.body == body)
        #expect(envelope.bodyString == #"{"error":{"message":"busy"}}"#)
        #expect(try envelope.requireParsedResponse().statusCode == 429)

        let unparseable = NetworkResponseEnvelope(
            statusCode: 503,
            body: Data("upstream unavailable".utf8)
        )
        #expect(throws: NetworkResponseEnvelopeError.unparseableBody(statusCode: 503)) {
            try unparseable.requireParsedResponse()
        }
    }

    @Test("Image generation cost requests retain selected resolution")
    func imageCostRequestResolution() {
        let request = ImageGenerationRequest(
            modelId: "model-id",
            prompt: "A test image",
            dimensions: "1:1",
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.OPENAI.providerId,
                providerCode: .OPENAI,
                projectId: UUID()
            ),
            providerSecret: "fixture",
            resolution: "2K"
        )

        #expect(ImageGenerationCostRequest(from: request).resolution == "2K")
        #expect(ImageGenerationCostRequest(resolution: "1K").resolution == "1K")
    }

    @Test("Media materialization downloads arbitrary bytes through the injected dependency")
    func mediaMaterialization() async throws {
        let network = MediaFixtureNetworkProvider(
            response: NetworkDataResponse(
                statusCode: 200,
                data: Data("video-bytes".utf8),
                headers: ["content-type": "video/mp4"]
            )
        )

        let base64 = try await ProviderMediaMaterializer.base64(
            from: #require(URL(string: "https://media.example/result.mp4?secret=fixture")),
            headers: ["Authorization": "Bearer fixture"],
            network: network
        )

        #expect(base64 == Data("video-bytes".utf8).base64EncodedString())
        #expect(network.capturedRequest?.httpMethod == "GET")
        #expect(network.capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer fixture")
        #expect(network.response.contentType == "video/mp4")
    }

    @Test("Media materialization rejects empty and failed responses")
    func mediaMaterializationFailures() async throws {
        await #expect(throws: ProviderMediaMaterializerError.httpStatus(404)) {
            try await ProviderMediaMaterializer.base64(
                from: #require(URL(string: "https://media.example/missing.mp4")),
                network: MediaFixtureNetworkProvider(
                    response: NetworkDataResponse(statusCode: 404, data: Data())
                )
            )
        }

        await #expect(throws: ProviderMediaMaterializerError.emptyResponse) {
            try await ProviderMediaMaterializer.base64(
                from: #require(URL(string: "https://media.example/empty.mp4")),
                network: MediaFixtureNetworkProvider(
                    response: NetworkDataResponse(statusCode: 200, data: Data())
                )
            )
        }
    }
}

private struct ServiceAccount: Decodable {
    let projectId: String

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
    }
}

private actor StatusSequence {
    private var values: [String]
    private(set) var requestCount = 0

    init(_ values: [String]) {
        self.values = values
    }

    func next() -> String {
        requestCount += 1
        return values.removeFirst()
    }
}

private final class MediaFixtureNetworkProvider: @unchecked Sendable, NetworkProvider {
    let response: NetworkDataResponse
    var capturedRequest: URLRequest?

    init(response: NetworkDataResponse) {
        self.response = response
    }

    func performRequest(
        url _: URL,
        method _: String,
        body _: (some Codable & Sendable)?,
        headers _: [String: String]?,
        attachments _: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseData {
        throw URLError(.unsupportedURL)
    }

    func performDataRequest(_ request: URLRequest) async throws -> NetworkDataResponse {
        capturedRequest = request
        return response
    }
}
