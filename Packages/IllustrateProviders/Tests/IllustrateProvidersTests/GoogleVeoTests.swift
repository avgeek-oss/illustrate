// MARK: - GoogleVeoTests.swift

import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Google Veo adapters", .serialized)
struct GoogleVeoTests {
    @Test("Veo 3.1 metadata reflects current Gemini API support")
    func veo31MetadataReflectsCurrentGoogleSupport() throws {
        let models = GoogleCloudModels.createModels()

        let standard = try #require(models.first { $0.modelCode == .GOOGLE_VEO_31 })
        #expect(standard.active)
        #expect(standard.modelParams.supportedVideoResolutions == ["720p", "1080p", "4k"])
        #expect(standard.modelParams.supportsAudio)
        #expect(standard.modelAPIDocumentationURL == "https://ai.google.dev/gemini-api/docs/veo")

        let fast = try #require(models.first { $0.modelCode == .GOOGLE_VEO_31_FAST })
        #expect(fast.active)
        #expect(fast.modelParams.supportedVideoResolutions == ["720p", "1080p", "4k"])
        #expect(fast.modelParams.supportsAudio)
        #expect(fast.modelParams.maxReferenceImages == 3)

        let lite = try #require(models.first { $0.modelCode == .GOOGLE_VEO_31_LITE })
        #expect(lite.active)
        #expect(lite.modelParams.supportedVideoResolutions == ["720p", "1080p"])
        #expect(lite.modelParams.supportsAudio)

        #expect(models.first { $0.modelCode == .GOOGLE_VEO_3 }?.active == false)
        #expect(models.first { $0.modelCode == .GOOGLE_VEO_3_FAST }?.active == false)
        #expect(models.first { $0.modelCode == .GOOGLE_VEO_2 }?.active == false)
        #expect(models.first { $0.modelCode == .GOOGLE_VEO_2 }?.modelParams.supportsAudio == false)
    }

