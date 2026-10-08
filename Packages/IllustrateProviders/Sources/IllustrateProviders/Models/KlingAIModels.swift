// MARK: - KlingAIModels.swift

import Foundation

public enum KlingAIModels {
    public static func createModels() -> [ProviderModelData] {
        let providerId = EnumProviderCode.KLING_AI.providerId
        let verifiedAt = getDateFromString("2026-07-10")
        let imageDocumentation =
            "https://app.klingai.com/global/dev/document-api/apiReference/model/imageGeneration"
        let videoDocumentation =
            "https://app.klingai.com/global/dev/document-api/apiReference/model/videoGeneration"
        let pricing =
            "https://app.klingai.com/global/dev/document-api/quickStart/productBilling/prePaidResourcePackage"
        let canonicalHost = "https://api-singapore.klingai.com"

        return [
            ProviderModelData(
                providerId: providerId,
                modelCode: .KLING_IMAGE_3_0,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Kling Image 3.0",
                modelDescription: "Create refined images with optional source guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxImageSizeBytes: 20_000_000,
                    maxPromptLength: 2500,
                    supportedDimensions: [
                        "16:9", "9:16", "1:1", "4:3", "3:4", "3:2", "2:3", "21:9",
                    ],
                    supportedImageResolutions: ["1K", "2K"],
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-02-04"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .image,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "$0.028 per 1K or 2K image."
                ),
                modelGenerateBaseURL: "\(canonicalHost)/v1/images/generations",
                modelStatusBaseURL: "\(canonicalHost)/v1/images/generations",
                modelAPIDocumentationURL: imageDocumentation,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .KLING_IMAGE_3_0_OMNI,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Kling Image 3.0 Omni",
                modelDescription: "Create flexible images from multiple visual references.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxImageSizeBytes: 20_000_000,
                    maxPromptLength: 2500,
                    maxReferenceImages: 9,
                    supportedDimensions: ["auto"],
                    supportedImageResolutions: ["1K", "2K", "4K"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-02-06"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .image,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "$0.028 at 1K/2K and $0.056 at 4K."
                ),
                modelGenerateBaseURL: "\(canonicalHost)/v1/images/omni-image",
                modelStatusBaseURL: "\(canonicalHost)/v1/images/omni-image",
                modelAPIDocumentationURL: imageDocumentation,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .KLING_VIDEO_3_0_T2V,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Kling Video 3.0 Text to Video",
                modelDescription: "Create cinematic videos from detailed written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 2500,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: Array(3 ... 15),
                    supportedVideoResolutions: ["720p", "1080p", "4K"],
                    supportsAudio: true,
                    supportsNegativePrompt: true
                ),
                modelLaunchDate: getDateFromString("2026-02-06"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .second,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "Without audio $0.084/$0.112/$0.42 per second at 720P/1080P/4K."
                ),
                modelGenerateBaseURL: "\(canonicalHost)/v1/videos/text2video",
                modelStatusBaseURL: "\(canonicalHost)/v1/videos/text2video",
                modelAPIDocumentationURL: videoDocumentation,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .KLING_VIDEO_3_0_I2V,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Kling Video 3.0 Image to Video",
                modelDescription: "Animate frames with optional final-frame guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxImageSizeBytes: 20_000_000,
                    maxPromptLength: 2500,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: Array(3 ... 15),
                    supportedVideoResolutions: ["720p", "1080p", "4K"],
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-02-06"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .second,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "Without audio $0.084/$0.112/$0.42 per second at 720P/1080P/4K."
                ),
                modelGenerateBaseURL: "\(canonicalHost)/v1/videos/image2video",
                modelStatusBaseURL: "\(canonicalHost)/v1/videos/image2video",
                modelAPIDocumentationURL: videoDocumentation,
                active: true
            ),
        ]
    }
}
