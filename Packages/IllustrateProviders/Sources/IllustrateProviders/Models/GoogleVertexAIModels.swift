// MARK: - GoogleVertexAIModels.swift

import Foundation

public enum GoogleVertexAIModels {
    public static func createModels() -> [ProviderModelData] {
        let providerId = EnumProviderCode.GOOGLE_VERTEX_AI.providerId
        let verifiedAt = getDateFromString("2026-07-10")
        let imageDocs = "https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/gemini/3-1-flash-image"
        let videoDocs = "https://docs.cloud.google.com/vertex-ai/generative-ai/docs/models/veo/3-1-generate"
        let pricing = "https://cloud.google.com/vertex-ai/generative-ai/pricing"

        return [
            ProviderModelData(
                providerId: providerId,
                modelCode: .VERTEX_GEMINI_3_1_FLASH_IMAGE,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Gemini 3.1 Flash Image",
                modelDescription: "Generate and edit detailed images with efficient multimodal reasoning.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 65536,
                    maxReferenceImages: 14,
                    supportedDimensions: [
                        "1:1", "2:3", "3:2", "3:4", "4:3",
                        "4:5", "5:4", "9:16", "16:9", "21:9",
                    ],
                    supportedImageResolutions: ["512", "1K", "2K", "4K"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-05-28"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .image,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "GA model with resolution-token output and input-media pricing; 4K output remains Preview."
                ),
                modelGenerateBaseURL: "https://LOCATION-aiplatform.googleapis.com/v1/projects/PROJECT/locations/LOCATION/publishers/google/models/gemini-3.1-flash-image:generateContent",
                modelStatusBaseURL: nil,
                modelAPIDocumentationURL: imageDocs,
                active: true
            ),
            veoModel(
                providerId: providerId,
                code: .VERTEX_VEO_3_1,
                name: "Veo 3.1",
                upstreamId: "veo-3.1-generate-001",
                launchedAt: getDateFromString("2026-03-03"),
                verifiedAt: verifiedAt,
                documentation: videoDocs,
                pricing: pricing
            ),
            veoModel(
                providerId: providerId,
                code: .VERTEX_VEO_3_1_FAST,
                name: "Veo 3.1 Fast",
                upstreamId: "veo-3.1-fast-generate-001",
                launchedAt: getDateFromString("2026-03-03"),
                verifiedAt: verifiedAt,
                documentation: videoDocs,
                pricing: pricing
            ),
        ]
    }

    private static func veoModel(
        providerId: UUID,
        code: EnumProviderModelCode,
        name: String,
        upstreamId: String,
        launchedAt: Date,
        verifiedAt: Date,
        documentation: String,
        pricing: String
    ) -> ProviderModelData {
        ProviderModelData(
            providerId: providerId,
            modelCode: code,
            modelSetType: .VIDEO_GENERATE,
            modelName: name,
            modelDescription: "Create cinematic videos with synchronized sound and frame control.",
            modelParams: ModelParams(
                maxGenerations: 1,
                maxPromptLength: 4000,
                supportedDimensions: ["16:9", "9:16"],
                supportedVideoDurations: [4, 6, 8],
                supportedVideoFPS: [24],
                supportedVideoResolutions: ["720p", "1080p"],
                supportsAudio: true,
                supportsLastFrame: true,
                supportsNegativePrompt: true,
                supportsPromptEnhance: true,
                supportsSeed: true,
                supportsSourceImage: true
            ),
            modelLaunchDate: launchedAt,
            modelVerificationDate: verifiedAt,
            pricingMetadata: ProviderPricingMetadata(
                unit: .second,
                sourceURL: pricing,
                verifiedAt: verifiedAt,
                notes: "Resolution, speed, and generated-audio pricing per output second."
            ),
            modelGenerateBaseURL: "https://LOCATION-aiplatform.googleapis.com/v1/projects/PROJECT/locations/LOCATION/publishers/google/models/\(upstreamId):predictLongRunning",
            modelStatusBaseURL: "https://LOCATION-aiplatform.googleapis.com/v1/projects/PROJECT/locations/LOCATION/publishers/google/models/\(upstreamId):fetchPredictOperation",
            modelAPIDocumentationURL: documentation,
            active: true
        )
    }
}
