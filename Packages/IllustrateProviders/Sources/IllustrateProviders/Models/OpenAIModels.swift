// MARK: - OpenAIModels.swift

// Factory for OpenAI model configurations.

import Foundation

/// Factory enum for creating OpenAI model configurations.
public enum OpenAIModels {
    /// Creates all OpenAI model configurations.
    public static func createModels() -> [ProviderModelData] {
        [
            ProviderModelData(
                providerId: EnumProviderCode.OPENAI.providerId,
                modelCode: EnumProviderModelCode.OPENAI_DALLE3,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "DALL·E 3",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 6,
                    maxPromptLength: 4000,
                    supportedDimensions: ["1024x1024", "1792x1024", "1024x1792"],
                    supportedImageQualities: ["standard", "hd"],
                    supportedStyles: ["natural", "vivid"]
                ),
                modelLaunchDate: getDateFromString("2023-08-20"),
                modelGenerateBaseURL: "https://api.openai.com/v1/images/generations",
                modelAPIDocumentationURL: "https://platform.openai.com/docs/api-reference/images/create",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.OPENAI.providerId,
                modelCode: EnumProviderModelCode.OPENAI_GPT_IMAGE_1,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "GPT Image 1",
                modelDescription: "Edit masked image areas with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 6,
                    maxPromptLength: 4000,
                    maxReferenceImages: 8,
                    supportedBackgrounds: ["auto", "transparent", "opaque"],
                    supportedDimensions: ["1024x1024", "1536x1024", "1024x1536"],
                    supportedModerations: ["auto", "low"],
                    supportedImageQualities: ["low", "medium", "high"],
                    supportsMask: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-04-01"),
                modelGenerateBaseURL: "https://api.openai.com/v1/images/generations",
                modelAPIDocumentationURL: "https://platform.openai.com/docs/api-reference/images/create",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.OPENAI.providerId,
                modelCode: EnumProviderModelCode.OPENAI_GPT_IMAGE_1_MINI,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "GPT Image 1 Mini",
                modelDescription: "Edit masked image areas with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 6,
                    maxPromptLength: 4000,
                    maxReferenceImages: 8,
                    supportedBackgrounds: ["auto", "transparent", "opaque"],
                    supportedDimensions: ["1024x1024", "1536x1024", "1024x1536"],
                    supportedModerations: ["auto", "low"],
                    supportedImageQualities: ["low", "medium", "high"],
                    supportsMask: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-12-17"),
                modelGenerateBaseURL: "https://api.openai.com/v1/images/generations",
                modelAPIDocumentationURL: "https://platform.openai.com/docs/api-reference/images/create",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.OPENAI.providerId,
                modelCode: EnumProviderModelCode.OPENAI_GPT_IMAGE_1_5,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "GPT Image 1.5",
                modelDescription: "Edit masked image areas with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 6,
                    maxPromptLength: 4000,
                    maxReferenceImages: 8,
                    supportedBackgrounds: ["auto", "transparent", "opaque"],
                    supportedDimensions: ["1024x1024", "1536x1024", "1024x1536"],
                    supportedModerations: ["auto", "low"],
                    supportedImageQualities: ["low", "medium", "high"],
                    supportsMask: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-12-01"),
                modelGenerateBaseURL: "https://api.openai.com/v1/images/generations",
                modelAPIDocumentationURL: "https://platform.openai.com/docs/api-reference/images/create",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.OPENAI.providerId,
                modelCode: EnumProviderModelCode.OPENAI_GPT_IMAGE_2,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "GPT Image 2",
                modelDescription: "Edit masked image areas with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 6,
                    maxPromptLength: 32000,
                    maxReferenceImages: 8,
                    supportedBackgrounds: ["auto", "opaque"],
                    supportedDimensions: [
                        "1024x1024",
                        "1536x1024",
                        "1024x1536",
                        "1536x864",
                        "864x1536",
                        "2048x1152",
                        "1152x2048",
                        "2560x1440",
                        "1440x2560",
                        "3840x2160",
                        "2160x3840",
                    ],
                    supportedModerations: ["auto", "low"],
                    supportedImageQualities: ["auto", "low", "medium", "high"],
                    supportsMask: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-04-21"),
                modelGenerateBaseURL: "https://api.openai.com/v1/images/generations",
                modelAPIDocumentationURL: "https://developers.openai.com/api/docs/models/gpt-image-2",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.OPENAI.providerId,
                modelCode: EnumProviderModelCode.OPENAI_SORA_2,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Sora 2",
                modelDescription: "Animate still images into motion clips.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280"],
                    supportedVideoDurations: [4, 8, 12],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-02-01"),
                modelGenerateBaseURL: "https://api.openai.com/v1/videos",
                modelAPIDocumentationURL: "https://developers.openai.com/api/reference/resources/videos/methods/create",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.OPENAI.providerId,
                modelCode: EnumProviderModelCode.OPENAI_SORA_2_PRO,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Sora 2 Pro",
                modelDescription: "Animate still images into motion clips.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280", "1792x1024", "1024x1792"],
                    supportedVideoDurations: [4, 8, 12],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-02-01"),
                modelGenerateBaseURL: "https://api.openai.com/v1/videos",
                modelAPIDocumentationURL: "https://developers.openai.com/api/reference/resources/videos/methods/create",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.OPENAI.providerId,
                modelCode: EnumProviderModelCode.OPENAI_SORA_2_REMIX,
                modelSetType: EnumSetType.VIDEO_EXTEND,
                modelName: "Sora 2",
                modelDescription: "Extend existing clips with continued motion.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    requiredMetadata: ["soraVideoId"],
                    supportedDimensions: ["1280x720", "720x1280"],
                    supportedVideoDurations: [4, 8, 12, 16, 20]
                ),
                modelLaunchDate: getDateFromString("2025-02-01"),
                modelGenerateBaseURL: "https://api.openai.com/v1/videos/extensions",
                modelAPIDocumentationURL: "https://developers.openai.com/api/reference/resources/videos/methods/extend",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.OPENAI.providerId,
                modelCode: EnumProviderModelCode.OPENAI_SORA_2_PRO_REMIX,
                modelSetType: EnumSetType.VIDEO_EXTEND,
                modelName: "Sora 2 Pro",
                modelDescription: "Extend existing clips with continued motion.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    requiredMetadata: ["soraVideoId"],
                    supportedDimensions: ["1280x720", "720x1280", "1792x1024", "1024x1792"],
                    supportedVideoDurations: [4, 8, 12, 16, 20]
                ),
                modelLaunchDate: getDateFromString("2025-02-01"),
                modelGenerateBaseURL: "https://api.openai.com/v1/videos/extensions",
                modelAPIDocumentationURL: "https://developers.openai.com/api/reference/resources/videos/methods/extend",
                active: true
            ),
        ]
    }
}
