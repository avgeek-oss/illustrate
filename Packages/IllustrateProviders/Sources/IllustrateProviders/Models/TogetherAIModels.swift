// MARK: - TogetherAIModels.swift

// Factory for Together AI model configurations.

import Foundation

/// Factory enum for creating Together AI model configurations.
public enum TogetherAIModels {
    /// Creates all Together AI model configurations.
    public static func createModels() -> [ProviderModelData] {
        let imageBaseURL = "https://api.together.ai/v1/images/generations"
        let videoBaseURL = "https://api.together.ai/v2/videos"
        let imageDocURL = "https://docs.together.ai/reference/post-images-generations"
        let videoDocURL = "https://docs.together.ai/reference/create-videos"
        let providerId = EnumProviderCode.TOGETHER_AI.providerId

        return createImageModels(
            providerId: providerId,
            baseURL: imageBaseURL,
            docURL: imageDocURL
        ) + createVideoModels(
            providerId: providerId,
            baseURL: videoBaseURL,
            docURL: videoDocURL
        )
    }

    private static func createImageModels(
        providerId: UUID,
        baseURL: String,
        docURL: String
    ) -> [ProviderModelData] {
        let commonDimensions = [
            "1024x1024",
            "1344x768",
            "768x1344",
            "1152x896",
            "896x1152",
        ]

        return [
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_FLUX_SCHNELL,
                modelSetType: .IMAGE_GENERATE,
                modelName: "FLUX.1 Schnell",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportedStepsRange: IntRange(1, 12),
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2024-08-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_FLUX_11_PRO,
                modelSetType: .IMAGE_GENERATE,
                modelName: "FLUX.1.1 Pro",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportedGuidanceRange: DoubleRange(1.0, 10.0),
                    supportedStepsRange: IntRange(1, 50),
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2024-10-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_FLUX_2_PRO,
                modelSetType: .IMAGE_GENERATE,
                modelName: "FLUX.2 Pro",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportedGuidanceRange: DoubleRange(1.0, 10.0),
                    supportedStepsRange: IntRange(1, 50),
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_FLUX_2_DEV,
                modelSetType: .IMAGE_GENERATE,
                modelName: "FLUX.2 Dev",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportedGuidanceRange: DoubleRange(1.0, 10.0),
                    supportedStepsRange: IntRange(1, 50),
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_FLUX_2_MAX,
                modelSetType: .IMAGE_GENERATE,
                modelName: "FLUX.2 Max",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportedGuidanceRange: DoubleRange(1.0, 10.0),
                    supportedStepsRange: IntRange(1, 50),
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_FLUX_KONTEXT_PRO,
                modelSetType: .IMAGE_GENERATE,
                modelName: "FLUX.1 Kontext Pro",
                modelDescription: "Create images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportedStepsRange: IntRange(1, 50),
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-03-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_FLUX_KONTEXT_MAX,
                modelSetType: .IMAGE_GENERATE,
                modelName: "FLUX.1 Kontext Max",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportedStepsRange: IntRange(1, 50),
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-03-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_SD3,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Stable Diffusion 3",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportedGuidanceRange: DoubleRange(1.0, 10.0),
                    supportedStepsRange: IntRange(1, 50),
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2024-06-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_SDXL,
                modelSetType: .IMAGE_GENERATE,
                modelName: "SD XL",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportedGuidanceRange: DoubleRange(1.0, 10.0),
                    supportedStepsRange: IntRange(1, 50),
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2023-07-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_IMAGEN_4_FAST,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Imagen 4.0 Fast",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-05-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_IMAGEN_4_ULTRA,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Imagen 4.0 Ultra",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-05-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_SEEDREAM_4,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Seedream 4.0",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-03-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_IDEOGRAM_3,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Ideogram 3.0",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-04-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_QWEN_IMAGE,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Qwen Image 2.0",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-05-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_FLUX_2_FLEX,
                modelSetType: .IMAGE_GENERATE,
                modelName: "FLUX.2 Flex",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportedGuidanceRange: DoubleRange(1.0, 10.0),
                    supportedStepsRange: IntRange(1, 50),
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_FLUX_KREA_DEV,
                modelSetType: .IMAGE_GENERATE,
                modelName: "FLUX.1 Krea Dev",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportedStepsRange: IntRange(1, 50),
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-04-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_IMAGEN_4_PREVIEW,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Imagen 4.0 Preview",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-05-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_FLASH_IMAGE_25,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Flash Image 2.5",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-04-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_GEMINI_3_PRO_IMAGE,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Gemini 3 Pro Image",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportedImageResolutions: ["1K", "2K", "4K"],
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-05-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_FLASH_IMAGE_31,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Gemini 3.1 Flash Image",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_SEEDREAM_3,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Seedream 3.0",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_QWEN_IMAGE_PRO,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Qwen Image 2.0 Pro",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_HIDREAM_DEV,
                modelSetType: .IMAGE_GENERATE,
                modelName: "HiDream I1 Dev",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-04-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_HIDREAM_FAST,
                modelSetType: .IMAGE_GENERATE,
                modelName: "HiDream I1 Fast",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-04-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_WAN_26_IMAGE,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Wan 2.6 Image",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-05-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_GPT_IMAGE_15,
                modelSetType: .IMAGE_GENERATE,
                modelName: "GPT Image 1.5",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-12-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_GROK_IMAGINE_PRO,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Grok Imagine Image Pro",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_QWEN_IMAGE_BASE,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Qwen Image",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-05-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_JUGGERNAUT_PRO_FLUX,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Juggernaut Pro Flux",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-04-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_JUGGERNAUT_LIGHTNING_FLUX,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Juggernaut Lightning Flux",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-04-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_DREAMSHAPER,
                modelSetType: .IMAGE_GENERATE,
                modelName: "DreamShaper",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2024-06-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_HIDREAM_FULL,
                modelSetType: .IMAGE_GENERATE,
                modelName: "HiDream I1 Full",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: commonDimensions,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-04-01"),
                modelGenerateBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
        ]
    }

