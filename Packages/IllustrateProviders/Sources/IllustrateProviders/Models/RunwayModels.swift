// MARK: - RunwayModels.swift

import Foundation

public enum RunwayModels {
    public static func createModels() -> [ProviderModelData] {
        let providerId = EnumProviderCode.RUNWAY.providerId
        let verifiedAt = getDateFromString("2026-07-10")
        let documentation = "https://docs.dev.runwayml.com/guides/using-the-api/"
        let pricing = "https://docs.dev.runwayml.com/guides/pricing/"
        let statusURL = "https://api.dev.runwayml.com/v1/tasks"

        return [
            ProviderModelData(
                providerId: providerId,
                modelCode: .RUNWAY_GEN_4_IMAGE_TURBO,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Gen-4 Image Turbo",
                modelDescription: "Create fast images guided by visual references.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxImageSizeBytes: 3_300_000,
                    maxPromptLength: 1000,
                    maxReferenceImages: 3,
                    supportedDimensions: [
                        "1024:1024", "1080:1080", "1168:880", "1360:768",
                        "1440:1080", "1080:1440", "1808:768", "1920:1080",
                        "1080:1920", "2112:912", "1280:720", "720:1280",
                        "720:720", "960:720", "720:960", "1680:720",
                    ],
                    supportedModerations: ["auto", "low"],
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-08-19"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .image,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "Two credits per image at $0.01 per credit."
                ),
                modelGenerateBaseURL: "https://api.dev.runwayml.com/v1/text_to_image",
                modelStatusBaseURL: statusURL,
                modelAPIDocumentationURL: documentation,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .RUNWAY_GEN_4_5,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Gen-4.5",
                modelDescription: "Create cinematic motion from detailed written prompts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 1000,
                    supportedDimensions: ["1280:720", "720:1280"],
                    supportedModerations: ["auto", "low"],
                    supportedVideoDurations: Array(2 ... 10),
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-02-10"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .second,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "Twelve credits per second at $0.01 per credit."
                ),
                modelGenerateBaseURL: "https://api.dev.runwayml.com/v1/text_to_video",
                modelStatusBaseURL: statusURL,
                modelAPIDocumentationURL: documentation,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .RUNWAY_GEN_4_5_I2V,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Gen-4.5 (Image to Video)",
                modelDescription: "Animate source imagery with controlled cinematic motion.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxImageSizeBytes: 3_300_000,
                    maxPromptLength: 1000,
                    supportedDimensions: [
                        "1280:720", "720:1280", "1104:832",
                        "832:1104", "960:960", "1584:672",
                    ],
                    supportedModerations: ["auto", "low"],
                    supportedVideoDurations: Array(2 ... 10),
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-02-10"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .second,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "Twelve credits per second at $0.01 per credit."
                ),
                modelGenerateBaseURL: "https://api.dev.runwayml.com/v1/image_to_video",
                modelStatusBaseURL: statusURL,
                modelAPIDocumentationURL: documentation,
                active: true
            ),
        ]
    }
}
