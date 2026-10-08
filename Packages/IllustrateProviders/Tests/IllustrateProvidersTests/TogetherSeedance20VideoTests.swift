import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Together Seedance 2.0 video adapter", .serialized)
struct TogetherSeedance20VideoTests {
    @Test("T2V sends Seedance resolution ratio settings payload without width and height")
    func t2vPayloadUsesSeedanceSchema() {
        let adapter = G_TOGETHER_SEEDANCE_2()
        let payload = adapter.transformRequest(
            request: videoRequest(
                dimensions: "4398x1886",
                durationSeconds: 2,
                resolution: "4K",
                generateAudio: false,
                seed: 123
            )
        )

        #expect(payload.model == "ByteDance/Seedance-2.0")
        #expect(payload.prompt == "A cinematic aircraft hangar reveal.")
        #expect(payload.width == nil)
        #expect(payload.height == nil)
        #expect(payload.resolution == "4k")
        #expect(payload.ratio == "21:9")
        #expect(payload.seconds == "4")
        #expect(payload.generate_audio == nil)
        #expect(payload.settings?.audio == false)
        #expect(payload.seed == 123)
        #expect(payload.media == nil)
        #expect(payload.frame_images == nil)
    }

    @Test("I2V sends first and last frames under media.frame_images")
    func i2vPayloadUsesMediaFrameImages() throws {
        let adapter = G_TOGETHER_SEEDANCE_2()
        let payload = adapter.transformRequest(
            request: videoRequest(
                dimensions: "3:4",
                durationSeconds: 30,
                resolution: "1080p",
                clientImage: "data:image/png;base64,c3RhcnQ=",
                clientLastFrame: "ZW5k",
                referenceImages: [
                    ReferenceImageData(base64Image: "data:image/png;base64,aWdub3JlZA=="),
                ]
            )
        )

        let frameImages = try #require(payload.media?.frame_images)
        #expect(payload.resolution == "1080p")
        #expect(payload.ratio == "3:4")
        #expect(payload.seconds == "15")
        #expect(payload.frame_images == nil)
        #expect(frameImages.count == 2)
        #expect(frameImages[0].input_image == "c3RhcnQ=")
        #expect(frameImages[0].frame == "first")
        #expect(frameImages[1].input_image == "ZW5k")
        #expect(frameImages[1].frame == "last")
        #expect(payload.media?.reference_images == nil)
    }

    @Test("Reference guided request sends up to nine reference images")
    func referencePayloadUsesMediaReferenceImages() throws {
        let adapter = G_TOGETHER_SEEDANCE_2()
        let payload = adapter.transformRequest(
            request: videoRequest(
                dimensions: "1080x1080",
                durationSeconds: 8,
                resolution: "bad-value",
                referenceImages: [
                    ReferenceImageData(base64Image: "data:image/png;base64,cmVmMQ=="),
                    ReferenceImageData(base64Image: "cmVmMg=="),
                    ReferenceImageData(base64Image: "cmVmMw=="),
                    ReferenceImageData(base64Image: "cmVmNA=="),
                    ReferenceImageData(base64Image: "cmVmNQ=="),
                    ReferenceImageData(base64Image: "cmVmNg=="),
                    ReferenceImageData(base64Image: "cmVmNw=="),
                    ReferenceImageData(base64Image: "cmVmOA=="),
                    ReferenceImageData(base64Image: "cmVmOQ=="),
                    ReferenceImageData(base64Image: "cmVmMTA="),
                ]
            )
        )

        let media = try #require(payload.media)
        #expect(payload.resolution == "720p")
        #expect(payload.ratio == "1:1")
        #expect(payload.seconds == "8")
        #expect(media.frame_images == nil)
        #expect(media.reference_images == [
            "cmVmMQ==",
            "cmVmMg==",
            "cmVmMw==",
            "cmVmNA==",
            "cmVmNQ==",
            "cmVmNg==",
            "cmVmNw==",
            "cmVmOA==",
            "cmVmOQ==",
        ])
    }

    @Test("Seedance pricing uses documented resolution tiers")
    func seedanceCostUsesResolutionTiers() {
        let adapter = G_TOGETHER_SEEDANCE_2()

        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 5, resolution: "480p")) - 0.35) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 5, resolution: "720p")) - 0.80) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 5, resolution: "1080p")) - 2.00) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 5, resolution: "4k")) - 4.18) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(
            durationSeconds: 20,
            numberOfVideos: 2,
            resolution: "4K"
        )) - 25.08) < 0.0001)
        #expect(adapter.formatCost(request: costRequest(durationSeconds: 5, resolution: "720p")) == "$0.8")
    }

    @Test("Seedance response helper parses completed cost")
    func responseHelperParsesCompletedCost() {
        let adapter = G_TOGETHER_SEEDANCE_2()

        #expect(adapter.extractCompletedCost(from: ["outputs": ["cost": 1.23]]) == 1.23)
        #expect(adapter.extractCompletedCost(from: ["outputs": ["cost": "4.56"]]) == 4.56)
        #expect(adapter.extractCompletedCost(from: ["outputs": ["cost": 2]]) == 2.0)
        #expect(adapter.extractCompletedCost(from: ["outputs": [:]]) == nil)
    }

    @Test("Seedance model metadata exposes documented controls")
    func seedanceMetadataIsRegistered() throws {
        let models = TogetherAIModels.createModels()
        let seedance = try #require(models.first { $0.modelCode == .TOGETHER_SEEDANCE_2 })

        #expect(seedance.modelParams.maxPromptLength == 3000)
        #expect(seedance.modelParams.supportedDimensions == ["16:9", "9:16", "1:1", "4:3", "3:4", "21:9"])
        #expect(seedance.modelParams.supportedVideoResolutions == ["480p", "720p", "1080p", "4k"])
        #expect(seedance.modelParams.supportedVideoDurations.first == 4)
        #expect(seedance.modelParams.supportedVideoDurations.last == 15)
        #expect(seedance.modelParams.supportsAudio)
        #expect(seedance.modelParams.supportsLastFrame)
        #expect(seedance.modelParams.supportsSourceImage)
        #expect(seedance.modelParams.supportsReferenceImages)
        #expect(seedance.modelParams.maxReferenceImages == 9)
        #expect(seedance.modelParams.supportedReferenceTypes == ["asset", "style"])
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

    private func costRequest(
        durationSeconds: Int? = nil,
        numberOfVideos: Int? = nil,
        resolution: String? = nil
    ) -> VideoGenerationCostRequest {
        VideoGenerationCostRequest(
            durationSeconds: durationSeconds,
            numberOfVideos: numberOfVideos,
            resolution: resolution
        )
    }
}
