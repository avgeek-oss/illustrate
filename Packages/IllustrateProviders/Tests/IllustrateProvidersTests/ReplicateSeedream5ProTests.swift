import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Replicate Seedream 5 Pro adapter", .serialized)
struct ReplicateSeedream5ProTests {
    @Test("Posts documented text payload and resolution estimate")
    func postsTextPayload() async throws {
        let mock = ReplicateSeedream5ProMockNetworkProvider()
        let adapter = G_REPLICATE_SEEDREAM_5_PRO()
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: ReplicateSeedream5ProTestModelProvider()
        ) {
            try await adapter.makeRequest(request: imageRequest(
                dimensions: "1920x1080",
                resolution: "1K"
            ))
        }

        let json = try capturedJSON(mock)
        let input = try #require(json["input"] as? [String: Any])
        #expect(mock.capturedURL?
            .absoluteString == "https://api.replicate.com/v1/models/bytedance/seedream-5-pro/predictions")
        #expect(mock.capturedMethod == "POST")
        #expect(mock.capturedHeaders?["Authorization"] == "Bearer replicate-test")
        #expect(input["prompt"] as? String == "A clean bilingual airport wayfinding poster.")
        #expect(input["image_input"] == nil)
        #expect(input["size"] as? String == "1K")
        #expect(input["aspect_ratio"] as? String == "16:9")
        #expect(input["output_format"] as? String == "png")
        #expect(input["seed"] == nil)
        #expect(response.status == .FAILED)
        #expect(response.errorMessage == "Invalid response")
        #expect(abs(adapter.getCostEstimate(request: costRequest(quality: "1K", numberOfImages: 2)) - 0.09) < 0.0001)
        #expect(adapter.formatCost(request: costRequest(quality: "2K")) == "$0.09")
    }

    @Test("Maps uploaded source and reference URLs to image_input")
    func mapsImageInputPayload() {
        let adapter = G_REPLICATE_SEEDREAM_5_PRO()
        let payload = adapter.transformRequest(
            request: imageRequest(dimensions: "match_input_image", resolution: "2K"),
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
        #expect(payload.size == "2K")
        #expect(payload.aspect_ratio == "match_input_image")
        #expect(payload.output_format == "png")
    }

    @Test("Parses data URI outputs with generation resolution pricing")
    func parsesDataURIOutput() throws {
        let mock = ReplicateSeedream5ProMockNetworkProvider()
        let response = try withProviderDependencies(
            networkProvider: mock,
            modelProvider: ReplicateSeedream5ProTestModelProvider()
        ) {
            try G_REPLICATE_SEEDREAM_5_PRO().transformResponse(
                request: imageRequest(resolution: "1K"),
                response: .dictionary(statusCode: 200, data: [
                    "status": "succeeded",
                    "output": ["data:image/png;base64,aW1hZ2U="],
                ])
            )
        }

        #expect(response.status == .GENERATED)
        #expect(response.base64 == "aW1hZ2U=")
        #expect(abs((response.cost ?? 0) - 0.045) < 0.0001)
    }

    @Test("Model metadata registers documented endpoint and capabilities")
    func modelMetadataIsRegistered() throws {
        let model = try #require(ReplicateModels.createModels().first {
            $0.modelCode == .REPLICATE_SEEDREAM_5_PRO
        })

        #expect(
            model.modelGenerateBaseURL == "https://api.replicate.com/v1/models/bytedance/seedream-5-pro/predictions"
        )
        #expect(model.modelStatusBaseURL == "https://api.replicate.com/v1/predictions")
        #expect(model.modelAPIDocumentationURL == "https://replicate.com/bytedance/seedream-5-pro")
        #expect(model.modelParams.maxGenerations == 1)
        #expect(model.modelParams.maxReferenceImages == 10)
        #expect(model.modelParams.supportedDimensions.contains("match_input_image"))
        #expect(model.modelParams.supportedDimensions.contains("21:9"))
        #expect(model.modelParams.supportedImageResolutions == ["1K", "2K"])
        #expect(model.modelParams.supportsSourceImage)
        #expect(!model.modelParams.supportsSeed)
    }

    private func capturedJSON(_ mock: ReplicateSeedream5ProMockNetworkProvider) throws -> [String: Any] {
        let data = try #require(mock.capturedBodyData)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func imageRequest(
        prompt: String = "A clean bilingual airport wayfinding poster.",
        dimensions: String = "1:1",
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

    private func costRequest(quality: String? = nil, numberOfImages: Int? = nil) -> ImageGenerationCostRequest {
        ImageGenerationCostRequest(quality: quality, numberOfImages: numberOfImages)
    }
}

private final class ReplicateSeedream5ProMockNetworkProvider: @unchecked Sendable, NetworkProvider {
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

private struct ReplicateSeedream5ProTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        ReplicateModels.createModels().first { $0.modelCode == code }
    }
}
