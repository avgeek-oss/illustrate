import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Luma Agents image adapters")
struct LumaAgentsImageTests {
    @Test("Uni 1 text request posts Agents image payload")
    func uni1TextRequestPostsImagePayload() {
        let adapter = G_LUMA_UNI_1()

        let serviceRequest = adapter.transformRequest(request: imageRequest(
            dimensions: "3000x1000",
            clientReferenceImages: [
                ReferenceImageData(
                    base64Image: "data:image/jpeg;base64,cmVmMQ==",
                    referenceType: "style",
                    mimeType: "image/jpeg"
                ),
            ]
        ))

        #expect(serviceRequest.model == "uni-1")
        #expect(serviceRequest.type == "image")
        #expect(serviceRequest.prompt == "Create a precise aircraft poster.")
        #expect(serviceRequest.aspect_ratio == "3:1")
        #expect(serviceRequest.source == nil)
        #expect(serviceRequest.image_ref?.count == 1)
        #expect(serviceRequest.image_ref?.first?.data == "cmVmMQ==")
        #expect(serviceRequest.image_ref?.first?.media_type == "image/jpeg")
    }

    @Test("Uni Max source image request posts Agents image edit payload")
    func uniMaxSourceImageRequestPostsImageEditPayload() {
        let adapter = G_LUMA_UNI_1_MAX()
        let references = (0 ..< 10).map { index in
            ReferenceImageData(
                base64Image: "ref-\(index)",
                referenceType: "asset",
                mimeType: "image/png"
            )
        }

        let serviceRequest = adapter.transformRequest(request: imageRequest(
            dimensions: "16:9",
            clientImage: "data:image/jpeg;base64,c291cmNl",
            clientReferenceImages: references
        ))

        #expect(serviceRequest.model == "uni-1-max")
        #expect(serviceRequest.type == "image_edit")
        #expect(serviceRequest.aspect_ratio == nil)
        #expect(serviceRequest.source?.data == "c291cmNl")
        #expect(serviceRequest.source?.media_type == "image/jpeg")
        #expect(serviceRequest.image_ref?.count == 8)
    }

    @Test("Agents response parses output URL and failed state")
    func agentsResponseParsing() throws {
        let adapter = G_LUMA_UNI_1()
        let request = imageRequest(numberOfImages: 2)

        let generated = try adapter.transformResponse(
            request: request,
            response: .dictionary(statusCode: 200, data: [
                "id": "gen_123",
                "state": "completed",
                "output": [
                    ["type": "image", "url": "https://example.com/image.png"],
                ],
            ])
        )

        #expect(generated.status == .GENERATED)
        #expect(generated.rawResponse == "https://example.com/image.png")
        #expect(generated.metadata?["lumaGenerationId"] == "gen_123")
        #expect(abs((generated.cost ?? 0) - 0.0808) < 0.0001)

        let failed = try adapter.transformResponse(
            request: request,
            response: .dictionary(statusCode: 200, data: [
                "id": "gen_124",
                "state": "failed",
                "failure_reason": "Prompt rejected",
            ])
        )

        #expect(failed.status == .FAILED)
        #expect(failed.errorMessage == "Prompt rejected")
    }

    @Test("Initial failed response returns immediately without polling")
    func initialFailedResponseReturnsImmediately() async throws {
        let mock = LumaAgentsMockNetworkProvider(response: .dictionary(statusCode: 200, data: [
            "id": "gen_failed",
            "state": "failed",
            "failure_reason": "Prompt rejected",
        ]))
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: LumaAgentsTestModelProvider()
        ) {
            try await G_LUMA_UNI_1().makeRequest(request: imageRequest())
        }

        #expect(response.status == .FAILED)
        #expect(response.errorMessage == "Prompt rejected")
        #expect(mock.requestCount == 1)
    }

    @Test("Uni pricing accounts for source and reference images")
    func uniPricingAccountsForInputImages() {
        let uni = G_LUMA_UNI_1()
        let max = G_LUMA_UNI_1_MAX()

        #expect(abs(uni.getCostEstimate(request: ImageGenerationCostRequest(numberOfImages: 1)) - 0.0404) < 0.0001)
        #expect(abs(max.getCostEstimate(request: ImageGenerationCostRequest(numberOfImages: 1)) - 0.1) < 0.0001)
        #expect(abs(uni.getCostEstimate(request: ImageGenerationCostRequest(
            numberOfImages: 1,
            hasSourceImage: true
        )) - 0.0434) < 0.0001)
        #expect(abs(uni.getCostEstimate(request: ImageGenerationCostRequest(
            numberOfImages: 1,
            hasSourceImage: true,
            referenceImageCount: 1
        )) - 0.0464) < 0.0001)
        #expect(abs(max.getCostEstimate(request: ImageGenerationCostRequest(
            numberOfImages: 1,
            referenceImageCount: 3
        )) - 0.109) < 0.0001)
    }

    @Test("Model metadata registers Agents endpoints and supported dimensions")
    func lumaAgentsMetadataIsRegistered() throws {
        let models = LumaAIModels.createModels()

        let uni = try #require(models.first { $0.modelCode == .LUMA_UNI_1 })
        #expect(uni.modelGenerateBaseURL == "https://agents.lumalabs.ai/v1/generations")
        #expect(uni.modelStatusBaseURL == "https://agents.lumalabs.ai/v1/generations")
        #expect(uni.modelParams.maxGenerations == 1)
        #expect(uni.modelParams.maxReferenceImages == 9)
        #expect(uni.modelParams.supportsSourceImage)
        #expect(uni.modelParams.supportedDimensions == [
            "3:1",
            "2:1",
            "16:9",
            "3:2",
            "1:1",
            "2:3",
            "9:16",
            "1:2",
            "1:3",
        ])

        let max = try #require(models.first { $0.modelCode == .LUMA_UNI_1_MAX })
        #expect(max.modelGenerateBaseURL == "https://agents.lumalabs.ai/v1/generations")
        #expect(max.modelParams.maxReferenceImages == 9)
    }

    private func imageRequest(
        dimensions: String = "16:9",
        clientImage: String? = nil,
        clientReferenceImages: [ReferenceImageData]? = nil,
        numberOfImages: Int = 1
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: UUID().uuidString,
            prompt: "Create a precise aircraft poster.",
            dimensions: dimensions,
            clientImage: clientImage,
            clientReferenceImages: clientReferenceImages,
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.LUMA_AI.providerId,
                providerCode: .LUMA_AI,
                projectId: UUID()
            ),
            providerSecret: "luma-test",
            numberOfImages: numberOfImages
        )
    }
}

private final class LumaAgentsMockNetworkProvider: @unchecked Sendable, NetworkProvider {
    private(set) var requestCount = 0
    let response: NetworkResponseData

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
        requestCount += 1
        return response
    }
}

private struct LumaAgentsTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        LumaAIModels.createModels().first { $0.modelCode == code }
    }
}
