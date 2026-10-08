// MARK: - AlibabaModelStudioModels.swift

import Foundation

public enum AlibabaModelStudioModels {
    public static func createModels() -> [ProviderModelData] {
        let providerId = EnumProviderCode.ALIBABA_MODEL_STUDIO.providerId
        let verifiedAt = getDateFromString("2026-07-10")
        let imageDocumentation =
            "https://www.alibabacloud.com/help/en/model-studio/wan-image-generation-and-editing-api-reference"
        let textVideoDocumentation =
            "https://www.alibabacloud.com/help/en/model-studio/text-to-video-api-reference"
        let imageVideoDocumentation =
            "https://www.alibabacloud.com/help/en/model-studio/image-to-video-general-api-reference"
        let pricing = "https://www.alibabacloud.com/help/en/model-studio/model-pricing"
        let canonicalHost = "https://{workspace}.ap-southeast-1.maas.aliyuncs.com"
        let statusBaseURL = "\(canonicalHost)/api/v1/tasks"

        return [
            ProviderModelData(
                providerId: providerId,
                modelCode: .ALIBABA_WAN_2_7_IMAGE_PRO,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Wan 2.7 Image Pro",
                modelDescription: "Create polished images with advanced editing controls.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxImageSizeBytes: 20_000_000,
                    maxPromptLength: 5000,
                    maxReferenceImages: 8,
                    supportedDimensions: ["1:1"],
                    supportedImageResolutions: ["1K", "2K", "4K"],
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-04-01"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .image,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "Singapore $0.075/image; Beijing $0.068761/image."
                ),
                modelGenerateBaseURL:
                "\(canonicalHost)/api/v1/services/aigc/image-generation/generation",
                modelStatusBaseURL: statusBaseURL,
                modelAPIDocumentationURL: imageDocumentation,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .ALIBABA_WAN_2_7_IMAGE,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Wan 2.7 Image",
                modelDescription: "Create and edit images with responsive generation.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxImageSizeBytes: 20_000_000,
                    maxPromptLength: 5000,
                    maxReferenceImages: 8,
                    supportedDimensions: ["1:1"],
                    supportedImageResolutions: ["1K", "2K"],
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-04-01"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .image,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "Singapore $0.03/image; Beijing $0.028671/image."
                ),
                modelGenerateBaseURL:
                "\(canonicalHost)/api/v1/services/aigc/image-generation/generation",
                modelStatusBaseURL: statusBaseURL,
                modelAPIDocumentationURL: imageDocumentation,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .ALIBABA_WAN_2_7_T2V,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Wan 2.7 Text to Video",
                modelDescription: "Create audiovisual scenes from detailed written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 5000,
                    supportedDimensions: ["16:9", "9:16", "1:1", "4:3", "3:4"],
                    supportedVideoDurations: Array(2 ... 15),
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsNegativePrompt: true,
                    supportsPromptEnhance: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-04-03"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .second,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "Singapore $0.10/$0.15 per second at 720P/1080P."
                ),
                modelGenerateBaseURL:
                "\(canonicalHost)/api/v1/services/aigc/video-generation/video-synthesis",
                modelStatusBaseURL: statusBaseURL,
                modelAPIDocumentationURL: textVideoDocumentation,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .ALIBABA_WAN_2_7_I2V,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Wan 2.7 Image to Video",
                modelDescription: "Animate frames or continue clips with guided motion.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxImageSizeBytes: 20_000_000,
                    maxPromptLength: 5000,
                    supportedDimensions: ["16:9", "9:16", "1:1", "4:3", "3:4"],
                    supportedVideoDurations: Array(2 ... 15),
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsLastFrame: true,
                    supportsNegativePrompt: true,
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsSourceImage: true,
                    supportsVideoUpload: true
                ),
                modelLaunchDate: getDateFromString("2026-04-03"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .second,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "Singapore $0.10/$0.15 per second at 720P/1080P."
                ),
                modelGenerateBaseURL:
                "\(canonicalHost)/api/v1/services/aigc/video-generation/video-synthesis",
                modelStatusBaseURL: statusBaseURL,
                modelAPIDocumentationURL: imageVideoDocumentation,
                active: true
            ),
        ]
    }
}
