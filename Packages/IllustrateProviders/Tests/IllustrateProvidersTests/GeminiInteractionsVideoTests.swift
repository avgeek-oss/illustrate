// MARK: - GeminiInteractionsVideoTests.swift

import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Gemini Interactions video adapters")
struct GeminiInteractionsVideoTests {
    @Test("Gemini Omni Flash posts documented text-to-video Interactions payload")
    func geminiOmniFlashPostsTextToVideoPayload() throws {
        let adapter = TestGeminiOmniFlashVideoAdapter()
        let request = adapter.buildInteractionRequest(request: videoRequest(
            dimensions: "9:16",
            negativePrompt: "no titles",
            durationSeconds: 12,
            resolution: "4k",
            generateAudio: true,
            seed: 123
        ))

        let data = try JSONEncoder().encode(request)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["model"] as? String == "gemini-omni-flash-preview")
        #expect(json["input"] as? String == "A marble rolling across a neon track.")
        #expect(json["response_modalities"] as? [String] == ["video"])
        #expect(json["background"] as? Bool == false)
        #expect(json["store"] as? Bool == true)
        #expect(json["stream"] as? Bool == false)

        let responseFormat = try #require(json["response_format"] as? [String: Any])
        #expect(responseFormat["type"] as? String == "video")
        #expect(responseFormat["aspect_ratio"] as? String == "9:16")
        #expect(responseFormat["delivery"] as? String == "uri")

