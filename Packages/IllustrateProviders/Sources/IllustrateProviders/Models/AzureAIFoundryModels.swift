// MARK: - AzureAIFoundryModels.swift

import Foundation

public enum AzureAIFoundryModels {
    public static func createModels() -> [ProviderModelData] {
        let providerId = EnumProviderCode.AZURE_AI_FOUNDRY.providerId
        let verifiedAt = getDateFromString("2026-07-10")
        let pricing = "https://azure.microsoft.com/en-us/pricing/details/azure-openai/"

        return [
            ProviderModelData(
                providerId: providerId,
                modelCode: .AZURE_GPT_IMAGE_2,
                modelSetType: .IMAGE_GENERATE,
                modelName: "GPT Image 2",
                modelDescription: "Create and edit detailed images through Azure deployments.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    maxReferenceImages: 8,
                    supportedBackgrounds: ["auto", "transparent", "opaque"],
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
                    supportedImageQualities: ["low", "medium", "high"],
                    supportsMask: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-04-21"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .image,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "Azure Global deployment token pricing; estimate excludes variable text and input-image tokens."
                ),
                modelGenerateBaseURL: "https://RESOURCE.openai.azure.com/openai/v1/images/generations?api-version=preview",
                modelStatusBaseURL: nil,
                modelAPIDocumentationURL: "https://learn.microsoft.com/en-us/azure/foundry/openai/how-to/dall-e",
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .AZURE_SORA_2,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Sora 2",
                modelDescription: "Create portrait and landscape videos through Azure deployments.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 32000,
                    supportedDimensions: ["1280x720", "720x1280"],
                    supportedVideoDurations: [4, 8, 12],
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-10-16"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .second,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "Azure Sora 2 Global output pricing per generated second."
                ),
                modelGenerateBaseURL: "https://RESOURCE.openai.azure.com/openai/v1/videos",
                modelStatusBaseURL: "https://RESOURCE.openai.azure.com/openai/v1/videos/{video_id}",
                modelAPIDocumentationURL: "https://learn.microsoft.com/en-us/azure/foundry/openai/concepts/video-generation",
                active: true
            ),
        ]
    }
}