    private static func createVideoModels(
        providerId: UUID,
        baseURL: String,
        docURL: String
    ) -> [ProviderModelData] {
        [
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_MINIMAX_DIRECTOR,
                modelSetType: .VIDEO_GENERATE,
                modelName: "MiniMax Director",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1366x768", "768x1366", "1088x832", "832x1088"],
                    supportedVideoDurations: [5, 6],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-05-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_HAILUO_02,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Hailuo 02",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["768x768", "768x480", "480x768"],
                    supportedVideoDurations: [5, 10],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_VEO_2,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Veo 2.0",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280"],
                    supportedVideoDurations: [5, 6],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-03-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_VEO_3_FAST,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Veo 3.0 Fast",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280", "1920x1080", "1080x1920"],
                    supportedVideoDurations: [8],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_SEEDANCE_LITE,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Seedance 1.0 Lite",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280"],
                    supportedVideoDurations: [5],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-04-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_SEEDANCE_PRO,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Seedance 1.0 Pro",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1920x1080", "1080x1920", "1280x720", "720x1280"],
                    supportedVideoDurations: [5],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-04-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_SEEDANCE_2,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Seedance 2.0",
                modelDescription: "Create images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 3000,
                    maxReferenceImages: 9,
                    supportedDimensions: ["16:9", "9:16", "1:1", "4:3", "3:4", "21:9"],
                    supportedReferenceTypes: ["asset", "style"],
                    supportedVideoDurations: [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
                    supportedVideoResolutions: ["480p", "720p", "1080p", "4k"],
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_KLING_21_PRO,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Kling 2.1 Pro",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1920x1080", "1080x1920", "1280x720", "720x1280"],
                    supportedVideoDurations: [5, 10],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_WAN_27_T2V,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Wan 2.7 T2V",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 5000,
                    supportedDimensions: ["16:9", "9:16", "1:1", "4:3", "3:4"],
                    supportedVideoDurations: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_WAN_27_I2V,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Wan 2.7 I2V",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 5000,
                    supportedDimensions: ["16:9", "9:16", "1:1", "4:3", "3:4"],
                    supportedVideoDurations: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsLastFrame: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_PIXVERSE_V6,
                modelSetType: .VIDEO_GENERATE,
                modelName: "PixVerse v6",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280"],
                    supportedVideoDurations: [5],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_VEO_3,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Veo 3.0",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280", "1920x1080", "1080x1920"],
                    supportedVideoDurations: [8],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_VEO_31,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Veo 3.1",
                modelDescription: "Generate cinematic videos from detailed written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000
                ),
                modelLaunchDate: getDateFromString("2026-05-25"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_VEO_31_LITE,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Veo 3.1 Lite",
                modelDescription: "Generate cinematic videos from detailed written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000
                ),
                modelLaunchDate: getDateFromString("2026-05-25"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_VEO_3_AUDIO,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Veo 3.0 + Audio",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280", "1920x1080", "1080x1920"],
                    supportedVideoDurations: [8],
                    supportsAudio: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_VEO_3_FAST_AUDIO,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Veo 3.0 Fast + Audio",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280", "1920x1080", "1080x1920"],
                    supportedVideoDurations: [8],
                    supportsAudio: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_KLING_21_MASTER,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Kling 2.1 Master",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1920x1080", "1080x1920", "1280x720", "720x1280"],
                    supportedVideoDurations: [5, 10],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_KLING_21_STD,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Kling 2.1 Standard",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280"],
                    supportedVideoDurations: [5, 10],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_KLING_20_MASTER,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Kling 2.0 Master",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1920x1080", "1080x1920", "1280x720", "720x1280"],
                    supportedVideoDurations: [5, 10],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-05-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_KLING_16_PRO,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Kling 1.6 Pro",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1920x1080", "1080x1920", "1280x720", "720x1280"],
                    supportedVideoDurations: [5, 10],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-03-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_KLING_16_STD,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Kling 1.6 Standard",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280"],
                    supportedVideoDurations: [5, 10],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-03-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_WAN_22_T2V,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Wan 2.2 T2V",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280"],
                    supportedVideoDurations: [5],
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-04-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_WAN_22_I2V,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Wan 2.2 I2V",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280"],
                    supportedVideoDurations: [5],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-04-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_WAN_27_R2V,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Wan 2.7 R2V",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 5000,
                    maxReferenceImages: 4,
                    supportedDimensions: ["16:9", "9:16", "1:1", "4:3", "3:4"],
                    supportedReferenceTypes: ["asset", "style"],
                    supportedVideoDurations: [2, 3, 4, 5, 6, 7, 8, 9, 10],
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_VIDU_20,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Vidu 2.0",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280"],
                    supportedVideoDurations: [5, 8],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_VIDU_Q1,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Vidu Q1",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280"],
                    supportedVideoDurations: [5, 8],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_VIDU_Q3,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Vidu Q3",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280"],
                    supportedVideoDurations: [5],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_VIDU_Q3_TURBO,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Vidu Q3 Turbo",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280"],
                    supportedVideoDurations: [5],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_PIXVERSE_V5,
                modelSetType: .VIDEO_GENERATE,
                modelName: "PixVerse v5",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280"],
                    supportedVideoDurations: [5],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-05-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_PIXVERSE_V56,
                modelSetType: .VIDEO_GENERATE,
                modelName: "PixVerse v5.6",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280"],
                    supportedVideoDurations: [5],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_SORA_2,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Sora 2",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280"],
                    supportedVideoDurations: [5, 8],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_SORA_2_PRO,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Sora 2 Pro",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280"],
                    supportedVideoDurations: [5, 8, 10],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .TOGETHER_HAPPY_HORSE,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Happy Horse",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280"],
                    supportedVideoDurations: [5],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-06-01"),
                modelGenerateBaseURL: baseURL,
                modelStatusBaseURL: baseURL,
                modelAPIDocumentationURL: docURL,
                active: true
            ),
        ]
    }
}
