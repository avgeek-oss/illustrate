import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import IllustrateProviders

@Suite("Recraft direct provider", .serialized)
struct RecraftProviderTests {
    @Test("Posts one documented raster generation with bearer authentication")
    func postsDocumentedRequest() async throws {
        let mock = RecraftMockNetworkProvider(responses: [
            .dictionary(statusCode: 200, data: [
                "data": [[
                    "b64_json": "aW1hZ2U=",
                    "image_id": "image_123",
                    "revised_prompt": "Revised aircraft poster",
                ]],
            ]),
        ])

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: RecraftTestModelProvider()
        ) {
            try await G_RECRAFT_V4_1().makeRequest(request: request(numberOfImages: 4, seed: 42))
        }

        let captured = try #require(mock.requests.first)
        #expect(captured.url.absoluteString == "https://external.api.recraft.ai/v1/images/generations/raster")
        #expect(captured.method == "POST")
        #expect(mock.singleAttemptRequestCount == 1)
        #expect(captured.headers?["Authorization"] == "Bearer recraft-test-token")
        let body = try #require(captured.body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["prompt"] as? String == "A precise airline poster")
        #expect(json["model"] as? String == "recraftv4_1")
        #expect(json["size"] as? String == "16:9")
        #expect(json["n"] as? Int == 1)
        #expect(json["random_seed"] as? Int == 42)
        #expect(json["response_format"] as? String == "b64_json")
        #expect(response.status == .GENERATED)
        #expect(response.base64 == "aW1hZ2U=")
        #expect(response.cost == 0.04)
    }

    @Test("Downloads a URL fallback through the injected network dependency")
    func downloadsURLFallback() async throws {
        let mock = RecraftMockNetworkProvider(
            responses: [
                .dictionary(statusCode: 200, data: [
                    "data": [["url": "https://cdn.example/recraft.png", "image_id": "image_456"]],
                ]),
            ],
            rawResponses: [.image(statusCode: 200, base64: "ZG93bmxvYWQ=", mimeType: "image/png")]
        )

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: RecraftTestModelProvider()
        ) {
            try await G_RECRAFT_V4_1().makeRequest(request: request())
        }

        #expect(mock.rawRequests.first?.url?.absoluteString == "https://cdn.example/recraft.png")
        #expect(response.status == .GENERATED)
        #expect(response.base64 == "ZG93bmxvYWQ=")
        #expect(response.metadata?["recraftImageId"] == "image_456")
    }

    @Test("Maps documented errors and credential failures")
    func mapsFailures() async throws {
        let mock = RecraftMockNetworkProvider(responses: [
            .dictionary(statusCode: 429, data: ["error": ["message": "Rate limit exceeded"]]),
        ])
        let providerError = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: RecraftTestModelProvider()
        ) {
            try await G_RECRAFT_V4_1().makeRequest(request: request())
        }
        #expect(providerError.status == .FAILED)
        #expect(providerError.errorMessage == "Rate limit exceeded")

        let emptyCredential = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: RecraftTestModelProvider()
        ) {
            try await G_RECRAFT_V4_1().makeRequest(request: request(secret: "   "))
        }
        #expect(emptyCredential.status == .FAILED)
        #expect(emptyCredential.errorMessage?.contains("credentials are empty") == true)
        #expect(mock.requests.count == 1)
    }

    @Test("Registers source-backed lifecycle and price metadata")
    func registersMetadataAndPricing() throws {
        let standard = try #require(RecraftModels.createModels().first { $0.modelCode == .RECRAFT_V4_1 })
        let pro = try #require(RecraftModels.createModels().first { $0.modelCode == .RECRAFT_V4_1_PRO })

        #expect(standard.providerId == EnumProviderCode.RECRAFT.providerId)
        #expect(standard.modelParams.maxGenerations == 6)
        #expect(standard.modelVerificationDate == getDateFromString("2026-07-10"))
        #expect(standard.pricingMetadata?.unit == .image)
        #expect(standard.pricingMetadata?.sourceURL == "https://www.recraft.ai/pricing?tab=api")
        #expect(G_RECRAFT_V4_1().getCostEstimate(request: .init(numberOfImages: 3)) == 0.12)
        #expect(G_RECRAFT_V4_1_PRO().getCostEstimate(request: .init(numberOfImages: 2)) == 0.50)
        #expect(pro.modelName == "Recraft V4.1 Pro")
    }

    private func request(
        secret: String = "recraft-test-token",
        numberOfImages: Int = 1,
        seed: Int? = nil
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: EnumProviderModelCode.RECRAFT_V4_1.modelId.uuidString,
            prompt: "A precise airline poster",
            dimensions: "16:9",
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.RECRAFT.providerId,
                providerCode: .RECRAFT,
                projectId: UUID()
            ),
            providerSecret: secret,
            numberOfImages: numberOfImages,
            seed: seed
        )
    }
}

private final class RecraftMockNetworkProvider: @unchecked Sendable, NetworkProvider {
    struct CapturedRequest {
        let url: URL
        let method: String
        let headers: [String: String]?
        let body: Data?
    }

    var requests: [CapturedRequest] = []
    var singleAttemptRequestCount = 0
    var rawRequests: [URLRequest] = []
    private var responses: [NetworkResponseData]
    private var rawResponses: [NetworkResponseData]

    init(responses: [NetworkResponseData], rawResponses: [NetworkResponseData] = []) {
        self.responses = responses
        self.rawResponses = rawResponses
    }

    func performRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments _: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseData {
        let encoded = try body.map { try JSONEncoder().encode($0) }
        requests.append(.init(url: url, method: method, headers: headers, body: encoded))
        guard !responses.isEmpty else { throw URLError(.badServerResponse) }
        return responses.removeFirst()
    }

    func performSingleAttemptRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseEnvelope {
        singleAttemptRequestCount += 1
        let response = try await performRequest(
            url: url,
            method: method,
            body: body,
            headers: headers,
            attachments: attachments
        )
        return NetworkResponseEnvelope(response: response)
    }

    func performRawRequest(_ request: URLRequest) async throws -> NetworkResponseData {
        rawRequests.append(request)
        guard !rawResponses.isEmpty else { throw URLError(.badServerResponse) }
        return rawResponses.removeFirst()
    }
}

private struct RecraftTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        RecraftModels.createModels().first { $0.modelCode == code }
    }
}
