// MARK: - MiniMaxModels.swift

import Foundation

public enum MiniMaxModels {
    public static func createModels() -> [ProviderModelData] {
        let providerId = EnumProviderCode.MINIMAX.providerId
        let verifiedAt = getDateFromString("2026-07-10")
        let imageDocumentation = "https://platform.minimax.io/docs/api-reference/image-generation-t2i"
        let textVideoDocumentation = "https://platform.minimax.io/docs/api-reference/video-generation-t2v"
        let imageVideoDocumentation = "https://platform.minimax.io/docs/api-reference/video-generation-i2v"
        let pricing = "https://platform.minimax.io/docs/guides/pricing-paygo"
        let canonicalHost = "https://api.minimax.io"

        return [
            ProviderModelData(
                providerId: providerId,
                modelCode: .MINIMAX_IMAGE_01,
                modelSetType: .IMAGE_GENERATE,
                modelName: "MiniMax Image-01",
                modelDescription: "Create vivid images from detailed written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 1500,
                    supportedDimensions: ["16:9", "4:3", "1:1", "3:4", "9:16", "21:9"],
                    supportsPromptEnhance: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-02-15"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .image,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "$0.0035 per generated image."
                ),
                modelGenerateBaseURL: "\(canonicalHost)/v1/image_generation",
                modelAPIDocumentationURL: imageDocumentation,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .MINIMAX_HAILUO_2_3_T2V,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Hailuo 2.3 Text to Video",
                modelDescription: "Create cinematic motion from detailed written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 2000,
                    supportedVideoDurations: [6, 10],
                    supportedVideoResolutions: ["768p", "1080p"],
                    supportsPromptEnhance: true
                ),
                modelLaunchDate: getDateFromString("2025-10-28"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .video,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "$0.28/$0.56 at 768P for 6s/10s; $0.49 at 1080P for 6s."
                ),
                modelGenerateBaseURL: "\(canonicalHost)/v1/video_generation",
                modelStatusBaseURL: "\(canonicalHost)/v1/query/video_generation",
                modelAPIDocumentationURL: textVideoDocumentation,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .MINIMAX_HAILUO_2_3_I2V,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Hailuo 2.3 Image to Video",
                modelDescription: "Animate still images with polished cinematic motion.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxImageSizeBytes: 20_000_000,
                    maxPromptLength: 2000,
                    supportedVideoDurations: [6, 10],
                    supportedVideoResolutions: ["768p", "1080p"],
                    supportsPromptEnhance: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-10-28"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .video,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "$0.28/$0.56 at 768P for 6s/10s; $0.49 at 1080P for 6s."
                ),
                modelGenerateBaseURL: "\(canonicalHost)/v1/video_generation",
                modelStatusBaseURL: "\(canonicalHost)/v1/query/video_generation",
                modelAPIDocumentationURL: imageVideoDocumentation,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .MINIMAX_HAILUO_2_3_FAST_I2V,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Hailuo 2.3 Fast Image to Video",
                modelDescription: "Animate still images with faster cinematic motion.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxImageSizeBytes: 20_000_000,
                    maxPromptLength: 2000,
                    supportedVideoDurations: [6, 10],
                    supportedVideoResolutions: ["768p", "1080p"],
                    supportsPromptEnhance: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-10-28"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .video,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "$0.19/$0.32 at 768P for 6s/10s; $0.33 at 1080P for 6s."
                ),
                modelGenerateBaseURL: "\(canonicalHost)/v1/video_generation",
                modelStatusBaseURL: "\(canonicalHost)/v1/query/video_generation",
                modelAPIDocumentationURL: imageVideoDocumentation,
                active: true
            ),
        ]
    }
}
