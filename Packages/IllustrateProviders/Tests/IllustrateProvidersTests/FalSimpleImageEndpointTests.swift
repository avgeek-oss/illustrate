import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Fal simple image endpoint adapters", .serialized)
struct FalSimpleImageEndpointTests {
    @Test("Flux 2 Klein 9B posts documented payload and megapixel estimate")
    func flux2Klein9BPostsPayload() async throws {
        let mock = FalImageMockNetworkProvider()

        let adapter = G_FAL_FLUX_2_KLEIN_9B()
        _ = try await withProviderDependencies(networkProvider: mock, modelProvider: FalImageTestModelProvider()) {
            try await adapter.makeRequest(request: imageRequest(
                dimensions: "1920x1080",
                numberOfImages: 2,
                seed: 42,
                safetyTolerance: 3
            ))
        }

        let json = try capturedJSON(mock)
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/fal-ai/flux-2/klein/9b")
        #expect(mock.capturedHeaders?["Authorization"] == "Key fal-test")
        #expect(json["prompt"] as? String == "A crisp aviation poster with readable runway signage.")
        #expect(json["image_size"] as? String == "landscape_16_9")
        #expect(json["num_images"] as? Int == 2)
        #expect(json["seed"] as? Int == 42)
        #expect(json["safety_tolerance"] as? String == "3")
        #expect(json["output_format"] as? String == "png")
        #expect(json["sync_mode"] as? Bool == true)
        #expect(abs(adapter.getCostEstimate(request: costRequest(dimensions: "1920x1080", numberOfImages: 2)) -
                0.0248832) < 0.0001)
    }

    @Test("Krea 2 Turbo uses prompt expansion and megapixel estimate")
    func krea2TurboPostsPayload() async throws {
        let mock = FalImageMockNetworkProvider()

        let adapter = G_FAL_KREA_2_TURBO()
        _ = try await withProviderDependencies(networkProvider: mock, modelProvider: FalImageTestModelProvider()) {
            try await adapter.makeRequest(request: imageRequest(
                dimensions: "1024x1024",
                numberOfImages: 5,
                seed: 7,
                promptEnhance: true
            ))
        }

        let json = try capturedJSON(mock)
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/fal-ai/krea-2/turbo")
        #expect(json["image_size"] as? String == "square_hd")
        #expect(json["num_images"] as? Int == 4)
        #expect(json["seed"] as? Int == 7)
        #expect(json["output_format"] as? String == "png")
        #expect(json["enable_prompt_expansion"] as? Bool == true)
        #expect(abs(adapter.getCostEstimate(request: costRequest(dimensions: "1024x1024", numberOfImages: 3)) -
                0.0251658) < 0.0001)
    }

    @Test("Ideogram V4 uses balanced rendering and unit estimate")
    func ideogramV4PostsPayload() async throws {
        let mock = FalImageMockNetworkProvider()

        let adapter = G_FAL_IDEOGRAM_V4()
        _ = try await withProviderDependencies(networkProvider: mock, modelProvider: FalImageTestModelProvider()) {
            try await adapter.makeRequest(request: imageRequest(
                dimensions: "1080x1920",
                numberOfImages: 3,
                seed: 88
            ))
        }

        let json = try capturedJSON(mock)
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/ideogram/v4")
        #expect(json["image_size"] as? String == "portrait_16_9")
        #expect(json["num_images"] as? Int == 3)
        #expect(json["seed"] as? Int == 88)
        #expect(json["output_format"] as? String == "png")
        #expect(json["rendering_speed"] as? String == "BALANCED")
        #expect(abs(adapter.getCostEstimate(request: costRequest(numberOfImages: 3)) - 0.0429153442) < 0.0001)
    }

    @Test("Nano Banana Lite text omits experimental fields and parses images output")
    func nanoBananaLiteTextPostsPayloadAndParsesResponse() async throws {
        let mock = FalImageMockNetworkProvider(response: .dictionary(
            statusCode: 200,
            data: ["images": [["url": "data:image/png;base64,aW1hZ2U="]]]
        ))

        let adapter = G_FAL_GOOGLE_NANO_BANANA_LITE()
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: FalImageTestModelProvider()
        ) {
            try await adapter.makeRequest(request: imageRequest(
                dimensions: "4:1",
                numberOfImages: 2,
                seed: 9
            ))
        }

        let json = try capturedJSON(mock)
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/google/nano-banana-lite")
        #expect(json["aspect_ratio"] as? String == "4:1")
        #expect(json["num_images"] as? Int == 2)
        #expect(json["seed"] as? Int == 9)
        #expect(json["output_format"] as? String == "png")
        #expect(json["resolution"] == nil)
        #expect(json["system_prompt"] == nil)
        #expect(json["limit_generations"] == nil)
        #expect(json["thinking_level"] == nil)
        #expect(response.status == .GENERATED)
        #expect(response.base64 == "aW1hZ2U=")
        #expect(abs((response.cost ?? 0) - 0.0796) < 0.0001)
        #expect(adapter.formatCost(request: costRequest(numberOfImages: 2)).hasSuffix("+"))
    }

    @Test("Nano Banana Lite edit posts source image URL")
    func nanoBananaLiteEditPostsPayload() async throws {
        let mock = FalImageMockNetworkProvider()

        let adapter = G_FAL_GOOGLE_NANO_BANANA_LITE_EDIT()
        _ = try await withProviderDependencies(networkProvider: mock, modelProvider: FalImageTestModelProvider()) {
            try await adapter.makeRequest(request: imageRequest(
                dimensions: "16:9",
                clientImage: "source-image",
                numberOfImages: 1,
                seed: 11
            ))
        }

        let json = try capturedJSON(mock)
        let imageURLs = try #require(json["image_urls"] as? [String])
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/google/nano-banana-lite/edit")
        #expect(imageURLs == ["data:image/png;base64,source-image"])
        #expect(json["aspect_ratio"] as? String == "auto")
        #expect(json["output_format"] as? String == "png")
        #expect(json["resolution"] == nil)
        #expect(json["system_prompt"] == nil)
        #expect(json["limit_generations"] == nil)
        #expect(json["thinking_level"] == nil)
    }

    @Test("Nano Banana 2 Lite text posts simple payload without resolution")
    func nanoBanana2LitePostsPayload() async throws {
        let mock = FalImageMockNetworkProvider()

        let adapter = G_FAL_GOOGLE_NANO_BANANA_2_LITE()
        _ = try await withProviderDependencies(networkProvider: mock, modelProvider: FalImageTestModelProvider()) {
            try await adapter.makeRequest(request: imageRequest(
                dimensions: "8:1",
                numberOfImages: 3,
                seed: 12
            ))
        }

        let json = try capturedJSON(mock)
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/google/nano-banana-2-lite")
        #expect(json["aspect_ratio"] as? String == "8:1")
        #expect(json["num_images"] as? Int == 3)
        #expect(json["output_format"] as? String == "png")
        #expect(json["resolution"] == nil)
        #expect(adapter.formatCost(request: costRequest(numberOfImages: 3)).hasSuffix("+"))
    }

    @Test("Seedream 5 Pro text posts documented payload without seed")
    func seedream5ProTextPostsPayload() async throws {
        let mock = FalImageMockNetworkProvider()

        let adapter = G_FAL_BYTEDANCE_SEEDREAM_V5_PRO_TEXT_TO_IMAGE()
        _ = try await withProviderDependencies(networkProvider: mock, modelProvider: FalImageTestModelProvider()) {
            try await adapter.makeRequest(request: imageRequest(
                numberOfImages: 7,
                seed: 99,
                resolution: "1K"
            ))
        }

        let json = try capturedJSON(mock)
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/bytedance/seedream/v5/pro/text-to-image")
        #expect(json["prompt"] as? String == "A crisp aviation poster with readable runway signage.")
        #expect(json["image_size"] as? String == "auto_1K")
        #expect(json["num_images"] as? Int == 6)
        #expect(json["output_format"] as? String == "png")
        #expect(json["sync_mode"] as? Bool == true)
        #expect(json["enable_safety_checker"] as? Bool == true)
        #expect(json["seed"] == nil)
        #expect(abs(adapter.getCostEstimate(request: costRequest(numberOfImages: 2)) - 0.27) < 0.0001)
    }

    @Test("Seedream 5 Pro edit posts source and references")
    func seedream5ProEditPostsReferencePayload() async throws {
        let mock = FalImageMockNetworkProvider()

        let adapter = G_FAL_BYTEDANCE_SEEDREAM_V5_PRO_EDIT()
        _ = try await withProviderDependencies(networkProvider: mock, modelProvider: FalImageTestModelProvider()) {
            try await adapter.makeRequest(request: imageRequest(
                clientImage: "source-image",
                clientReferenceImages: [
                    ReferenceImageData(base64Image: "reference-one"),
                    ReferenceImageData(base64Image: "data:image/jpeg;base64,reference-two", mimeType: "image/jpeg"),
                ],
                numberOfImages: 2,
                resolution: "2K"
            ))
        }

        let json = try capturedJSON(mock)
        let imageURLs = try #require(json["image_urls"] as? [String])
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/bytedance/seedream/v5/pro/edit")
        #expect(imageURLs == [
            "data:image/png;base64,source-image",
            "data:image/png;base64,reference-one",
            "data:image/jpeg;base64,reference-two",
        ])
        #expect(json["image_size"] as? String == "auto_2K")
        #expect(json["num_images"] as? Int == 2)
        #expect(json["output_format"] as? String == "png")
        #expect(json["enable_safety_checker"] as? Bool == true)
        #expect(json["seed"] == nil)
        #expect(abs(adapter.getCostEstimate(request: costRequest(
            numberOfImages: 2,
            referenceImageCount: 2
        )) - 0.279) < 0.0001)
    }

    @Test("New Fal model metadata exposes only supported simple controls")
    func modelMetadataIsRegistered() throws {
        let models = FALModels.createModels()

        let flux9B = try #require(models.first { $0.modelCode == .FAL_FLUX_2_KLEIN_9B })
        #expect(flux9B.modelGenerateBaseURL == "https://fal.run/fal-ai/flux-2/klein/9b")
        #expect(flux9B.modelParams.supportsSeed)
        #expect(flux9B.modelParams.supportsSafetyRange)

        let liteEdit = try #require(models.first { $0.modelCode == .FAL_GOOGLE_NANO_BANANA_LITE_EDIT })
        #expect(liteEdit.modelParams.supportsSourceImage)
        #expect(liteEdit.modelParams.supportedImageResolutions.isEmpty)

        let banana2Lite = try #require(models.first { $0.modelCode == .FAL_GOOGLE_NANO_BANANA_2_LITE })
        #expect(banana2Lite.modelGenerateBaseURL == "https://fal.run/google/nano-banana-2-lite")
        #expect(banana2Lite.modelParams.supportedImageResolutions.isEmpty)

        let seedreamPro = try #require(models.first {
            $0.modelCode == .FAL_BYTEDANCE_SEEDREAM_V5_PRO_TEXT_TO_IMAGE
        })
        #expect(seedreamPro.modelGenerateBaseURL == "https://fal.run/bytedance/seedream/v5/pro/text-to-image")
        #expect(seedreamPro.modelParams.maxGenerations == 6)
        #expect(seedreamPro.modelParams.supportedImageResolutions == ["1K", "2K"])
        #expect(!seedreamPro.modelParams.supportsSeed)

        let seedreamProEdit = try #require(models.first { $0.modelCode == .FAL_BYTEDANCE_SEEDREAM_V5_PRO_EDIT })
        #expect(seedreamProEdit.modelGenerateBaseURL == "https://fal.run/bytedance/seedream/v5/pro/edit")
        #expect(seedreamProEdit.modelParams.maxReferenceImages == 10)
        #expect(seedreamProEdit.modelParams.supportsSourceImage)
        #expect(!seedreamProEdit.modelParams.supportsSeed)
    }

    private func configureFal(_ mock: FalImageMockNetworkProvider) {
        ProviderDependencies.shared.configure(
            networkProvider: mock,
            modelProvider: FalImageTestModelProvider()
        )
    }

    private func capturedJSON(_ mock: FalImageMockNetworkProvider) throws -> [String: Any] {
        let data = try #require(mock.capturedBodyData)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func imageRequest(
        prompt: String = "A crisp aviation poster with readable runway signage.",
        dimensions: String = "16:9",
        clientImage: String? = nil,
        clientReferenceImages: [ReferenceImageData]? = nil,
        numberOfImages: Int = 1,
        seed: Int? = nil,
        safetyTolerance: Int? = nil,
        promptEnhance: Bool? = nil,
        resolution: String? = nil
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: UUID().uuidString,
            prompt: prompt,
            dimensions: dimensions,
            clientImage: clientImage,
            clientReferenceImages: clientReferenceImages,
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.FAL_AI.providerId,
                providerCode: .FAL_AI,
                projectId: UUID()
            ),
            providerSecret: "fal-test",
            numberOfImages: numberOfImages,
            resolution: resolution,
            seed: seed,
            safetyTolerance: safetyTolerance,
            promptEnhance: promptEnhance
        )
    }

    private func costRequest(
        dimensions: String? = nil,
        numberOfImages: Int? = nil,
        referenceImageCount: Int = 0
    ) -> ImageGenerationCostRequest {
        ImageGenerationCostRequest(
            dimensions: dimensions,
            numberOfImages: numberOfImages,
            referenceImageCount: referenceImageCount
        )
    }
}

private final class FalImageMockNetworkProvider: @unchecked Sendable, NetworkProvider {
    var capturedURL: URL?
    var capturedMethod: String?
    var capturedBodyData: Data?
    var capturedHeaders: [String: String]?
    let response: NetworkResponseData

    init(response: NetworkResponseData = .dictionary(statusCode: 400, data: ["detail": "stubbed fal response"])) {
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

private struct FalImageTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        FALModels.createModels().first { $0.modelCode == code }
    }
}
