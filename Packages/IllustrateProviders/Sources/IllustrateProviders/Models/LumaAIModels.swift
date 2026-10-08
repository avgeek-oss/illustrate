// MARK: - LumaAIModels.swift

// Factory for Luma AI model configurations.

import Foundation

public enum LumaAIModels {
    public static func createModels() -> [ProviderModelData] {
        let imageBaseURL = "https://api.lumalabs.ai/dream-machine/v1/generations/image"
        let videoBaseURL = "https://api.lumalabs.ai/dream-machine/v1/generations/video"
        let statusBaseURL = "https://api.lumalabs.ai/dream-machine/v1/generations"
        let agentsBaseURL = "https://agents.lumalabs.ai/v1/generations"
        let docURL = "https://docs.agents.lumalabs.ai"
        let agentsImageDocURL = "https://docs.agents.lumalabs.ai/guides/images/generation/"
        let agentsVideoDocURL = "https://docs.agents.lumalabs.ai/guides/videos/generation/"
        let providerId = EnumProviderCode.LUMA_AI.providerId

        let aspectRatios = [
            "1:1",
            "16:9",
            "9:16",
            "4:3",
            "3:4",
            "21:9",
            "9:21",
        ]

        let agentsAspectRatios = [
            "3:1",
            "2:1",
            "16:9",
            "3:2",
            "1:1",
            "2:3",
            "9:16",
            "1:2",
            "1:3",
        ]

        let agentsVideoAspectRatios = [
            "9:16",
            "3:4",
            "1:1",
            "4:3",
            "16:9",
            "21:9",
        ]

        return createImageModels(
            providerId: providerId,
            baseURL: imageBaseURL,
            statusBaseURL: statusBaseURL,
            docURL: docURL,
            aspectRatios: aspectRatios,
            agentsBaseURL: agentsBaseURL,
            agentsDocURL: agentsImageDocURL,
            agentsAspectRatios: agentsAspectRatios
        ) + createVideoModels(
            providerId: providerId,
            baseURL: videoBaseURL,
            statusBaseURL: statusBaseURL,
            docURL: docURL,
            aspectRatios: aspectRatios,
            agentsBaseURL: agentsBaseURL,
            agentsDocURL: agentsVideoDocURL,
            agentsAspectRatios: agentsVideoAspectRatios
        )
    }

    private static func createImageModels(
        providerId: UUID,
        baseURL: String,
        statusBaseURL: String,
        docURL: String,
        aspectRatios: [String],
        agentsBaseURL: String,
        agentsDocURL: String,
        agentsAspectRatios: [String]
    ) -> [ProviderModelData] {
        [
            ProviderModelData(
                providerId: providerId,
                modelCode: .LUMA_PHOTON,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Photon",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: aspectRatios,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: statusBaseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .LUMA_PHOTON_FLASH,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Photon Flash",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: aspectRatios,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: statusBaseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .LUMA_UNI_1,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Uni 1",
                modelDescription: "Create images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 6000,
                    maxReferenceImages: 9,
                    supportedDimensions: agentsAspectRatios,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: agentsBaseURL,
                modelStatusBaseURL: agentsBaseURL,
                modelAPIDocumentationURL: agentsDocURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .LUMA_UNI_1_MAX,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Uni 1 Max",
                modelDescription: "Create images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 6000,
                    maxReferenceImages: 9,
                    supportedDimensions: agentsAspectRatios,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: agentsBaseURL,
                modelStatusBaseURL: agentsBaseURL,
                modelAPIDocumentationURL: agentsDocURL,
                active: true
            ),
        ]
    }

    private static func createVideoModels(
        providerId: UUID,
        baseURL: String,
        statusBaseURL: String,
        docURL: String,
        aspectRatios: [String],
        agentsBaseURL: String,
        agentsDocURL: String,
        agentsAspectRatios: [String]
    ) -> [ProviderModelData] {
        [
            ProviderModelData(
                providerId: providerId,
                modelCode: .LUMA_RAY_2,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Ray 2",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    supportedDimensions: aspectRatios,
                    supportedVideoDurations: [5, 9],
                    supportedVideoResolutions: ["540p", "720p", "1080p"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: statusBaseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .LUMA_RAY_FLASH_2,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Ray Flash 2",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    supportedDimensions: aspectRatios,
                    supportedVideoDurations: [5, 9],
                    supportedVideoResolutions: ["540p", "720p", "1080p"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: statusBaseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .LUMA_RAY_2_I2V,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Ray 2 (Image to Video)",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    supportedDimensions: aspectRatios,
                    supportedVideoDurations: [5, 9],
                    supportedVideoResolutions: ["540p", "720p", "1080p"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: statusBaseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .LUMA_RAY_FLASH_2_I2V,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Ray Flash 2 (Image to Video)",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    supportedDimensions: aspectRatios,
                    supportedVideoDurations: [5, 9],
                    supportedVideoResolutions: ["540p", "720p", "1080p"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: statusBaseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .LUMA_RAY_3_2,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Ray 3.2",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 6000,
                    supportedDimensions: agentsAspectRatios,
                    supportedVideoDurations: [5, 10],
                    supportedVideoResolutions: ["360p", "540p", "720p", "1080p"],
                    supportsLastFrame: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: agentsBaseURL,
                modelStatusBaseURL: agentsBaseURL,
                modelAPIDocumentationURL: agentsDocURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .LUMA_RAY_3_2_KEYFRAMES,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Ray 3.2 Keyframes",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 6000,
                    supportedDimensions: agentsAspectRatios,
                    supportedVideoDurations: [5, 10],
                    supportedVideoResolutions: ["360p", "540p", "720p", "1080p"]
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: agentsBaseURL,
                modelStatusBaseURL: agentsBaseURL,
                modelAPIDocumentationURL: agentsDocURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .LUMA_RAY_3_2_EXTEND,
                modelSetType: .VIDEO_EXTEND,
                modelName: "Ray 3.2",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 6000,
                    requiredMetadata: ["lumaGenerationId"],
                    supportedDimensions: agentsAspectRatios,
                    supportedVideoDurations: [5],
                    supportedVideoResolutions: ["540p", "720p", "1080p"]
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: agentsBaseURL,
                modelStatusBaseURL: agentsBaseURL,
                modelAPIDocumentationURL: agentsDocURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .LUMA_RAY_3_2_EDIT,
                modelSetType: .VIDEO_EXTEND,
                modelName: "Ray 3.2 Edit",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 6000,
                    requiredMetadata: ["lumaGenerationId"],
                    supportedVideoDurations: [5, 10],
                    supportedVideoResolutions: ["360p", "540p", "720p", "1080p"]
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: agentsBaseURL,
                modelStatusBaseURL: agentsBaseURL,
                modelAPIDocumentationURL: agentsDocURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .LUMA_RAY_3_2_REFRAME,
                modelSetType: .VIDEO_EXTEND,
                modelName: "Ray 3.2 Reframe",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 6000,
                    requiredMetadata: ["lumaGenerationId"],
                    supportedDimensions: agentsAspectRatios,
                    supportedVideoResolutions: ["360p", "540p", "720p", "1080p"]
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: agentsBaseURL,
                modelStatusBaseURL: agentsBaseURL,
                modelAPIDocumentationURL: agentsDocURL,
                active: true
            ),
        ]
    }
}
