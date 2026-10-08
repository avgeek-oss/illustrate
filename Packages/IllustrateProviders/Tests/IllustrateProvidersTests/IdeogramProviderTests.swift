import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import IllustrateProviders

@Suite("Ideogram direct provider", .serialized)
struct IdeogramProviderTests {
    @Test("Builds documented scalar multipart fields and API key header")
    func buildsDocumentedRequest() async throws {
        let mock = IdeogramMockNetworkProvider(
            responses: [
                .dictionary(statusCode: 200, data: [
                    "created": "2026-07-10T00:00:00Z",
                    "data": [[
                        "prompt": "A polished aircraft wordmark",
                        "resolution": "2560x1440",
                        "is_image_safe": true,
                        "seed": 12345,
                        "url": "https://cdn.example/ideogram.png",
                    ]],
                    "response_type": "url",
                ]),
            ],
            rawResponses: [.image(statusCode: 200, base64: "aWRlb2dyYW0=", mimeType: "image/png")]
        )

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: IdeogramTestModelProvider()
        ) {
            try await G_IDEOGRAM_V4_TURBO().makeRequest(request: request())
        }

        let captured = try #require(mock.requests.first)
        #expect(captured.url.absoluteString == "https://api.ideogram.ai/v1/ideogram-v4/generate")
        #expect(captured.method == "POST")
        #expect(mock.singleAttemptRequestCount == 1)
        #expect(captured.headers?["Api-Key"] == "ideogram-test-key")
        #expect(captured.headers?["Content-Type"] == "multipart/form-data")
        let body = try #require(captured.body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["text_prompt"] as? String == "A polished aircraft wordmark")
        #expect(json["resolution"] as? String == "2560x1440")
        #expect(json["rendering_speed"] as? String == "TURBO")
        #expect(json["enable_copyright_detection"] as? Bool == false)
        #expect(response.status == .GENERATED)
        #expect(response.base64 == "aWRlb2dyYW0=")
        #expect(response.metadata?["ideogramSeed"] == "12345")
        #expect(mock.rawRequests.first?.url?.absoluteString == "https://cdn.example/ideogram.png")
    }

    @Test("Maps supported aspect ratios to documented resolutions")
    func mapsResolutions() {
        #expect(G_IDEOGRAM_V4.mapResolution("1:1") == "2048x2048")
        #expect(G_IDEOGRAM_V4.mapResolution("16:9") == "2560x1440")
        #expect(G_IDEOGRAM_V4.mapResolution("9:16") == "1440x2560")
        #expect(G_IDEOGRAM_V4.mapResolution("2304x1728") == "2304x1728")
        #expect(G_IDEOGRAM_V4.mapResolution("unsupported") == "2048x2048")
    }

    @Test("Rejects FLASH and prices the three documented active speeds")
    func registersOnlyActiveSpeedsAndPricing() throws {
        let models = IdeogramModels.createModels()
        #expect(models.map(\.modelCode) == [.IDEOGRAM_V4_TURBO, .IDEOGRAM_V4_DEFAULT, .IDEOGRAM_V4_QUALITY])
        #expect(models.allSatisfy { $0.modelVerificationDate == getDateFromString("2026-07-10") })
        #expect(!models.map(\.modelName).contains { $0.contains("Flash") })
        #expect(G_IDEOGRAM_V4_TURBO().getCostEstimate(request: .init(numberOfImages: 2)) == 0.06)
        #expect(G_IDEOGRAM_V4_DEFAULT().getCostEstimate(request: .init(numberOfImages: 2)) == 0.12)
        #expect(G_IDEOGRAM_V4_QUALITY().getCostEstimate(request: .init(numberOfImages: 2)) == 0.20)
        let quality = try #require(models.last)
        #expect(quality.pricingMetadata?.sourceURL == "https://ideogram.ai/api-pricing/")
    }

    @Test("Maps provider and credential errors without making extra calls")
    func mapsErrors() async throws {
        let mock = IdeogramMockNetworkProvider(responses: [
            .dictionary(statusCode: 400, data: ["message": "Invalid rendering speed"]),
        ])
        let providerError = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: IdeogramTestModelProvider()
        ) {
            try await G_IDEOGRAM_V4_DEFAULT().makeRequest(request: request())
        }
        #expect(providerError.status == .FAILED)
        #expect(providerError.errorMessage == "Invalid rendering speed")

        let credentialError = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: IdeogramTestModelProvider()
        ) {
            try await G_IDEOGRAM_V4_DEFAULT().makeRequest(request: request(secret: ""))
        }
        #expect(credentialError.status == .FAILED)
        #expect(credentialError.errorMessage?.contains("credentials are empty") == true)
        #expect(mock.requests.count == 1)
    }

    private func request(secret: String = "ideogram-test-key") -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: EnumProviderModelCode.IDEOGRAM_V4_TURBO.modelId.uuidString,
            prompt: "A polished aircraft wordmark",
            dimensions: "16:9",
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.IDEOGRAM.providerId,
                providerCode: .IDEOGRAM,
                projectId: UUID()
            ),
            providerSecret: secret
        )
    }
}

private final class IdeogramMockNetworkProvider: @unchecked Sendable, NetworkProvider {
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

private struct IdeogramTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        IdeogramModels.createModels().first { $0.modelCode == code }
    }
}
