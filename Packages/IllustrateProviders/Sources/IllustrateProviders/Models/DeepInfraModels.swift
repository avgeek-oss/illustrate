// MARK: - DeepInfraModels.swift

import Foundation

public enum DeepInfraModels {
    public static func createModels() -> [ProviderModelData] {
        let providerId = EnumProviderCode.DEEPINFRA.providerId
        let endpoint = "https://api.deepinfra.com/v1/openai/images/generations"
        let documentation = "https://docs.deepinfra.com/apis/image-generation"
        let verifiedAt = getDateFromString("2026-07-10")
        let launchDate = getDateFromString("2026-01-20")
        let dimensions = [
            "1024x1024", "1344x768", "768x1344", "1152x896", "896x1152",
            "1216x832", "832x1216",
        ]

        return [
            ProviderModelData(
                providerId: providerId,
                modelCode: .DEEPINFRA_FLUX_2_KLEIN_4B,
                modelSetType: .IMAGE_GENERATE,
                modelName: "FLUX.2 Klein 4B",
                modelDescription: "Fast open-model image generation for rapid creative iteration.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    supportedDimensions: dimensions
                ),
                modelLaunchDate: launchDate,
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .megapixel,
                    sourceURL: "https://deepinfra.com/black-forest-labs/FLUX-2-klein-4b/api",
                    verifiedAt: verifiedAt,
                    notes: "$0.014 × (width / 1024) × (height / 1024)."
                ),
                modelGenerateBaseURL: endpoint,
                modelAPIDocumentationURL: documentation,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .DEEPINFRA_FLUX_2_KLEIN_9B,
                modelSetType: .IMAGE_GENERATE,
                modelName: "FLUX.2 Klein 9B",
                modelDescription: "Production image generation with a quality-to-latency focus.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    supportedDimensions: dimensions
                ),
                modelLaunchDate: launchDate,
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .megapixel,
                    sourceURL: "https://deepinfra.com/black-forest-labs/FLUX-2-klein-9b/api",
                    verifiedAt: verifiedAt,
                    notes: "$0.015 × (width / 1024) × (height / 1024)."
                ),
                modelGenerateBaseURL: endpoint,
                modelAPIDocumentationURL: documentation,
                active: true
            ),
        ]
    }
}
