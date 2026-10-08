import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Fal catalog audit adapters", .serialized)
struct FalCatalogAuditTests {
    @Test("Seedream Lite uses current endpoints and documented payload")
    func seedreamLiteUsesCurrentEndpoints() async throws {
        let textMock = FalCatalogAuditMock()
        let textAdapter = try await withFalDependencies(textMock) {
            let adapter = G_FAL_BYTEDANCE_SEEDREAM_V5_LITE_TEXT_TO_IMAGE()
            _ = try await adapter.makeRequest(request: imageRequest(
                numberOfImages: 6,
                resolution: "4K",
                seed: 17
            ))
            return adapter
        }

        let textJSON = try capturedJSON(textMock)
        #expect(textMock.capturedURL?.absoluteString == "https://fal.run/bytedance/seedream/v5/lite/text-to-image")
        #expect(textJSON["image_size"] as? String == "auto_4K")
        #expect(textJSON["num_images"] as? Int == 6)
        #expect(textJSON["max_images"] as? Int == 1)
        #expect(textJSON["seed"] == nil)
        #expect(abs(textAdapter.getCostEstimate(request: ImageGenerationCostRequest(numberOfImages: 6)) - 0.21) <
            0.0001)

        let editMock = FalCatalogAuditMock()
        try await withFalDependencies(editMock) {
            _ = try await G_FAL_BYTEDANCE_SEEDREAM_V5_LITE_EDIT().makeRequest(request: imageRequest(
                clientImage: "source",
                clientReferenceImages: [ReferenceImageData(base64Image: "reference")],
                resolution: "3K"
            ))
        }

