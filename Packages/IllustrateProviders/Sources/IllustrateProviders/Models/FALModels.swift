// MARK: - FALModels.swift

// Factory for Fal AI model configurations.

import Foundation

/// Factory enum for creating Fal AI model configurations.
public enum FALModels {
    /// Creates all Fal AI model configurations.
    /// Split into smaller arrays to avoid Swift type-checking timeouts.
    public static func createModels() -> [ProviderModelData] {
        var models: [ProviderModelData] = []
        models.append(contentsOf: createFlux1Models())
        models.append(contentsOf: createFlux2Models())
        models.append(contentsOf: createFluxKontextModels())
        models.append(contentsOf: createBriaModels())
        models.append(contentsOf: createLumaPhotonModels())
        models.append(contentsOf: createGLMQwenModels())
        models.append(contentsOf: createByteDanceModels())
        models.append(contentsOf: createKlingImageModels())
        models.append(contentsOf: createOpenAIGPTImageModels())
        models.append(contentsOf: createGoogleImageModels())
        models.append(contentsOf: createMiscImageModels())
        models.append(contentsOf: createVeoVideoModels())
        models.append(contentsOf: createSeedanceVideoModels())
        models.append(contentsOf: createCatalogRefreshVideoModels())
        models.append(contentsOf: createWanVideoModels())
        models.append(contentsOf: createKlingVideoModels())
        models.append(contentsOf: createSoraVideoModels())
        models.append(contentsOf: createMiniMaxVideoModels())
        models.append(contentsOf: createPixverseVideoModels())
        models.append(contentsOf: createHappyHorseVideoModels())
        models.append(contentsOf: createXaiImageModels())
        models.append(contentsOf: createHiDreamImageModels())
        models.append(contentsOf: createErnieImageModels())
        models.append(contentsOf: createRecraftV41ImageModels())
        return models
    }

    // MARK: - FLUX 1 Models

