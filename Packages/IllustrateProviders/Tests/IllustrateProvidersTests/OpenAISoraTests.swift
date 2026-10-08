import Foundation
import Testing
@testable import IllustrateProviders

@Suite("OpenAI Sora", .serialized)
struct OpenAISoraTests {
    @Test("Sora 2 metadata matches the current create-video reference")
    func sora2MetadataMatchesCreateVideoReference() throws {
        let model = try #require(OpenAIModels.createModels().first { $0.modelCode == .OPENAI_SORA_2 })

        #expect(model.modelParams.maxPromptLength == 32000)
        #expect(model.modelParams.supportedDimensions == ["1280x720", "720x1280"])
        #expect(model.modelParams.supportedVideoDurations == [4, 8, 12])
        #expect(model.modelParams.supportsSourceImage)
        #expect(model
            .modelAPIDocumentationURL == "https://developers.openai.com/api/reference/resources/videos/methods/create")
    }

    @Test("Sora 2 Pro keeps 1080p out of the picker until the create-video enum accepts it")
    func sora2ProMetadataKeepsUnexposedGuideValuesOutOfPicker() throws {
        let model = try #require(OpenAIModels.createModels().first { $0.modelCode == .OPENAI_SORA_2_PRO })

        #expect(model.modelParams.maxPromptLength == 32000)
        #expect(model.modelParams.supportedDimensions == ["1280x720", "720x1280", "1792x1024", "1024x1792"])
        #expect(!model.modelParams.supportedDimensions.contains("1920x1080"))
        #expect(!model.modelParams.supportedDimensions.contains("1080x1920"))
        #expect(model.modelParams.supportedVideoDurations == [4, 8, 12])
        #expect(model.modelParams.supportsSourceImage)
        #expect(model
            .modelAPIDocumentationURL == "https://developers.openai.com/api/reference/resources/videos/methods/create")
    }

    @Test("Sora extension metadata matches the official extension reference")
    func soraExtensionMetadataMatchesOfficialReference() throws {
        let model = try #require(OpenAIModels.createModels().first { $0.modelCode == .OPENAI_SORA_2_REMIX })

        #expect(model.modelSetType == .VIDEO_EXTEND)
        #expect(model.modelName == "Sora 2")
        #expect(model.modelParams.maxPromptLength == 32000)
        #expect(model.modelParams.requiredMetadata == ["soraVideoId"])
        #expect(model.modelParams.supportedDimensions == ["1280x720", "720x1280"])
        #expect(model.modelParams.supportedVideoDurations == [4, 8, 12, 16, 20])
        #expect(model.modelGenerateBaseURL == "https://api.openai.com/v1/videos/extensions")
        #expect(model
            .modelAPIDocumentationURL == "https://developers.openai.com/api/reference/resources/videos/methods/extend")
    }

    @Test("Sora Pro extension metadata matches the official extension reference")
    func soraProExtensionMetadataMatchesOfficialReference() throws {
        let model = try #require(OpenAIModels.createModels().first { $0.modelCode == .OPENAI_SORA_2_PRO_REMIX })

        #expect(model.modelSetType == .VIDEO_EXTEND)
        #expect(model.modelName == "Sora 2 Pro")
        #expect(model.modelParams.maxPromptLength == 32000)
        #expect(model.modelParams.requiredMetadata == ["soraVideoId"])
        #expect(model.modelParams.supportedDimensions == ["1280x720", "720x1280", "1792x1024", "1024x1792"])
        #expect(model.modelParams.supportedVideoDurations == [4, 8, 12, 16, 20])
        #expect(model.modelGenerateBaseURL == "https://api.openai.com/v1/videos/extensions")
        #expect(model
            .modelAPIDocumentationURL == "https://developers.openai.com/api/reference/resources/videos/methods/extend")
    }

    @Test("Sora generation request preserves supported create-video values")
    func soraRequestPreservesSupportedValues() {
        configureProviderDependencies()

        let adapter = G_OPENAI_SORA_2()
        let serviceRequest = adapter.transformRequest(
            request: videoRequest(
                dimensions: "720x1280",
                durationSeconds: 8
            )
        )

        #expect(serviceRequest.model == "sora-2")
        #expect(serviceRequest.prompt == "Create a clean cinematic runway shot.")
        #expect(serviceRequest.seconds == 8)
        #expect(serviceRequest.size == "720x1280")
    }

    @Test("Sora generation request clamps guide-only values to the create-video enum")
    func soraRequestClampsUnexposedGuideOnlyValues() {
        configureProviderDependencies()

        let adapter = G_OPENAI_SORA_2_PRO()
        let serviceRequest = adapter.transformRequest(
            request: videoRequest(
                dimensions: "1920x1080",
                durationSeconds: 20
            )
        )

        #expect(serviceRequest.model == "sora-2-pro")
        #expect(serviceRequest.seconds == 12)
        #expect(serviceRequest.size == "1280x720")
    }

    @Test("Sora generation cost request uses clamped create-video values")
    func soraCostRequestUsesClampedCreateVideoValues() {
        configureProviderDependencies()

        let adapter = G_OPENAI_SORA_2_PRO()
        let request = videoRequest(
            dimensions: "1920x1080",
            durationSeconds: 20
        )
        let serviceRequest = adapter.transformRequest(request: request)
        let costRequest = adapter.transformCostRequest(request: request, serviceRequest: serviceRequest)

        #expect(costRequest.dimensions == "1280x720")
        #expect(costRequest.durationSeconds == 12)
        #expect(abs(adapter.getCostEstimate(request: costRequest) - 3.60) < 0.0001)
    }

    @Test("Sora extension request preserves official extension fields")
    func soraExtensionRequestPreservesOfficialFields() {
        configureProviderDependencies()

        let adapter = G_OPENAI_SORA_2_REMIX()
        let serviceRequest = adapter.transformExtensionRequest(
            request: videoRequest(
                dimensions: "1280x720",
                durationSeconds: 20,
                sourceMetadata: [G_OPENAI_SORA_BASE.soraVideoIdKey: "video_123"]
            ),
            soraVideoId: "video_123"
        )

        #expect(serviceRequest.video.id == "video_123")
        #expect(serviceRequest.prompt == "Create a clean cinematic runway shot.")
        #expect(serviceRequest.seconds == "20")
    }

    @Test("Sora extension posts official extension endpoint payload")
    func soraExtensionPostsOfficialEndpointPayload() async throws {
        let mock = OpenAISoraMockNetworkProvider(response: .dictionary(
            statusCode: 400,
            data: ["error": ["message": "stop after capture"]]
        ))

        let adapter = G_OPENAI_SORA_2_REMIX()
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: OpenAISoraModelProvider()
        ) {
            try await adapter.makeRequest(request: videoRequest(
                dimensions: "1280x720",
                durationSeconds: 20,
                sourceMetadata: [G_OPENAI_SORA_BASE.soraVideoIdKey: "video_123"]
            ))
        }

        let json = try capturedJSON(mock)
        let video = try #require(json["video"] as? [String: Any])
        #expect(mock.capturedURL?.absoluteString == "https://api.openai.com/v1/videos/extensions")
        #expect(mock.capturedMethod == "POST")
        #expect(mock.capturedHeaders?["Content-Type"] == "application/json")
        #expect(mock.capturedHeaders?["Accept"] == "application/json")
        #expect(video["id"] as? String == "video_123")
        #expect(json["prompt"] as? String == "Create a clean cinematic runway shot.")
        #expect(json["seconds"] as? String == "20")
        #expect(json["model"] == nil)
        #expect(json["size"] == nil)
        #expect(response.status == .FAILED)
        #expect(response.errorMessage == "stop after capture")
    }

    @Test("Sora extension requires generated Sora video metadata")
    func soraExtensionRequiresSoraVideoMetadata() async throws {
        let mock = OpenAISoraMockNetworkProvider()

        let adapter = G_OPENAI_SORA_2_REMIX()
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: OpenAISoraModelProvider()
        ) {
            try await adapter.makeRequest(request: videoRequest(
                dimensions: "1280x720",
                durationSeconds: 8
            ))
        }

        #expect(response.status == .FAILED)
        #expect(response.errorMessage == "No Sora video ID provided for extension")
        #expect(mock.capturedURL == nil)
    }

    @Test("Sora Pro cost estimate includes current standard, 1024p, and 1080p pricing tiers")
    func soraProCostEstimateUsesCurrentPricingTiers() {
        let adapter = G_OPENAI_SORA_2_PRO()

        #expect(abs(adapter.getCostEstimate(request: costRequest(dimensions: "1280x720", durationSeconds: 4)) - 1.20) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(dimensions: "1792x1024", durationSeconds: 4)) - 2.00) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(dimensions: "1920x1080", durationSeconds: 4)) - 2.80) <
            0.0001)
    }

    @Test("Sora Pro extension cost estimate uses the same OpenAI video pricing tiers")
    func soraProExtensionCostEstimateUsesCurrentPricingTiers() {
        let adapter = G_OPENAI_SORA_2_PRO_REMIX()

        #expect(abs(adapter.getCostEstimate(request: costRequest(dimensions: "1280x720", durationSeconds: 20)) - 6.00) <
            0.0001)
        #expect(abs(adapter
                .getCostEstimate(request: costRequest(dimensions: "1792x1024", durationSeconds: 20)) - 10.00) <
            0.0001)
        #expect(abs(adapter
                .getCostEstimate(request: costRequest(dimensions: "1920x1080", durationSeconds: 20)) - 14.00) <
            0.0001)
    }

    private func configureProviderDependencies(_ mock: OpenAISoraMockNetworkProvider =
        OpenAISoraMockNetworkProvider())
    {
        ProviderDependencies.shared.configure(
            networkProvider: mock,
            modelProvider: OpenAISoraModelProvider()
        )
    }

    private func capturedJSON(_ mock: OpenAISoraMockNetworkProvider) throws -> [String: Any] {
        let data = try #require(mock.capturedBodyData)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func videoRequest(
        dimensions: String,
        durationSeconds: Int,
        sourceMetadata: [String: String]? = nil
    ) -> VideoGenerationRequest {
        VideoGenerationRequest(
            modelId: UUID().uuidString,
            prompt: "Create a clean cinematic runway shot.",
            dimensions: dimensions,
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.OPENAI.providerId,
                providerCode: .OPENAI,
                projectId: UUID()
            ),
            providerSecret: "sk-test",
            durationSeconds: durationSeconds,
            sourceMetadata: sourceMetadata
        )
    }

    private func costRequest(
        dimensions: String,
        durationSeconds: Int
    ) -> VideoGenerationCostRequest {
        VideoGenerationCostRequest(
            dimensions: dimensions,
            durationSeconds: durationSeconds,
            numberOfVideos: 1
        )
    }
}

private final class OpenAISoraMockNetworkProvider: @unchecked Sendable, NetworkProvider {
    var capturedURL: URL?
    var capturedMethod: String?
    var capturedBodyData: Data?
    var capturedHeaders: [String: String]?
    var capturedAttachments: [NetworkRequestAttachment]?
    let response: NetworkResponseData

    init(response: NetworkResponseData = .dictionary(statusCode: 200, data: [:])) {
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

private struct OpenAISoraModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        AllModels.createModels().first { $0.modelCode == code }
    }
}
