import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Replicate Krea 2 adapters", .serialized)
struct ReplicateKrea2Tests {
    @Test("Medium posts documented text-to-image payload and unit estimate")
    func mediumPostsPayload() async throws {
        let mock = ReplicateKrea2MockNetworkProvider()
        let adapter = G_REPLICATE_KREA_2_MEDIUM()
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: ReplicateKrea2TestModelProvider()
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
            .absoluteString == "https://api.replicate.com/v1/models/krea/krea-2-medium/predictions")
        #expect(mock.capturedMethod == "POST")
        #expect(mock.capturedHeaders?["Authorization"] == "Bearer replicate-test")
        #expect(input["prompt"] as? String == "A crisp aviation poster with readable runway signage.")
        #expect(input["aspect_ratio"] as? String == "16:9")
        #expect(input["creativity"] as? String == "medium")
        #expect(input["seed"] as? Int == 42)
        #expect(input["style_reference_images"] == nil)
        #expect(input["moodboard_id"] == nil)
        #expect(response.status == .FAILED)
        #expect(abs(adapter.getCostEstimate(request: costRequest(numberOfImages: 2)) - 0.06) < 0.0001)
        #expect(adapter.formatCost(request: costRequest(numberOfImages: 2)) == "$0.06")
    }

    @Test("Large maps exact and closest supported aspect ratios")
    func largeMapsAspectRatios() {
        let adapter = G_REPLICATE_KREA_2_LARGE()

        let exact = adapter.transformRequest(request: imageRequest(dimensions: "2.35:1"))
        #expect(exact.aspect_ratio == "2.35:1")

        let closest = adapter.transformRequest(request: imageRequest(dimensions: "1536x1024"))
        #expect(closest.aspect_ratio == "3:2")

        #expect(abs(adapter.getCostEstimate(request: costRequest(numberOfImages: 2)) - 0.12) < 0.0001)
    }

    @Test("Large parses data URI output")
    func largeParsesDataURIOutput() throws {
        try withProviderDependencies(
            networkProvider: ReplicateKrea2MockNetworkProvider(),
            modelProvider: ReplicateKrea2TestModelProvider()
        ) {
            let adapter = G_REPLICATE_KREA_2_LARGE()
            let response = try adapter.transformResponse(
                request: imageRequest(),
                response: .dictionary(statusCode: 200, data: [
                    "status": "succeeded",
                    "output": "data:image/png;base64,aW1hZ2U=",
                ])
            )

            #expect(response.status == .GENERATED)
            #expect(response.base64 == "aW1hZ2U=")
            #expect(abs((response.cost ?? 0) - 0.06) < 0.0001)
        }
    }

    @Test("Failed prediction maps provider error")
    func failedPredictionMapsError() throws {
        try withProviderDependencies(
            networkProvider: ReplicateKrea2MockNetworkProvider(),
            modelProvider: ReplicateKrea2TestModelProvider()
        ) {
            let adapter = G_REPLICATE_KREA_2_MEDIUM()
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
    }

    @Test("Network failures map to failed response")
    func networkFailureMapsToModelError() async throws {
        let mock = ReplicateKrea2MockNetworkProvider(error: URLError(.notConnectedToInternet))
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: ReplicateKrea2TestModelProvider()
        ) {
            try await G_REPLICATE_KREA_2_MEDIUM().makeRequest(request: imageRequest())
        }

        #expect(response.status == .FAILED)
        #expect(response.errorCode == .MODEL_ERROR)
        #expect(response.errorMessage?.contains("Failed with error:") == true)
    }

    @Test("Model metadata registers endpoints and documented aspect ratios")
    func modelMetadataIsRegistered() throws {
        let models = ReplicateModels.createModels()

        let medium = try #require(models.first { $0.modelCode == .REPLICATE_KREA_2_MEDIUM })
        #expect(medium.modelGenerateBaseURL == "https://api.replicate.com/v1/models/krea/krea-2-medium/predictions")
        #expect(medium.modelAPIDocumentationURL == "https://replicate.com/krea/krea-2-medium")
        #expect(medium.modelParams.maxGenerations == 1)
        #expect(medium.modelParams.supportsSeed)
        #expect(medium.modelParams.supportedDimensions.contains("2.35:1"))

        let large = try #require(models.first { $0.modelCode == .REPLICATE_KREA_2_LARGE })
        #expect(large.modelGenerateBaseURL == "https://api.replicate.com/v1/models/krea/krea-2-large/predictions")
        #expect(large.modelAPIDocumentationURL == "https://replicate.com/krea/krea-2-large")
        #expect(large.modelParams.supportedDimensions.contains("16:9"))
    }

    private func capturedJSON(_ mock: ReplicateKrea2MockNetworkProvider) throws -> [String: Any] {
        let data = try #require(mock.capturedBodyData)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func imageRequest(
        prompt: String = "A crisp aviation poster with readable runway signage.",
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

private final class ReplicateKrea2MockNetworkProvider: @unchecked Sendable, NetworkProvider {
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

private struct ReplicateKrea2TestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        ReplicateModels.createModels().first { $0.modelCode == code }
    }
}
