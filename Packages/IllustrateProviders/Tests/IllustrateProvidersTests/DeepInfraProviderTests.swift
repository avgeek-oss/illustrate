import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import IllustrateProviders

@Suite("DeepInfra direct provider", .serialized)
struct DeepInfraProviderTests {
    @Test("Posts one OpenAI-compatible FLUX.2 Klein generation")
    func postsDocumentedRequest() async throws {
        let mock = DeepInfraMockNetworkProvider(responses: [
            .dictionary(statusCode: 200, data: [
                "created": 1_707_000_000,
                "data": [[
                    "b64_json": "aW1hZ2U=",
                    "revised_prompt": "A precise airline poster",
                ]],
            ]),
        ])

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: DeepInfraTestModelProvider()
        ) {
            try await G_DEEPINFRA_FLUX_2_KLEIN_4B().makeRequest(
                request: request(numberOfImages: 4)
            )
        }

        let captured = try #require(mock.requests.first)
        #expect(captured.url.absoluteString == "https://api.deepinfra.com/v1/openai/images/generations")
        #expect(captured.method == "POST")
        #expect(mock.singleAttemptRequestCount == 1)
        #expect(captured.headers?["Authorization"] == "Bearer deepinfra-test-token")
        let body = try #require(captured.body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "black-forest-labs/FLUX-2-klein-4b")
        #expect(json["prompt"] as? String == "A precise airline poster")
        #expect(json["size"] as? String == "1344x768")
        #expect(json["n"] as? Int == 1)
        #expect(json["response_format"] as? String == "b64_json")
        #expect(response.status == .GENERATED)
        #expect(response.base64 == "aW1hZ2U=")
        #expect(response.modelPrompt == "A precise airline poster")
        #expect(response.cost == G_DEEPINFRA_FLUX_2_KLEIN_4B().getCostEstimate(
            request: .init(dimensions: "1344x768")
        ))
    }

    @Test("Uses the published normalized pixel price for both models")
    func usesPublishedPricing() {
        let square = ImageGenerationCostRequest(dimensions: "1024x1024", numberOfImages: 8)
        #expect(G_DEEPINFRA_FLUX_2_KLEIN_4B().getCostEstimate(request: square) == 0.014)
        #expect(G_DEEPINFRA_FLUX_2_KLEIN_9B().getCostEstimate(request: square) == 0.015)

        let doubleArea = ImageGenerationCostRequest(dimensions: "2048x1024")
        #expect(G_DEEPINFRA_FLUX_2_KLEIN_4B().getCostEstimate(request: doubleArea) == 0.028)
        #expect(G_DEEPINFRA_FLUX_2_KLEIN_9B().getCostEstimate(request: doubleArea) == 0.03)
    }

    @Test("Maps documented validation and provider errors")
    func mapsErrors() async throws {
        let mock = DeepInfraMockNetworkProvider(responses: [
            .dictionary(statusCode: 422, data: [
                "detail": [["loc": ["body", "size"], "msg": "Unsupported image size", "type": "value_error"]],
            ]),
            .dictionary(statusCode: 429, data: ["detail": ["error": "Rate limit exceeded"]]),
        ])

        let validation = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: DeepInfraTestModelProvider()
        ) {
            try await G_DEEPINFRA_FLUX_2_KLEIN_4B().makeRequest(request: request())
        }
        #expect(validation.status == .FAILED)
        #expect(validation.errorMessage == "Unsupported image size")

        let rateLimit = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: DeepInfraTestModelProvider()
        ) {
            try await G_DEEPINFRA_FLUX_2_KLEIN_9B().makeRequest(request: request())
        }
        #expect(rateLimit.status == .FAILED)
        #expect(rateLimit.errorMessage == "Rate limit exceeded")
        #expect(mock.singleAttemptRequestCount == 2)
    }

    @Test("Rejects unsupported inputs before a billable request")
    func rejectsUnsupportedInputs() async throws {
        let mock = DeepInfraMockNetworkProvider(responses: [])

        let invalidDimensions = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: DeepInfraTestModelProvider()
        ) {
            try await G_DEEPINFRA_FLUX_2_KLEIN_4B().makeRequest(
                request: request(dimensions: "4096x4096")
            )
        }
        #expect(invalidDimensions.status == .FAILED)
        #expect(invalidDimensions.errorMessage?.contains("between 128 and 1920") == true)

        let sourceImage = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: DeepInfraTestModelProvider()
        ) {
            var sourceRequest = request()
            sourceRequest.clientImage = "data:image/png;base64,aW1hZ2U="
            return try await G_DEEPINFRA_FLUX_2_KLEIN_4B().makeRequest(request: sourceRequest)
        }
        #expect(sourceImage.status == .FAILED)
        #expect(sourceImage.errorMessage?.contains("source images") == true)

        let emptyCredential = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: DeepInfraTestModelProvider()
        ) {
            try await G_DEEPINFRA_FLUX_2_KLEIN_4B().makeRequest(request: request(secret: "  "))
        }
        #expect(emptyCredential.status == .FAILED)
        #expect(emptyCredential.errorMessage?.contains("credentials are empty") == true)
        #expect(mock.requests.isEmpty)
    }

    @Test("Registers exact live model identifiers and provenance")
    func registersCatalogMetadata() throws {
        let models = DeepInfraModels.createModels()
        #expect(models.count == 2)
        let fourB = try #require(models.first { $0.modelCode == .DEEPINFRA_FLUX_2_KLEIN_4B })
        let nineB = try #require(models.first { $0.modelCode == .DEEPINFRA_FLUX_2_KLEIN_9B })

        #expect(fourB.providerId == EnumProviderCode.DEEPINFRA.providerId)
        #expect(fourB.modelGenerateBaseURL == "https://api.deepinfra.com/v1/openai/images/generations")
        #expect(fourB.pricingMetadata?.unit == .megapixel)
        #expect(fourB.pricingMetadata?.sourceURL == "https://deepinfra.com/black-forest-labs/FLUX-2-klein-4b/api")
        #expect(fourB.modelVerificationDate == getDateFromString("2026-07-10"))
        #expect(nineB.pricingMetadata?.sourceURL == "https://deepinfra.com/black-forest-labs/FLUX-2-klein-9b/api")
        #expect(nineB.active)
    }

    private func request(
        secret: String = "deepinfra-test-token",
        dimensions: String = "1344x768",
        numberOfImages: Int = 1
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: EnumProviderModelCode.DEEPINFRA_FLUX_2_KLEIN_4B.modelId.uuidString,
            prompt: "A precise airline poster",
            dimensions: dimensions,
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.DEEPINFRA.providerId,
                providerCode: .DEEPINFRA,
                projectId: UUID()
            ),
            providerSecret: secret,
            numberOfImages: numberOfImages
        )
    }
}

private final class DeepInfraMockNetworkProvider: @unchecked Sendable, NetworkProvider {
    struct CapturedRequest {
        let url: URL
        let method: String
        let headers: [String: String]?
        let body: Data?
    }

    var requests: [CapturedRequest] = []
    var singleAttemptRequestCount = 0
    private var responses: [NetworkResponseData]

    init(responses: [NetworkResponseData]) {
        self.responses = responses
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
}

private struct DeepInfraTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        DeepInfraModels.createModels().first { $0.modelCode == code }
    }
}
