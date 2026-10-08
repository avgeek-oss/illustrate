import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Replicate Ideogram V4 adapters", .serialized)
struct ReplicateIdeogramV4Tests {
    @Test("Turbo posts documented resolution payload and unit estimate")
    func turboPostsResolutionPayload() async throws {
        let mock = ReplicateIdeogramV4MockNetworkProvider()

        let adapter = G_REPLICATE_IDEOGRAM_V4_TURBO()
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: ReplicateIdeogramV4TestModelProvider()
        ) {
            try await adapter.makeRequest(request: imageRequest(
                dimensions: "1920x1080",
                numberOfImages: 3
            ))
        }

        let json = try capturedJSON(mock)
        let input = try #require(json["input"] as? [String: Any])
        #expect(mock.capturedURL?
            .absoluteString == "https://api.replicate.com/v1/models/ideogram-ai/ideogram-v4-turbo/predictions")
        #expect(mock.capturedMethod == "POST")
        #expect(mock.capturedHeaders?["Authorization"] == "Bearer replicate-test")
        #expect(input["prompt"] as? String == "A crisp aviation poster with readable runway signage.")
        #expect(input["resolution"] as? String == "2560x1440")
        #expect(input["enable_copyright_detection"] as? Bool == false)
        #expect(input["json_prompt"] == nil)
        #expect(input["aspect_ratio"] == nil)
        #expect(input["seed"] == nil)
        #expect(response.status == .FAILED)
        #expect(abs(adapter.getCostEstimate(request: costRequest(numberOfImages: 3)) - 0.09) < 0.0001)
        #expect(adapter.formatCost(request: costRequest(numberOfImages: 3)) == "$0.09")
    }

    @Test("Balanced keeps exact supported resolution")
    func balancedKeepsExactResolution() {
        let adapter = G_REPLICATE_IDEOGRAM_V4_BALANCED()
        let serviceRequest = adapter.transformRequest(request: imageRequest(
            dimensions: "2048x2048",
            resolution: "1440x2880"
        ))

        #expect(serviceRequest.resolution == "1440x2880")
        #expect(abs(adapter.getCostEstimate(request: costRequest(numberOfImages: 2)) - 0.12) < 0.0001)
    }

    @Test("Quality parses data URI output")
    func qualityParsesDataURIOutput() throws {
        configureReplicate(ReplicateIdeogramV4MockNetworkProvider())

        let adapter = G_REPLICATE_IDEOGRAM_V4_QUALITY()
        let response = try adapter.transformResponse(
            request: imageRequest(),
            response: .dictionary(statusCode: 200, data: [
                "status": "succeeded",
                "output": "data:image/png;base64,aW1hZ2U=",
            ])
        )

        #expect(response.status == .GENERATED)
        #expect(response.base64 == "aW1hZ2U=")
        #expect(abs((response.cost ?? 0) - 0.10) < 0.0001)
    }

    @Test("Failed prediction maps provider error")
    func failedPredictionMapsError() throws {
        configureReplicate(ReplicateIdeogramV4MockNetworkProvider())

        let adapter = G_REPLICATE_IDEOGRAM_V4_TURBO()
        let response = try adapter.transformResponse(
            request: imageRequest(),
            response: .dictionary(statusCode: 200, data: [
                "status": "failed",
                "error": "quota exceeded",
            ])
        )

        #expect(response.status == .FAILED)
        #expect(response.errorMessage == "quota exceeded")
    }

    @Test("Model metadata registers endpoints and documented dimensions")
    func modelMetadataIsRegistered() throws {
        let models = ReplicateModels.createModels()

        let turbo = try #require(models.first { $0.modelCode == .REPLICATE_IDEOGRAM_V4_TURBO })
        #expect(turbo
            .modelGenerateBaseURL == "https://api.replicate.com/v1/models/ideogram-ai/ideogram-v4-turbo/predictions")
        #expect(turbo.modelAPIDocumentationURL == "https://replicate.com/ideogram-ai/ideogram-v4-turbo")
        #expect(turbo.modelParams.maxGenerations == 1)
        #expect(turbo.modelParams.supportedDimensions.contains("2048x2048"))
        #expect(turbo.modelParams.supportedDimensions.contains("3072x1280"))

        let balanced = try #require(models.first { $0.modelCode == .REPLICATE_IDEOGRAM_V4_BALANCED })
        #expect(balanced
            .modelGenerateBaseURL == "https://api.replicate.com/v1/models/ideogram-ai/ideogram-v4-balanced/predictions")

        let quality = try #require(models.first { $0.modelCode == .REPLICATE_IDEOGRAM_V4_QUALITY })
        #expect(quality
            .modelGenerateBaseURL == "https://api.replicate.com/v1/models/ideogram-ai/ideogram-v4-quality/predictions")
    }

    private func configureReplicate(_ mock: ReplicateIdeogramV4MockNetworkProvider) {
        ProviderDependencies.shared.configure(
            networkProvider: mock,
            modelProvider: ReplicateIdeogramV4TestModelProvider()
        )
    }

    private func capturedJSON(_ mock: ReplicateIdeogramV4MockNetworkProvider) throws -> [String: Any] {
        let data = try #require(mock.capturedBodyData)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func imageRequest(
        prompt: String = "A crisp aviation poster with readable runway signage.",
        dimensions: String = "16:9",
        resolution: String? = nil,
        numberOfImages: Int = 1
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
            resolution: resolution
        )
    }

    private func costRequest(numberOfImages: Int? = nil) -> ImageGenerationCostRequest {
        ImageGenerationCostRequest(numberOfImages: numberOfImages)
    }
}

private final class ReplicateIdeogramV4MockNetworkProvider: @unchecked Sendable, NetworkProvider {
    var capturedURL: URL?
    var capturedMethod: String?
    var capturedBodyData: Data?
    var capturedHeaders: [String: String]?
    let response: NetworkResponseData

    init(response: NetworkResponseData = .dictionary(statusCode: 400, data: ["error": "stubbed replicate response"])) {
        self.response = response
    }

    func performRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseData {
        capturedURL = url
        capturedMethod = method
        capturedHeaders = headers
        if let body {
            capturedBodyData = try JSONEncoder().encode(body)
        }
        return response
    }
}

private struct ReplicateIdeogramV4TestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        ReplicateModels.createModels().first { $0.modelCode == code }
    }
}
