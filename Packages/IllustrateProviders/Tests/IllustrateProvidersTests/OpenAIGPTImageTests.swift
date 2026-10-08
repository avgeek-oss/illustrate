import Foundation
import Testing
@testable import IllustrateProviders

@Suite("OpenAI GPT Image", .serialized)
struct OpenAIGPTImageTests {
    @Test("GPT Image 2 preserves valid flexible sizes and omits unsupported fields")
    func gptImage2RequestPreservesFlexibleSize() {
        let adapter = G_OPENAI_GPT_IMAGE_2()
        let request = imageRequest(
            quality: "high",
            dimensions: "2048x1152",
            background: "opaque",
            inputFidelity: "low"
        )

        let serviceRequest = adapter.transformRequest(request: request)

        #expect(serviceRequest.model == "gpt-image-2")
        #expect(serviceRequest.size == "2048x1152")
        #expect(serviceRequest.quality == "high")
        #expect(serviceRequest.background == "opaque")
        #expect(serviceRequest.input_fidelity == nil)
    }

    @Test("GPT Image 2 rejects invalid flexible sizes and transparent background")
    func gptImage2RequestSanitizesUnsupportedValues() {
        let adapter = G_OPENAI_GPT_IMAGE_2()
        let request = imageRequest(
            quality: "",
            dimensions: "1025x1024",
            background: "transparent"
        )

        let serviceRequest = adapter.transformRequest(request: request)

        #expect(serviceRequest.size == "1024x1024")
        #expect(serviceRequest.quality == "auto")
        #expect(serviceRequest.background == nil)
    }

    @Test("GPT Image 2 rejects common 1080p dimensions because both edges must be multiples of 16")
    func gptImage2RequestRejectsInvalid1080pSizes() {
        let adapter = G_OPENAI_GPT_IMAGE_2()
        let request = imageRequest(
            quality: "high",
            dimensions: "1920x1080",
            background: "opaque"
        )

        let serviceRequest = adapter.transformRequest(request: request)

        #expect(serviceRequest.size == "1024x1024")
    }

    @Test("older GPT Image models keep the existing three-size clamp")
    func olderGPTImageModelsKeepStandardSizes() {
        let adapter = G_OPENAI_GPT_IMAGE_1()
        let request = imageRequest(
            quality: "medium",
            dimensions: "1536x864",
            background: "transparent",
            inputFidelity: "high"
        )

        let serviceRequest = adapter.transformRequest(request: request)

        #expect(serviceRequest.size == "1024x1024")
        #expect(serviceRequest.background == "transparent")
        #expect(serviceRequest.input_fidelity == "high")
    }

    @Test("generation request encodes GPT Image 2 background and parses usage metadata")
    func makeRequestEncodesBackgroundAndParsesUsage() async throws {
        let mock = OpenAIMockNetworkProvider(response: .dictionary(statusCode: 200, data: [
            "data": [
                [
                    "b64_json": "image-data",
                ],
            ],
            "background": "opaque",
            "output_format": "png",
            "quality": "high",
            "size": "1536x864",
            "usage": [
                "input_tokens": 12,
                "output_tokens": 34,
                "total_tokens": 46,
                "input_tokens_details": [
                    "image_tokens": 0,
                    "text_tokens": 12,
                ],
            ],
        ]))

        let adapter = G_OPENAI_GPT_IMAGE_2()
        let response = try await withProviderDependencies(networkProvider: mock, modelProvider: OpenAIModelProvider()) {
            try await adapter.makeRequest(request: imageRequest(
                quality: "high",
                dimensions: "1536x864",
                background: "opaque"
            ))
        }

        #expect(response.status == .GENERATED)
        #expect(response.base64 == "image-data")
        #expect(response.actualDimensions == "1536x864")
        #expect(response.metadata?["usage.total_tokens"] == "46")
        #expect(response.metadata?["usage.input_tokens_details.text_tokens"] == "12")
        #expect(response.metadata?["background"] == "opaque")

        let data = try #require(mock.capturedBodyData)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["model"] as? String == "gpt-image-2")
        #expect(json["size"] as? String == "1536x864")
        #expect(json["quality"] as? String == "high")
        #expect(json["background"] as? String == "opaque")
        #expect(json["input_fidelity"] == nil)
        #expect(mock.capturedURL?.absoluteString == "https://api.openai.com/v1/images/generations")
    }

    @Test("GPT Image 2 model metadata matches documented generation capabilities")
    func gptImage2ModelMetadataMatchesGenerationSurface() throws {
        let model = try #require(OpenAIModels.createModels().first { $0.modelCode == .OPENAI_GPT_IMAGE_2 })

        #expect(model.modelParams.maxPromptLength == 32000)
        #expect(model.modelParams.supportedBackgrounds == ["auto", "opaque"])
        #expect(model.modelParams.supportedImageQualities == ["auto", "low", "medium", "high"])
        #expect(model.modelParams.supportedDimensions.contains("1536x864"))
        #expect(model.modelParams.supportedDimensions.contains("2048x1152"))
        #expect(model.modelParams.supportedDimensions.contains("1152x2048"))
        #expect(model.modelParams.supportedDimensions.contains("3840x2160"))
        #expect(model.modelParams.supportedDimensions.contains("2160x3840"))
        #expect(!model.modelParams.supportedDimensions.contains("1920x1080"))
        #expect(!model.modelParams.supportedDimensions.contains("1080x1920"))
        #expect(model.modelParams.maxReferenceImages == 8)
        #expect(model.modelParams.supportsSourceImage == true)
        #expect(model.modelParams.supportsMask == true)
    }

    @Test("GPT Image 2 estimates use the documented standard size table")
    func gptImage2CostTableUsesDocumentedEstimates() {
        let adapter = G_OPENAI_GPT_IMAGE_2()

        #expect(abs(adapter.getCostEstimate(request: costRequest(quality: "low", dimensions: "1024x1024")) - 0.006) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(quality: "medium", dimensions: "1536x1024")) - 0.041) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(quality: "high", dimensions: "1024x1536")) - 0.165) <
            0.0001)
        #expect(adapter.formatCost(request: costRequest(quality: "high", dimensions: "1024x1536")) == "$0.17+")
    }

    private func imageRequest(
        quality: String,
        dimensions: String,
        background: String? = nil,
        inputFidelity: String? = nil
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: UUID().uuidString,
            prompt: "Create a clean product photo.",
            quality: quality,
            dimensions: dimensions,
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.OPENAI.providerId,
                providerCode: .OPENAI,
                projectId: UUID()
            ),
            providerSecret: "sk-test",
            background: background,
            inputFidelity: inputFidelity
        )
    }

    private func costRequest(
        quality: String,
        dimensions: String,
        numberOfImages: Int = 1
    ) -> ImageGenerationCostRequest {
        ImageGenerationCostRequest(
            quality: quality,
            dimensions: dimensions,
            numberOfImages: numberOfImages
        )
    }
}

private final class OpenAIMockNetworkProvider: @unchecked Sendable, NetworkProvider {
    let response: NetworkResponseData
    var capturedURL: URL?
    var capturedMethod: String?
    var capturedBodyData: Data?
    var capturedHeaders: [String: String]?
    var capturedAttachments: [NetworkRequestAttachment]?

    init(response: NetworkResponseData) {
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
        capturedAttachments = attachments
        if let body {
            capturedBodyData = try JSONEncoder().encode(body)
        }
        return response
    }
}

private struct OpenAIModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        AllModels.createModels().first { $0.modelCode == code }
    }
}