    @Test("Veo 3.1 cost estimates use documented resolution prices")
    func veo31CostEstimatesUseDocumentedResolutionPrices() {
        withGoogleDependencies {
            let standard = adapter(.GOOGLE_VEO_31)
            #expect(abs(standard.getCostEstimate(request: costRequest(durationSeconds: 8)) - 3.20) < 0.0001)
            #expect(abs(standard.getCostEstimate(request: costRequest(durationSeconds: 8, resolution: "4K")) - 4.80) <
                0.0001)
            #expect(abs(standard
                    .getCostEstimate(request: costRequest(durationSeconds: 4, resolution: "1080p")) - 3.20) <
                0.0001)

            let fast = adapter(.GOOGLE_VEO_31_FAST)
            #expect(abs(fast.getCostEstimate(request: costRequest(durationSeconds: 8)) - 0.80) < 0.0001)
            #expect(abs(fast.getCostEstimate(request: costRequest(durationSeconds: 8, resolution: "1080p")) - 0.96) <
                0.0001)
            #expect(abs(fast.getCostEstimate(request: costRequest(durationSeconds: 8, resolution: "4k")) - 2.40) <
                0.0001)

            let lite = adapter(.GOOGLE_VEO_31_LITE)
            #expect(abs(lite.getCostEstimate(request: costRequest(durationSeconds: 8, resolution: "720p")) - 0.40) <
                0.0001)
            #expect(abs(lite.getCostEstimate(request: costRequest(durationSeconds: 8, resolution: "1080p")) - 0.64) <
                0.0001)
            #expect(abs(lite.getCostEstimate(request: costRequest(durationSeconds: 8, resolution: "4k")) - 0.40) <
                0.0001)
        }
    }

    @Test("Veo reference-image cost estimates use API-enforced eight-second duration")
    func veoReferenceImageCostEstimatesUseEightSecondDuration() {
        withGoogleDependencies {
            let standard = adapter(.GOOGLE_VEO_31)
            let directRequest = costRequest(durationSeconds: 4, resolution: "720p", hasReferenceImages: true)
            #expect(abs(standard.getCostEstimate(request: directRequest) - 3.20) < 0.0001)

            let generatedRequest = VideoGenerationCostRequest(
                from: videoRequest(
                    durationSeconds: 4,
                    resolution: "720p",
                    clientReferenceImages: [
                        ReferenceImageData(base64Image: "data:image/png;base64,AAAA", referenceType: "asset"),
                    ]
                )
            )
            #expect(generatedRequest.hasReferenceImages)
            #expect(abs(standard.getCostEstimate(request: generatedRequest) - 3.20) < 0.0001)

            let fast = adapter(.GOOGLE_VEO_31_FAST)
            #expect(abs(fast.getCostEstimate(request: directRequest) - 0.80) < 0.0001)
        }
    }

    @Test("Veo request normalization enforces documented duration and resolution constraints")
    func veoRequestNormalizationEnforcesDocumentedConstraints() {
        withGoogleDependencies {
            let standard = adapter(.GOOGLE_VEO_31)
            let standardRequest = standard.transformRequest(request: videoRequest(durationSeconds: 4, resolution: "4K"))
            #expect(standardRequest.parameters?.resolution == "4k")
            #expect(standardRequest.parameters?.durationSeconds == 8)

            let lite = adapter(.GOOGLE_VEO_31_LITE)
            let liteRequest = lite.transformRequest(
                request: videoRequest(modelCode: .GOOGLE_VEO_31_LITE, durationSeconds: 8, resolution: "4k")
            )
            #expect(liteRequest.parameters?.resolution == "720p")
            #expect(liteRequest.parameters?.durationSeconds == 8)

            let extend = adapter(.GOOGLE_VEO_31_EXTEND)
            let extendRequest = extend.transformRequest(
                request: videoRequest(
                    modelCode: .GOOGLE_VEO_31_EXTEND,
                    durationSeconds: 4,
                    resolution: "4k",
                    sourceMetadata: [G_GOOGLE_VEO_BASE.veoGeneratedUriKey: "https://example.com/video.mp4"]
                )
            )
            #expect(extendRequest.parameters?.resolution == "720p")
            #expect(extendRequest.parameters?.durationSeconds == 8)
            #expect(extendRequest.instances.first?.video?.uri == "https://example.com/video.mp4")

            let referenceRequest = standard.transformRequest(
                request: videoRequest(
                    durationSeconds: 4,
                    resolution: "720p",
                    clientReferenceImages: [
                        ReferenceImageData(base64Image: "data:image/png;base64,AAAA", referenceType: "asset"),
                    ]
                )
            )
            #expect(referenceRequest.parameters?.durationSeconds == 8)
        }
    }

    private func adapter(_ modelCode: EnumProviderModelCode) -> G_GOOGLE_VEO_BASE {
        G_GOOGLE_VEO_BASE(modelCode: modelCode)
    }

    private func withGoogleDependencies<Result>(_ operation: () throws -> Result) rethrows -> Result {
        try ProviderDependencies.shared.withDependencies(
            networkProvider: GoogleVeoNoopNetworkProvider(),
            modelProvider: GoogleVeoTestModelProvider(),
            operation: operation
        )
    }

    private func costRequest(
        durationSeconds: Int,
        resolution: String? = nil,
        hasReferenceImages: Bool = false
    ) -> VideoGenerationCostRequest {
        VideoGenerationCostRequest(
            durationSeconds: durationSeconds,
            resolution: resolution,
            hasReferenceImages: hasReferenceImages
        )
    }

    private func videoRequest(
        modelCode: EnumProviderModelCode = .GOOGLE_VEO_31,
        dimensions: String = "16:9",
        durationSeconds: Int? = 8,
        resolution: String? = "720p",
        clientReferenceImages: [ReferenceImageData]? = nil,
        sourceMetadata: [String: String]? = nil
    ) -> VideoGenerationRequest {
        VideoGenerationRequest(
            modelId: modelCode.rawValue,
            prompt: "A cinematic aircraft hangar reveal.",
            dimensions: dimensions,
            clientReferenceImages: clientReferenceImages,
            providerKey: ProviderKeyInfo(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                providerCode: .GOOGLE_CLOUD,
                projectId: UUID()
            ),
            providerSecret: "AIza-test",
            durationSeconds: durationSeconds,
            resolution: resolution,
            sourceMetadata: sourceMetadata
        )
    }
}

private struct GoogleVeoTestModelProvider: ModelProvider {
    func model(by code: EnumProviderModelCode) -> ProviderModelData? {
        GoogleCloudModels.createModels().first { $0.modelCode == code }
    }
}

private struct GoogleVeoNoopNetworkProvider: NetworkProvider {
    func performRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseData {
        throw NSError(domain: "GoogleVeoNoopNetworkProvider", code: -1)
    }
}
