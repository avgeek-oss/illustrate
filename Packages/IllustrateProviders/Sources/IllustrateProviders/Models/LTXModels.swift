// MARK: - LTXModels.swift

import Foundation

public enum LTXModels {
    public static func createModels() -> [ProviderModelData] {
        let providerId = EnumProviderCode.LTX.providerId
        let launchedAt = getDateFromString("2026-02-23")
        let verifiedAt = getDateFromString("2026-07-10")
        let documentation = "https://docs.ltx.video/models"
        let pricing = "https://docs.ltx.video/pricing"
        let generateURL = "https://api.ltx.video/v2/text-to-video"
        let statusBaseURL = "https://api.ltx.video/v2"
        let resolutions = ["4K", "1440p", "1080p"]
        let fps = [24, 25, 48, 50]

        return [
            ProviderModelData(
                providerId: providerId,
                modelCode: .LTX_2_3_FAST,
                modelSetType: .VIDEO_GENERATE,
                modelName: "LTX-2.3 Fast",
                modelDescription: "Create synchronized video and audio for rapid creative iteration.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxImageSizeBytes: LTXJobClient.maxImageDataURIBytes,
                    maxPromptLength: 10000,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [6, 8, 10, 12, 14, 16, 18, 20],
                    supportedVideoFPS: fps,
                    supportedVideoResolutions: resolutions,
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: launchedAt,
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .second,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "Resolution-tier pricing for text-to-video and image-to-video."
                ),
                modelGenerateBaseURL: generateURL,
                modelStatusBaseURL: statusBaseURL,
                modelAPIDocumentationURL: documentation,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .LTX_2_3_PRO,
                modelSetType: .VIDEO_GENERATE,
                modelName: "LTX-2.3 Pro",
                modelDescription: "Create cinematic video with refined motion and visual detail.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxImageSizeBytes: LTXJobClient.maxImageDataURIBytes,
                    maxPromptLength: 10000,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [6, 8, 10],
                    supportedVideoFPS: fps,
                    supportedVideoResolutions: resolutions,
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: launchedAt,
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .second,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "Resolution-tier pricing for text-to-video and image-to-video."
                ),
                modelGenerateBaseURL: generateURL,
                modelStatusBaseURL: statusBaseURL,
                modelAPIDocumentationURL: documentation,
                active: true
            ),
        ]
    }
}
