import Foundation

public enum XAIModels {
    public static func createModels() -> [ProviderModelData] {
        let providerId = EnumProviderCode.XAI.providerId
        let verifiedAt = getDateFromString("2026-07-10")
        let pricing = "https://docs.x.ai/developers/pricing"
        let imageDocumentation = "https://docs.x.ai/developers/rest-api-reference/inference/images"
        let videoDocumentation = "https://docs.x.ai/developers/rest-api-reference/inference/videos"
        let imageGenerateURL = "https://api.x.ai/v1/images/generations"
        let videoGenerateURL = "https://api.x.ai/v1/videos/generations"
        let videoStatusURL = "https://api.x.ai/v1/videos"
        let imageRatios = [
            "1:1", "16:9", "9:16", "4:3", "3:4", "3:2", "2:3",
            "2:1", "1:2", "19.5:9", "9:19.5", "20:9", "9:20", "auto",
        ]
        let videoRatios = ["1:1", "16:9", "9:16", "4:3", "3:4", "3:2", "2:3"]

        return [
            ProviderModelData(
                providerId: providerId,
                modelCode: .XAI_GROK_IMAGINE_IMAGE,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Grok Imagine Image",
                modelDescription: "Create polished images from text and visual references.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 1024,
                    maxReferenceImages: 3,
                    supportedDimensions: imageRatios,
                    supportedImageResolutions: ["1k", "2k"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-03-02"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .image,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "$0.02 output plus $0.002 per input image."
                ),
                modelGenerateBaseURL: imageGenerateURL,
                modelAPIDocumentationURL: imageDocumentation,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .XAI_GROK_IMAGINE_IMAGE_QUALITY,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Grok Imagine Image Quality",
                modelDescription: "Create detailed images from text and visual references.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 1024,
                    maxReferenceImages: 3,
                    supportedDimensions: imageRatios,
                    supportedImageResolutions: ["1k", "2k"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-04-03"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .image,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "$0.05 at 1K or $0.07 at 2K plus $0.01 per input image."
                ),
                modelGenerateBaseURL: imageGenerateURL,
                modelAPIDocumentationURL: imageDocumentation,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .XAI_GROK_IMAGINE_VIDEO,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Grok Imagine Video",
                modelDescription: "Create cinematic videos from prompts and visual references.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    maxReferenceImages: 7,
                    supportedDimensions: videoRatios,
                    supportedVideoDurations: Array(1 ... 15),
                    supportedVideoResolutions: ["480p", "720p"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-01-28"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .second,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "$0.05 per 480p second or $0.07 per 720p second, plus $0.002 per reference image."
                ),
                modelGenerateBaseURL: videoGenerateURL,
                modelStatusBaseURL: videoStatusURL,
                modelAPIDocumentationURL: videoDocumentation,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .XAI_GROK_IMAGINE_VIDEO_1_5,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Grok Imagine Video 1.5",
                modelDescription: "Animate source images into detailed cinematic videos.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    supportedDimensions: videoRatios,
                    supportedVideoDurations: Array(1 ... 15),
                    supportedVideoResolutions: ["480p", "720p", "1080p"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-06-16"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .second,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "$0.08, $0.14, or $0.25 per output second by resolution, plus $0.01 per source image."
                ),
                modelGenerateBaseURL: videoGenerateURL,
                modelStatusBaseURL: videoStatusURL,
                modelAPIDocumentationURL: videoDocumentation,
                active: true
            ),
        ]
    }
}