    private static func createFlux1Models() -> [ProviderModelData] {
        [
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_SCHNELL,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX.1 [schnell]",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 6,
                    maxPromptLength: 4096,
                    supportedDimensions: ["1024x1024", "1920x1080", "1440x1080", "1080x1920", "1080x1440"],
                    supportedGuidanceRange: DoubleRange(1.0, 10.0),
                    supportedSafetyRange: IntRange(1, 5),
                    supportedStepsRange: IntRange(1, 4),
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2023-12-13"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux/schnell",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux/schnell",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_DEV,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX.1 [dev]",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 6,
                    maxPromptLength: 4096,
                    supportedDimensions: ["1024x1024", "1920x1080", "1440x1080", "1080x1920", "1080x1440"],
                    supportedGuidanceRange: DoubleRange(1.0, 10.0),
                    supportedSafetyRange: IntRange(1, 5),
                    supportedStepsRange: IntRange(1, 50),
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2023-12-13"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux/dev",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux/dev",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_PRO,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX.1 [pro]",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 6,
                    maxPromptLength: 4096,
                    supportedDimensions: ["1024x1024", "1920x1080", "1440x1080", "1080x1920", "1080x1440"],
                    supportedGuidanceRange: DoubleRange(1.0, 10.0),
                    supportedSafetyRange: IntRange(1, 5),
                    supportedStepsRange: IntRange(1, 50),
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2023-07-26"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux-pro",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux-pro",
                active: true
            ),

            // MARK: - FLUX 1 Image-to-Image & Redux

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_DEV_IMAGE_TO_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX.1 [dev] Image-to-Image",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    supportedDimensions: ["1024x1024", "1920x1080", "1440x1080", "1080x1920", "1080x1440"],
                    supportedGuidanceRange: DoubleRange(1.0, 20.0),
                    supportedStepsRange: IntRange(10, 50),
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2024-08-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux/dev/image-to-image",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux/dev/image-to-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_DEV_REDUX,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX.1 [dev] Redux",
                modelDescription: "Create visual variations from source images.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    supportedDimensions: ["1024x1024", "1920x1080", "1440x1080", "1080x1920", "1080x1440"],
                    supportedGuidanceRange: DoubleRange(1.0, 20.0),
                    supportedStepsRange: IntRange(1, 50),
                    supportsPrompt: false,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2024-08-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux/dev/redux",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux/dev/redux",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_SCHNELL_REDUX,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX.1 [schnell] Redux",
                modelDescription: "Create visual variations from source images.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    supportedDimensions: ["1024x1024", "1920x1080", "1440x1080", "1080x1920", "1080x1440"],
                    supportedGuidanceRange: DoubleRange(1.0, 20.0),
                    supportedStepsRange: IntRange(1, 4),
                    supportsPrompt: false,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2024-08-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux/schnell/redux",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux/schnell/redux",
                active: true
            ),
        ]
    }

    // MARK: - FLUX 2 Models

    private static func createFlux2Models() -> [ProviderModelData] {
        [
            // MARK: FLUX 2 Text-to-Image

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_2,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX 2 [dev]",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    supportedDimensions: ["1024x1024", "1920x1080", "1440x1080", "1080x1920", "1080x1440"],
                    supportedGuidanceRange: DoubleRange(0, 20.0),
                    supportedStepsRange: IntRange(4, 50),
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux-2",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux-2",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_2_PRO,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX 2 [pro]",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    supportedDimensions: ["1024x1024", "1920x1080", "1440x1080", "1080x1920", "1080x1440"],
                    supportedSafetyRange: IntRange(1, 5),
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux-2-pro",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux-2-pro",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_2_FLEX,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX 2 [flex]",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    supportedDimensions: ["1024x1024", "1920x1080", "1440x1080", "1080x1920", "1080x1440"],
                    supportedGuidanceRange: DoubleRange(1.5, 10.0),
                    supportedSafetyRange: IntRange(1, 5),
                    supportedStepsRange: IntRange(2, 50),
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux-2-flex",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux-2-flex",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_2_MAX,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX 2 [max]",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    supportedDimensions: ["1024x1024", "1920x1080", "1440x1080", "1080x1920", "1080x1440"],
                    supportedSafetyRange: IntRange(1, 5),
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux-2-max",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux-2-max",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_2_TURBO,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX 2 [turbo]",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    supportedDimensions: ["1024x1024", "1920x1080", "1440x1080", "1080x1920", "1080x1440"],
                    supportedGuidanceRange: DoubleRange(0, 20.0),
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux-2/turbo",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux-2/turbo",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_2_KLEIN_4B,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX 2 Klein 4B",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    supportedDimensions: ["1024x1024", "1920x1080", "1440x1080", "1080x1920", "1080x1440"],
                    supportedStepsRange: IntRange(4, 8),
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux-2/klein/4b",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux-2/klein/4b",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_2_KLEIN_9B,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX 2 Klein 9B",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    supportedDimensions: ["1024x1024", "1920x1080", "1440x1080", "1080x1920", "1080x1440"],
                    supportedSafetyRange: IntRange(1, 5),
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux-2/klein/9b",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux-2/klein/9b",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_2_FLASH,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX 2 Flash",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    supportedDimensions: ["1024x1024", "1920x1080", "1440x1080", "1080x1920", "1080x1440"],
                    supportedGuidanceRange: DoubleRange(0, 20.0),
                    supportedStepsRange: IntRange(1, 8),
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux-2/flash",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux-2/flash",
                active: true
            ),

            // MARK: - FLUX 2 Edit (Image-to-Image)

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_2_PRO_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX 2 [pro] Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    supportedSafetyRange: IntRange(1, 5),
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux-2-pro/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux-2-pro/edit",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_2_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX 2 [dev] Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    supportedGuidanceRange: DoubleRange(0, 20.0),
                    supportedStepsRange: IntRange(4, 50),
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux-2/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux-2/edit",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_2_FLEX_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX 2 [flex] Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    supportedGuidanceRange: DoubleRange(1.5, 10.0),
                    supportedSafetyRange: IntRange(1, 5),
                    supportedStepsRange: IntRange(2, 50),
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux-2-flex/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux-2-flex/edit",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_2_MAX_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX 2 [max] Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    supportedSafetyRange: IntRange(1, 5),
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux-2-max/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux-2-max/edit",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_2_TURBO_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX 2 [turbo] Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    supportedGuidanceRange: DoubleRange(0, 20.0),
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux-2/turbo/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux-2/turbo/edit",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_2_KLEIN_4B_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX 2 Klein 4B Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    supportedStepsRange: IntRange(4, 8),
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux-2/klein/4b/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux-2/klein/4b/edit",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_2_FLASH_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX 2 Flash Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    supportedGuidanceRange: DoubleRange(0, 20.0),
                    supportedStepsRange: IntRange(1, 8),
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux-2/flash/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux-2/flash/edit",
                active: true
            ),
        ]
    }

    // MARK: - FLUX Kontext Models

    private static func createFluxKontextModels() -> [ProviderModelData] {
        [
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_KONTEXT_DEV,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX Kontext [dev]",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    supportedGuidanceRange: DoubleRange(1.0, 20.0),
                    supportedStepsRange: IntRange(10, 50),
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux-kontext/dev",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux-kontext/dev",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_PRO_KONTEXT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX Kontext [pro]",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    supportedGuidanceRange: DoubleRange(1.0, 20.0),
                    supportedSafetyRange: IntRange(1, 6),
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux-pro/kontext",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux-pro/kontext",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_PRO_KONTEXT_MAX,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX Kontext [max]",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    supportedGuidanceRange: DoubleRange(1.0, 20.0),
                    supportedSafetyRange: IntRange(1, 6),
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux-pro/kontext/max",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux-pro/kontext/max",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_PRO_KONTEXT_T2I,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX Kontext [pro] T2I",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    supportedDimensions: ["1024x1024", "1920x1080", "1440x1080", "1080x1920", "1080x1440"],
                    supportedGuidanceRange: DoubleRange(1.0, 20.0),
                    supportedSafetyRange: IntRange(1, 6),
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux-pro/kontext/text-to-image",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux-pro/kontext/text-to-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_FLUX_PRO_KONTEXT_MAX_T2I,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "FLUX Kontext [max] T2I",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    supportedDimensions: ["1024x1024", "1920x1080", "1440x1080", "1080x1920", "1080x1440"],
                    supportedGuidanceRange: DoubleRange(1.0, 20.0),
                    supportedSafetyRange: IntRange(1, 6),
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2024-12-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/flux-pro/kontext/max/text-to-image",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/flux-pro/kontext/max/text-to-image",
                active: true
            ),
        ]
    }

    // MARK: - Bria Models

    private static func createBriaModels() -> [ProviderModelData] {
        [
            // MARK: Bria Fibo Edit Models

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BRIA_FIBO_EDIT_REPLACE_OBJECT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Fibo Edit - Replace Object",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/bria/fibo-edit/replace_object_by_text",
                modelAPIDocumentationURL: "https://fal.ai/models/bria/fibo-edit/replace_object_by_text",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BRIA_FIBO_EDIT_SKETCH_TO_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Fibo Edit - Sketch to Image",
                modelDescription: "Create visual variations from source images.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    supportsPrompt: false,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/bria/fibo-edit/sketch_to_colored_image",
                modelAPIDocumentationURL: "https://fal.ai/models/bria/fibo-edit/sketch_to_colored_image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BRIA_FIBO_EDIT_RESTORE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Fibo Edit - Restore",
                modelDescription: "Create visual variations from source images.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    supportsPrompt: false,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/bria/fibo-edit/restore",
                modelAPIDocumentationURL: "https://fal.ai/models/bria/fibo-edit/restore",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BRIA_FIBO_EDIT_RESEASON,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Fibo Edit - Reseason",
                modelDescription: "Create visual variations from source images.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    supportedStyles: ["spring", "summer", "autumn", "winter"],
                    supportsPrompt: false,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/bria/fibo-edit/reseason",
                modelAPIDocumentationURL: "https://fal.ai/models/bria/fibo-edit/reseason",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BRIA_FIBO_EDIT_RELIGHT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Fibo Edit - Relight",
                modelDescription: "Create visual variations from source images.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    supportedStyles: [
                        "midday", "blue hour light", "low-angle sunlight", "sunrise light",
                        "spotlight on subject", "overcast light", "soft overcast daylight lighting",
                        "cloud-filtered lighting", "fog-diffused lighting", "moonlight lighting",
                        "starlight nighttime", "soft bokeh lighting", "harsh studio lighting",
                    ],
                    supportedVariants: ["front", "side", "bottom", "top-down"],
                    supportsPrompt: false,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/bria/fibo-edit/relight",
                modelAPIDocumentationURL: "https://fal.ai/models/bria/fibo-edit/relight",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BRIA_FIBO_EDIT_RESTYLE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Fibo Edit - Restyle",
                modelDescription: "Create visual variations from source images.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    supportedStyles: [
                        "3D Render", "Cubism", "Oil Painting", "Anime", "Cartoon",
                        "Coloring Book", "Retro Ad", "Pop Art Halftone", "Vector Art",
                        "Story Board", "Art Nouveau", "Cross Etching", "Wood Cut",
                    ],
                    supportsPrompt: false,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/bria/fibo-edit/restyle",
                modelAPIDocumentationURL: "https://fal.ai/models/bria/fibo-edit/restyle",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BRIA_FIBO_EDIT_REWRITE_TEXT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Fibo Edit - Rewrite Text",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/bria/fibo-edit/rewrite_text",
                modelAPIDocumentationURL: "https://fal.ai/models/bria/fibo-edit/rewrite_text",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BRIA_FIBO_EDIT_ERASE_BY_TEXT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Fibo Edit - Erase by Text",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/bria/fibo-edit/erase_by_text",
                modelAPIDocumentationURL: "https://fal.ai/models/bria/fibo-edit/erase_by_text",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BRIA_FIBO_EDIT_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Fibo Edit",
                modelDescription: "Edit masked image areas with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedGuidanceRange: DoubleRange(1.0, 10.0),
                    supportedStepsRange: IntRange(20, 50),
                    supportsMask: true,
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/bria/fibo-edit/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/bria/fibo-edit/edit",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BRIA_FIBO_EDIT_ADD_OBJECT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Fibo Edit - Add Object",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/bria/fibo-edit/add_object_by_text",
                modelAPIDocumentationURL: "https://fal.ai/models/bria/fibo-edit/add_object_by_text",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BRIA_FIBO_EDIT_BLEND,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Fibo Edit - Blend",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/bria/fibo-edit/blend",
                modelAPIDocumentationURL: "https://fal.ai/models/bria/fibo-edit/blend",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BRIA_FIBO_EDIT_COLORIZE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Fibo Edit - Colorize",
                modelDescription: "Create visual variations from source images.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    supportedStyles: ["contemporary color", "vivid color", "black and white colors", "sepia vintage"],
                    supportsPrompt: false,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/bria/fibo-edit/colorize",
                modelAPIDocumentationURL: "https://fal.ai/models/bria/fibo-edit/colorize",
                active: true
            ),

            // MARK: - Bria (Generate / Reimagine / Utility)

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BRIA_FIBO_GENERATE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Fibo [generate]",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    supportedDimensions: ["1:1", "2:3", "3:2", "3:4", "4:3", "4:5", "5:4", "9:16", "16:9"],
                    supportedGuidanceRange: DoubleRange(3.0, 5.0),
                    supportedStepsRange: IntRange(20, 50),
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/bria/fibo/generate",
                modelAPIDocumentationURL: "https://fal.ai/models/bria/fibo/generate",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BRIA_REIMAGINE_3_2,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Reimagine 3.2",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    supportedDimensions: ["1:1", "2:3", "3:2", "3:4", "4:3", "4:5", "5:4", "9:16", "16:9"],
                    supportedGuidanceRange: DoubleRange(1.0, 10.0),
                    supportedStepsRange: IntRange(20, 50),
                    supportsNegativePrompt: true,
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/bria/reimagine/3.2",
                modelAPIDocumentationURL: "https://fal.ai/models/bria/reimagine/3.2",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BRIA_REIMAGINE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Bria Reimagine",
                modelDescription: "Create images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedStepsRange: IntRange(20, 50),
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bria/reimagine",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bria/reimagine",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BRIA_BACKGROUND_REMOVE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Bria Background Remove (RMBG 2.0)",
                modelDescription: "Create visual variations from source images.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    supportsPrompt: false,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bria/background/remove",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bria/background/remove",
                active: true
            ),
        ]
    }

    // MARK: - Luma Photon Models

    private static func createLumaPhotonModels() -> [ProviderModelData] {
        [
            // MARK: Luma Photon (Text-to-Image)

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_LUMA_PHOTON,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Luma Photon",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4", "21:9", "9:21"]
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/luma-photon",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/luma-photon",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_LUMA_PHOTON_FLASH,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Luma Photon Flash",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4", "21:9", "9:21"]
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/luma-photon/flash",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/luma-photon/flash",
                active: true
            ),

            // MARK: - Luma Photon (Image-to-Image / Modify)

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_LUMA_PHOTON_MODIFY,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Luma Photon Modify",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4", "21:9", "9:21"],
                    supportedGuidanceRange: DoubleRange(0.0, 10.0),
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/luma-photon/modify",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/luma-photon/modify",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_LUMA_PHOTON_FLASH_MODIFY,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Luma Photon Flash Modify",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4", "21:9", "9:21"],
                    supportedGuidanceRange: DoubleRange(0.0, 10.0),
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/luma-photon/flash/modify",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/luma-photon/flash/modify",
                active: true
            ),

            // MARK: - Luma Photon (Reframe / Outpainting)

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_LUMA_PHOTON_REFRAME,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Luma Photon Reframe",
                modelDescription: "Extend images beyond their original frame.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4", "21:9", "9:21"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/luma-photon/reframe",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/luma-photon/reframe",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_LUMA_PHOTON_FLASH_REFRAME,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Luma Photon Flash Reframe",
                modelDescription: "Extend images beyond their original frame.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4", "21:9", "9:21"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/luma-photon/flash/reframe",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/luma-photon/flash/reframe",
                active: true
            ),
        ]
    }

    // MARK: - GLM & Qwen Models

    private static func createGLMQwenModels() -> [ProviderModelData] {
        [
            // MARK: GLM Image

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GLM_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "GLM Image",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportedGuidanceRange: DoubleRange(1.0, 10.0),
                    supportedStepsRange: IntRange(10, 100),
                    supportsPromptEnhance: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/glm-image",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/glm-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GLM_IMAGE_TO_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "GLM Image-to-Image",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportedGuidanceRange: DoubleRange(1.0, 10.0),
                    supportedStepsRange: IntRange(10, 100),
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/glm-image/image-to-image",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/glm-image/image-to-image",
                active: true
            ),

            // MARK: - Qwen Image

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_QWEN_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Qwen Image",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportedGuidanceRange: DoubleRange(0.0, 20.0),
                    supportedStepsRange: IntRange(2, 250),
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/qwen-image",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/qwen-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_QWEN_IMAGE_2512,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Qwen Image 2512",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportedGuidanceRange: DoubleRange(0.0, 20.0),
                    supportedStepsRange: IntRange(1, 50),
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/qwen-image-2512",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/qwen-image-2512",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_QWEN_IMAGE_TO_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Qwen Image-to-Image",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportedGuidanceRange: DoubleRange(0.0, 20.0),
                    supportedStepsRange: IntRange(2, 250),
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/qwen-image/image-to-image",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/qwen-image/image-to-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_QWEN_IMAGE_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Qwen Image Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportedGuidanceRange: DoubleRange(0.0, 20.0),
                    supportedStepsRange: IntRange(2, 50),
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/qwen-image-edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/qwen-image-edit",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_QWEN_IMAGE_EDIT_PLUS,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Qwen Image Edit Plus",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportedGuidanceRange: DoubleRange(0.0, 20.0),
                    supportedStepsRange: IntRange(2, 100),
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/qwen-image-edit-plus",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/qwen-image-edit-plus",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_QWEN_IMAGE_EDIT_IMAGE_TO_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Qwen Image Edit (I2I)",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportedGuidanceRange: DoubleRange(0.0, 20.0),
                    supportedStepsRange: IntRange(2, 50),
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/qwen-image-edit/image-to-image",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/qwen-image-edit/image-to-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_QWEN_IMAGE_EDIT_INPAINT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Qwen Image Edit Inpaint",
                modelDescription: "Edit masked image areas with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportedGuidanceRange: DoubleRange(0.0, 20.0),
                    supportedStepsRange: IntRange(2, 50),
                    supportsMask: true,
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/qwen-image-edit/inpaint",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/qwen-image-edit/inpaint",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_QWEN_IMAGE_LAYERED,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Qwen Image Layered",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 10000,
                    supportedGuidanceRange: DoubleRange(1.0, 20.0),
                    supportedStepsRange: IntRange(1, 50),
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/qwen-image-layered",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/qwen-image-layered",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_QWEN_IMAGE_EDIT_2511,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Qwen Image Edit 2511",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportedGuidanceRange: DoubleRange(1.0, 20.0),
                    supportedStepsRange: IntRange(1, 50),
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/qwen-image-edit-2511",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/qwen-image-edit-2511",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_QWEN_IMAGE_EDIT_2511_MULTIPLE_ANGLES,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Qwen Image Edit 2511 Multi-Angles",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportedGuidanceRange: DoubleRange(1.0, 20.0),
                    supportedStepsRange: IntRange(1, 50),
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/qwen-image-edit-2511-multiple-angles",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/qwen-image-edit-2511-multiple-angles",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_QWEN_IMAGE_EDIT_2509,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Qwen Image Edit 2509",
                modelDescription: "Create images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportedGuidanceRange: DoubleRange(0.0, 20.0),
                    supportedStepsRange: IntRange(2, 100),
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/qwen-image-edit-2509",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/qwen-image-edit-2509",
                active: true
            ),

            // MARK: - WAN v2.6

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_WAN_V26_TEXT_TO_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "WAN v2.6 Text-to-Image",
                modelDescription: "Create images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 5,
                    maxPromptLength: 4096,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "portrait_9_16",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/wan/v2.6/text-to-image",
                modelAPIDocumentationURL: "https://fal.ai/models/wan/v2.6/text-to-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_WAN_V26_IMAGE_TO_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "WAN v2.6 Image-to-Image",
                modelDescription: "Create images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4096,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "portrait_9_16",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportsNegativePrompt: true,
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/wan/v2.6/image-to-image",
                modelAPIDocumentationURL: "https://fal.ai/models/wan/v2.6/image-to-image",
                active: true
            ),
        ]
    }

    // MARK: - ByteDance Models

    private static func createByteDanceModels() -> [ProviderModelData] {
        [
            // MARK: ByteDance Seedream

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BYTEDANCE_SEEDREAM_V45_TEXT_TO_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Seedream 4.5",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 6,
                    maxPromptLength: 4000,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bytedance/seedream/v4.5/text-to-image",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bytedance/seedream/v4.5/text-to-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BYTEDANCE_SEEDREAM_V45_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Seedream 4.5 Edit",
                modelDescription: "Create images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 6,
                    maxPromptLength: 4000,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bytedance/seedream/v4.5/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bytedance/seedream/v4.5/edit",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BYTEDANCE_SEEDREAM_V4_TEXT_TO_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Seedream 4.0",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 6,
                    maxPromptLength: 4000,
                    supportsPromptEnhance: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bytedance/seedream/v4/text-to-image",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bytedance/seedream/v4/text-to-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BYTEDANCE_SEEDREAM_V4_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Seedream 4.0 Edit",
                modelDescription: "Create images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 6,
                    maxPromptLength: 4000,
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bytedance/seedream/v4/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bytedance/seedream/v4/edit",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BYTEDANCE_SEEDREAM_V3_TEXT_TO_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Seedream 3.0",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedGuidanceRange: DoubleRange(1.0, 10.0),
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bytedance/seedream/v3/text-to-image",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bytedance/seedream/v3/text-to-image",
                active: true
            ),

            // MARK: - ByteDance Dreamina

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BYTEDANCE_DREAMINA_V31_TEXT_TO_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Dreamina 3.1",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportsPromptEnhance: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bytedance/dreamina/v3.1/text-to-image",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bytedance/dreamina/v3.1/text-to-image",
                active: true
            ),

            // MARK: - ByteDance Bagel

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BYTEDANCE_BAGEL,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Bagel",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 10000,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bagel",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bagel",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BYTEDANCE_BAGEL_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Bagel Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 10000,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bagel/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bagel/edit",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BYTEDANCE_SEEDREAM_V5_PRO_TEXT_TO_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Seedream 5.0 Pro",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 6,
                    maxPromptLength: 4000,
                    supportedImageResolutions: ["1K", "2K"]
                ),
                modelLaunchDate: getDateFromString("2026-07-09"),
                modelGenerateBaseURL: "https://fal.run/bytedance/seedream/v5/pro/text-to-image",
                modelAPIDocumentationURL: "https://fal.ai/models/bytedance/seedream/v5/pro/text-to-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BYTEDANCE_SEEDREAM_V5_PRO_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Seedream 5.0 Pro Edit",
                modelDescription: "Create images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 6,
                    maxPromptLength: 4000,
                    maxReferenceImages: 10,
                    supportedImageResolutions: ["1K", "2K"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-07-09"),
                modelGenerateBaseURL: "https://fal.run/bytedance/seedream/v5/pro/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/bytedance/seedream/v5/pro/edit",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BYTEDANCE_SEEDREAM_V5_LITE_TEXT_TO_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Seedream 5.0 Lite",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 6,
                    maxPromptLength: 10000,
                    supportedImageResolutions: ["2K", "3K", "4K"]
                ),
                modelLaunchDate: getDateFromString("2026-07-08"),
                modelGenerateBaseURL: "https://fal.run/bytedance/seedream/v5/lite/text-to-image",
                modelAPIDocumentationURL: "https://fal.ai/models/bytedance/seedream/v5/lite/text-to-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BYTEDANCE_SEEDREAM_V5_LITE_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Seedream 5.0 Lite Edit",
                modelDescription: "Create images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 6,
                    maxPromptLength: 10000,
                    maxReferenceImages: 10,
                    supportedImageResolutions: ["2K", "3K", "4K"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-07-08"),
                modelGenerateBaseURL: "https://fal.run/bytedance/seedream/v5/lite/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/bytedance/seedream/v5/lite/edit",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BYTEDANCE_BERNINI_R_EDIT_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Bernini-R Edit Image",
                modelDescription: "Edit source images while preserving their composition.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 5000,
                    supportedStepsRange: IntRange(1, 50),
                    supportsNegativePrompt: true,
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-06-09"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bernini-r/edit-image",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bernini-r/edit-image",
                active: true
            ),
        ]
    }

    // MARK: - Kling Image Models

    private static func createKlingImageModels() -> [ProviderModelData] {
        [
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_IMAGE_O1,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Kling O1 Image",
                modelDescription: "Create images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 9,
                    maxPromptLength: 4096,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4", "3:2", "2:3", "21:9"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-image/o1",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-image/o1",
                active: true
            ),
        ]
    }

    // MARK: - OpenAI GPT Image Models

    private static func createOpenAIGPTImageModels() -> [ProviderModelData] {
        [
            // MARK: OpenAI GPT Image (via Fal)

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GPT_IMAGE_1_MINI,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "GPT Image 1 Mini",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: ["1024x1024", "1536x1024", "1024x1536"]
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/gpt-image-1-mini",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/gpt-image-1-mini",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GPT_IMAGE_1_MINI_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "GPT Image 1 Mini Edit",
                modelDescription: "Create images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: ["1024x1024", "1536x1024", "1024x1536"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/gpt-image-1-mini/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/gpt-image-1-mini/edit",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GPT_IMAGE_1,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "GPT Image 1",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: ["1024x1024", "1536x1024", "1024x1536"]
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/gpt-image-1/text-to-image",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/gpt-image-1/text-to-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GPT_IMAGE_1_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "GPT Image 1 Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: ["1024x1024", "1536x1024", "1024x1536"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/gpt-image-1/edit-image",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/gpt-image-1/edit-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GPT_IMAGE_15,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "GPT Image 1.5",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: ["1024x1024", "1536x1024", "1024x1536"]
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/gpt-image-1.5",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/gpt-image-1.5",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GPT_IMAGE_15_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "GPT Image 1.5 Edit",
                modelDescription: "Edit masked image areas with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: ["1024x1024", "1536x1024", "1024x1536"],
                    supportsMask: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/gpt-image-1.5/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/gpt-image-1.5/edit",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GPT_IMAGE_2,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "GPT Image 2",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: ["1024x1024", "1536x1024", "1024x1536"],
                    supportedImageQualities: ["low", "medium", "high", "auto"]
                ),
                modelLaunchDate: getDateFromString("2026-04-21"),
                modelGenerateBaseURL: "https://fal.run/openai/gpt-image-2",
                modelAPIDocumentationURL: "https://fal.ai/models/openai/gpt-image-2",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GPT_IMAGE_2_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "GPT Image 2 Edit",
                modelDescription: "Edit masked image areas with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: ["1024x1024", "1536x1024", "1024x1536"],
                    supportedImageQualities: ["low", "medium", "high", "auto"],
                    supportsMask: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-04-21"),
                modelGenerateBaseURL: "https://fal.run/openai/gpt-image-2/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/openai/gpt-image-2/edit",
                active: true
            ),
        ]
    }

    // MARK: - Google Image Models

    private static func createGoogleImageModels() -> [ProviderModelData] {
        [
            // MARK: Z-Image Turbo

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_ZIMAGE_TURBO,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Z-Image Turbo",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: [
                        "square_hd",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportedStepsRange: IntRange(1, 8),
                    supportsPromptEnhance: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/z-image/turbo",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/z-image/turbo",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_ZIMAGE_TURBO_IMAGE_TO_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Z-Image Turbo Image-to-Image",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedGuidanceRange: DoubleRange(0.0, 10.0),
                    supportedStepsRange: IntRange(1, 8),
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/z-image/turbo/image-to-image",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/z-image/turbo/image-to-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_ZIMAGE_TURBO_INPAINT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Z-Image Turbo Inpaint",
                modelDescription: "Edit masked image areas with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedStepsRange: IntRange(1, 8),
                    supportsMask: true,
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/z-image/turbo/inpaint",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/z-image/turbo/inpaint",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_ZIMAGE_TURBO_INPAINT_LORA,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Z-Image Turbo Inpaint LoRA",
                modelDescription: "Edit masked image areas with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedStepsRange: IntRange(1, 8),
                    supportsMask: true,
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/z-image/turbo/inpaint/lora",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/z-image/turbo/inpaint/lora",
                active: true
            ),

            // MARK: - Google Gemini 3 Pro Image

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GOOGLE_GEMINI_3_PRO_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Gemini 3 Pro Image",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4", "3:2", "2:3", "5:4", "4:5", "21:9"],
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/gemini-3-pro-image-preview",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/gemini-3-pro-image-preview",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GOOGLE_GEMINI_3_PRO_IMAGE_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Gemini 3 Pro Image Edit",
                modelDescription: "Create images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4", "3:2", "2:3", "5:4", "4:5", "21:9"],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/gemini-3-pro-image-preview/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/gemini-3-pro-image-preview/edit",
                active: true
            ),

            // MARK: - Google Nano Banana Pro

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GOOGLE_NANO_BANANA_PRO,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Nano Banana Pro",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4", "3:2", "2:3", "5:4", "4:5", "21:9"],
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/nano-banana-pro",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/nano-banana-pro",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GOOGLE_NANO_BANANA_PRO_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Nano Banana Pro Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4", "3:2", "2:3", "5:4", "4:5", "21:9"],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/nano-banana-pro/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/nano-banana-pro/edit",
                active: true
            ),

            // MARK: - Google Gemini 2.5 Flash Image

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GOOGLE_GEMINI_25_FLASH_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Gemini 2.5 Flash Image",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4", "3:2", "2:3", "5:4", "4:5", "21:9"]
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/gemini-25-flash-image",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/gemini-25-flash-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GOOGLE_GEMINI_25_FLASH_IMAGE_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Gemini 2.5 Flash Image Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4", "3:2", "2:3", "5:4", "4:5", "21:9"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/gemini-25-flash-image/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/gemini-25-flash-image/edit",
                active: true
            ),

            // MARK: - Google Nano Banana

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GOOGLE_NANO_BANANA,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Nano Banana",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4", "3:2", "2:3", "5:4", "4:5", "21:9"]
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/nano-banana",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/nano-banana",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GOOGLE_NANO_BANANA_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Nano Banana Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4", "3:2", "2:3", "5:4", "4:5", "21:9"],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/nano-banana/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/nano-banana/edit",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GOOGLE_NANO_BANANA_2,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Nano Banana 2",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: [
                        "1:1",
                        "16:9",
                        "9:16",
                        "4:3",
                        "3:4",
                        "3:2",
                        "2:3",
                        "5:4",
                        "4:5",
                        "21:9",
                        "4:1",
                        "1:4",
                        "8:1",
                        "1:8",
                    ],
                    supportedImageResolutions: ["0.5K", "1K", "2K", "4K"],
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/nano-banana-2",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/nano-banana-2",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GOOGLE_NANO_BANANA_2_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Nano Banana 2 Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: [
                        "1:1",
                        "16:9",
                        "9:16",
                        "4:3",
                        "3:4",
                        "3:2",
                        "2:3",
                        "5:4",
                        "4:5",
                        "21:9",
                        "4:1",
                        "1:4",
                        "8:1",
                        "1:8",
                    ],
                    supportedImageResolutions: ["0.5K", "1K", "2K", "4K"],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/nano-banana-2/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/nano-banana-2/edit",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GOOGLE_NANO_BANANA_LITE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Nano Banana Lite",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 5000,
                    supportedDimensions: [
                        "1:1",
                        "16:9",
                        "9:16",
                        "4:3",
                        "3:4",
                        "3:2",
                        "2:3",
                        "5:4",
                        "4:5",
                        "21:9",
                        "4:1",
                        "1:4",
                        "8:1",
                        "1:8",
                    ],
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/google/nano-banana-lite",
                modelAPIDocumentationURL: "https://fal.ai/models/google/nano-banana-lite",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GOOGLE_NANO_BANANA_LITE_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Nano Banana Lite Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 5000,
                    supportedDimensions: [
                        "1:1",
                        "16:9",
                        "9:16",
                        "4:3",
                        "3:4",
                        "3:2",
                        "2:3",
                        "5:4",
                        "4:5",
                        "21:9",
                        "4:1",
                        "1:4",
                        "8:1",
                        "1:8",
                    ],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/google/nano-banana-lite/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/google/nano-banana-lite/edit",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GOOGLE_NANO_BANANA_2_LITE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Nano Banana 2 Lite",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 5000,
                    supportedDimensions: [
                        "1:1",
                        "16:9",
                        "9:16",
                        "4:3",
                        "3:4",
                        "3:2",
                        "2:3",
                        "5:4",
                        "4:5",
                        "21:9",
                        "4:1",
                        "1:4",
                        "8:1",
                        "1:8",
                    ],
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/google/nano-banana-2-lite",
                modelAPIDocumentationURL: "https://fal.ai/models/google/nano-banana-2-lite",
                active: true
            ),

            // MARK: - Google Imagen 4

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GOOGLE_IMAGEN4_PREVIEW,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Imagen 4",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4"]
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/imagen4/preview",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/imagen4/preview",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GOOGLE_IMAGEN4_PREVIEW_FAST,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Imagen 4 Fast",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4"]
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/imagen4/preview/fast",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/imagen4/preview/fast",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GOOGLE_IMAGEN4_PREVIEW_ULTRA,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Imagen 4 Ultra",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 10000,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4"]
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/imagen4/preview/ultra",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/imagen4/preview/ultra",
                active: true
            ),

            // MARK: - Half Moon AI Home

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_HALFMOON_AI_HOME_STYLE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "AI Home Style",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/half-moon-ai/ai-home/style",
                modelAPIDocumentationURL: "https://fal.ai/models/half-moon-ai/ai-home/style",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_HALFMOON_AI_HOME_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "AI Home Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/half-moon-ai/ai-home/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/half-moon-ai/ai-home/edit",
                active: true
            ),
        ]
    }

    // MARK: - Misc Image Models

    private static func createMiscImageModels() -> [ProviderModelData] {
        [
            // MARK: Krea 2

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KREA_2_TURBO,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Krea 2 Turbo",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 5000,
                    supportedDimensions: ["1024x1024", "1920x1080", "1440x1080", "1080x1920", "1080x1440"],
                    supportsPromptEnhance: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/krea-2/turbo",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/krea-2/turbo",
                active: true
            ),

            // MARK: Ideogram

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_IDEOGRAM_V4,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Ideogram V4",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 5000,
                    supportedDimensions: ["1024x1024", "1920x1080", "1440x1080", "1080x1920", "1080x1440"],
                    supportsPromptEnhance: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-06-03"),
                modelGenerateBaseURL: "https://fal.run/ideogram/v4",
                modelAPIDocumentationURL: "https://fal.ai/models/ideogram/v4",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_IDEOGRAM_V4_FAST,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Ideogram V4 Fast",
                modelDescription: "Generate typography-rich images with a fast sampler.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 5000,
                    supportedDimensions: ["1024x1024", "1920x1080", "1440x1080", "1080x1920", "1080x1440"],
                    supportsPromptEnhance: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-07-06"),
                modelGenerateBaseURL: "https://fal.run/ideogram/v4/fast",
                modelAPIDocumentationURL: "https://fal.ai/models/ideogram/v4/fast",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_IDEOGRAM_V4_INSTANT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Ideogram V4 Instant",
                modelDescription: "Generate typography-rich images with an instant sampler.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 5000,
                    supportedDimensions: ["1024x1024", "1920x1080", "1440x1080", "1080x1920", "1080x1440"],
                    supportsPromptEnhance: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-07-06"),
                modelGenerateBaseURL: "https://fal.run/ideogram/v4/instant",
                modelAPIDocumentationURL: "https://fal.ai/models/ideogram/v4/instant",
                active: true
            ),

            // MARK: Recraft V3

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_RECRAFT_V3,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Recraft V3",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 5000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ]
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/recraft/v3/text-to-image",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/recraft/v3/text-to-image",
                active: true
            ),
        ]
    }

    // MARK: - Google Veo Video Models

    private static func createVeoVideoModels() -> [ProviderModelData] {
        [
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_VEO_3_FAST,
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
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/veo3/fast",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/veo3/fast",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_VEO_3,
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
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/veo3",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/veo3",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_VEO_3_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Veo 3 Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [4, 6, 8],
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsAudio: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/veo3/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/veo3/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_VEO_3_FAST_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Veo 3 Fast Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [4, 6, 8],
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsAudio: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/veo3/fast/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/veo3/fast/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_VEO_31_FAST,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Veo 3.1 Fast",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [4, 6, 8],
                    supportedVideoResolutions: ["720p", "1080p", "4k"],
                    supportsAudio: true,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/veo3.1/fast",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/veo3.1/fast",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_VEO_31,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Veo 3.1",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [4, 6, 8],
                    supportedVideoResolutions: ["720p", "1080p", "4k"],
                    supportsAudio: true,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/veo3.1",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/veo3.1",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_VEO_31_LITE,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Veo 3.1 Lite",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 20000,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [4, 6, 8],
                    supportedSafetyRange: IntRange(1, 6),
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsAudio: true,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/veo3.1/lite",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/veo3.1/lite",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_VEO_31_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Veo 3.1 Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [4, 6, 8],
                    supportedVideoResolutions: ["720p", "1080p", "4k"],
                    supportsAudio: true,
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/veo3.1/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/veo3.1/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_VEO_31_FAST_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Veo 3.1 Fast Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [4, 6, 8],
                    supportedVideoResolutions: ["720p", "1080p", "4k"],
                    supportsAudio: true,
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/veo3.1/fast/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/veo3.1/fast/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_VEO_31_LITE_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Veo 3.1 Lite Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 20000,
                    supportedDimensions: ["auto", "16:9", "9:16"],
                    supportedVideoDurations: [4, 6, 8],
                    supportedSafetyRange: IntRange(1, 6),
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsAudio: true,
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/veo3.1/lite/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/veo3.1/lite/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_VEO_31_REF_TO_VIDEO,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Veo 3.1 Reference-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    maxReferenceImages: 5,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [8],
                    supportedVideoResolutions: ["720p", "1080p", "4k"],
                    supportsAudio: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/veo3.1/reference-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/veo3.1/reference-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_VEO_31_FIRST_LAST_FRAME,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Veo 3.1 First-Last Frame",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [4, 6, 8],
                    supportedVideoResolutions: ["720p", "1080p", "4k"],
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/veo3.1/first-last-frame-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/veo3.1/first-last-frame-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_VEO_31_FAST_FIRST_LAST_FRAME,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Veo 3.1 Fast First-Last Frame",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [4, 6, 8],
                    supportedVideoResolutions: ["720p", "1080p", "4k"],
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/veo3.1/fast/first-last-frame-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/veo3.1/fast/first-last-frame-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_VEO_31_LITE_FIRST_LAST_FRAME,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Veo 3.1 Lite First-Last Frame",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 20000,
                    supportedDimensions: ["auto", "16:9", "9:16"],
                    supportedVideoDurations: [8],
                    supportedSafetyRange: IntRange(1, 6),
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/veo3.1/lite/first-last-frame-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/veo3.1/lite/first-last-frame-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_VEO_31_EXTEND,
                modelSetType: EnumSetType.VIDEO_EXTEND,
                modelName: "Veo 3.1",
                modelDescription: "Extend existing clips with continued motion.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 20000,
                    supportedDimensions: ["auto", "16:9", "9:16"],
                    supportedVideoDurations: [7],
                    supportedSafetyRange: IntRange(1, 6),
                    supportedVideoResolutions: ["720p"],
                    supportsAudio: true,
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsVideoUpload: true
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/veo3.1/extend-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/veo3.1/extend-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_VEO_31_FAST_EXTEND,
                modelSetType: EnumSetType.VIDEO_EXTEND,
                modelName: "Veo 3.1 Fast",
                modelDescription: "Extend existing clips with continued motion.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 20000,
                    supportedDimensions: ["auto", "16:9", "9:16"],
                    supportedVideoDurations: [7],
                    supportedSafetyRange: IntRange(1, 6),
                    supportedVideoResolutions: ["720p"],
                    supportsAudio: true,
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsVideoUpload: true
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/veo3.1/fast/extend-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/veo3.1/fast/extend-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_VEO_2,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Veo 2",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [5, 6, 7, 8],
                    supportedVideoResolutions: ["720p"],
                    supportsAudio: false,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/veo2",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/veo2",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_VEO_2_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Veo 2 Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [5, 6, 7, 8],
                    supportedVideoResolutions: ["720p"],
                    supportsAudio: false,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/veo2/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/veo2/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_VEO_31_FAST_REF_TO_VIDEO,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Veo 3.1 Fast Ref-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [8],
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsAudio: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/veo3.1/fast/reference-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/veo3.1/fast/reference-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GOOGLE_GEMINI_OMNI_FLASH_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Gemini Omni Flash Text-to-Video",
                modelDescription: "Generate videos with synchronized sound from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 20000,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [3, 4, 5, 6, 7, 8, 9, 10]
                ),
                modelLaunchDate: getDateFromString("2026-06-30"),
                modelGenerateBaseURL: "https://fal.run/google/gemini-omni-flash",
                modelAPIDocumentationURL: "https://fal.ai/models/google/gemini-omni-flash",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GOOGLE_GEMINI_OMNI_FLASH_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Gemini Omni Flash Image-to-Video",
                modelDescription: "Animate still images into motion clips.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 20000,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [3, 4, 5, 6, 7, 8, 9, 10],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: "https://fal.run/google/gemini-omni-flash/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/google/gemini-omni-flash/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GOOGLE_GEMINI_OMNI_FLASH_REF2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Gemini Omni Flash Reference-to-Video",
                modelDescription: "Generate motion clips from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 20000,
                    maxReferenceImages: 10,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [3, 4, 5, 6, 7, 8, 9, 10]
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: "https://fal.run/google/gemini-omni-flash/reference-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/google/gemini-omni-flash/reference-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_GOOGLE_GEMINI_OMNI_FLASH_EDIT,
                modelSetType: EnumSetType.VIDEO_EXTEND,
                modelName: "Gemini Omni Flash Video Edit",
                modelDescription: "Transform uploaded videos using natural language instructions.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 20000,
                    supportsVideoUpload: true
                ),
                modelLaunchDate: getDateFromString("2026-06-30"),
                modelGenerateBaseURL: "https://fal.run/google/gemini-omni-flash/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/google/gemini-omni-flash/edit",
                active: true
            ),
        ]
    }

    // MARK: - ByteDance Seedance Video Models

    private static func createSeedanceVideoModels() -> [ProviderModelData] {
        [
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SEEDANCE_V1_PRO_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Seedance 1.0 Pro",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["21:9", "16:9", "4:3", "1:1", "3:4", "9:16"],
                    supportedVideoDurations: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
                    supportedVideoResolutions: ["480p", "720p", "1080p"],
                    supportsAudio: false,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bytedance/seedance/v1/pro/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bytedance/seedance/v1/pro/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SEEDANCE_V1_PRO_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Seedance 1.0 Pro Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["21:9", "16:9", "4:3", "1:1", "3:4", "9:16"],
                    supportedVideoDurations: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
                    supportedVideoResolutions: ["480p", "720p", "1080p"],
                    supportsAudio: false,
                    supportsLastFrame: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bytedance/seedance/v1/pro/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bytedance/seedance/v1/pro/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SEEDANCE_V1_PRO_FAST_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Seedance 1.0 Pro Fast",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["21:9", "16:9", "4:3", "1:1", "3:4", "9:16"],
                    supportedVideoDurations: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
                    supportedVideoResolutions: ["480p", "720p", "1080p"],
                    supportsAudio: false,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bytedance/seedance/v1/pro/fast/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bytedance/seedance/v1/pro/fast/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SEEDANCE_V1_PRO_FAST_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Seedance 1.0 Pro Fast Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["21:9", "16:9", "4:3", "1:1", "3:4", "9:16"],
                    supportedVideoDurations: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
                    supportedVideoResolutions: ["480p", "720p", "1080p"],
                    supportsAudio: false,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bytedance/seedance/v1/pro/fast/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bytedance/seedance/v1/pro/fast/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SEEDANCE_V1_LITE_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Seedance 1.0 Lite",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["21:9", "16:9", "4:3", "1:1", "3:4", "9:16", "9:21"],
                    supportedVideoDurations: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
                    supportedVideoResolutions: ["480p", "720p", "1080p"],
                    supportsAudio: false,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bytedance/seedance/v1/lite/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bytedance/seedance/v1/lite/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SEEDANCE_V1_LITE_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Seedance 1.0 Lite Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["21:9", "16:9", "4:3", "1:1", "3:4", "9:16"],
                    supportedVideoDurations: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
                    supportedVideoResolutions: ["480p", "720p", "1080p"],
                    supportsAudio: false,
                    supportsLastFrame: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bytedance/seedance/v1/lite/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bytedance/seedance/v1/lite/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SEEDANCE_V1_LITE_REF2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Seedance 1.0 Lite Reference-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    maxReferenceImages: 4,
                    supportedDimensions: ["21:9", "16:9", "4:3", "1:1", "3:4", "9:16"],
                    supportedVideoDurations: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
                    supportedVideoResolutions: ["480p", "720p"],
                    supportsAudio: false,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bytedance/seedance/v1/lite/reference-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bytedance/seedance/v1/lite/reference-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SEEDANCE_V15_PRO_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Seedance 1.5 Pro",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["21:9", "16:9", "4:3", "1:1", "3:4", "9:16"],
                    supportedVideoDurations: [4, 5, 6, 7, 8, 9, 10, 11, 12],
                    supportedVideoResolutions: ["480p", "720p", "1080p"],
                    supportsAudio: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bytedance/seedance/v1.5/pro/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bytedance/seedance/v1.5/pro/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SEEDANCE_V15_PRO_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Seedance 1.5 Pro Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["21:9", "16:9", "4:3", "1:1", "3:4", "9:16"],
                    supportedVideoDurations: [4, 5, 6, 7, 8, 9, 10, 11, 12],
                    supportedVideoResolutions: ["480p", "720p", "1080p"],
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bytedance/seedance/v1.5/pro/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bytedance/seedance/v1.5/pro/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SEEDANCE_V2_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Seedance 2",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["21:9", "16:9", "4:3", "1:1", "3:4", "9:16"],
                    supportedVideoDurations: [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
                    supportedVideoResolutions: ["480p", "720p", "1080p"],
                    supportsAudio: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/bytedance/seedance-2.0/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/bytedance/seedance-2.0/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SEEDANCE_V2_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Seedance 2 Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["21:9", "16:9", "4:3", "1:1", "3:4", "9:16"],
                    supportedVideoDurations: [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
                    supportedVideoResolutions: ["480p", "720p", "1080p"],
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/bytedance/seedance-2.0/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/bytedance/seedance-2.0/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SEEDANCE_V2_REF2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Seedance 2 Reference-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    maxReferenceImages: 4,
                    supportedDimensions: ["21:9", "16:9", "4:3", "1:1", "3:4", "9:16"],
                    supportedVideoDurations: [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
                    supportedVideoResolutions: ["480p", "720p", "1080p"],
                    supportsAudio: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/bytedance/seedance-2.0/reference-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/bytedance/seedance-2.0/reference-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SEEDANCE_V2_FAST_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Seedance 2 Fast",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["21:9", "16:9", "4:3", "1:1", "3:4", "9:16"],
                    supportedVideoDurations: [4, 5, 6, 7, 8],
                    supportedVideoResolutions: ["480p", "720p"],
                    supportsAudio: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/bytedance/seedance-2.0/fast/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/bytedance/seedance-2.0/fast/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SEEDANCE_V2_FAST_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Seedance 2 Fast Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["21:9", "16:9", "4:3", "1:1", "3:4", "9:16"],
                    supportedVideoDurations: [4, 5, 6, 7, 8],
                    supportedVideoResolutions: ["480p", "720p"],
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/bytedance/seedance-2.0/fast/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/bytedance/seedance-2.0/fast/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SEEDANCE_V2_FAST_REF2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Seedance 2 Fast Reference-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    maxReferenceImages: 4,
                    supportedDimensions: ["21:9", "16:9", "4:3", "1:1", "3:4", "9:16"],
                    supportedVideoDurations: [4, 5, 6, 7, 8],
                    supportedVideoResolutions: ["480p", "720p"],
                    supportsAudio: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/bytedance/seedance-2.0/fast/reference-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/bytedance/seedance-2.0/fast/reference-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SEEDANCE_V2_MINI_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Seedance 2 Mini",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["21:9", "16:9", "4:3", "1:1", "3:4", "9:16"],
                    supportedVideoDurations: [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
                    supportedVideoResolutions: ["480p", "720p"],
                    supportsAudio: true
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: "https://fal.run/bytedance/seedance-2.0/mini/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/bytedance/seedance-2.0/mini/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SEEDANCE_V2_MINI_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Seedance 2 Mini Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["21:9", "16:9", "4:3", "1:1", "3:4", "9:16"],
                    supportedVideoDurations: [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
                    supportedVideoResolutions: ["480p", "720p"],
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: "https://fal.run/bytedance/seedance-2.0/mini/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/bytedance/seedance-2.0/mini/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SEEDANCE_V2_MINI_REF2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Seedance 2 Mini Reference-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    maxReferenceImages: 9,
                    supportedDimensions: ["21:9", "16:9", "4:3", "1:1", "3:4", "9:16"],
                    supportedVideoDurations: [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
                    supportedVideoResolutions: ["480p", "720p"],
                    supportsAudio: true
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: "https://fal.run/bytedance/seedance-2.0/mini/reference-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/bytedance/seedance-2.0/mini/reference-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_LYNX,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Lynx",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedGuidanceRange: DoubleRange(1.0, 20.0),
                    supportedStepsRange: IntRange(1, 75),
                    supportedVideoResolutions: ["480p", "580p", "720p"],
                    supportsAudio: false,
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/bytedance/lynx",
                modelAPIDocumentationURL: "https://fal.ai/models/bytedance/lynx",
                active: true
            ),
        ]
    }

    // MARK: - Catalog Refresh Video Models

    private static func createCatalogRefreshVideoModels() -> [ProviderModelData] {
        [
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BYTEDANCE_BERNINI_R_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Bernini-R Text-to-Video",
                modelDescription: "Generate coherent videos from detailed written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 5000,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: [3, 4, 5, 6, 7],
                    supportedVideoFPS: [16],
                    supportedStepsRange: IntRange(1, 50),
                    supportedVideoResolutions: ["576p", "848p", "1280p"],
                    supportsNegativePrompt: true,
                    supportsPromptEnhance: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-06-09"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bernini-r/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bernini-r/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BYTEDANCE_BERNINI_R_REF2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Bernini-R Reference-to-Video",
                modelDescription: "Create coherent videos from multiple visual references.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 5000,
                    maxReferenceImages: 5,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: [3, 4, 5, 6, 7],
                    supportedVideoFPS: [16],
                    supportedStepsRange: IntRange(1, 50),
                    supportedVideoResolutions: ["576p", "848p", "1280p"],
                    supportsNegativePrompt: true,
                    supportsPromptEnhance: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-06-09"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bernini-r/reference-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bernini-r/reference-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BYTEDANCE_BERNINI_R_EDIT_VIDEO,
                modelSetType: EnumSetType.VIDEO_EXTEND,
                modelName: "Bernini-R Edit Video",
                modelDescription: "Transform existing videos while preserving their original motion.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 5000,
                    supportedVideoDurations: [3, 4, 5, 6, 7],
                    supportedVideoFPS: [16],
                    supportedStepsRange: IntRange(1, 50),
                    supportedVideoResolutions: ["576p", "848p", "1280p"],
                    supportsNegativePrompt: true,
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsVideoUpload: true
                ),
                modelLaunchDate: getDateFromString("2026-06-09"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bernini-r/edit-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bernini-r/edit-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BYTEDANCE_BERNINI_R_REFERENCE_EDIT_VIDEO,
                modelSetType: EnumSetType.VIDEO_EXTEND,
                modelName: "Bernini-R Reference Edit Video",
                modelDescription: "Guide precise video edits with visual references.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 5000,
                    maxReferenceImages: 5,
                    supportedVideoDurations: [3, 4, 5, 6, 7],
                    supportedVideoFPS: [16],
                    supportedStepsRange: IntRange(1, 50),
                    supportedVideoResolutions: ["576p", "848p", "1280p"],
                    supportsNegativePrompt: true,
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsVideoUpload: true
                ),
                modelLaunchDate: getDateFromString("2026-06-09"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bernini-r/reference-edit-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bernini-r/reference-edit-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BYTEDANCE_DREAMACTOR_V2,
                modelSetType: EnumSetType.VIDEO_EXTEND,
                modelName: "ByteDance DreamActor V2",
                modelDescription: "Animate characters using motion from a driving video.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxImageSizeBytes: 4_700_000,
                    maxPromptLength: 0,
                    supportedVideoDurations: [5, 10, 15, 20, 25, 30],
                    supportsPrompt: false,
                    supportsSourceImage: true,
                    supportsVideoUpload: true
                ),
                modelLaunchDate: getDateFromString("2026-02-06"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bytedance/dreamactor/v2",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bytedance/dreamactor/v2",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BYTEDANCE_VIDEO_UPSCALER,
                modelSetType: EnumSetType.VIDEO_EXTEND,
                modelName: "ByteDance Video Upscaler",
                modelDescription: "Enhance uploaded videos with restored detail and clarity.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 0,
                    supportedVideoFPS: [30],
                    supportedVideoResolutions: ["1080p", "2K", "4K"],
                    supportsPrompt: false,
                    supportsVideoUpload: true
                ),
                modelLaunchDate: getDateFromString("2025-10-31"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bytedance-upscaler/upscale/video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bytedance-upscaler/upscale/video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_BYTEDANCE_OMNIHUMAN_V15,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "ByteDance OmniHuman V1.5",
                modelDescription: "Animate human portraits from supplied speech audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 5000,
                    requiredMetadata: ["audio_url"],
                    supportedVideoDurations: [5, 10, 15, 20, 25, 30, 60],
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsMask: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-09-23"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/bytedance/omnihuman/v1.5",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/bytedance/omnihuman/v1.5",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_LTX_23_EXTEND,
                modelSetType: EnumSetType.VIDEO_EXTEND,
                modelName: "LTX 2.3 Video Extend",
                modelDescription: "Extend existing videos forward or backward seamlessly.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 5000,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: [3, 4, 5],
                    supportedVideoFPS: [24],
                    supportedVideoResolutions: ["480p", "720p", "1080p"],
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsNegativePrompt: true,
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsVideoUpload: true
                ),
                modelLaunchDate: getDateFromString("2026-07-07"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/ltx-2.3-quality/extend-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/ltx-2.3-quality/extend-video",
                active: true
            ),
        ]
    }

    // MARK: - Wan Video Models

    private static func createWanVideoModels() -> [ProviderModelData] {
        [
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_WAN_27_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Wan 2.7",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 5000,
                    supportedDimensions: ["16:9", "9:16", "1:1", "4:3", "3:4"],
                    supportedVideoDurations: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsAudio: false,
                    supportsNegativePrompt: true,
                    supportsPromptEnhance: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/wan/v2.7/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/wan/v2.7/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_WAN_27_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Wan 2.7 Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 5000,
                    supportedDimensions: ["16:9", "9:16", "1:1", "4:3", "3:4"],
                    supportedVideoDurations: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsAudio: false,
                    supportsLastFrame: true,
                    supportsNegativePrompt: true,
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/wan/v2.7/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/wan/v2.7/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_WAN_22_A14B_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Wan 2.2 A14B",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedGuidanceRange: DoubleRange(1.0, 10.0),
                    supportedStepsRange: IntRange(2, 40),
                    supportedVideoResolutions: ["480p", "580p", "720p"],
                    supportsAudio: false,
                    supportsNegativePrompt: true,
                    supportsPromptEnhance: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/wan/v2.2-a14b/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/wan/v2.2-a14b/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_WAN_22_A14B_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Wan 2.2 A14B Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedGuidanceRange: DoubleRange(1.0, 10.0),
                    supportedStepsRange: IntRange(2, 40),
                    supportedVideoResolutions: ["480p", "580p", "720p"],
                    supportsAudio: false,
                    supportsLastFrame: true,
                    supportsNegativePrompt: true,
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/wan/v2.2-a14b/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/wan/v2.2-a14b/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_WAN_22_A14B_TURBO_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Wan 2.2 Turbo",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoResolutions: ["480p", "580p", "720p"],
                    supportsAudio: false,
                    supportsPromptEnhance: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/wan/v2.2-a14b/text-to-video/turbo",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/wan/v2.2-a14b/text-to-video/turbo",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_WAN_22_A14B_TURBO_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Wan 2.2 Turbo Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoResolutions: ["480p", "580p", "720p"],
                    supportsAudio: false,
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/wan/v2.2-a14b/image-to-video/turbo",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/wan/v2.2-a14b/image-to-video/turbo",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_WAN_22_5B_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Wan 2.2 5B",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedGuidanceRange: DoubleRange(1.0, 10.0),
                    supportedStepsRange: IntRange(2, 40),
                    supportedVideoResolutions: ["480p", "580p", "720p"],
                    supportsAudio: false,
                    supportsNegativePrompt: true,
                    supportsPromptEnhance: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/wan/v2.2-5b/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/wan/v2.2-5b/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_WAN_22_5B_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Wan 2.2 5B Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedGuidanceRange: DoubleRange(1.0, 10.0),
                    supportedStepsRange: IntRange(2, 40),
                    supportedVideoResolutions: ["480p", "580p", "720p"],
                    supportsAudio: false,
                    supportsNegativePrompt: true,
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/wan/v2.2-5b/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/wan/v2.2-5b/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_WAN_21_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Wan 2.1",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedStepsRange: IntRange(2, 40),
                    supportedVideoResolutions: ["480p", "580p", "720p"],
                    supportsAudio: false,
                    supportsNegativePrompt: true,
                    supportsPromptEnhance: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/wan-t2v",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/wan-t2v",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_WAN_21_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Wan 2.1 Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedGuidanceRange: DoubleRange(1.0, 10.0),
                    supportedStepsRange: IntRange(2, 40),
                    supportedVideoResolutions: ["480p", "720p"],
                    supportsAudio: false,
                    supportsNegativePrompt: true,
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/wan-i2v",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/wan-i2v",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_WAN_21_FLF2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Wan 2.1 First-Last-Frame",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedGuidanceRange: DoubleRange(1.0, 10.0),
                    supportedStepsRange: IntRange(2, 40),
                    supportedVideoResolutions: ["480p", "720p"],
                    supportsAudio: false,
                    supportsLastFrame: true,
                    supportsNegativePrompt: true,
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/wan-flf2v",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/wan-flf2v",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_WAN_PRO_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Wan Pro",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoDurations: [6],
                    supportedVideoResolutions: ["1080p"],
                    supportsAudio: false,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/wan-pro/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/wan-pro/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_WAN_PRO_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Wan Pro Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoDurations: [6],
                    supportedVideoResolutions: ["1080p"],
                    supportsAudio: false,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/wan-pro/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/wan-pro/image-to-video",
                active: true
            ),

            // MARK: - Pika Video Models

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_PIKA_SCENES,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Pika Scenes",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    maxReferenceImages: 4,
                    supportsAudio: false,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/pika/v2.2/pikascenes",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/pika/v2.2/pikascenes",
                active: true
            ),
        ]
    }

    // MARK: - Kling Video Models

    private static func createKlingVideoModels() -> [ProviderModelData] {
        [
            // MARK: Kling v2.6 Pro Video Models

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V26_PRO_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 2.6 Pro",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: [5, 10],
                    supportedGuidanceRange: DoubleRange(0.0, 1.0),
                    supportsAudio: true,
                    supportsNegativePrompt: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v2.6/pro/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v2.6/pro/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V26_PRO_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 2.6 Pro Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoDurations: [5, 10],
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v2.6/pro/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v2.6/pro/image-to-video",
                active: true
            ),

            // MARK: - Kling v2.5 Turbo Video Models

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V25_TURBO_PRO_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 2.5 Turbo Pro",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: [5, 10],
                    supportedGuidanceRange: DoubleRange(0.0, 1.0),
                    supportsAudio: false,
                    supportsNegativePrompt: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v2.5-turbo/pro/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v2.5-turbo/pro/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V25_TURBO_PRO_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 2.5 Turbo Pro Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoDurations: [5, 10],
                    supportsAudio: false,
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v2.5-turbo/pro/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v2.5-turbo/pro/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V25_TURBO_STD_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 2.5 Turbo Standard Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoDurations: [5, 10],
                    supportsAudio: false,
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v2.5-turbo/standard/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v2.5-turbo/standard/image-to-video",
                active: true
            ),

            // MARK: - Kling v2.1 Video Models

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V21_MASTER_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 2.1 Master",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: [5, 10],
                    supportedGuidanceRange: DoubleRange(0.0, 1.0),
                    supportsAudio: false,
                    supportsNegativePrompt: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v2.1/master/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v2.1/master/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V21_MASTER_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 2.1 Master Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoDurations: [5, 10],
                    supportsAudio: false,
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v2.1/master/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v2.1/master/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V21_PRO_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 2.1 Pro Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoDurations: [5, 10],
                    supportsAudio: false,
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v2.1/pro/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v2.1/pro/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V21_STD_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 2.1 Standard Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoDurations: [5, 10],
                    supportsAudio: false,
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v2.1/standard/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v2.1/standard/image-to-video",
                active: true
            ),

            // MARK: - Kling v2.0 Video Models

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V20_MASTER_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 2.0 Master",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: [5, 10],
                    supportedGuidanceRange: DoubleRange(0.0, 1.0),
                    supportsAudio: false,
                    supportsNegativePrompt: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v2/master/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v2/master/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V20_MASTER_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 2.0 Master Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoDurations: [5, 10],
                    supportsAudio: false,
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v2/master/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v2/master/image-to-video",
                active: true
            ),

            // MARK: - Kling v1.6 Video Models

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V16_PRO_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 1.6 Pro",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: [5, 10],
                    supportedGuidanceRange: DoubleRange(0.0, 1.0),
                    supportsAudio: false,
                    supportsNegativePrompt: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v1.6/pro/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v1.6/pro/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V16_PRO_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 1.6 Pro Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoDurations: [5, 10],
                    supportsAudio: false,
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v1.6/pro/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v1.6/pro/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V16_STD_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 1.6 Standard",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: [5, 10],
                    supportedGuidanceRange: DoubleRange(0.0, 1.0),
                    supportsAudio: false,
                    supportsNegativePrompt: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v1.6/standard/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v1.6/standard/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V16_STD_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 1.6 Standard Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoDurations: [5, 10],
                    supportsAudio: false,
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v1.6/standard/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v1.6/standard/image-to-video",
                active: true
            ),

            // MARK: - Kling v1.5 Video Models

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V15_PRO_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 1.5 Pro",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: [5, 10],
                    supportedGuidanceRange: DoubleRange(0.0, 1.0),
                    supportsAudio: false,
                    supportsNegativePrompt: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v1.5/pro/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v1.5/pro/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V15_PRO_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 1.5 Pro Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoDurations: [5, 10],
                    supportsAudio: false,
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v1.5/pro/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v1.5/pro/image-to-video",
                active: true
            ),

            // MARK: - Kling v1.0 Video Models

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V10_PRO_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 1.0 Pro",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: [5, 10],
                    supportedGuidanceRange: DoubleRange(0.0, 1.0),
                    supportsAudio: false,
                    supportsNegativePrompt: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v1/pro/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v1/pro/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V10_PRO_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 1.0 Pro Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoDurations: [5, 10],
                    supportsAudio: false,
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v1/pro/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v1/pro/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V10_STD_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 1.0 Standard",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: [5, 10],
                    supportedGuidanceRange: DoubleRange(0.0, 1.0),
                    supportsAudio: false,
                    supportsNegativePrompt: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v1/standard/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v1/standard/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V10_STD_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 1.0 Standard Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoDurations: [5, 10],
                    supportsAudio: false,
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v1/standard/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v1/standard/image-to-video",
                active: true
            ),

            // MARK: - Kling Special Video Models

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_O1_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling O1 First-Last Frame",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoDurations: [5, 10],
                    supportsAudio: false,
                    supportsLastFrame: true,
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/o1/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/o1/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_O1_REF2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling O1 Reference-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    maxReferenceImages: 4,
                    supportedVideoDurations: [5, 10],
                    supportsAudio: false,
                    supportsNegativePrompt: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/o1/reference-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/o1/reference-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_LIPSYNC_A2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling LipSync Audio-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    supportsAudio: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/lipsync/audio-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/lipsync/audio-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_LIPSYNC_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling LipSync Text-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportsAudio: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/lipsync/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/lipsync/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V3_PRO_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 3 Pro Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsSeed: false,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v3/pro/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v3/pro/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V3_PRO_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 3 Pro",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
                    supportsAudio: true,
                    supportsSeed: false
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v3/pro/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v3/pro/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V3_STD_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 3 Standard",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: [5, 10],
                    supportsAudio: true,
                    supportsSeed: false
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v3/standard/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v3/standard/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V3_STD_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling 3 Standard Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: [5, 10],
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsSeed: false,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v3/standard/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v3/standard/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V3_4K_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling v3 4K",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: [5, 10],
                    supportedVideoResolutions: ["4K"],
                    supportsAudio: true,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v3/4k/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v3/4k/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_V3_4K_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling v3 4K I2V",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: [5, 10],
                    supportedVideoResolutions: ["4K"],
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/v3/4k/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/v3/4k/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_O3_4K_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling O3 4K",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: [5, 10],
                    supportedVideoResolutions: ["4K"],
                    supportsAudio: true,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/o3/4k/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/o3/4k/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_O3_4K_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling O3 4K I2V",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: [5, 10],
                    supportedVideoResolutions: ["4K"],
                    supportsAudio: true,
                    supportsLastFrame: true,
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/o3/4k/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/o3/4k/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_KLING_O3_4K_REF2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Kling O3 4K Ref-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1"],
                    supportedVideoDurations: [5, 10],
                    supportedVideoResolutions: ["4K"],
                    supportsAudio: true,
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/kling-video/o3/4k/reference-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/kling-video/o3/4k/reference-to-video",
                active: true
            ),
        ]
    }

    // MARK: - OpenAI Sora Video Models

    private static func createSoraVideoModels() -> [ProviderModelData] {
        [
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SORA_2_PRO_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Sora 2 Pro",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [4, 8, 12],
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsAudio: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/sora-2/text-to-video/pro",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/sora-2/text-to-video/pro",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SORA_2_PRO_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Sora 2 Pro Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "auto"],
                    supportedVideoDurations: [4, 8, 12],
                    supportedVideoResolutions: ["720p", "1080p", "auto"],
                    supportsAudio: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/sora-2/image-to-video/pro",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/sora-2/image-to-video/pro",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SORA_2_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Sora 2",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16"],
                    supportedVideoDurations: [4, 8, 12],
                    supportedVideoResolutions: ["720p"],
                    supportsAudio: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/sora-2/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/sora-2/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_SORA_2_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Sora 2 Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "auto"],
                    supportedVideoDurations: [4, 8, 12],
                    supportedVideoResolutions: ["720p", "auto"],
                    supportsAudio: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/sora-2/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/sora-2/image-to-video",
                active: true
            ),
        ]
    }

    // MARK: - MiniMax Video Models

    private static func createMiniMaxVideoModels() -> [ProviderModelData] {
        [
            // MARK: MiniMax Hailuo 2.3 Video Models

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_MINIMAX_HAILUO_23_PRO_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Hailuo 2.3 Pro",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoResolutions: ["1080p"],
                    supportsAudio: false,
                    supportsPromptEnhance: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/minimax/hailuo-2.3/pro/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/minimax/hailuo-2.3/pro/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_MINIMAX_HAILUO_23_PRO_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Hailuo 2.3 Pro Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoResolutions: ["1080p"],
                    supportsAudio: false,
                    supportsPromptEnhance: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/minimax/hailuo-2.3/pro/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/minimax/hailuo-2.3/pro/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_MINIMAX_HAILUO_23_STD_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Hailuo 2.3 Standard",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoDurations: [6, 10],
                    supportedVideoResolutions: ["768p"],
                    supportsAudio: false,
                    supportsPromptEnhance: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/minimax/hailuo-2.3/standard/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/minimax/hailuo-2.3/standard/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_MINIMAX_HAILUO_23_STD_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Hailuo 2.3 Standard Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoDurations: [6, 10],
                    supportedVideoResolutions: ["768p"],
                    supportsAudio: false,
                    supportsPromptEnhance: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/minimax/hailuo-2.3/standard/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/minimax/hailuo-2.3/standard/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_MINIMAX_HAILUO_23_FAST_PRO_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Hailuo 2.3 Fast Pro Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoResolutions: ["1080p"],
                    supportsAudio: false,
                    supportsPromptEnhance: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/minimax/hailuo-2.3-fast/pro/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/minimax/hailuo-2.3-fast/pro/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_MINIMAX_HAILUO_23_FAST_STD_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Hailuo 2.3 Fast Standard Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoResolutions: ["768p"],
                    supportsAudio: false,
                    supportsPromptEnhance: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/minimax/hailuo-2.3-fast/standard/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/minimax/hailuo-2.3-fast/standard/image-to-video",
                active: true
            ),

            // MARK: - MiniMax Hailuo 02 Video Models

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_MINIMAX_HAILUO_02_PRO_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Hailuo 02 Pro",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoResolutions: ["1080p"],
                    supportsAudio: false,
                    supportsPromptEnhance: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/minimax/hailuo-02/pro/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/minimax/hailuo-02/pro/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_MINIMAX_HAILUO_02_PRO_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Hailuo 02 Pro Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoResolutions: ["1080p"],
                    supportsAudio: false,
                    supportsLastFrame: true,
                    supportsPromptEnhance: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/minimax/hailuo-02/pro/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/minimax/hailuo-02/pro/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_MINIMAX_HAILUO_02_STD_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Hailuo 02 Standard",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoResolutions: ["768p", "512p"],
                    supportsAudio: false,
                    supportsPromptEnhance: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/minimax/hailuo-02/standard/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/minimax/hailuo-02/standard/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_MINIMAX_HAILUO_02_STD_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Hailuo 02 Standard Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedVideoResolutions: ["768p", "512p"],
                    supportsAudio: false,
                    supportsPromptEnhance: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/minimax/hailuo-02/standard/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/minimax/hailuo-02/standard/image-to-video",
                active: true
            ),

            // MARK: - MiniMax Video-01 Models

            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_MINIMAX_VIDEO_01_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Video-01 Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportsAudio: false,
                    supportsPromptEnhance: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/minimax/video-01/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/minimax/video-01/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_MINIMAX_VIDEO_01_DIRECTOR,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Video-01 Director",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportsAudio: false,
                    supportsCameraFixed: true,
                    supportsPromptEnhance: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/minimax/video-01-director",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/minimax/video-01-director",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_MINIMAX_VIDEO_01_DIRECTOR_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Video-01 Director Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportsAudio: false,
                    supportsCameraFixed: true,
                    supportsPromptEnhance: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/minimax/video-01-director/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/minimax/video-01-director/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_MINIMAX_VIDEO_01_LIVE,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Video-01 Live",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportsAudio: false,
                    supportsPromptEnhance: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/minimax/video-01-live",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/minimax/video-01-live",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_MINIMAX_VIDEO_01_LIVE_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Video-01 Live Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportsAudio: false,
                    supportsPromptEnhance: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/minimax/video-01-live/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/minimax/video-01-live/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_MINIMAX_VIDEO_01_SUBJECT_REF,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Video-01 Subject Reference",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportsAudio: false,
                    supportsPromptEnhance: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-01-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/minimax/video-01-subject-reference",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/minimax/video-01-subject-reference",
                active: true
            ),
        ]
    }

    private static func createPixverseVideoModels() -> [ProviderModelData] {
        [
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_PIXVERSE_V6_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "PixVerse V6 Text-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "4:3", "1:1", "3:4", "9:16", "2:3", "3:2", "21:9"],
                    supportedVideoDurations: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
                    supportedVideoResolutions: ["360p", "540p", "720p", "1080p"],
                    supportsAudio: true,
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/pixverse/v6/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/pixverse/v6/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_PIXVERSE_V6_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "PixVerse V6",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "4:3", "1:1", "3:4", "9:16"],
                    supportedVideoDurations: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
                    supportedVideoResolutions: ["360p", "540p", "720p", "1080p"],
                    supportsAudio: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/pixverse/v6/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/pixverse/v6/image-to-video",
                active: true
            ),
        ]
    }

    private static func createHappyHorseVideoModels() -> [ProviderModelData] {
        [
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_HAPPY_HORSE_T2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Happy Horse",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1", "4:3", "3:4"],
                    supportedVideoDurations: [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/alibaba/happy-horse/text-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/alibaba/happy-horse/text-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_HAPPY_HORSE_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Happy Horse Image-to-Video",
                modelDescription: "Create motion clips with synchronized audio.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1", "4:3", "3:4"],
                    supportedVideoDurations: [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/alibaba/happy-horse/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/alibaba/happy-horse/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_HAPPY_HORSE_REF2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Happy Horse Ref-to-Video",
                modelDescription: "Generate motion clips from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: ["16:9", "9:16", "1:1", "4:3", "3:4"],
                    supportedVideoDurations: [3, 5, 8, 10],
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/alibaba/happy-horse/reference-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/alibaba/happy-horse/reference-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_HAPPY_HORSE_V11_I2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Happy Horse 1.1 Image-to-Video",
                modelDescription: "Animate still images into motion clips.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 2500,
                    supportedVideoDurations: [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: "https://fal.run/alibaba/happy-horse/v1.1/image-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/alibaba/happy-horse/v1.1/image-to-video",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_HAPPY_HORSE_V11_REF2V,
                modelSetType: EnumSetType.VIDEO_GENERATE,
                modelName: "Happy Horse 1.1 Reference-to-Video",
                modelDescription: "Generate motion clips from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 2500,
                    maxReferenceImages: 9,
                    supportedDimensions: ["16:9", "9:16", "1:1", "4:3", "3:4", "21:9", "9:21", "5:4", "4:5"],
                    supportedVideoDurations: [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
                    supportedVideoResolutions: ["720p", "1080p"],
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelGenerateBaseURL: "https://fal.run/alibaba/happy-horse/v1.1/reference-to-video",
                modelAPIDocumentationURL: "https://fal.ai/models/alibaba/happy-horse/v1.1/reference-to-video",
                active: true
            ),
        ]
    }

    // MARK: - xAI Image Models

    private static func createXaiImageModels() -> [ProviderModelData] {
        [
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_XAI_GROK_IMAGINE_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Grok Imagine Image",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4", "3:2", "2:3", "2:1", "20:9"],
                    supportsSeed: true,
                    supportsSourceImage: false
                ),
                modelLaunchDate: getDateFromString("2026-02-01"),
                modelGenerateBaseURL: "https://fal.run/xai/grok-imagine-image",
                modelAPIDocumentationURL: "https://fal.ai/models/xai/grok-imagine-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_XAI_GROK_IMAGINE_IMAGE_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Grok Imagine Image Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4", "3:2", "2:3", "2:1", "20:9"],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-02-01"),
                modelGenerateBaseURL: "https://fal.run/xai/grok-imagine-image/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/xai/grok-imagine-image/edit",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_XAI_GROK_IMAGINE_IMAGE_QUALITY,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Grok Imagine Image Quality",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4", "3:2", "2:3", "2:1", "20:9"],
                    supportsSeed: true,
                    supportsSourceImage: false
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/xai/grok-imagine-image/quality/text-to-image",
                modelAPIDocumentationURL: "https://fal.ai/models/xai/grok-imagine-image/quality/text-to-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_XAI_GROK_IMAGINE_IMAGE_QUALITY_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Grok Imagine Image Quality Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4000,
                    supportedDimensions: ["1:1", "16:9", "9:16", "4:3", "3:4", "3:2", "2:3", "2:1", "20:9"],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/xai/grok-imagine-image/quality/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/xai/grok-imagine-image/quality/edit",
                active: true
            ),
        ]
    }

    // MARK: - HiDream Image Models

    private static func createHiDreamImageModels() -> [ProviderModelData] {
        [
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_HIDREAM_O1_IMAGE,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "HiDream O1 Image",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportedGuidanceRange: DoubleRange(1.0, 20.0),
                    supportedStepsRange: IntRange(1, 100),
                    supportsSeed: true,
                    supportsSourceImage: false
                ),
                modelLaunchDate: getDateFromString("2026-04-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/hidream-o1-image",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/hidream-o1-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_HIDREAM_O1_IMAGE_DEV,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "HiDream O1 Image Dev",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportedGuidanceRange: DoubleRange(1.0, 20.0),
                    supportedStepsRange: IntRange(1, 100),
                    supportsSeed: true,
                    supportsSourceImage: false
                ),
                modelLaunchDate: getDateFromString("2026-04-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/hidream-o1-image/dev",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/hidream-o1-image/dev",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_HIDREAM_O1_IMAGE_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "HiDream O1 Image Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportedGuidanceRange: DoubleRange(1.0, 20.0),
                    supportedStepsRange: IntRange(1, 100),
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-04-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/hidream-o1-image/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/hidream-o1-image/edit",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_HIDREAM_O1_IMAGE_DEV_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "HiDream O1 Image Dev Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportedGuidanceRange: DoubleRange(1.0, 20.0),
                    supportedStepsRange: IntRange(1, 100),
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-04-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/hidream-o1-image/dev/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/hidream-o1-image/dev/edit",
                active: true
            ),
        ]
    }

    // MARK: - ERNIE Image Models

    private static func createErnieImageModels() -> [ProviderModelData] {
        [
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_ERNIE_IMAGE_LORA,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "ERNIE Image LoRA",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                        "portrait_3_2",
                        "landscape_3_2",
                    ],
                    supportedGuidanceRange: DoubleRange(1.0, 20.0),
                    supportedStepsRange: IntRange(1, 100),
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: false
                ),
                modelLaunchDate: getDateFromString("2026-04-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/ernie-image/lora",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/ernie-image/lora",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_ERNIE_IMAGE_LORA_TURBO,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "ERNIE Image LoRA Turbo",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                        "portrait_3_2",
                        "landscape_3_2",
                    ],
                    supportedGuidanceRange: DoubleRange(1.0, 20.0),
                    supportedStepsRange: IntRange(1, 50),
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: false
                ),
                modelLaunchDate: getDateFromString("2026-04-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/ernie-image/lora/turbo",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/ernie-image/lora/turbo",
                active: true
            ),
        ]
    }

    // MARK: - Recraft V4.1 Image Models

    private static func createRecraftV41ImageModels() -> [ProviderModelData] {
        [
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_RECRAFT_V4_1,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Recraft V4.1",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportsSeed: true,
                    supportsSourceImage: false
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/recraft/v4.1/text-to-image",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/recraft/v4.1/text-to-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_RECRAFT_V4_1_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Recraft V4.1 Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/recraft/v4.1/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/recraft/v4.1/edit",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_RECRAFT_V4_1_ULTRA,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Recraft V4.1 Ultra",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportsSeed: true,
                    supportsSourceImage: false
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/recraft/v4.1/ultra/text-to-image",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/recraft/v4.1/ultra/text-to-image",
                active: true
            ),
            ProviderModelData(
                providerId: EnumProviderCode.FAL_AI.providerId,
                modelCode: EnumProviderModelCode.FAL_RECRAFT_V4_1_ULTRA_EDIT,
                modelSetType: EnumSetType.IMAGE_GENERATE,
                modelName: "Recraft V4.1 Ultra Edit",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 4000,
                    supportedDimensions: [
                        "square_hd",
                        "square",
                        "portrait_4_3",
                        "portrait_16_9",
                        "landscape_4_3",
                        "landscape_16_9",
                    ],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-05-01"),
                modelGenerateBaseURL: "https://fal.run/fal-ai/recraft/v4.1/ultra/edit",
                modelAPIDocumentationURL: "https://fal.ai/models/fal-ai/recraft/v4.1/ultra/edit",
                active: true
            ),
        ]
    }
}
