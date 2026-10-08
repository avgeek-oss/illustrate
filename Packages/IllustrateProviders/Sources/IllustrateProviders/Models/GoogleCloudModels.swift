// MARK: - GoogleCloudModels.swift

// Factory for Google Cloud AI model configurations.

import Foundation

/// Factory enum for creating Google Cloud model configurations.
public enum GoogleCloudModels {
    /// Creates all Google Cloud model configurations.
    public static func createModels() -> [ProviderModelData] {
        [
            ProviderModelData(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                modelCode: EnumProviderModelCode.GOOGLE_GEMINI_FLASH_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Nano Banana",
                modelDescription: "Create images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    maxReferenceImages: 3,
                    supportedDimensions: [
                        "1:1",
                        "2:3",
                        "3:2",
                        "3:4",
                        "4:3",
                        "4:5",
                        "5:4",
                        "9:16",
                        "16:9",
                        "21:9",
                    ],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2024-11-01"),
                modelGenerateBaseURL: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent",
                modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/image-generation",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                modelCode: EnumProviderModelCode.GOOGLE_GEMINI_31_FLASH_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Nano Banana 2",
                modelDescription: "Create images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    maxReferenceImages: 3,
                    supportedDimensions: [
                        "1:1",
                        "1:4",
                        "1:8",
                        "2:3",
                        "3:2",
                        "3:4",
                        "4:1",
                        "4:3",
                        "4:5",
                        "5:4",
                        "8:1",
                        "9:16",
                        "16:9",
                        "21:9",
                    ],
                    supportedTools: ["google_search"],
                    supportedImageQualities: ["1K", "2K", "4K", "0.5K"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-02-01"),
                modelGenerateBaseURL: "https://generativelanguage.googleapis.com/v1beta/interactions",
                modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/interactions/image-generation",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                modelCode: EnumProviderModelCode.GOOGLE_GEMINI_31_FLASH_LITE_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Nano Banana 2 Lite",
                modelDescription: "Create images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    maxReferenceImages: 3,
                    supportedDimensions: [
                        "1:1",
                        "2:3",
                        "3:2",
                        "3:4",
                        "4:3",
                        "4:5",
                        "5:4",
                        "9:16",
                        "16:9",
                        "21:9",
                    ],
                    supportedImageQualities: ["1K"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: "https://generativelanguage.googleapis.com/v1beta/interactions",
                modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/models/gemini-3.1-flash-lite-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                modelCode: EnumProviderModelCode.GOOGLE_GEMINI_PRO_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Nano Banana Pro",
                modelDescription: "Create images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    maxReferenceImages: 14,
                    supportedDimensions: [
                        "1:1",
                        "2:3",
                        "3:2",
                        "3:4",
                        "4:3",
                        "4:5",
                        "5:4",
                        "9:16",
                        "16:9",
                        "21:9",
                    ],
                    supportedTools: ["google_search"],
                    supportedImageQualities: ["2K", "4K", "1K"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-05-28"),
                modelGenerateBaseURL: "https://generativelanguage.googleapis.com/v1beta/interactions",
                modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/models/gemini-3-pro-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                modelCode: EnumProviderModelCode.GOOGLE_IMAGEN_3,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Imagen 3",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4096,
                    supportedDimensions: ["1:1", "3:4", "4:3", "9:16", "16:9"],
                    supportedPersonGenerationOptions: ["dont_allow", "allow_adult", "allow_all"],
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: "https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-002:predict",
                modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/imagen",
                active: false
            ),
            // The native Gemini API Imagen 4 endpoints were deprecated on June 15, 2026
            // and shut down on August 17, 2026. Preserve these records for historical
            // generations, but keep them out of new-generation model queries.
            ProviderModelData(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                modelCode: EnumProviderModelCode.GOOGLE_IMAGEN_4_FAST,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Imagen 4 Fast",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4096,
                    supportedDimensions: ["1:1", "3:4", "4:3", "9:16", "16:9"],
                    supportedPersonGenerationOptions: ["dont_allow", "allow_adult", "allow_all"],
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelDeprecationDate: getDateFromString("2026-06-15"),
                modelVerificationDate: getDateFromString("2026-07-10"),
                modelShutdownDate: getDateFromString("2026-08-17"),
                replacementModelCode: EnumProviderModelCode.GOOGLE_GEMINI_31_FLASH_IMAGE,
                modelGenerateBaseURL: "https://generativelanguage.googleapis.com/v1beta/models/imagen-4.0-fast-generate-001:predict",
                modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/models/imagen",
                active: false
            ),
            ProviderModelData(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                modelCode: EnumProviderModelCode.GOOGLE_IMAGEN_4_STANDARD,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Imagen 4 Standard",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4096,
                    supportedDimensions: ["1:1", "3:4", "4:3", "9:16", "16:9"],
                    supportedPersonGenerationOptions: ["dont_allow", "allow_adult", "allow_all"],
                    supportedImageQualities: ["1K", "2K"],
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelDeprecationDate: getDateFromString("2026-06-15"),
                modelVerificationDate: getDateFromString("2026-07-10"),
                modelShutdownDate: getDateFromString("2026-08-17"),
                replacementModelCode: EnumProviderModelCode.GOOGLE_GEMINI_31_FLASH_IMAGE,
                modelGenerateBaseURL: "https://generativelanguage.googleapis.com/v1beta/models/imagen-4.0-generate-001:predict",
                modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/models/imagen",
                active: false
            ),
            ProviderModelData(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                modelCode: EnumProviderModelCode.GOOGLE_IMAGEN_4_ULTRA,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Imagen 4 Ultra",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4096,
                    supportedDimensions: ["1:1", "3:4", "4:3", "9:16", "16:9"],
                    supportedPersonGenerationOptions: ["dont_allow", "allow_adult", "allow_all"],
                    supportedImageQualities: ["1K", "2K"],
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelDeprecationDate: getDateFromString("2026-06-15"),
                modelVerificationDate: getDateFromString("2026-07-10"),
                modelShutdownDate: getDateFromString("2026-08-17"),
                replacementModelCode: EnumProviderModelCode.GOOGLE_GEMINI_31_FLASH_IMAGE,
                modelGenerateBaseURL: "https://generativelanguage.googleapis.com/v1beta/models/imagen-4.0-ultra-generate-001:predict",
                modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/models/imagen",
                active: false
            ),
            ProviderModelData(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                modelCode: EnumProviderModelCode.GOOGLE_GEMINI_OMNI_FLASH_VIDEO,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Gemini Omni Flash",
                modelDescription: "Animate still images into motion clips.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    maxReferenceImages: 3,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [3, 4, 5, 6, 7, 8, 9, 10],
                    supportedVideoResolutions: ["720p"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: "https://generativelanguage.googleapis.com/v1beta/interactions",
                modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/omni",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                modelCode: EnumProviderModelCode.GOOGLE_GEMINI_OMNI_FLASH_VIDEO_EDIT,
                modelSetType: EnumSetType.VIDEO_EXTEND,
                modelName: "Gemini Omni Flash",
                modelDescription: "Edit existing clips with prompt-guided changes.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    requiredMetadata: [GeminiInteractionMetadataKey.interactionId],
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [3, 4, 5, 6, 7, 8, 9, 10],
                    supportedVideoResolutions: ["720p"]
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: "https://generativelanguage.googleapis.com/v1beta/interactions",
                modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/omni",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                modelCode: EnumProviderModelCode.GOOGLE_VEO_31,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Veo 3.1",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    maxReferenceImages: 3,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedReferenceTypes: ["asset", "style"],
                    supportedVideoDurations: [4, 6, 8],
                    supportedVideoResolutions: ["720p", "1080p", "4k"],
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-09-01"),
                modelGenerateBaseURL: "https://generativelanguage.googleapis.com/v1beta/models/veo-3.1-generate-preview:predictLongRunning",
                modelStatusBaseURL: "https://generativelanguage.googleapis.com/v1beta",
                modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/veo",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                modelCode: EnumProviderModelCode.GOOGLE_VEO_31_EXTEND,
                modelSetType: EnumSetType.VIDEO_EXTEND,
                modelName: "Veo 3.1",
                modelDescription: "Extend existing clips with continued motion.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    maxReferenceImages: 3,
                    requiredMetadata: ["veoGeneratedUri"],
                    supportedDimensions: ["16:9", "9:16"],
                    supportedReferenceTypes: ["asset", "style"],
                    supportedVideoDurations: [8],
                    supportedVideoResolutions: ["720p"],
                    supportsAudio: true,
                    supportsNegativePrompt: true
                ),
                modelLaunchDate: getDateFromString("2025-09-01"),
                modelGenerateBaseURL: "https://generativelanguage.googleapis.com/v1beta/models/veo-3.1-generate-preview:predictLongRunning",
                modelStatusBaseURL: "https://generativelanguage.googleapis.com/v1beta",
                modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/veo",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                modelCode: EnumProviderModelCode.GOOGLE_VEO_31_FAST,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Veo 3.1 Fast",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    maxReferenceImages: 3,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedReferenceTypes: ["asset", "style"],
                    supportedVideoDurations: [4, 6, 8],
                    supportedVideoResolutions: ["720p", "1080p", "4k"],
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-09-01"),
                modelGenerateBaseURL: "https://generativelanguage.googleapis.com/v1beta/models/veo-3.1-fast-generate-preview:predictLongRunning",
                modelStatusBaseURL: "https://generativelanguage.googleapis.com/v1beta",
                modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/veo",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                modelCode: EnumProviderModelCode.GOOGLE_VEO_31_FAST_EXTEND,
                modelSetType: EnumSetType.VIDEO_EXTEND,
                modelName: "Veo 3.1 Fast",
                modelDescription: "Extend existing clips with continued motion.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    requiredMetadata: ["veoGeneratedUri"],
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [8],
                    supportedVideoResolutions: ["720p"],
                    supportsAudio: true,
                    supportsNegativePrompt: true
                ),
                modelLaunchDate: getDateFromString("2025-09-01"),
                modelGenerateBaseURL: "https://generativelanguage.googleapis.com/v1beta/models/veo-3.1-fast-generate-preview:predictLongRunning",
                modelStatusBaseURL: "https://generativelanguage.googleapis.com/v1beta",
                modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/veo",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                modelCode: EnumProviderModelCode.GOOGLE_VEO_3,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Veo 3",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [4, 6, 8],
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-07-01"),
                modelGenerateBaseURL: "https://generativelanguage.googleapis.com/v1beta/models/veo-3.0-generate-001:predictLongRunning",
                modelStatusBaseURL: "https://generativelanguage.googleapis.com/v1beta",
                modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/veo",
                active: false
            ),
            ProviderModelData(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                modelCode: EnumProviderModelCode.GOOGLE_VEO_3_FAST,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Veo 3 Fast",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [4, 6, 8],
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-07-01"),
                modelGenerateBaseURL: "https://generativelanguage.googleapis.com/v1beta/models/veo-3.0-fast-generate-001:predictLongRunning",
                modelStatusBaseURL: "https://generativelanguage.googleapis.com/v1beta",
                modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/veo",
                active: false
            ),
            ProviderModelData(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                modelCode: EnumProviderModelCode.GOOGLE_VEO_2,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Veo 2",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [5, 6, 8],
                    supportedVideoResolutions: ["720p"],
                    supportsAudio: false,
                    supportsLastFrame: true,
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-04-01"),
                modelGenerateBaseURL: "https://generativelanguage.googleapis.com/v1beta/models/veo-2.0-generate-001:predictLongRunning",
                modelStatusBaseURL: "https://generativelanguage.googleapis.com/v1beta",
                modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/veo",
                active: false
            ),
            ProviderModelData(
                providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
                modelCode: EnumProviderModelCode.GOOGLE_VEO_31_LITE,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Veo 3.1 Lite",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [4, 6, 8],
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-10-01"),
                modelGenerateBaseURL: "https://generativelanguage.googleapis.com/v1beta/models/veo-3.1-lite-generate-preview:predictLongRunning",
                modelStatusBaseURL: "https://generativelanguage.googleapis.com/v1beta",
                modelAPIDocumentationURL: "https://ai.google.dev/gemini-api/docs/veo",
                active: true
            ),
        ]
    }
}
