import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Replicate 2026 video refresh adapters", .serialized)
struct Replicate2026VideoRefreshTests {
    @Test("Seedance 2 Mini maps first/last frame payloads and non-video input pricing")
    func seedanceMiniPayloadAndCost() {
        let adapter = G_REPLICATE_SEEDANCE_2_MINI()
        let payload = adapter.transformRequest(
            request: videoRequest(
                dimensions: "9:21",
                durationSeconds: -1,
                resolution: "480p",
                generateAudio: false,
                seed: 123
            ),
            imageUrl: "https://files.example/start.png",
            lastFrameImageUrl: "https://files.example/end.png",
            referenceImageUrls: ["https://files.example/ref.png"]
        )

        #expect(payload.prompt == "A cinematic aircraft hangar reveal.")
        #expect(payload.image == "https://files.example/start.png")
        #expect(payload.last_frame_image == "https://files.example/end.png")
        #expect(payload.reference_images == nil)
        #expect(payload.duration == -1)
        #expect(payload.resolution == "480p")
        #expect(payload.aspect_ratio == "9:21")
        #expect(payload.generate_audio == false)
        #expect(payload.seed == 123)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 5, resolution: "480p")) - 0.20) <
            0.0001)
    }

    @Test("Seedance 2 Mini maps reference images when no first frame is present")
    func seedanceMiniReferencePayload() {
        let adapter = G_REPLICATE_SEEDANCE_2_MINI()
        let payload = adapter.transformRequest(
            request: videoRequest(dimensions: "21:9"),
            referenceImageUrls: ["https://files.example/ref-1.png", "https://files.example/ref-2.png"]
        )

        #expect(payload.image == nil)
        #expect(payload.last_frame_image == nil)
        #expect(payload.reference_images == ["https://files.example/ref-1.png", "https://files.example/ref-2.png"])
        #expect(payload.aspect_ratio == "21:9")
    }

    @Test("Happy Horse 1.1 maps image/reference URLs and resolution pricing")
    func happyHorse11PayloadAndCost() {
        let adapter = G_REPLICATE_HAPPY_HORSE_1_1()
        let payload = adapter.transformRequest(
            request: videoRequest(
                dimensions: "3:4",
                durationSeconds: 15,
                resolution: "720p",
                seed: 42
            ),
            imageUrls: ["https://files.example/source.png", "https://files.example/ref.png"]
        )

        #expect(payload.images == ["https://files.example/source.png", "https://files.example/ref.png"])
        #expect(payload.resolution == "720p")
        #expect(payload.aspect_ratio == "3:4")
        #expect(payload.duration == 15)
        #expect(payload.seed == 42)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 15, resolution: "720p")) - 2.10) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 5, resolution: "1080p")) - 0.90) <
            0.0001)
    }

    @Test("Luma Ray 3.2 sends SDR payloads and forces image-anchored clips to 5 seconds")
    func lumaRay32PayloadAndCost() {
        let adapter = G_REPLICATE_LUMA_RAY_3_2()
        let payload = adapter.transformRequest(
            request: videoRequest(
                dimensions: "1920x1080",
                durationSeconds: 10,
                resolution: "1080p",
                clientImage: "placeholder"
            ),
            startImageUrl: "https://files.example/start.png",
            endImageUrl: "https://files.example/end.png"
        )

        #expect(payload.aspect_ratio == "16:9")
        #expect(payload.resolution == "1080p")
        #expect(payload.duration == 5)
        #expect(payload.hdr == false)
        #expect(payload.exr_export == false)
        #expect(payload.loop == false)
        #expect(payload.start_image == "https://files.example/start.png")
        #expect(payload.end_image == "https://files.example/end.png")
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 5, resolution: "540p")) - 0.15) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 10, resolution: "1080p")) - 3.60) <
            0.0001)
    }

    @Test("Vidu Q3 Turbo maps start/end frames, audio, seed, and tiered cost")
    func viduQ3TurboPayloadAndCost() {
        let adapter = G_REPLICATE_VIDU_Q3_TURBO()
        let payload = adapter.transformRequest(
            request: videoRequest(
                dimensions: "4:3",
                durationSeconds: 30,
                resolution: "1080p",
                generateAudio: false,
                seed: 77
            ),
            startImageUrl: "https://files.example/start.png",
            endImageUrl: "https://files.example/end.png"
        )

        #expect(payload.start_image == "https://files.example/start.png")
        #expect(payload.end_image == "https://files.example/end.png")
        #expect(payload.duration == 16)
        #expect(payload.aspect_ratio == "4:3")
        #expect(payload.resolution == "1080p")
        #expect(payload.audio == false)
        #expect(payload.seed == 77)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 16, resolution: "1080p")) - 1.28) <
            0.0001)
        #expect(abs(adapter.getCostEstimate(request: costRequest(durationSeconds: 5, resolution: "540p")) - 0.20) <
            0.0001)
    }

    @Test("Text-only request posts to the versionless Vidu Q3 Turbo prediction endpoint")
    func postsViduTextPayloadToVersionlessEndpoint() async throws {
        let mock = Replicate2026VideoMockNetworkProvider()

        let response = try await withProviderDependencies(
            networkProvider: mock,
            modelProvider: Replicate2026VideoTestModelProvider()
        ) {
            try await G_REPLICATE_VIDU_Q3_TURBO().makeRequest(
                request: videoRequest(
                    dimensions: "16:9",
                    durationSeconds: 5,
                    resolution: "720p",
                    generateAudio: false,
                    seed: 101
                )
            )
        }

        let input = try capturedInput(mock)
        #expect(mock.capturedURL?.absoluteString == "https://api.replicate.com/v1/models/vidu/q3-turbo/predictions")
        #expect(mock.capturedMethod == "POST")
        #expect(mock.capturedHeaders?["Authorization"] == "Bearer replicate-test")
        #expect(input["prompt"] as? String == "A cinematic aircraft hangar reveal.")
        #expect(input["duration"] as? Int == 5)
        #expect(input["resolution"] as? String == "720p")
        #expect(input["audio"] as? Bool == false)
        #expect(input["seed"] as? Int == 101)
        #expect(response.status == .FAILED)
        #expect(response.errorMessage == "stubbed replicate response")
    }

    @Test("Data URI video output is parsed and image-anchored Luma cost uses posted 5 second duration")
    func parsesDataURIOutput() throws {
        configureReplicate(Replicate2026VideoMockNetworkProvider())

        let response = try G_REPLICATE_LUMA_RAY_3_2().transformResponse(
            request: videoRequest(
                durationSeconds: 10,
                resolution: "1080p",
                clientImage: "placeholder"
            ),
            response: .dictionary(statusCode: 200, data: [
                "status": "succeeded",
                "output": "data:video/mp4;base64,dmlkZW8=",
            ])
        )

        #expect(response.status == .GENERATED)
        #expect(response.base64 == "dmlkZW8=")
        #expect(abs((response.cost ?? 0) - 1.20) < 0.0001)
    }

    @Test("Model metadata registers endpoints and official schema capabilities")
    func modelMetadataIsRegistered() throws {
        let models = ReplicateModels.createModels()
        let seedance = try #require(models.first { $0.modelCode == .REPLICATE_SEEDANCE_2_MINI })
        let happyHorse = try #require(models.first { $0.modelCode == .REPLICATE_HAPPY_HORSE_1_1 })
        let luma = try #require(models.first { $0.modelCode == .REPLICATE_LUMA_RAY_3_2 })
        let vidu = try #require(models.first { $0.modelCode == .REPLICATE_VIDU_Q3_TURBO })

        #expect(seedance
            .modelGenerateBaseURL == "https://api.replicate.com/v1/models/bytedance/seedance-2.0-mini/predictions")
        #expect(seedance.modelParams.maxReferenceImages == 9)
        #expect(seedance.modelParams.supportedVideoResolutions == ["480p", "720p"])
        #expect(seedance.modelParams.supportsAudio)
        #expect(seedance.modelParams.supportsLastFrame)

        #expect(happyHorse
            .modelGenerateBaseURL == "https://api.replicate.com/v1/models/alibaba/happyhorse-1.1/predictions")
        #expect(happyHorse.modelParams.supportedVideoDurations.contains(15))
        #expect(happyHorse.modelParams.supportedVideoResolutions == ["720p", "1080p"])

        #expect(luma.modelGenerateBaseURL == "https://api.replicate.com/v1/models/luma/ray-3.2/predictions")
        #expect(luma.modelParams.supportedVideoDurations == [5, 10])
        #expect(luma.modelParams.supportedVideoResolutions == ["540p", "720p", "1080p"])
        #expect(luma.modelParams.supportsLastFrame)

        #expect(vidu.modelGenerateBaseURL == "https://api.replicate.com/v1/models/vidu/q3-turbo/predictions")
        #expect(vidu.modelParams.maxPromptLength == 5000)
        #expect(vidu.modelParams.supportedVideoDurations.contains(16))
        #expect(vidu.modelParams.supportsAudio)
    }

    private func configureReplicate(_ mock: Replicate2026VideoMockNetworkProvider) {
        ProviderDependencies.shared.configure(
            networkProvider: mock,
            modelProvider: Replicate2026VideoTestModelProvider()
        )
    }

    private func capturedInput(_ mock: Replicate2026VideoMockNetworkProvider) throws -> [String: Any] {
        let data = try #require(mock.capturedBodyData)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(json["input"] as? [String: Any])
    }

    private func videoRequest(
        dimensions: String = "16:9",
        durationSeconds: Int? = 5,
        resolution: String? = "720p",
        generateAudio: Bool? = true,
        seed: Int? = nil,
        clientImage: String? = nil,
        clientLastFrame: String? = nil,
        referenceImages: [ReferenceImageData]? = nil
    ) -> VideoGenerationRequest {
        VideoGenerationRequest(
            modelId: UUID().uuidString,
            prompt: "A cinematic aircraft hangar reveal.",
            dimensions: dimensions,
            clientImage: clientImage,
            clientLastFrame: clientLastFrame,
            clientReferenceImages: referenceImages,
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.REPLICATE.providerId,
                providerCode: .REPLICATE,
                projectId: UUID()
            ),
            providerSecret: "replicate-test",
            durationSeconds: durationSeconds,
            resolution: resolution,
            generateAudio: generateAudio,
            seed: seed
        )
    }

    private func costRequest(durationSeconds: Int? = nil, resolution: String? = nil) -> VideoGenerationCostRequest {
        VideoGenerationCostRequest(durationSeconds: durationSeconds, resolution: resolution)
    }
}

private final class Replicate2026VideoMockNetworkProvider: @unchecked Sendable, NetworkProvider {
    var capturedURL: URL?
    var capturedMethod: String?
    var capturedBodyData: Data?
    var capturedHeaders: [String: String]?
    let response: NetworkResponseData

    init(response: NetworkResponseData = .dictionary(statusCode: 400, data: ["error": "stubbed replicate response"])) {
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
        if let body {
            capturedBodyData = try JSONEncoder().encode(body)
        }
        return response
    }
}

private struct Replicate2026VideoTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        ReplicateModels.createModels().first { $0.modelCode == code }
    }
}
