import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Together Wan 2.7 video adapters", .serialized)
struct TogetherWan27VideoTests {
    @Test("T2V sends Wan resolution ratio payload without width and height")
    func t2vPayloadUsesWanSchema() {
        let adapter = G_TOGETHER_WAN_27_T2V()
        let payload = adapter.transformRequest(
            request: videoRequest(
                dimensions: "1920x1080",
                durationSeconds: 10,
                resolution: "1080p",
                generateAudio: true,
                seed: 123
            )
        )

        #expect(payload.model == "Wan-AI/wan2.7-t2v")
        #expect(payload.prompt == "A cinematic aircraft hangar reveal.")
        #expect(payload.width == nil)
        #expect(payload.height == nil)
        #expect(payload.resolution == "1080P")
        #expect(payload.ratio == "16:9")
        #expect(payload.seconds == "10")
        #expect(payload.generate_audio == true)
        #expect(payload.seed == 123)
        #expect(payload.media == nil)
        #expect(payload.frame_images == nil)
    }

    @Test("I2V sends first and last frames under media.frame_images")
    func i2vPayloadUsesMediaFrameImages() throws {
        let adapter = G_TOGETHER_WAN_27_I2V()
        let payload = adapter.transformRequest(
            request: videoRequest(
                dimensions: "3:4",
                durationSeconds: 30,
                resolution: "720p",
                clientImage: "data:image/png;base64,c3RhcnQ=",
                clientLastFrame: "ZW5k"
            )
        )

        let frameImages = try #require(payload.media?.frame_images)
        #expect(payload.model == "Wan-AI/wan2.7-i2v")
        #expect(payload.width == nil)
        #expect(payload.height == nil)
        #expect(payload.resolution == "720P")
        #expect(payload.ratio == "3:4")
        #expect(payload.seconds == "15")
        #expect(payload.frame_images == nil)
        #expect(frameImages.count == 2)
        #expect(frameImages[0].input_image == "c3RhcnQ=")
        #expect(frameImages[0].frame == "first")
        #expect(frameImages[1].input_image == "ZW5k")
        #expect(frameImages[1].frame == "last")
    }

    @Test("R2V sends reference images only under media.reference_images")
    func r2vPayloadUsesReferenceMedia() throws {
        let adapter = G_TOGETHER_WAN_27_R2V()
        let payload = adapter.transformRequest(
            request: videoRequest(
                dimensions: "1080x1080",
                durationSeconds: 12,
                resolution: "bad-value",
                clientImage: "c291cmNl",
                referenceImages: [
                    ReferenceImageData(base64Image: "data:image/png;base64,cmVmMQ=="),
                    ReferenceImageData(base64Image: "cmVmMg=="),
                    ReferenceImageData(base64Image: "cmVmMw=="),
                    ReferenceImageData(base64Image: "cmVmNA=="),
                    ReferenceImageData(base64Image: "cmVmNQ=="),
                ]
            )
        )

        let media = try #require(payload.media)
        #expect(payload.model == "Wan-AI/wan2.7-r2v")
        #expect(payload.resolution == "1080P")
        #expect(payload.ratio == "1:1")
        #expect(payload.seconds == "10")
        #expect(media.frame_images == nil)
        #expect(media.reference_images == ["cmVmMQ==", "cmVmMg==", "cmVmMw==", "cmVmNA=="])
    }

    @Test("Wan 2.7 pricing uses serverless catalog per video cost")
    func wan27CostUsesCatalogPrice() {
        let adapter = G_TOGETHER_WAN_27_T2V()

        #expect(abs(adapter.getCostEstimate(request: costRequest()) - 0.10) < 0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(numberOfVideos: 3)) - 0.30) < 0.0001)
        #expect(adapter.formatCost(request: costRequest()) == "$0.1")
    }

    @Test("Wan 2.7 response helpers parse completed URL and errors")
    func responseHelpersParseTerminalData() {
        let adapter = G_TOGETHER_WAN_27_T2V()

        #expect(adapter.extractCompletedVideoURL(from: [
            "outputs": ["video_url": "https://example.com/video.mp4"],
        ]) == "https://example.com/video.mp4")
        #expect(adapter.extractCompletedVideoURL(from: ["outputs": [:]]) == nil)
        #expect(adapter.extractErrorMessage(from: ["error": ["message": "Prompt rejected"]]) == "Prompt rejected")
        #expect(adapter.extractErrorMessage(from: ["error": "Quota exceeded"]) == "Quota exceeded")
    }

    @Test("Wan 2.7 model metadata exposes documented ratios and media capabilities")
    func wan27MetadataIsRegistered() throws {
        let models = TogetherAIModels.createModels()
        let t2v = try #require(models.first { $0.modelCode == .TOGETHER_WAN_27_T2V })
        let i2v = try #require(models.first { $0.modelCode == .TOGETHER_WAN_27_I2V })
        let r2v = try #require(models.first { $0.modelCode == .TOGETHER_WAN_27_R2V })

        #expect(t2v.modelParams.maxPromptLength == 5000)
        #expect(t2v.modelParams.supportedDimensions == ["16:9", "9:16", "1:1", "4:3", "3:4"])
        #expect(t2v.modelParams.supportedVideoResolutions == ["720p", "1080p"])
        #expect(t2v.modelParams.supportedVideoDurations.first == 2)
        #expect(t2v.modelParams.supportedVideoDurations.last == 15)
        #expect(!t2v.modelParams.supportsSourceImage)

        #expect(i2v.modelParams.supportsSourceImage)
        #expect(i2v.modelParams.supportsLastFrame)
        #expect(i2v.modelParams.supportedVideoDurations.last == 15)

        #expect(r2v.modelParams.supportsReferenceImages)
        #expect(r2v.modelParams.maxReferenceImages == 4)
        #expect(r2v.modelParams.supportedReferenceTypes == ["asset", "style"])
        #expect(r2v.modelParams.supportedVideoDurations.last == 10)
        #expect(!r2v.modelParams.supportsSourceImage)
    }

    private func videoRequest(
        dimensions: String = "16:9",
        durationSeconds: Int? = 5,
        resolution: String? = "720p",
        generateAudio: Bool? = nil,
        seed: Int? = nil,
        clientImage: String? = nil,
        clientLastFrame: String? = nil,
        referenceImages: [ReferenceImageData]? = nil
    ) -> VideoGenerationRequest {
        VideoGenerationRequest(
            modelId: UUID().uuidString,
            prompt: "A cinematic aircraft hangar reveal.",
            negativePrompt: "low quality",
            dimensions: dimensions,
            clientImage: clientImage,
            clientLastFrame: clientLastFrame,
            clientReferenceImages: referenceImages,
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.TOGETHER_AI.providerId,
                providerCode: .TOGETHER_AI,
                projectId: UUID()
            ),
            providerSecret: "together-test",
            durationSeconds: durationSeconds,
            resolution: resolution,
            generateAudio: generateAudio,
            seed: seed
        )
    }

    private func costRequest(numberOfVideos: Int? = nil) -> VideoGenerationCostRequest {
        VideoGenerationCostRequest(numberOfVideos: numberOfVideos)
    }
}