        let editJSON = try capturedJSON(editMock)
        #expect(editMock.capturedURL?.absoluteString == "https://fal.run/bytedance/seedream/v5/lite/edit")
        #expect(editJSON["image_size"] as? String == "auto_3K")
        #expect(editJSON["image_urls"] as? [String] == [
            "data:image/png;base64,source",
            "data:image/png;base64,reference",
        ])
        #expect(editJSON["seed"] == nil)
    }

    @Test("Ideogram Fast and Instant encode their current schemas")
    func ideogramVariantsEncodeCurrentSchemas() async throws {
        let fastMock = FalCatalogAuditMock()
        let fast = try await withFalDependencies(fastMock) {
            let adapter = G_FAL_IDEOGRAM_V4_FAST()
            _ = try await adapter.makeRequest(request: imageRequest(numberOfImages: 2, promptEnhance: false))
            return adapter
        }
        let fastJSON = try capturedJSON(fastMock)
        #expect(fastMock.capturedURL?.absoluteString == "https://fal.run/ideogram/v4/fast")
        #expect(fastJSON["rendering_speed"] as? String == "BALANCED")
        #expect(fastJSON["expansion_model"] as? String == "None")
        #expect(abs(fast.getCostEstimate(request: ImageGenerationCostRequest(
            dimensions: "1024x1024",
            numberOfImages: 2
        )) - 0.021) < 0.0001)

        let instantMock = FalCatalogAuditMock()
        let instant = try await withFalDependencies(instantMock) {
            let adapter = G_FAL_IDEOGRAM_V4_INSTANT()
            _ = try await adapter.makeRequest(request: imageRequest(numberOfImages: 2, promptEnhance: true))
            return adapter
        }
        let instantJSON = try capturedJSON(instantMock)
        #expect(instantMock.capturedURL?.absoluteString == "https://fal.run/ideogram/v4/instant")
        #expect(instantJSON["rendering_speed"] == nil)
        #expect(instantJSON["expansion_model"] as? String == "Medium")
        #expect(abs(instant.getCostEstimate(request: ImageGenerationCostRequest(
            dimensions: "1024x1024",
            numberOfImages: 2
        )) - 0.015) < 0.0001)
    }

    @Test("Bernini image and video adapters map existing Illustrate inputs")
    func berniniAdaptersMapExistingInputs() async throws {
        let imageMock = FalCatalogAuditMock()
        let image = try await withFalDependencies(imageMock) {
            let adapter = G_FAL_BYTEDANCE_BERNINI_R_EDIT_IMAGE()
            _ = try await adapter.makeRequest(request: imageRequest(
                negativePrompt: "blur",
                dimensions: "1920x1080",
                clientImage: "source",
                steps: 44,
                seed: 9,
                promptEnhance: true
            ))
            return adapter
        }
        let imageJSON = try capturedJSON(imageMock)
        #expect(imageJSON["image_url"] as? String == "data:image/png;base64,source")
        #expect(imageJSON["max_image_size"] as? Int == 1280)
        #expect(imageJSON["num_inference_steps"] as? Int == 44)
        #expect(imageJSON["enable_prompt_expansion"] as? Bool == true)
        #expect(abs(image.getCostEstimate(request: ImageGenerationCostRequest(
            dimensions: "1920x1080"
        )) - 0.03) < 0.0001)

        let videoMock = FalCatalogAuditMock()
        let video = try await withFalDependencies(videoMock) {
            let adapter = G_FAL_BYTEDANCE_BERNINI_R_T2V()
            _ = try await adapter.makeRequest(request: videoRequest(
                negativePrompt: "blur",
                dimensions: "9:16",
                durationSeconds: 7,
                resolution: "1280p",
                fps: 16,
                seed: 10,
                promptEnhance: true
            ))
            return adapter
        }
        let videoJSON = try capturedJSON(videoMock)
        #expect(videoJSON["aspect_ratio"] as? String == "9:16")
        #expect(videoJSON["max_image_size"] as? Int == 1280)
        #expect(videoJSON["num_frames"] as? Int == 113)
        #expect(videoJSON["frames_per_second"] as? Int == 16)
        #expect(abs(video.getCostEstimate(request: VideoGenerationCostRequest(
            durationSeconds: 7,
            resolution: "1280p"
        )) - 1.13) < 0.0001)
    }

    @Test("Bernini reference edit posts video and reference inputs")
    func berniniReferenceEditPostsInputs() async throws {
        let mock = FalCatalogAuditMock()
        try await withFalDependencies(mock) {
            _ = try await G_FAL_BYTEDANCE_BERNINI_R_REFERENCE_EDIT_VIDEO().makeRequest(request: videoRequest(
                clientVideo: "source-video",
                clientReferenceImages: [
                    ReferenceImageData(base64Image: "first"),
                    ReferenceImageData(base64Image: "second", mimeType: "image/jpeg"),
                ]
            ))
        }

        let json = try capturedJSON(mock)
        #expect(mock.capturedURL?.absoluteString == "https://fal.run/fal-ai/bernini-r/reference-edit-video")
        #expect(json["video_url"] as? String == "data:video/mp4;base64,source-video")
        #expect(json["reference_image_urls"] as? [String] == [
            "data:image/png;base64,first",
            "data:image/jpeg;base64,second",
        ])
    }

    @Test("Gemini Omni text and edit endpoints use their distinct schemas")
    func geminiOmniTextAndEditUseDistinctSchemas() async throws {
        let textMock = FalCatalogAuditMock()
        let text = try await withFalDependencies(textMock) {
            let adapter = G_FAL_GOOGLE_GEMINI_OMNI_FLASH_T2V()
            _ = try await adapter.makeRequest(request: videoRequest(
                dimensions: "9:16",
                durationSeconds: 6
            ))
            return adapter
        }
        let textJSON = try capturedJSON(textMock)
        #expect(textMock.capturedURL?.absoluteString == "https://fal.run/google/gemini-omni-flash")
        #expect(textJSON["aspect_ratio"] as? String == "9:16")
        #expect(textJSON["duration"] as? Int == 6)
        #expect(abs(text.getCostEstimate(request: VideoGenerationCostRequest(durationSeconds: 6)) - 0.75) < 0.0001)

        let editMock = FalCatalogAuditMock()
        try await withFalDependencies(editMock) {
            _ = try await G_FAL_GOOGLE_GEMINI_OMNI_FLASH_EDIT().makeRequest(request: videoRequest(
                clientVideo: "source-video"
            ))
        }
        let editJSON = try capturedJSON(editMock)
        #expect(editMock.capturedURL?.absoluteString == "https://fal.run/google/gemini-omni-flash/edit")
        #expect(editJSON["video_url"] as? String == "data:video/mp4;base64,source-video")
        #expect(editJSON["duration"] == nil)
    }

    @Test("ByteDance motion, upscale, and avatar endpoints validate required media")
    func byteDanceUtilityEndpointsMapRequiredMedia() async throws {
        let dreamMock = FalCatalogAuditMock()
        let dream = try await withFalDependencies(dreamMock) {
            let adapter = G_FAL_BYTEDANCE_DREAMACTOR_V2()
            _ = try await adapter.makeRequest(request: videoRequest(
                clientImage: "character",
                clientVideo: "driver",
                durationSeconds: 10
            ))
            return adapter
        }
        let dreamJSON = try capturedJSON(dreamMock)
        #expect(dreamJSON["image_url"] as? String == "data:image/png;base64,character")
        #expect(dreamJSON["video_url"] as? String == "data:video/mp4;base64,driver")
        #expect(dreamJSON["cut_first_second"] == nil)
        #expect(dreamJSON["trim_first_second"] as? Bool == true)
        #expect(abs(dream.getCostEstimate(request: VideoGenerationCostRequest(durationSeconds: 10)) - 0.5) < 0.0001)

        let upscaleMock = FalCatalogAuditMock()
        let upscale = try await withFalDependencies(upscaleMock) {
            let adapter = G_FAL_BYTEDANCE_VIDEO_UPSCALER()
            _ = try await adapter.makeRequest(request: videoRequest(
                clientVideo: "source-video",
                durationSeconds: 10,
                resolution: "4K"
            ))
            return adapter
        }
        let upscaleJSON = try capturedJSON(upscaleMock)
        #expect(upscaleJSON["target_resolution"] as? String == "4k")
        #expect(upscaleJSON["target_fps"] as? String == "30fps")
        #expect(abs(upscale.getCostEstimate(request: VideoGenerationCostRequest(
            durationSeconds: 10,
            resolution: "4K"
        )) - 0.288) < 0.0001)

        let avatarMock = FalCatalogAuditMock()
        try await withFalDependencies(avatarMock) {
            _ = try await G_FAL_BYTEDANCE_OMNIHUMAN_V15().makeRequest(request: videoRequest(
                clientImage: "portrait",
                durationSeconds: 10,
                resolution: "720p",
                sourceMetadata: ["audio_url": "https://example.com/speech.mp3"]
            ))
        }
        let avatarJSON = try capturedJSON(avatarMock)
        #expect(avatarJSON["image_url"] as? String == "data:image/png;base64,portrait")
        #expect(avatarJSON["audio_url"] as? String == "https://example.com/speech.mp3")
        #expect(avatarJSON["resolution"] as? String == "720p")
    }

    @Test("LTX extension sends aligned output size and frame budget")
    func ltxExtensionSendsAlignedOutputSize() async throws {
        let mock = FalCatalogAuditMock(response: .dictionary(statusCode: 200, data: [
            "video": ["url": "data:video/mp4;base64,dmlkZW8="],
        ]))
        let result = try await withFalDependencies(mock) {
            try await G_FAL_LTX_23_EXTEND().makeRequest(request: videoRequest(
                negativePrompt: "blur",
                clientLastFrame: "end-frame",
                clientVideo: "source-video",
                durationSeconds: 5,
                resolution: "720p",
                generateAudio: false,
                seed: 42,
                promptEnhance: false,
                sourceMetadata: ["extend_direction": "backward"]
            ))
        }

        let json = try capturedJSON(mock)
        let resolution = try #require(json["resolution"] as? [String: Any])
        #expect(json["num_frames"] as? Int == 145)
        #expect(json["num_context_frames"] as? Int == 25)
        #expect(json["extend_direction"] as? String == "backward")
        #expect(json["end_image_url"] as? String == "data:image/png;base64,end-frame")
        #expect(json["generate_audio"] as? Bool == false)
        #expect(resolution["width"] as? Int == 1280)
        #expect(resolution["height"] as? Int == 704)
        #expect(result.status == .GENERATED)
        #expect(result.base64 == "dmlkZW8=")
        #expect(abs((result.cost ?? 0) - 0.3153825) < 0.001)
    }

    @Test("Fal catalog refresh registrations expose compatible capabilities")
    func catalogRefreshRegistrationsExposeCapabilities() throws {
        let models = FALModels.createModels()
        let expected: [EnumProviderModelCode: String] = [
            .FAL_IDEOGRAM_V4_FAST: "https://fal.run/ideogram/v4/fast",
            .FAL_IDEOGRAM_V4_INSTANT: "https://fal.run/ideogram/v4/instant",
            .FAL_BYTEDANCE_BERNINI_R_EDIT_IMAGE: "https://fal.run/fal-ai/bernini-r/edit-image",
            .FAL_GOOGLE_GEMINI_OMNI_FLASH_T2V: "https://fal.run/google/gemini-omni-flash",
            .FAL_GOOGLE_GEMINI_OMNI_FLASH_EDIT: "https://fal.run/google/gemini-omni-flash/edit",
            .FAL_BYTEDANCE_BERNINI_R_T2V: "https://fal.run/fal-ai/bernini-r/text-to-video",
            .FAL_BYTEDANCE_BERNINI_R_REF2V: "https://fal.run/fal-ai/bernini-r/reference-to-video",
            .FAL_BYTEDANCE_BERNINI_R_EDIT_VIDEO: "https://fal.run/fal-ai/bernini-r/edit-video",
            .FAL_BYTEDANCE_BERNINI_R_REFERENCE_EDIT_VIDEO: "https://fal.run/fal-ai/bernini-r/reference-edit-video",
            .FAL_BYTEDANCE_DREAMACTOR_V2: "https://fal.run/fal-ai/bytedance/dreamactor/v2",
            .FAL_BYTEDANCE_VIDEO_UPSCALER: "https://fal.run/fal-ai/bytedance-upscaler/upscale/video",
            .FAL_BYTEDANCE_OMNIHUMAN_V15: "https://fal.run/fal-ai/bytedance/omnihuman/v1.5",
            .FAL_LTX_23_EXTEND: "https://fal.run/fal-ai/ltx-2.3-quality/extend-video",
        ]

        for (code, endpoint) in expected {
            let model = try #require(models.first { $0.modelCode == code })
            #expect(model.modelGenerateBaseURL == endpoint)
            #expect(model.providerId == EnumProviderCode.FAL_AI.providerId)
            #expect(model.active)
        }

        let dreamActor = try #require(models.first { $0.modelCode == .FAL_BYTEDANCE_DREAMACTOR_V2 })
        #expect(dreamActor.modelParams.supportsSourceImage)
        #expect(dreamActor.modelParams.supportsVideoUpload)
        #expect(!dreamActor.modelParams.supportsPrompt)

        let omniHuman = try #require(models.first { $0.modelCode == .FAL_BYTEDANCE_OMNIHUMAN_V15 })
        #expect(omniHuman.modelParams.requiredMetadata == ["audio_url"])
        #expect(omniHuman.modelParams.supportsSourceImage)

        let ltx = try #require(models.first { $0.modelCode == .FAL_LTX_23_EXTEND })
        #expect(ltx.modelSetType == .VIDEO_EXTEND)
        #expect(ltx.modelParams.supportsVideoUpload)
        #expect(ltx.modelParams.supportsLastFrame)
    }

    private func withFalDependencies<Result>(
        _ mock: FalCatalogAuditMock,
        operation: () async throws -> Result
    ) async rethrows -> Result {
        try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: FalCatalogAuditModelProvider(),
            operation: operation
        )
    }

    private func capturedJSON(_ mock: FalCatalogAuditMock) throws -> [String: Any] {
        let data = try #require(mock.capturedBodyData)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func imageRequest(
        negativePrompt: String? = nil,
        dimensions: String = "1024x1024",
        clientImage: String? = nil,
        clientReferenceImages: [ReferenceImageData]? = nil,
        numberOfImages: Int = 1,
        resolution: String? = nil,
        steps: Int? = nil,
        seed: Int? = nil,
        promptEnhance: Bool? = nil
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: UUID().uuidString,
            prompt: "A polished editorial scene.",
            negativePrompt: negativePrompt,
            dimensions: dimensions,
            clientImage: clientImage,
            clientReferenceImages: clientReferenceImages,
            providerKey: providerKey(),
            providerSecret: "fal-test",
            numberOfImages: numberOfImages,
            resolution: resolution,
            steps: steps,
            seed: seed,
            promptEnhance: promptEnhance
        )
    }

    private func videoRequest(
        negativePrompt: String? = nil,
        dimensions: String = "16:9",
        clientImage: String? = nil,
        clientMask: String? = nil,
        clientLastFrame: String? = nil,
        clientVideo: String? = nil,
        clientReferenceImages: [ReferenceImageData]? = nil,
        durationSeconds: Int? = 5,
        resolution: String? = nil,
        fps: Int? = nil,
        generateAudio: Bool? = nil,
        seed: Int? = nil,
        promptEnhance: Bool? = nil,
        sourceMetadata: [String: String]? = nil
    ) -> VideoGenerationRequest {
        VideoGenerationRequest(
            modelId: UUID().uuidString,
            prompt: "A cinematic camera move.",
            negativePrompt: negativePrompt,
            dimensions: dimensions,
            clientImage: clientImage,
            clientMask: clientMask,
            clientLastFrame: clientLastFrame,
            clientVideo: clientVideo,
            clientReferenceImages: clientReferenceImages,
            providerKey: providerKey(),
            providerSecret: "fal-test",
            durationSeconds: durationSeconds,
            resolution: resolution,
            fps: fps,
            generateAudio: generateAudio,
            seed: seed,
            promptEnhance: promptEnhance,
            sourceMetadata: sourceMetadata
        )
    }

    private func providerKey() -> ProviderKeyInfo {
        ProviderKeyInfo(
            providerId: EnumProviderCode.FAL_AI.providerId,
            providerCode: .FAL_AI,
            projectId: UUID()
        )
    }
}

private final class FalCatalogAuditMock: @unchecked Sendable, NetworkProvider {
    var capturedURL: URL?
    var capturedBodyData: Data?
    let response: NetworkResponseData

    init(response: NetworkResponseData = .dictionary(statusCode: 400, data: ["detail": "stubbed response"])) {
        self.response = response
    }

    func performRequest(
        url: URL,
        method _: String,
        body: (some Codable & Sendable)?,
        headers _: [String: String]?,
        attachments _: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseData {
        capturedURL = url
        if let body {
            capturedBodyData = try JSONEncoder().encode(body)
        }
        return response
    }
}

private struct FalCatalogAuditModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        FALModels.createModels().first { $0.modelCode == code }
    }
}
