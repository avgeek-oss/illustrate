import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Replicate Gemini 2.5 Flash Image adapter", .serialized)
struct ReplicateGemini25FlashImageTests {
    @Test("Posts documented text payload and unit estimate")
    func postsTextPayload() async throws {
        let mock = ReplicateGemini25FlashImageMockNetworkProvider()
        let adapter = G_REPLICATE_GOOGLE_GEMINI_2_5_FLASH_IMAGE()
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: ReplicateGemini25FlashImageTestModelProvider()
        ) {
            try await adapter.makeRequest(request: imageRequest(
                dimensions: "1920x1080",
                numberOfImages: 2
            ))
        }

        let json = try capturedJSON(mock)
        let input = try #require(json["input"] as? [String: Any])
        #expect(mock.capturedURL?
            .absoluteString == "https://api.replicate.com/v1/models/google/gemini-2.5-flash-image/predictions")
        #expect(mock.capturedMethod == "POST")
        #expect(mock.capturedHeaders?["Authorization"] == "Bearer replicate-test")
        #expect(input["prompt"] as? String == "A clean bilingual airport wayfinding poster.")
        #expect(input["image_input"] == nil)
        #expect(input["aspect_ratio"] as? String == "16:9")
        #expect(input["output_format"] as? String == "png")
        #expect(response.status == .FAILED)
        #expect(response.errorMessage == "Failed to create prediction")
        #expect(abs(adapter.getCostEstimate(request: costRequest(numberOfImages: 2)) - 0.078) < 0.0001)
        #expect(adapter.formatCost(request: costRequest(numberOfImages: 2)) == "$0.08")
    }

    @Test("Maps uploaded source and reference URLs to image_input")
    func mapsImageInputPayload() {
        let adapter = G_REPLICATE_GOOGLE_GEMINI_2_5_FLASH_IMAGE()
        let payload = adapter.transformRequest(
            request: imageRequest(dimensions: "match_input_image"),
            imageURLs: [
                "https://files.example/source.png",
                "https://files.example/reference-1.png",
                "https://files.example/reference-2.webp",
            ]
        )

        #expect(payload.prompt == "A clean bilingual airport wayfinding poster.")
        #expect(payload.image_input == [
            "https://files.example/source.png",
            "https://files.example/reference-1.png",
            "https://files.example/reference-2.webp",
        ])
        #expect(payload.aspect_ratio == "match_input_image")
        #expect(payload.output_format == "png")
    }

    @Test("Parses string and array URL outputs")
    func parsesURLOutputs() throws {
        configureReplicate(ReplicateGemini25FlashImageMockNetworkProvider())

        let dataURIResponse = try G_REPLICATE_GOOGLE_GEMINI_2_5_FLASH_IMAGE().transformResponse(
            request: imageRequest(numberOfImages: 2),
            response: .dictionary(statusCode: 200, data: [
                "status": "succeeded",
                "output": ["data:image/png;base64,aW1hZ2U="],
            ])
        )

        #expect(dataURIResponse.status == .GENERATED)
        #expect(dataURIResponse.base64 == "aW1hZ2U=")
        #expect(abs((dataURIResponse.cost ?? 0) - 0.078) < 0.0001)
    }

    @Test("Failed prediction maps provider error")
    func failedPredictionMapsError() throws {
        configureReplicate(ReplicateGemini25FlashImageMockNetworkProvider())

        let response = try G_REPLICATE_GOOGLE_GEMINI_2_5_FLASH_IMAGE().transformResponse(
            request: imageRequest(),
            response: .dictionary(statusCode: 200, data: [
                "status": "failed",
                "error": "quota exceeded",
            ])
        )

        #expect(response.status == .FAILED)
        #expect(response.errorMessage == "quota exceeded")
    }

    @Test("Model metadata registers documented endpoint and capabilities")
    func modelMetadataIsRegistered() throws {
        let model = try #require(ReplicateModels.createModels().first {
            $0.modelCode == .REPLICATE_GOOGLE_GEMINI_2_5_FLASH_IMAGE
        })

        #expect(
            model.modelGenerateBaseURL == "https://api.replicate.com/v1/models/google/gemini-2.5-flash-image/predictions"
        )
        #expect(model.modelStatusBaseURL == "https://api.replicate.com/v1/predictions")
        #expect(model.modelAPIDocumentationURL == "https://replicate.com/google/gemini-2.5-flash-image")
        #expect(model.modelParams.maxGenerations == 1)
        #expect(model.modelParams.maxReferenceImages == 4)
        #expect(model.modelParams.supportedDimensions.contains("match_input_image"))
        #expect(model.modelParams.supportedDimensions.contains("21:9"))
        #expect(model.modelParams.supportsSourceImage)
    }

    private func configureReplicate(_ mock: ReplicateGemini25FlashImageMockNetworkProvider) {
        ProviderDependencies.shared.configure(
            networkProvider: mock,
            modelProvider: ReplicateGemini25FlashImageTestModelProvider()
        )
    }

    private func capturedJSON(_ mock: ReplicateGemini25FlashImageMockNetworkProvider) throws -> [String: Any] {
        let data = try #require(mock.capturedBodyData)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func imageRequest(
        prompt: String = "A clean bilingual airport wayfinding poster.",
        dimensions: String = "1:1",
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
            numberOfImages: numberOfImages
        )
    }

    private func costRequest(numberOfImages: Int? = nil) -> ImageGenerationCostRequest {
        ImageGenerationCostRequest(numberOfImages: numberOfImages)
    }
}

private final class ReplicateGemini25FlashImageMockNetworkProvider: @unchecked Sendable, NetworkProvider {
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

private struct ReplicateGemini25FlashImageTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        ReplicateModels.createModels().first { $0.modelCode == code }
    }
}