        let generationConfig = try #require(json["generation_config"] as? [String: Any])
        let videoConfig = try #require(generationConfig["video_config"] as? [String: Any])
        #expect(videoConfig["task"] as? String == "text_to_video")
        #expect(videoConfig["duration"] == nil)
        #expect(videoConfig["duration_seconds"] == nil)
        #expect(videoConfig.count == 1)
        #expect(generationConfig["temperature"] == nil)
        #expect(generationConfig["top_p"] == nil)
        #expect(generationConfig["stop_sequences"] == nil)
        #expect(generationConfig["seed"] == nil)
        #expect(json["system_instruction"] == nil)
        #expect(json["negative_prompt"] == nil)
        #expect(responseFormat["resolution"] == nil)
    }

    @Test("Gemini Omni Flash posts documented image-to-video payload")
    func geminiOmniFlashPostsImageToVideoPayload() throws {
        let adapter = TestGeminiOmniFlashVideoAdapter()
        let request = adapter.buildInteractionRequest(request: videoRequest(
            clientImage: "data:image/png;base64,source-image"
        ))

        let data = try JSONEncoder().encode(request)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let input = try #require(json["input"] as? [[String: Any]])
        #expect(input.count == 2)
        #expect(input[0]["type"] as? String == "image")
        #expect(input[0]["data"] as? String == "source-image")
        #expect(input[0]["mime_type"] as? String == "image/png")
        #expect(input[1]["type"] as? String == "text")
        #expect(input[1]["text"] as? String == "A marble rolling across a neon track.")

        let generationConfig = try #require(json["generation_config"] as? [String: Any])
        let videoConfig = try #require(generationConfig["video_config"] as? [String: Any])
        #expect(videoConfig["task"] as? String == "image_to_video")
    }

    @Test("Gemini Omni Flash sends image and subject references before prompt")
    func geminiOmniFlashPostsReferenceToVideoPayload() async throws {
        let mock = MockNetworkProvider(response: .dictionary(statusCode: 200, data: [
            "id": "v1_omni",
            "status": "completed",
            "model": "gemini-omni-flash-preview",
            "steps": [
                [
                    "type": "model_output",
                    "content": [
                        ["type": "video", "mime_type": "video/mp4", "data": "generated-video"],
                    ],
                ],
            ],
        ]))
        let adapter = TestGeminiOmniFlashVideoAdapter(
            service: GeminiInteractionsService(networkProvider: mock)
        )

        let response = try await adapter.makeRequest(request: videoRequest(
            clientImage: "data:image/png;base64,source-image",
            clientReferenceImages: [
                ReferenceImageData(base64Image: "reference-image", mimeType: "image/jpeg"),
            ]
        ))

        #expect(response.status == .GENERATED)
        #expect(response.base64 == "generated-video")
        #expect(abs((response.cost ?? 0) - 0.81088) < 0.0001)
        #expect(response.metadata?[GeminiInteractionMetadataKey.interactionId] == "v1_omni")
        #expect(mock.capturedURL?.absoluteString == GeminiInteractionsService.defaultBaseURL.absoluteString)
        #expect(mock.capturedHeaders?["Api-Revision"] == GeminiInteractionsService.apiRevision)

        let data = try #require(mock.capturedBodyData)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let input = try #require(json["input"] as? [[String: Any]])
        #expect(input[0]["type"] as? String == "image")
        #expect(input[0]["data"] as? String == "source-image")
        #expect(input[0]["mime_type"] as? String == "image/png")
        #expect(input[1]["type"] as? String == "image")
        #expect(input[1]["data"] as? String == "reference-image")
        #expect(input[1]["mime_type"] as? String == "image/jpeg")
        #expect(input[2]["type"] as? String == "text")

        let generationConfig = try #require(json["generation_config"] as? [String: Any])
        let videoConfig = try #require(generationConfig["video_config"] as? [String: Any])
        #expect(videoConfig["task"] as? String == "reference_to_video")
    }

    @Test("Gemini Omni Flash marks uploaded video inputs as edit tasks")
    func geminiOmniFlashPostsEditPayload() throws {
        let adapter = TestGeminiOmniFlashVideoAdapter()
        let request = adapter.buildInteractionRequest(request: videoRequest(
            clientVideo: "data:video/mp4;base64,source-video"
        ))

        let data = try JSONEncoder().encode(request)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let input = try #require(json["input"] as? [[String: Any]])
        let userInput = try #require(input.first)
        #expect(userInput["type"] as? String == "user_input")

        let content = try #require(userInput["content"] as? [[String: Any]])
        #expect(content[0]["type"] as? String == "video")
        #expect(content[0]["data"] as? String == "source-video")
        #expect(content[0]["mime_type"] as? String == "video/mp4")
        #expect(content[1]["type"] as? String == "text")

        let generationConfig = try #require(json["generation_config"] as? [String: Any])
        let videoConfig = try #require(generationConfig["video_config"] as? [String: Any])
        #expect(videoConfig["task"] as? String == "edit")
    }

    @Test("Gemini Omni Flash metadata and cost reflect current live parameters")
    func geminiOmniFlashMetadataAndCostReflectCurrentLiveParameters() throws {
        let model = try #require(GoogleCloudModels.createModels().first {
            $0.modelCode == .GOOGLE_GEMINI_OMNI_FLASH_VIDEO
        })
        #expect(model.modelParams.supportedDimensions == ["16:9", "9:16"])
        #expect(model.modelParams.supportedVideoDurations == [3, 4, 5, 6, 7, 8, 9, 10])
        #expect(model.modelParams.supportedVideoResolutions == ["720p"])
        #expect(model.modelParams.maxReferenceImages == 3)
        #expect(model.modelParams.supportsSourceImage)
        #expect(model.modelParams.supportsVideoUpload == false)
        #expect(model.modelParams.supportsNegativePrompt == false)
        #expect(model.modelParams.supportsAudio == false)
        #expect(model.modelAPIDocumentationURL == "https://ai.google.dev/gemini-api/docs/omni")

        let adapter = TestGeminiOmniFlashVideoAdapter()
        #expect(abs(adapter.getCostEstimate(request: VideoGenerationCostRequest(durationSeconds: 2)) - 0.30408) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: VideoGenerationCostRequest(durationSeconds: 8)) - 0.81088) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: VideoGenerationCostRequest(durationSeconds: 12)) - 1.0136) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: VideoGenerationCostRequest(numberOfVideos: 2)) - 1.62176) <
            0.0001)
    }

    @Test("Gemini Omni Flash edit model requires stored interaction metadata")
    func geminiOmniFlashEditModelRequiresStoredInteractionMetadata() throws {
        let model = try #require(GoogleCloudModels.createModels().first {
            $0.modelCode == .GOOGLE_GEMINI_OMNI_FLASH_VIDEO_EDIT
        })

        #expect(model.modelSetType == .VIDEO_EXTEND)
        #expect(model.modelParams.requiredMetadata == [GeminiInteractionMetadataKey.interactionId])
        #expect(model.modelParams.supportedDimensions == ["16:9", "9:16"])
        #expect(model.modelParams.supportedVideoDurations == [3, 4, 5, 6, 7, 8, 9, 10])
        #expect(model.modelParams.supportedVideoResolutions == ["720p"])
        #expect(model.active)
    }

    @Test("Gemini Omni Flash edit posts previous interaction payload")
    func geminiOmniFlashEditPostsPreviousInteractionPayload() throws {
        let adapter = TestGeminiOmniFlashVideoAdapter(
            modelCode: .GOOGLE_GEMINI_OMNI_FLASH_VIDEO_EDIT,
            modelSetType: .VIDEO_EXTEND,
            requiredMetadata: [GeminiInteractionMetadataKey.interactionId]
        )
        let request = adapter.buildInteractionRequest(request: videoRequest(
            clientVideo: "data:video/mp4;base64,source-video",
            sourceMetadata: [GeminiInteractionMetadataKey.interactionId: "v1_source"]
        ))

        let data = try JSONEncoder().encode(request)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["model"] as? String == "gemini-omni-flash-preview")
        #expect(json["input"] as? String == "A marble rolling across a neon track.")
        #expect(json["previous_interaction_id"] as? String == "v1_source")
        #expect(json["store"] as? Bool == true)

        let generationConfig = try #require(json["generation_config"] as? [String: Any])
        let videoConfig = try #require(generationConfig["video_config"] as? [String: Any])
        #expect(videoConfig["task"] as? String == "edit")
    }

    @Test("Gemini Omni Flash edit fails gracefully without previous interaction")
    func geminiOmniFlashEditFailsGracefullyWithoutPreviousInteraction() async throws {
        let adapter = TestGeminiOmniFlashVideoAdapter(
            modelCode: .GOOGLE_GEMINI_OMNI_FLASH_VIDEO_EDIT,
            modelSetType: .VIDEO_EXTEND,
            requiredMetadata: [GeminiInteractionMetadataKey.interactionId]
        )

        let response = try await adapter.makeRequest(request: videoRequest())

        #expect(response.status == .FAILED)
        #expect(response.errorCode == .MODEL_ERROR)
        #expect(response.errorMessage?.contains("requires a stored Gemini interaction ID") == true)
    }

    @Test("Gemini Omni Flash downloads URI video outputs")
    func geminiOmniFlashDownloadsURIOutputs() async throws {
        let recorder = DownloadRecorder(data: Data("video-bytes".utf8))
        let mock = MockNetworkProvider(response: .dictionary(statusCode: 200, data: [
            "id": "v1_omni_uri",
            "status": "completed",
            "model": "gemini-omni-flash-preview",
            "steps": [
                [
                    "type": "model_output",
                    "content": [
                        [
                            "type": "video",
                            "mime_type": "video/mp4",
                            "uri": "https://generativelanguage.googleapis.com/v1beta/files/abc123:download?alt=media",
                        ],
                    ],
                ],
            ],
        ]))
        let adapter = TestGeminiOmniFlashVideoAdapter(
            service: GeminiInteractionsService(networkProvider: mock),
            videoDownloader: { uri, apiKey in
                await recorder.download(uri: uri, apiKey: apiKey)
            }
        )

        let response = try await adapter.makeRequest(request: videoRequest())
        let captured = await recorder.captured()

        #expect(response.status == .GENERATED)
        #expect(response.base64 == Data("video-bytes".utf8).base64EncodedString())
        #expect(response.metadata?[GeminiInteractionMetadataKey.interactionId] == "v1_omni_uri")
        #expect(response.metadata?[GeminiInteractionMetadataKey.outputVideoUri] == captured.uri)
        #expect(captured.uri == "https://generativelanguage.googleapis.com/v1beta/files/abc123:download?alt=media")
        #expect(captured.apiKey == "AIza-test")
    }

    @Test("Gemini Omni Flash maps failed interactions to model errors")
    func geminiOmniFlashMapsFailedInteractions() async throws {
        let mock = MockNetworkProvider(response: .dictionary(statusCode: 200, data: [
            "id": "v1_failed",
            "status": "failed",
            "steps": [],
        ]))
        let adapter = TestGeminiOmniFlashVideoAdapter(
            service: GeminiInteractionsService(networkProvider: mock)
        )

        let response = try await adapter.makeRequest(request: videoRequest())

        #expect(response.status == .FAILED)
        #expect(response.errorCode == .MODEL_ERROR)
        #expect(response.errorMessage == "Gemini interaction failed")
        #expect(response.metadata?[GeminiInteractionMetadataKey.interactionId] == "v1_failed")
    }

    private func videoRequest(
        dimensions: String = "16:9",
        negativePrompt: String? = nil,
        clientImage: String? = nil,
        clientVideo: String? = nil,
        clientReferenceImages: [ReferenceImageData]? = nil,
        durationSeconds: Int? = 8,
        resolution: String? = nil,
        generateAudio: Bool? = nil,
        seed: Int? = nil,
        sourceMetadata: [String: String]? = nil
    ) -> VideoGenerationRequest {
        VideoGenerationRequest(
            modelId: UUID().uuidString,
            prompt: "A marble rolling across a neon track.",
            negativePrompt: negativePrompt,
            dimensions: dimensions,
            clientImage: clientImage,
            clientVideo: clientVideo,
            clientReferenceImages: clientReferenceImages,
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                providerCode: .GOOGLE_CLOUD,
                projectId: UUID()
            ),
            providerSecret: "AIza-test",
            durationSeconds: durationSeconds,
            resolution: resolution,
            generateAudio: generateAudio,
            seed: seed,
            sourceMetadata: sourceMetadata
        )
    }
}

