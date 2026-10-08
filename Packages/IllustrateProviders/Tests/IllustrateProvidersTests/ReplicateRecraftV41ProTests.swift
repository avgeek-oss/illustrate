import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Replicate Recraft V4.1 Pro adapter", .serialized)
struct ReplicateRecraftV41ProTests {
    @Test("Posts documented aspect-ratio payload and unit estimate")
    func postsAspectRatioPayload() async throws {
        let mock = ReplicateRecraftV41ProMockNetworkProvider()
        let adapter = G_REPLICATE_RECRAFT_V4_1_PRO()
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: ReplicateRecraftV41ProTestModelProvider()
        ) {
            try await adapter.makeRequest(request: imageRequest(
                dimensions: "1920x1080",
                numberOfImages: 2,
                seed: 42
            ))
        }

        let json = try capturedJSON(mock)
        let input = try #require(json["input"] as? [String: Any])
        #expect(mock.capturedURL?
            .absoluteString == "https://api.replicate.com/v1/models/recraft-ai/recraft-v4.1-pro/predictions")
        #expect(mock.capturedMethod == "POST")
        #expect(mock.capturedHeaders?["Authorization"] == "Bearer replicate-test")
        #expect(input["prompt"] as? String == "A premium airline poster with crisp typography.")
        #expect(input["aspect_ratio"] as? String == "16:9")
        #expect(input["size"] == nil)
        #expect(input["seed"] == nil)
        #expect(input["output_format"] == nil)
        #expect(response.status == .FAILED)
        #expect(abs(adapter.getCostEstimate(request: costRequest(numberOfImages: 2)) - 0.50) < 0.0001)
        #expect(adapter.formatCost(request: costRequest(numberOfImages: 2)) == "$0.5")
    }

    @Test("Uses documented size when selected directly")
    func postsSizePayload() {
        let adapter = G_REPLICATE_RECRAFT_V4_1_PRO()

        let request = adapter.transformRequest(request: imageRequest(dimensions: "3072x1536"))

        #expect(request.aspect_ratio == nil)
        #expect(request.size == "3072x1536")
    }

    @Test("Maps unsupported dimensions to nearest documented aspect ratio")
    func mapsUnsupportedDimensions() {
        let adapter = G_REPLICATE_RECRAFT_V4_1_PRO()

        let request = adapter.transformRequest(request: imageRequest(dimensions: "1536x1024"))

        #expect(request.aspect_ratio == "3:2")
        #expect(request.size == nil)
    }

    @Test("Parses data URI output")
    func parsesDataURIOutput() throws {
        configureReplicate(ReplicateRecraftV41ProMockNetworkProvider())

        let adapter = G_REPLICATE_RECRAFT_V4_1_PRO()
        let response = try adapter.transformResponse(
            request: imageRequest(),
            response: .dictionary(statusCode: 200, data: [
                "status": "succeeded",
                "output": "data:image/webp;base64,aW1hZ2U=",
            ])
        )

        #expect(response.status == .GENERATED)
        #expect(response.base64 == "aW1hZ2U=")
        #expect(abs((response.cost ?? 0) - 0.25) < 0.0001)
    }

    @Test("Failed prediction maps provider error")
    func failedPredictionMapsProviderError() throws {
        configureReplicate(ReplicateRecraftV41ProMockNetworkProvider())

        let response = try G_REPLICATE_RECRAFT_V4_1_PRO().transformResponse(
            request: imageRequest(),
            response: .dictionary(statusCode: 200, data: [
                "status": "failed",
                "error": "quota exceeded",
            ])
        )

        #expect(response.status == .FAILED)
        #expect(response.errorMessage == "quota exceeded")
    }

    @Test("Network failures map to failed response")
    func networkFailureMapsToModelError() async throws {
        let mock = ReplicateRecraftV41ProMockNetworkProvider(error: URLError(.notConnectedToInternet))
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: ReplicateRecraftV41ProTestModelProvider()
        ) {
            try await G_REPLICATE_RECRAFT_V4_1_PRO().makeRequest(request: imageRequest())
        }

        #expect(response.status == .FAILED)
        #expect(response.errorCode == .MODEL_ERROR)
        #expect(response.errorMessage?.contains("Failed with error:") == true)
    }

    @Test("Model metadata registers endpoint and documented dimensions")
    func modelMetadataIsRegistered() throws {
        let models = ReplicateModels.createModels()
        let model = try #require(models.first { $0.modelCode == .REPLICATE_RECRAFT_V4_1_PRO })

        #expect(model.modelName == "Recraft V4.1 Pro")
        #expect(model
            .modelGenerateBaseURL == "https://api.replicate.com/v1/models/recraft-ai/recraft-v4.1-pro/predictions")
        #expect(model.modelAPIDocumentationURL == "https://replicate.com/recraft-ai/recraft-v4.1-pro")
        #expect(model.modelParams.maxGenerations == 1)
        #expect(model.modelParams.maxPromptLength == 10000)
        #expect(!model.modelParams.supportsSeed)
        #expect(model.modelParams.supportedDimensions.contains("10:14"))
        #expect(model.modelParams.supportedDimensions.contains("3072x1536"))
    }

    private func configureReplicate(_ mock: ReplicateRecraftV41ProMockNetworkProvider) {
        ProviderDependencies.shared.configure(
            networkProvider: mock,
            modelProvider: ReplicateRecraftV41ProTestModelProvider()
        )
    }

    private func capturedJSON(_ mock: ReplicateRecraftV41ProMockNetworkProvider) throws -> [String: Any] {
        let data = try #require(mock.capturedBodyData)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func imageRequest(
        prompt: String = "A premium airline poster with crisp typography.",
        dimensions: String = "16:9",
        numberOfImages: Int = 1,
        seed: Int? = nil
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: UUID().uuidString,
            prompt: prompt,
            dimensions: dimensions,
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.REPLICATE.providerId,
                providerCode: .REPLICATE,
                projectId: UUID()
            ),
            providerSecret: "replicate-test",
            numberOfImages: numberOfImages,
            seed: seed
        )
    }

    private func costRequest(numberOfImages: Int? = nil) -> ImageGenerationCostRequest {
        ImageGenerationCostRequest(numberOfImages: numberOfImages)
    }
}

private final class ReplicateRecraftV41ProMockNetworkProvider: @unchecked Sendable, NetworkProvider {
    var capturedURL: URL?
    var capturedMethod: String?
    var capturedBodyData: Data?
    var capturedHeaders: [String: String]?
    let response: NetworkResponseData
    let error: Error?

    init(
        response: NetworkResponseData = .dictionary(statusCode: 400, data: ["error": "stubbed replicate response"]),
        error: Error? = nil
    ) {
        self.response = response
        self.error = error
    }

    func performRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseData {
        if let error {
            throw error
        }
        capturedURL = url
        capturedMethod = method
        capturedHeaders = headers
        if let body {
            capturedBodyData = try JSONEncoder().encode(body)
        }
        return response
    }
}

private struct ReplicateRecraftV41ProTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        ReplicateModels.createModels().first { $0.modelCode == code }
    }
}
