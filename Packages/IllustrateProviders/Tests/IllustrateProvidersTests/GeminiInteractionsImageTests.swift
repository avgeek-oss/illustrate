// MARK: - GeminiInteractionsImageTests.swift

import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Gemini Interactions image adapters")
struct GeminiInteractionsImageTests {
    @Test("Nano Banana 2 image adapter posts documented Interactions payload")
    func nanoBanana2PostsInteractionsPayload() async throws {
        let mock = MockNetworkProvider(response: .dictionary(statusCode: 200, data: [
            "id": "v1_image",
            "status": "completed",
            "model": "gemini-3.1-flash-image",
            "steps": [
                [
                    "type": "model_output",
                    "content": [
                        ["type": "image", "mime_type": "image/png", "data": "generated-image"],
                    ],
                ],
            ],
        ]))
        let adapter = TestGemini31FlashImageAdapter(
            service: GeminiInteractionsService(networkProvider: mock)
        )

        let response = try await adapter.makeRequest(request: imageRequest(
            quality: "2K",
            selectedTools: ["google_search"]
        ))

        #expect(response.status == .GENERATED)
        #expect(response.base64 == "generated-image")
        #expect(abs((response.cost ?? 0) - 0.1008) < 0.0001)
        #expect(response.metadata?[GeminiInteractionMetadataKey.interactionId] == "v1_image")
        #expect(mock.capturedURL?.absoluteString == "https://generativelanguage.googleapis.com/v1beta/interactions")
        #expect(mock.capturedHeaders?["Api-Revision"] == GeminiInteractionsService.apiRevision)
        #expect(mock.capturedHeaders?["x-goog-api-key"] == "AIza-test")

        let data = try #require(mock.capturedBodyData)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["model"] as? String == "gemini-3.1-flash-image")
        #expect(json["store"] as? Bool == false)

        let input = try #require(json["input"] as? [[String: Any]])
        #expect(input[0]["type"] as? String == "text")
        #expect(input[0]["text"] as? String == "Create a clean product photo.")
        #expect(input[1]["type"] as? String == "image")
        #expect(input[1]["data"] as? String == "source-image")
        #expect(input[2]["type"] as? String == "image")
        #expect(input[2]["mime_type"] as? String == "image/jpeg")

        let responseFormat = try #require(json["response_format"] as? [String: Any])
        #expect(responseFormat["type"] as? String == "image")
        #expect(responseFormat["aspect_ratio"] as? String == "16:9")
        #expect(responseFormat["image_size"] as? String == "2K")

        let tools = try #require(json["tools"] as? [[String: Any]])
        #expect(tools.first?["type"] as? String == "google_search")
    }

    @Test("Nano Banana Lite forces 1K output and omits unsupported tools")
    func nanoBananaLiteForces1K() throws {
        let adapter = TestGemini31FlashLiteImageAdapter()

        let request = adapter.buildInteractionRequest(request: imageRequest(
            quality: "2K",
            selectedTools: ["google_search"]
        ))
        let data = try JSONEncoder().encode(request)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["model"] as? String == "gemini-3.1-flash-lite-image")
        #expect(json["tools"] == nil)

