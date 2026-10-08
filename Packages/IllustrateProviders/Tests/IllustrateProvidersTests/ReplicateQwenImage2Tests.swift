import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Replicate Qwen Image 2 adapters", .serialized)
struct ReplicateQwenImage2Tests {
    @Test("Qwen Image 2 posts documented text payload and unit estimate")
    func qwenImage2PostsTextPayload() async throws {
        let mock = ReplicateQwenImage2MockNetworkProvider()

        let adapter = G_REPLICATE_QWEN_IMAGE_2()
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: ReplicateQwenImage2TestModelProvider()
        ) {
            try await adapter.makeRequest(request: imageRequest(
                dimensions: "1920x1080",
                negativePrompt: "watermark",
                numberOfImages: 2,
                promptEnhance: false,
                seed: 42
            ))
        }

        let json = try capturedJSON(mock)
        let input = try #require(json["input"] as? [String: Any])
        #expect(mock.capturedURL?
            .absoluteString == "https://api.replicate.com/v1/models/qwen/qwen-image-2/predictions")
        #expect(mock.capturedMethod == "POST")
        #expect(mock.capturedHeaders?["Authorization"] == "Bearer replicate-test")
        #expect(input["prompt"] as? String == "A clean bilingual airport wayfinding poster.")
        #expect(input["image"] == nil)
        #expect(input["match_input_image"] as? Bool == false)
        #expect(input["aspect_ratio"] as? String == "16:9")
        #expect(input["enable_prompt_expansion"] as? Bool == false)
        #expect(input["negative_prompt"] as? String == "watermark")
        #expect(input["seed"] as? Int == 42)
        #expect(response.status == .FAILED)
        #expect(response.errorMessage == "stubbed replicate response")
        #expect(abs(adapter.getCostEstimate(request: costRequest(numberOfImages: 2)) - 0.07) < 0.0001)
        #expect(adapter.formatCost(request: costRequest(numberOfImages: 2)) == "$0.07")
    }

    @Test("Qwen Image 2 Pro maps image edit payload and pro price")
    func qwenImage2ProMapsImagePayload() {
        let adapter = G_REPLICATE_QWEN_IMAGE_2_PRO()
        let payload = adapter.transformRequest(
            request: imageRequest(
                dimensions: "2:1",
                numberOfImages: 3,
                seed: 77
            ),
            imageURL: "https://files.example/source.png"
        )

        #expect(payload.image == "https://files.example/source.png")
        #expect(payload.match_input_image == true)
        #expect(payload.aspect_ratio == "2:1")
        #expect(payload.enable_prompt_expansion == true)
        #expect(payload.negative_prompt == "")
        #expect(payload.seed == 77)
        #expect(abs(adapter.getCostEstimate(request: costRequest(numberOfImages: 3)) - 0.225) < 0.0001)
    }

    @Test("Qwen Image 2 parses data URI output")
    func parsesDataURIOutput() throws {
        configureReplicate(ReplicateQwenImage2MockNetworkProvider())

        let response = try G_REPLICATE_QWEN_IMAGE_2_PRO().transformResponse(
            request: imageRequest(numberOfImages: 2),
            response: .dictionary(statusCode: 200, data: [
                "status": "succeeded",
                "output": ["data:image/png;base64,aW1hZ2U="],
            ])
        )

        #expect(response.status == .GENERATED)
        #expect(response.base64 == "aW1hZ2U=")
        #expect(abs((response.cost ?? 0) - 0.15) < 0.0001)
    }

    @Test("Failed prediction maps provider error")
    func failedPredictionMapsError() throws {
        configureReplicate(ReplicateQwenImage2MockNetworkProvider())

        let response = try G_REPLICATE_QWEN_IMAGE_2().transformResponse(
            request: imageRequest(),
            response: .dictionary(statusCode: 200, data: [
                "status": "failed",
                "error": "quota exceeded",
            ])
        )

        #expect(response.status == .FAILED)
        #expect(response.errorMessage == "quota exceeded")
    }

    @Test("Model metadata registers endpoints and documented schema capabilities")
    func modelMetadataIsRegistered() throws {
        let models = ReplicateModels.createModels()
        let standard = try #require(models.first { $0.modelCode == .REPLICATE_QWEN_IMAGE_2 })
        let pro = try #require(models.first { $0.modelCode == .REPLICATE_QWEN_IMAGE_2_PRO })

        #expect(standard.modelGenerateBaseURL == "https://api.replicate.com/v1/models/qwen/qwen-image-2/predictions")
        #expect(standard.modelAPIDocumentationURL == "https://replicate.com/qwen/qwen-image-2")
        #expect(standard.modelParams.maxGenerations == 1)
        #expect(standard.modelParams.maxReferenceImages == 1)
        #expect(standard.modelParams.supportedDimensions.contains("2:1"))
        #expect(standard.modelParams.supportsNegativePrompt)
        #expect(standard.modelParams.supportsPromptEnhance)
        #expect(standard.modelParams.supportsSeed)
        #expect(standard.modelParams.supportsSourceImage)

        #expect(pro.modelGenerateBaseURL == "https://api.replicate.com/v1/models/qwen/qwen-image-2-pro/predictions")
        #expect(pro.modelAPIDocumentationURL == "https://replicate.com/qwen/qwen-image-2-pro")
        #expect(pro.modelParams.supportedDimensions.contains("1:2"))
    }

    private func configureReplicate(_ mock: ReplicateQwenImage2MockNetworkProvider) {
        ProviderDependencies.shared.configure(
            networkProvider: mock,
            modelProvider: ReplicateQwenImage2TestModelProvider()
        )
    }

    private func capturedJSON(_ mock: ReplicateQwenImage2MockNetworkProvider) throws -> [String: Any] {
        let data = try #require(mock.capturedBodyData)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func imageRequest(
        prompt: String = "A clean bilingual airport wayfinding poster.",
        dimensions: String = "1:1",
        negativePrompt: String? = nil,
        numberOfImages: Int = 1,
        promptEnhance: Bool? = nil,
        seed: Int? = nil
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: UUID().uuidString,
            prompt: prompt,
            negativePrompt: negativePrompt,
            dimensions: dimensions,
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.REPLICATE.providerId,
                providerCode: .REPLICATE,
                projectId: UUID()
            ),
            providerSecret: "replicate-test",
            numberOfImages: numberOfImages,
            seed: seed,
            promptEnhance: promptEnhance
        )
    }

    private func costRequest(numberOfImages: Int? = nil) -> ImageGenerationCostRequest {
        ImageGenerationCostRequest(numberOfImages: numberOfImages)
    }
}

private final class ReplicateQwenImage2MockNetworkProvider: @unchecked Sendable, NetworkProvider {
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

private struct ReplicateQwenImage2TestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        ReplicateModels.createModels().first { $0.modelCode == code }
    }
}
