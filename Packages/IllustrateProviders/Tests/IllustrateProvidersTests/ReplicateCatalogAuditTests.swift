import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Replicate catalog audit adapters", .serialized)
struct ReplicateCatalogAuditTests {
    @Test("Seedream Lite uses its current schema and unit price")
    func seedreamLiteUsesCurrentSchema() {
        let adapter = G_REPLICATE_SEEDREAM_5_LITE()
        let input = adapter.buildInput(
            request: imageRequest(dimensions: "16:9", resolution: "3K", seed: 99),
            sourceImageURL: "https://files.example/source.png",
            maskURL: nil,
            referenceImageURLs: ["https://files.example/ref.png"]
        )

        #expect(input.prompt == "A polished editorial scene.")
        #expect(input.image_input == [
            "https://files.example/source.png",
            "https://files.example/ref.png",
        ])
        #expect(input.aspect_ratio == "16:9")
        #expect(input.size == "3K")
        #expect(input.max_images == 1)
        #expect(input.sequential_image_generation == "disabled")
        #expect(input.seed == nil)
        #expect(abs(adapter.getCostEstimate(request: ImageGenerationCostRequest(numberOfImages: 1)) - 0.035) < 0.0001)
    }

    @Test("FLUX Fill and Bria generation payloads map image controls")
    func imageGenerationPayloadsMapControls() {
        let flux = G_REPLICATE_FLUX_FILL_PRO()
        let fluxInput = flux.buildInput(
            request: imageRequest(
                guidance: 120,
                steps: 4,
                seed: 7,
                safetyTolerance: 9,
                promptEnhance: true
            ),
            sourceImageURL: "https://files.example/source.png",
            maskURL: "https://files.example/mask.png",
            referenceImageURLs: []
        )
        #expect(fluxInput.image == "https://files.example/source.png")
        #expect(fluxInput.mask == "https://files.example/mask.png")
        #expect(fluxInput.guidance == 100)
        #expect(fluxInput.steps == 15)
        #expect(fluxInput.safety_tolerance == 6)
        #expect(fluxInput.prompt_upsampling == true)
        #expect(abs(flux.getCostEstimate(request: ImageGenerationCostRequest()) - 0.05) < 0.0001)

        let fiboInput = G_REPLICATE_BRIA_FIBO().buildInput(
            request: imageRequest(
                negativePrompt: "blur",
                dimensions: "1080x1920",
                guidance: 9,
                seed: 8
            ),
            sourceImageURL: "https://files.example/source.png",
            maskURL: nil,
            referenceImageURLs: []
        )
        #expect(fiboInput.aspect_ratio == "9:16")
        #expect(fiboInput.guidance_scale == 5)
        #expect(fiboInput.negative_prompt == "blur")

        let imageInput = G_REPLICATE_BRIA_IMAGE_3_2().buildInput(
            request: imageRequest(dimensions: "3:2", promptEnhance: true),
            sourceImageURL: nil,
            maskURL: nil,
            referenceImageURLs: []
        )
        #expect(imageInput.aspect_ratio == "3:2")
        #expect(imageInput.prompt_enhancement == true)
    }

    @Test("Bria edit utilities require and encode source media")
    func briaEditUtilitiesEncodeSourceMedia() async throws {
        let missingMask = try await G_REPLICATE_BRIA_ERASER().makeRequest(request: imageRequest(clientImage: "source"))
        #expect(missingMask.status == .FAILED)
        #expect(missingMask.errorMessage == "This model requires a mask")

        let editInput = G_REPLICATE_BRIA_FIBO_EDIT().buildInput(
            request: imageRequest(negativePrompt: "noise", guidance: 4.5, seed: 11),
            sourceImageURL: "https://files.example/source.png",
            maskURL: "https://files.example/mask.png",
            referenceImageURLs: []
        )
        #expect(editInput.instruction == "A polished editorial scene.")
        #expect(editInput.image == "https://files.example/source.png")
        #expect(editInput.mask == "https://files.example/mask.png")

        let expandInput = G_REPLICATE_BRIA_EXPAND_IMAGE().buildInput(
            request: imageRequest(dimensions: "4:5"),
            sourceImageURL: "https://files.example/source.png",
            maskURL: nil,
            referenceImageURLs: []
        )
        #expect(expandInput.aspect_ratio == "4:5")
        #expect(expandInput.sync == true)

        let backgroundInput = G_REPLICATE_BRIA_GENERATE_BACKGROUND().buildInput(
            request: imageRequest(promptEnhance: false),
            sourceImageURL: "https://files.example/product.png",
            maskURL: nil,
            referenceImageURLs: ["https://files.example/background.png"]
        )
        #expect(backgroundInput.bg_prompt == "A polished editorial scene.")
        #expect(backgroundInput.ref_image_file == "https://files.example/background.png")
        #expect(backgroundInput.refine_prompt == false)
    }

    @Test("Riverflow variants encode current agentic image controls")
    func riverflowPayloadAndCost() {
        let pro = G_REPLICATE_RIVERFLOW_2_5_PRO()
        let input = pro.buildInput(
            request: imageRequest(dimensions: "21:9", resolution: "4K", promptEnhance: true),
            sourceImageURL: "https://files.example/source.png",
            maskURL: nil,
            referenceImageURLs: ["https://files.example/ref.png"]
        )

        #expect(input.instruction == "A polished editorial scene.")
        #expect(input.init_images == ["https://files.example/source.png", "https://files.example/ref.png"])
        #expect(input.aspect_ratio == "21:9")
        #expect(input.resolution == "4K")
        #expect(input.output_format == "png")
        #expect(input.thinking_level == "medium")
        #expect(abs(pro.getCostEstimate(request: ImageGenerationCostRequest()) - 0.02) < 0.0001)
        #expect(pro.formatCost(request: ImageGenerationCostRequest()).hasSuffix("+"))
        #expect(abs(G_REPLICATE_RIVERFLOW_2_5_FAST().getCostEstimate(
            request: ImageGenerationCostRequest()
        ) - 0.0041) < 0.0001)
    }

    @Test("Wan 2.7 adapters use current text and image schemas")
    func wan27PayloadsAndCosts() {
        let text = G_REPLICATE_WAN_2_7_T2V()
        let textInput = text.buildInput(
            request: videoRequest(
                negativePrompt: "blur",
                dimensions: "4:3",
                durationSeconds: 20,
                resolution: "720p",
                seed: 12,
                promptEnhance: false
            ),
            sourceImageURL: nil,
            lastFrameURL: nil,
            videoURL: nil,
            referenceImageURLs: []
        )
        #expect(textInput.aspect_ratio == "4:3")
        #expect(textInput.duration == 15)
        #expect(textInput.resolution == "720p")
        #expect(textInput.enable_prompt_expansion == false)
        #expect(abs(text.getCostEstimate(request: VideoGenerationCostRequest(durationSeconds: 5)) - 0.5) < 0.0001)

        let image = G_REPLICATE_WAN_2_7_I2V()
        let imageInput = image.buildInput(
            request: videoRequest(durationSeconds: 12, resolution: "1080p", seed: 13),
            sourceImageURL: "https://files.example/start.png",
            lastFrameURL: "https://files.example/end.png",
            videoURL: nil,
            referenceImageURLs: []
        )
        #expect(imageInput.first_frame == "https://files.example/start.png")
        #expect(imageInput.last_frame == "https://files.example/end.png")
        #expect(imageInput.first_clip == nil)
        #expect(abs(image.getCostEstimate(request: VideoGenerationCostRequest(
            durationSeconds: 12,
            resolution: "1080p"
        )) - 1.8) < 0.0001)
    }

    @Test("Vidu Q3 Pro and Grok Video encode current controls")
    func currentVideoGenerationPayloads() {
        let vidu = G_REPLICATE_VIDU_Q3_PRO()
        let viduInput = vidu.buildInput(
            request: videoRequest(
                dimensions: "3:4",
                durationSeconds: 18,
                resolution: "1080p",
                generateAudio: false,
                seed: 14
            ),
            sourceImageURL: "https://files.example/start.png",
            lastFrameURL: "https://files.example/end.png",
            videoURL: nil,
            referenceImageURLs: []
        )
        #expect(viduInput.start_image == "https://files.example/start.png")
        #expect(viduInput.end_image == "https://files.example/end.png")
        #expect(viduInput.duration == 16)
        #expect(viduInput.audio == false)
        #expect(abs(vidu.getCostEstimate(request: VideoGenerationCostRequest(
            durationSeconds: 10,
            resolution: "1080p"
        )) - 1.6) < 0.0001)

        let grok = G_REPLICATE_XAI_GROK_IMAGINE_VIDEO_1_5()
        let grokInput = grok.buildInput(
            request: videoRequest(dimensions: "2:3", durationSeconds: 15, resolution: "480p"),
            sourceImageURL: "https://files.example/source.png",
            lastFrameURL: nil,
            videoURL: nil,
            referenceImageURLs: []
        )
        #expect(grokInput.image == "https://files.example/source.png")
        #expect(grokInput.aspect_ratio == "2:3")
        #expect(grokInput.resolution == "480p")
        #expect(abs(grok.getCostEstimate(request: VideoGenerationCostRequest(durationSeconds: 15)) - 1.2) < 0.0001)
    }

    @Test("Motion transfer and video edit payloads preserve required media")
    func motionTransferPayloads() {
        let dream = G_REPLICATE_BYTEDANCE_DREAMACTOR_M2_0()
        let dreamInput = dream.buildInput(
            request: videoRequest(),
            sourceImageURL: "https://files.example/character.png",
            lastFrameURL: nil,
            videoURL: "https://files.example/driver.mp4",
            referenceImageURLs: []
        )
        #expect(dreamInput.image == "https://files.example/character.png")
        #expect(dreamInput.video == "https://files.example/driver.mp4")
        #expect(dreamInput.cut_first_second == true)

        let animate = G_REPLICATE_PRUNA_P_VIDEO_ANIMATE()
        let animateInput = animate.buildInput(
            request: videoRequest(resolution: "1080p", fps: 48, generateAudio: false, seed: 15),
            sourceImageURL: "https://files.example/subject.png",
            lastFrameURL: nil,
            videoURL: "https://files.example/motion.mp4",
            referenceImageURLs: []
        )
        #expect(animateInput.target_fps == "48")
        #expect(animateInput.save_audio == false)
        #expect(animateInput.ignore_audio == true)
        #expect(abs(animate.getCostEstimate(request: VideoGenerationCostRequest(
            durationSeconds: 10,
            resolution: "1080p"
        )) - 0.6) < 0.0001)

        let kling = G_REPLICATE_KLING_O1()
        let klingInput = kling.buildInput(
            request: videoRequest(generateAudio: true),
            sourceImageURL: "https://files.example/source.png",
            lastFrameURL: nil,
            videoURL: "https://files.example/edit.mp4",
            referenceImageURLs: ["https://files.example/ref.png"]
        )
        #expect(klingInput.reference_video == "https://files.example/edit.mp4")
        #expect(klingInput.reference_images == [
            "https://files.example/source.png",
            "https://files.example/ref.png",
        ])
        #expect(klingInput.video_reference_type == "base")
        #expect(klingInput.mode == "pro")
        #expect(klingInput.keep_original_sound == true)
    }

    @Test("Versionless prediction request posts to corrected Wan endpoint")
    func postsToCorrectedWanEndpoint() async throws {
        let mock = ReplicateCatalogAuditMock()
        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: ReplicateCatalogAuditModelProvider()
        ) {
            try await G_REPLICATE_WAN_2_7_T2V().makeRequest(request: videoRequest())
        }

        let input = try capturedInput(mock)
        #expect(mock.capturedURL?.absoluteString ==
            "https://api.replicate.com/v1/models/wan-video/wan-2.7-t2v/predictions")
        #expect(mock.capturedHeaders?["Authorization"] == "Bearer replicate-test")
        #expect(input["prompt"] as? String == "A cinematic camera move.")
        #expect(response.status == .FAILED)
        #expect(response.errorMessage == "stubbed replicate response")
    }

    @Test("Data URI outputs and model registrations are complete")
    func outputAndRegistrationAudit() throws {
        let imageResponse = try G_REPLICATE_FLUX_FILL_PRO().transformResponse(
            request: imageRequest(),
            response: .dictionary(statusCode: 200, data: [
                "status": "succeeded",
                "output": "data:image/png;base64,aW1hZ2U=",
            ])
        )
        #expect(imageResponse.status == .GENERATED)
        #expect(imageResponse.base64 == "aW1hZ2U=")

        let models = ReplicateModels.createModels()
        let expected: [EnumProviderModelCode: String] = [
            .REPLICATE_FLUX_FILL_PRO: "black-forest-labs/flux-fill-pro",
            .REPLICATE_BRIA_FIBO: "bria/fibo",
            .REPLICATE_BRIA_FIBO_EDIT: "bria/fibo-edit",
            .REPLICATE_BRIA_IMAGE_3_2: "bria/image-3.2",
            .REPLICATE_BRIA_ERASER: "bria/eraser",
            .REPLICATE_BRIA_GENFILL: "bria/genfill",
            .REPLICATE_BRIA_EXPAND_IMAGE: "bria/expand-image",
            .REPLICATE_BRIA_GENERATE_BACKGROUND: "bria/generate-background",
            .REPLICATE_RIVERFLOW_2_5_PRO: "sourceful/riverflow-v2.5-pro",
            .REPLICATE_RIVERFLOW_2_5_FAST: "sourceful/riverflow-v2.5-fast",
            .REPLICATE_XAI_GROK_IMAGINE_VIDEO_1_5: "xai/grok-imagine-video-1.5",
            .REPLICATE_BYTEDANCE_DREAMACTOR_M2_0: "bytedance/dreamactor-m2.0",
            .REPLICATE_PRUNA_P_VIDEO_ANIMATE: "prunaai/p-video-animate",
            .REPLICATE_KLING_O1: "kwaivgi/kling-o1",
        ]

        for (code, slug) in expected {
            let model = try #require(models.first { $0.modelCode == code })
            #expect(model.modelGenerateBaseURL == "https://api.replicate.com/v1/models/\(slug)/predictions")
            #expect(model.modelAPIDocumentationURL == "https://replicate.com/\(slug)")
            #expect(model.active)
        }

        let wan = try #require(models.first { $0.modelCode == .REPLICATE_WAN_2_7_I2V })
        let vidu = try #require(models.first { $0.modelCode == .REPLICATE_VIDU_Q3_PRO })
        let seedream = try #require(models.first { $0.modelCode == .REPLICATE_SEEDREAM_5_LITE })
        #expect(wan.modelGenerateBaseURL.contains("wan-video/wan-2.7-i2v"))
        #expect(wan.modelParams.supportsVideoUpload)
        #expect(vidu.modelGenerateBaseURL.contains("vidu/q3-pro"))
        #expect(vidu.modelParams.supportedVideoResolutions == ["540p", "720p", "1080p"])
        #expect(seedream.modelParams.maxReferenceImages == 14)
        #expect(!seedream.modelParams.supportsSeed)
    }

    private func capturedInput(_ mock: ReplicateCatalogAuditMock) throws -> [String: Any] {
        let data = try #require(mock.capturedBodyData)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(json["input"] as? [String: Any])
    }

    private func imageRequest(
        negativePrompt: String? = nil,
        dimensions: String = "1024x1024",
        clientImage: String? = nil,
        clientMask: String? = nil,
        resolution: String? = nil,
        guidance: Double? = nil,
        steps: Int? = nil,
        seed: Int? = nil,
        safetyTolerance: Int? = nil,
        promptEnhance: Bool? = nil
    ) -> ImageGenerationRequest {
        ImageGenerationRequest(
            modelId: UUID().uuidString,
            prompt: "A polished editorial scene.",
            negativePrompt: negativePrompt,
            dimensions: dimensions,
            clientImage: clientImage,
            clientMask: clientMask,
            providerKey: providerKey(),
            providerSecret: "replicate-test",
            numberOfImages: 1,
            resolution: resolution,
            steps: steps,
            guidance: guidance,
            seed: seed,
            safetyTolerance: safetyTolerance,
            promptEnhance: promptEnhance
        )
    }

    private func videoRequest(
        negativePrompt: String? = nil,
        dimensions: String = "16:9",
        durationSeconds: Int? = 5,
        resolution: String? = "720p",
        fps: Int? = nil,
        generateAudio: Bool? = true,
        seed: Int? = nil,
        promptEnhance: Bool? = nil
    ) -> VideoGenerationRequest {
        VideoGenerationRequest(
            modelId: UUID().uuidString,
            prompt: "A cinematic camera move.",
            negativePrompt: negativePrompt,
            dimensions: dimensions,
            providerKey: providerKey(),
            providerSecret: "replicate-test",
            durationSeconds: durationSeconds,
            resolution: resolution,
            fps: fps,
            generateAudio: generateAudio,
            seed: seed,
            promptEnhance: promptEnhance
        )
    }

    private func providerKey() -> ProviderKeyInfo {
        ProviderKeyInfo(
            providerId: EnumProviderCode.REPLICATE.providerId,
            providerCode: .REPLICATE,
            projectId: UUID()
        )
    }
}

private final class ReplicateCatalogAuditMock: @unchecked Sendable, NetworkProvider {
    var capturedURL: URL?
    var capturedBodyData: Data?
    var capturedHeaders: [String: String]?

    func performRequest(
        url: URL,
        method _: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments _: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseData {
        capturedURL = url
        capturedHeaders = headers
        if let body {
            capturedBodyData = try JSONEncoder().encode(body)
        }
        return .dictionary(statusCode: 400, data: ["error": "stubbed replicate response"])
    }
}

private struct ReplicateCatalogAuditModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        ReplicateModels.createModels().first { $0.modelCode == code }
    }
}
