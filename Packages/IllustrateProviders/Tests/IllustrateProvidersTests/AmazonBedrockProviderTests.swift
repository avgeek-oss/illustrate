import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Amazon Bedrock direct provider", .serialized)
struct AmazonBedrockProviderTests {
    private let secret = #"{"api_key":"bedrock-secret","region":"us-west-2"}"#

    @Test("Configuration constructs only allowlisted Bedrock Runtime endpoints")
    func configurationAndEndpointValidation() throws {
        let configuration = try AmazonBedrockConfiguration(secret: secret)
        let url = try configuration.invokeURL(modelId: "stability.stable-image-ultra-v1:1")

        #expect(url.absoluteString ==
            "https://bedrock-runtime.us-west-2.amazonaws.com/model/stability.stable-image-ultra-v1:1/invoke")
        #expect(throws: AmazonBedrockError.self) {
            try AmazonBedrockConfiguration(
                secret: #"{"api_key":"key","region":"us-west-2.evil.example"}"#
            )
        }
        #expect(throws: AmazonBedrockError.self) {
            try configuration.invokeURL(modelId: "../../evil")
        }
        let unavailable = try AmazonBedrockConfiguration(
            secret: #"{"api_key":"key","region":"us-east-1"}"#
        )
        #expect(throws: AmazonBedrockError.self) {
            try unavailable.invokeURL(modelId: "stability.stable-image-core-v1:1")
        }
    }

    @Test("Stable Image Ultra sends one native invocation and decodes output")
    func ultraFlow() async throws {
        let mock = BedrockMockNetworkProvider(singleResponses: [
            .init(response: .dictionary(statusCode: 200, data: [
                "images": ["aW1hZ2U="],
                "seeds": [42],
                "finish_reasons": [NSNull()],
            ])),
        ])

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: BedrockTestModelProvider()
        ) {
            try await G_BEDROCK_STABLE_IMAGE_ULTRA_1_1().makeRequest(request: imageRequest())
        }

        #expect(mock.singleRequests.count == 1)
        let sent = try #require(mock.singleRequests.first)
        #expect(sent.method == "POST")
        #expect(sent.url.absoluteString.contains("stability.stable-image-ultra-v1:1/invoke"))
        #expect(sent.headers?["Authorization"] == "Bearer bedrock-secret")
        #expect(sent.headers?["Content-Type"] == "application/json")
        let body = try #require(sent.body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["prompt"] as? String == "A cinematic aircraft portrait")
        #expect(json["mode"] as? String == "text-to-image")
        #expect(json["aspect_ratio"] as? String == "16:9")
        #expect(json["output_format"] as? String == "png")
        #expect(json["seed"] as? Int == 42)
        #expect(json["negative_prompt"] as? String == "text overlays")

        #expect(response.status == .GENERATED)
        #expect(response.base64 == "aW1hZ2U=")
        #expect(response.cost == 0.14)
        #expect(response.metadata?["bedrockModelId"] == "stability.stable-image-ultra-v1:1")
        #expect(response.metadata?["bedrockRegion"] == "us-west-2")
        #expect(response.metadata?["bedrockSeed"] == "42")
    }

    @Test("Stable Image Core uses its model route and cost")
    func coreFlow() async throws {
        let mock = BedrockMockNetworkProvider(singleResponses: [
            .init(response: .dictionary(statusCode: 200, data: [
                "images": ["Y29yZQ=="],
                "finish_reasons": [NSNull()],
            ])),
        ])
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: BedrockTestModelProvider()
        ) {
            try await G_BEDROCK_STABLE_IMAGE_CORE_1_1().makeRequest(request: imageRequest())
        }

        #expect(mock.singleRequests.first?.url.absoluteString.contains("stability.stable-image-core-v1:1") == true)
        #expect(response.status == .GENERATED)
        #expect(response.cost == 0.04)
        #expect(G_BEDROCK_STABLE_IMAGE_CORE_1_1().formatCost(request: .init(numberOfImages: 1)) == "$0.04")
    }

    @Test("Provider moderation failures and HTTP errors fail closed")
    func providerFailures() async throws {
        let filtered = BedrockMockNetworkProvider(singleResponses: [
            .init(response: .dictionary(statusCode: 200, data: [
                "images": [],
                "finish_reasons": ["Filter reason: prompt"],
            ])),
        ])
        let filteredResponse = try await withProviderDependencies(
            networkProvider: filtered,
            modelProvider: BedrockTestModelProvider()
        ) {
            try await G_BEDROCK_STABLE_IMAGE_ULTRA_1_1().makeRequest(request: imageRequest())
        }
        #expect(filtered.singleRequests.count == 1)
        #expect(filteredResponse.status == .FAILED)
        #expect(filteredResponse.errorMessage?.contains("Filter reason: prompt") == true)

        let body = Data(#"{"message":"throttled"}"#.utf8)
        let throttled = BedrockMockNetworkProvider(singleResponses: [
            .init(
                statusCode: 429,
                headers: ["x-amzn-requestid": "request-123"],
                body: body,
                response: .dictionary(statusCode: 429, data: ["message": "throttled"])
            ),
        ])
        let throttledResponse = try await withProviderDependencies(
            networkProvider: throttled,
            modelProvider: BedrockTestModelProvider()
        ) {
            try await G_BEDROCK_STABLE_IMAGE_ULTRA_1_1().makeRequest(request: imageRequest())
        }
        #expect(throttled.singleRequests.count == 1)
        #expect(throttledResponse.status == .FAILED)
        #expect(throttledResponse.errorMessage?.contains("throttled") == true)
        #expect(throttledResponse.rawResponse?.contains("429") == true)
    }

    @Test("Unsupported controls are rejected before a billable invocation")
    func validation() async throws {
        let mock = BedrockMockNetworkProvider()
        var request = imageRequest()
        request.clientImage = "aW1hZ2U="

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: BedrockTestModelProvider()
        ) {
            try await G_BEDROCK_STABLE_IMAGE_ULTRA_1_1().makeRequest(request: request)
        }

        #expect(mock.singleRequests.isEmpty)
        #expect(response.status == .FAILED)
        #expect(response.errorMessage?.contains("text-to-image") == true)
    }

    @Test("Catalog exposes only active Stability models")
    func catalog() {
        let models = AmazonBedrockModels.createModels()
        #expect(models.map(\.modelCode) == [
            .BEDROCK_STABLE_IMAGE_ULTRA_1_1,
            .BEDROCK_STABLE_IMAGE_CORE_1_1,
        ])
        #expect(models.map(\.active) == [true, true])
        #expect(models.allSatisfy { $0.providerId == EnumProviderCode.AMAZON_BEDROCK.providerId })
        #expect(models.allSatisfy { $0.modelVerificationDate == getDateFromString("2026-07-10") })
    }

    private func imageRequest() -> ImageGenerationRequest {
        .init(
            modelId: EnumProviderModelCode.BEDROCK_STABLE_IMAGE_ULTRA_1_1.modelId.uuidString,
            prompt: "A cinematic aircraft portrait",
            negativePrompt: "text overlays",
            dimensions: "16:9",
            providerKey: .init(
                providerId: EnumProviderCode.AMAZON_BEDROCK.providerId,
                providerCode: .AMAZON_BEDROCK,
                projectId: UUID()
            ),
            providerSecret: secret,
            seed: 42
        )
    }
}

private final class BedrockMockNetworkProvider: NetworkProvider, @unchecked Sendable {
    struct Request {
        let url: URL
        let method: String
        let body: Data?
        let headers: [String: String]?
    }

    private var singleResponses: [NetworkResponseEnvelope]
    private(set) var singleRequests: [Request] = []

    init(singleResponses: [NetworkResponseEnvelope] = []) {
        self.singleResponses = singleResponses
    }

    func performSingleAttemptRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments _: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseEnvelope {
        try singleRequests.append(.init(
            url: url,
            method: method,
            body: body.map { try JSONEncoder().encode($0) },
            headers: headers
        ))
        guard !singleResponses.isEmpty else { throw URLError(.badServerResponse) }
        return singleResponses.removeFirst()
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
}

private struct BedrockTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        AllModels.createModels().first { $0.modelCode == code }
    }
}
