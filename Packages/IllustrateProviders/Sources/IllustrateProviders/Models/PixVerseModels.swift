// MARK: - PixVerseModels.swift

import Foundation

public enum PixVerseModels {
    public static func createModels() -> [ProviderModelData] {
        let providerId = EnumProviderCode.PIXVERSE.providerId
        let verifiedAt = getDateFromString("2026-07-10")
        let documentation = "https://docs.platform.pixverse.ai/text-to-video-generation-13016634e0"
        let pricing = "https://docs.platform.pixverse.ai/pricing-796039m0"
        let statusURL = "https://app-api.pixverse.ai/openapi/v2/video/result"
        let params = ModelParams(
            maxGenerations: 1,
            maxPromptLength: 5000,
            supportedDimensions: ["16:9", "4:3", "1:1", "3:4", "9:16", "2:3", "3:2", "21:9"],
            supportedVideoDurations: Array(1 ... 15),
            supportedVideoResolutions: ["360p", "540p", "720p", "1080p"],
            supportsAudio: true,
            supportsSeed: true
        )

        return [
            ProviderModelData(
                providerId: providerId,
                modelCode: .PIXVERSE_C1,
                modelSetType: .VIDEO_GENERATE,
                modelName: "PixVerse C1",
                modelDescription: "Create cinematic video with synchronized audio and structured storytelling.",
                modelParams: params,
                modelLaunchDate: getDateFromString("2026-04-07"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    currency: "PixVerse credits",
                    unit: .second,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "Per-second credit pricing varies by resolution and synchronized-audio selection."
                ),
                modelGenerateBaseURL: "https://app-api.pixverse.ai/openapi/v2/video/text/generate",
                modelStatusBaseURL: statusURL,
                modelAPIDocumentationURL: documentation,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .PIXVERSE_V6,
                modelSetType: .VIDEO_GENERATE,
                modelName: "PixVerse V6",
                modelDescription: "Create flexible video with synchronized audio and broad ratios.",
                modelParams: params,
                modelLaunchDate: getDateFromString("2026-03-29"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    currency: "PixVerse credits",
                    unit: .second,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "Per-second credit pricing varies by resolution and synchronized-audio selection."
                ),
                modelGenerateBaseURL: "https://app-api.pixverse.ai/openapi/v2/video/text/generate",
                modelStatusBaseURL: statusURL,
                modelAPIDocumentationURL: documentation,
                active: true
            ),
        ]
    }
}