        let responseFormat = try #require(json["response_format"] as? [String: Any])
        #expect(responseFormat["image_size"] as? String == "1K")
        #expect(abs(adapter.getCostEstimate(request: ImageGenerationCostRequest(numberOfImages: 1)) - 0.0336) < 0.0001)
    }

    @Test("Nano Banana Pro uses stable Interactions model and pricing")
    func nanoBananaProUsesStableInteractionsModel() async throws {
        let mock = MockNetworkProvider(response: .dictionary(statusCode: 200, data: [
            "id": "v1_pro_image",
            "status": "completed",
            "model": "gemini-3-pro-image",
            "steps": [
                [
                    "type": "model_output",
                    "content": [
                        ["type": "image", "mime_type": "image/png", "data": "pro-generated-image"],
                    ],
                ],
            ],
        ]))
        let adapter = TestGeminiProImageAdapter(
            service: GeminiInteractionsService(networkProvider: mock)
        )

        let response = try await adapter.makeRequest(request: imageRequest(
            quality: "2K",
            selectedTools: ["google_search", "url_context"]
        ))

        #expect(response.status == .GENERATED)
        #expect(response.base64 == "pro-generated-image")
        #expect(abs((response.cost ?? 0) - 0.1344) < 0.0001)
        #expect(response.metadata?[GeminiInteractionMetadataKey.interactionId] == "v1_pro_image")
        #expect(mock.capturedURL?.absoluteString == GeminiInteractionsService.defaultBaseURL.absoluteString)
        #expect(mock.capturedHeaders?["Api-Revision"] == GeminiInteractionsService.apiRevision)

        let data = try #require(mock.capturedBodyData)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["model"] as? String == "gemini-3-pro-image")
        #expect(json["store"] as? Bool == false)

        let input = try #require(json["input"] as? [[String: Any]])
        #expect(input[0]["type"] as? String == "text")
        #expect(input[1]["type"] as? String == "image")
        #expect(input[1]["data"] as? String == "source-image")
        #expect(input[2]["type"] as? String == "image")
        #expect(input[2]["data"] as? String == "reference-image")

        let responseFormat = try #require(json["response_format"] as? [String: Any])
        #expect(responseFormat["type"] as? String == "image")
        #expect(responseFormat["aspect_ratio"] as? String == "16:9")
        #expect(responseFormat["image_size"] as? String == "2K")

        let tools = try #require(json["tools"] as? [[String: Any]])
        #expect(tools.count == 1)
        #expect(tools.first?["type"] as? String == "google_search")

        let oneKCost = adapter.getCostEstimate(request: ImageGenerationCostRequest(quality: "1K", numberOfImages: 1))
        let fourKCost = adapter.getCostEstimate(request: ImageGenerationCostRequest(quality: "4K", numberOfImages: 1))
        #expect(abs(oneKCost - 0.1344) < 0.0001)
        #expect(abs(fourKCost - 0.24) < 0.0001)
    }

    private func imageRequest(
        quality: String,
        selectedTools: [String]?
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: UUID().uuidString,
            prompt: "Create a clean product photo.",
            quality: quality,
            dimensions: "16:9",
            clientImage: "source-image",
            clientReferenceImages: [
                ReferenceImageData(base64Image: "reference-image", mimeType: "image/jpeg"),
            ],
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                providerCode: .GOOGLE_CLOUD,
                projectId: UUID()
            ),
            providerSecret: "AIza-test",
            selectedTools: selectedTools
        )
    }
}

private final class TestGemini31FlashImageAdapter: Gemini31FlashImageBase {
    private let testModel: ProviderModelData

    override init(service: GeminiInteractionsService = GeminiInteractionsService()) {
        testModel = ProviderModelData(
            providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
            modelCode: .GOOGLE_GEMINI_31_FLASH_IMAGE,
            modelSetType: .IMAGE_GENERATE,
            modelName: "Nano Banana 2",
            modelDescription: "Test model",
            modelParams: ModelParams(
                supportedTools: ["google_search"],
                supportedImageQualities: ["1K", "2K", "4K", "0.5K"],
                supportsSourceImage: true
            ),
            modelLaunchDate: Date(),
            modelGenerateBaseURL: GeminiInteractionsService.defaultBaseURL.absoluteString,
            modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/interactions/image-generation",
            active: true
        )
        super.init(service: service)
    }

    override var geminiModelId: String {
        "gemini-3.1-flash-image"
    }

    override var model: ProviderModelData {
        testModel
    }
}

private final class TestGemini31FlashLiteImageAdapter: Gemini31FlashLiteImageBase {
    private let testModel: ProviderModelData

    override init(service: GeminiInteractionsService = GeminiInteractionsService()) {
        testModel = ProviderModelData(
            providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
            modelCode: .GOOGLE_GEMINI_31_FLASH_LITE_IMAGE,
            modelSetType: .IMAGE_GENERATE,
            modelName: "Nano Banana 2 Lite",
            modelDescription: "Test model",
            modelParams: ModelParams(
                supportedImageQualities: ["1K"],
                supportsSourceImage: true
            ),
            modelLaunchDate: Date(),
            modelGenerateBaseURL: GeminiInteractionsService.defaultBaseURL.absoluteString,
            modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/models/gemini-3.1-flash-lite-image",
            active: true
        )
        super.init(service: service)
    }

    override var geminiModelId: String {
        "gemini-3.1-flash-lite-image"
    }

    override var model: ProviderModelData {
        testModel
    }
}

private final class TestGeminiProImageAdapter: GeminiProImageBase {
    private let testModel: ProviderModelData

    override init(service: GeminiInteractionsService = GeminiInteractionsService()) {
        testModel = ProviderModelData(
            providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
            modelCode: .GOOGLE_GEMINI_PRO_IMAGE,
            modelSetType: .IMAGE_GENERATE,
            modelName: "Nano Banana Pro",
            modelDescription: "Test model",
            modelParams: ModelParams(
                supportedTools: ["google_search"],
                supportedImageQualities: ["2K", "4K", "1K"],
                supportsSourceImage: true
            ),
            modelLaunchDate: Date(),
            modelGenerateBaseURL: GeminiInteractionsService.defaultBaseURL.absoluteString,
            modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/models/gemini-3-pro-image",
            active: true
        )
        super.init(service: service)
    }

    override var geminiModelId: String {
        "gemini-3-pro-image"
    }

    override var model: ProviderModelData {
        testModel
    }
}
