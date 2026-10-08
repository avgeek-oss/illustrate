import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Together Veo 3.1 video adapters", .serialized)
struct TogetherVeo31VideoTests {
    @Test("Production model IDs use prompt-only Together payloads")
    func payloadUsesPublishedContractOnly() {
        let standard = G_TOGETHER_VEO_31().transformRequest(request: videoRequest())
        let lite = G_TOGETHER_VEO_31_LITE().transformRequest(request: videoRequest())

        #expect(standard.model == "google/veo-3.1")
        #expect(lite.model == "google/veo-3.1-lite")
        #expect(standard.prompt == "A cinematic aircraft hangar reveal.")
        #expect(standard.width == nil)
        #expect(standard.height == nil)
        #expect(standard.resolution == nil)
        #expect(standard.ratio == nil)
        #expect(standard.seconds == nil)
        #expect(standard.seed == nil)
        #expect(standard.generate_audio == nil)
        #expect(standard.frame_images == nil)
        #expect(standard.media == nil)
    }

    @Test("Unpublished pricing remains zero without claiming the models are free")
    func pricingIsExplicitlyUnavailable() {
        let request = VideoGenerationCostRequest(numberOfVideos: 3)

        #expect(G_TOGETHER_VEO_31().getCostEstimate(request: request) == 0)
        #expect(G_TOGETHER_VEO_31_LITE().getCostEstimate(request: request) == 0)
        #expect(G_TOGETHER_VEO_31().formatCost(request: request) == "Pricing unavailable")
        #expect(G_TOGETHER_VEO_31_LITE().formatCost(request: request) == "Pricing unavailable")
    }

    @Test("Both production entries are active without invented capability metadata")
    func metadataIsRegistered() throws {
        let models = TogetherAIModels.createModels()
        let standard = try #require(models.first { $0.modelCode == .TOGETHER_VEO_31 })
        let lite = try #require(models.first { $0.modelCode == .TOGETHER_VEO_31_LITE })

        #expect(standard.active)
        #expect(lite.active)
        #expect(standard.modelName == "Veo 3.1")
        #expect(lite.modelName == "Veo 3.1 Lite")
        #expect(standard.modelParams.maxPromptLength == 32000)
        #expect(standard.modelParams.supportedDimensions.isEmpty)
        #expect(standard.modelParams.supportedVideoDurations.isEmpty)
        #expect(standard.modelParams.supportedVideoResolutions.isEmpty)
        #expect(!standard.modelParams.supportsSourceImage)
        #expect(!standard.modelParams.supportsAudio)
    }

    private func videoRequest() -> VideoGenerationRequest {
        VideoGenerationRequest(
            modelId: UUID().uuidString,
            prompt: "A cinematic aircraft hangar reveal.",
            negativePrompt: "low quality",
            dimensions: "1920x1080",
            clientImage: "data:image/png;base64,c291cmNl",
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.TOGETHER_AI.providerId,
                providerCode: .TOGETHER_AI,
                projectId: UUID()
            ),
            providerSecret: "together-test",
            durationSeconds: 8,
            resolution: "1080p",
            generateAudio: true,
            seed: 123
        )
    }
}
