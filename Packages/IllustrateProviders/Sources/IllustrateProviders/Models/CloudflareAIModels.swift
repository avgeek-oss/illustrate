// MARK: - CloudflareAIModels.swift

// Factory for Cloudflare Workers AI model configurations.

import Foundation

public enum CloudflareAIModels {
    public static func createModels() -> [ProviderModelData] {
        let providerId = EnumProviderCode.CLOUDFLARE_AI.providerId
        let baseURL = "https://api.cloudflare.com/client/v4/accounts"
        let docURL = "https://developers.cloudflare.com/workers-ai/models/"

        return [
            ProviderModelData(
                providerId: providerId,
                modelCode: .CLOUDFLARE_FLUX_2_KLEIN_9B,
                modelSetType: .IMAGE_GENERATE,
                modelName: "FLUX.2 Klein 9B",
                modelDescription: "Create images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxImagePixels: 262_144,
                    maxPromptLength: 4096,
                    maxReferenceImages: 4,
                    supportedDimensions: [
                        "512x512", "768x768", "1024x1024", "1280x720", "720x1280",
                    ],
                    supportsNegativePrompt: false,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-01-28"),
                modelGenerateBaseURL: "\(baseURL)/{{ACCOUNT_ID}}/ai/run/@cf/black-forest-labs/flux-2-klein-9b",
                modelAPIDocumentationURL: "\(docURL)flux-2-klein-9b/",
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .CLOUDFLARE_FLUX_2_KLEIN_4B,
                modelSetType: .IMAGE_GENERATE,
                modelName: "FLUX.2 Klein 4B",
                modelDescription: "Create images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxImagePixels: 262_144,
                    maxPromptLength: 4096,
                    maxReferenceImages: 4,
                    supportedDimensions: [
                        "512x512", "768x768", "1024x1024", "1280x720", "720x1280",
                    ],
                    supportsNegativePrompt: false,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-01-15"),
                modelGenerateBaseURL: "\(baseURL)/{{ACCOUNT_ID}}/ai/run/@cf/black-forest-labs/flux-2-klein-4b",
                modelAPIDocumentationURL: "\(docURL)flux-2-klein-4b/",
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .CLOUDFLARE_FLUX_2_DEV,
                modelSetType: .IMAGE_GENERATE,
                modelName: "FLUX.2 Dev",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: [
                        "512x512", "768x768", "1024x1024", "1280x720", "720x1280",
                    ],
                    supportedStepsRange: IntRange(1, 50),
                    supportsNegativePrompt: false,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-05-01"),
                modelGenerateBaseURL: "\(baseURL)/{{ACCOUNT_ID}}/ai/run/@cf/black-forest-labs/flux-2-dev",
                modelAPIDocumentationURL: "\(docURL)flux-2-dev/",
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .CLOUDFLARE_LUCID_ORIGIN,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Lucid Origin",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: [
                        "512x512", "768x768", "1024x1024", "1120x1120", "1280x720", "720x1280",
                    ],
                    supportedGuidanceRange: DoubleRange(0, 10),
                    supportedStepsRange: IntRange(1, 40),
                    supportsNegativePrompt: false,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-04-01"),
                modelGenerateBaseURL: "\(baseURL)/{{ACCOUNT_ID}}/ai/run/@cf/leonardo/lucid-origin",
                modelAPIDocumentationURL: "\(docURL)lucid-origin/",
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .CLOUDFLARE_PHOENIX_1,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Phoenix 1.0",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: [
                        "512x512", "768x768", "1024x1024", "1280x720", "720x1280",
                    ],
                    supportedGuidanceRange: DoubleRange(2, 10),
                    supportedStepsRange: IntRange(1, 50),
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2025-03-01"),
                modelGenerateBaseURL: "\(baseURL)/{{ACCOUNT_ID}}/ai/run/@cf/leonardo/phoenix-1.0",
                modelAPIDocumentationURL: "\(docURL)phoenix-1.0/",
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .CLOUDFLARE_FLUX_1_SCHNELL,
                modelSetType: .IMAGE_GENERATE,
                modelName: "FLUX.1 Schnell",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 2048,
                    supportedStepsRange: IntRange(1, 8),
                    supportsNegativePrompt: false,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2024-08-01"),
                modelGenerateBaseURL: "\(baseURL)/{{ACCOUNT_ID}}/ai/run/@cf/black-forest-labs/flux-1-schnell",
                modelAPIDocumentationURL: "\(docURL)flux-1-schnell/",
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .CLOUDFLARE_SD_XL_BASE,
                modelSetType: .IMAGE_GENERATE,
                modelName: "SDXL Base 1.0",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: [
                        "512x512", "768x768", "1024x1024", "1280x720", "720x1280",
                    ],
                    supportedGuidanceRange: DoubleRange(1, 20),
                    supportedStepsRange: IntRange(1, 20),
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2023-07-01"),
                modelGenerateBaseURL: "\(baseURL)/{{ACCOUNT_ID}}/ai/run/@cf/stabilityai/stable-diffusion-xl-base-1.0",
                modelAPIDocumentationURL: "\(docURL)stable-diffusion-xl-base-1.0/",
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .CLOUDFLARE_SD_15_IMG2IMG,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Stable Diffusion 1.5 Img2Img",
                modelDescription: "Transform source images with prompt guidance.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxImagePixels: 2_097_152,
                    maxPromptLength: 4096,
                    supportedDimensions: [
                        "512x512", "768x768", "1024x1024", "1280x720", "720x1280",
                    ],
                    supportedGuidanceRange: DoubleRange(1, 20),
                    supportedStepsRange: IntRange(1, 20),
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2023-01-01"),
                modelGenerateBaseURL: "\(baseURL)/{{ACCOUNT_ID}}/ai/run/@cf/runwayml/stable-diffusion-v1-5-img2img",
                modelAPIDocumentationURL: "\(docURL)stable-diffusion-v1-5-img2img/",
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .CLOUDFLARE_DREAMSHAPER_8_LCM,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Dreamshaper 8 LCM",
                modelDescription: "Generate polished images from written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 4096,
                    supportedDimensions: [
                        "512x512", "768x768", "1024x1024", "1280x720", "720x1280",
                    ],
                    supportedGuidanceRange: DoubleRange(1, 20),
                    supportedStepsRange: IntRange(1, 20),
                    supportsNegativePrompt: true,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2024-01-01"),
                modelGenerateBaseURL: "\(baseURL)/{{ACCOUNT_ID}}/ai/run/@cf/lykon/dreamshaper-8-lcm",
                modelAPIDocumentationURL: "\(docURL)dreamshaper-8-lcm/",
                active: true
            ),
        ]
    }
}