private actor DownloadRecorder {
    private let data: Data
    private var capturedURI: String?
    private var capturedAPIKey: String?

    init(data: Data) {
        self.data = data
    }

    func download(uri: String, apiKey: String) -> Data {
        capturedURI = uri
        capturedAPIKey = apiKey
        return data
    }

    func captured() -> (uri: String?, apiKey: String?) {
        (capturedURI, capturedAPIKey)
    }
}

private final class TestGeminiOmniFlashVideoAdapter: GeminiOmniFlashVideoBase {
    private let testModel: ProviderModelData

    init(
        modelCode: EnumProviderModelCode = .GOOGLE_GEMINI_OMNI_FLASH_VIDEO,
        modelSetType: EnumSetType = .VIDEO_GENERATE,
        requiredMetadata: [String] = [],
        service: GeminiInteractionsService = GeminiInteractionsService(),
        videoDownloader: @escaping GeminiOmniVideoDownloader = { _, _ in Data() }
    ) {
        testModel = ProviderModelData(
            providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
            modelCode: modelCode,
            modelSetType: modelSetType,
            modelName: "Gemini Omni Flash",
            modelDescription: "Test model",
            modelParams: ModelParams(
                maxReferenceImages: 3,
                requiredMetadata: requiredMetadata,
                supportedDimensions: ["16:9", "9:16"],
                supportedVideoDurations: [3, 4, 5, 6, 7, 8, 9, 10],
                supportedVideoResolutions: ["720p"],
                supportsSourceImage: true
            ),
            modelLaunchDate: Date(),
            modelGenerateBaseURL: GeminiInteractionsService.defaultBaseURL.absoluteString,
            modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/omni",
            active: true
        )
        super.init(service: service, videoDownloader: videoDownloader)
    }

    override var model: ProviderModelData {
        testModel
    }
}
