// MARK: - BlackForestLabsModels.swift

import Foundation

public enum BlackForestLabsModels {
    public static func createModels() -> [ProviderModelData] {
        let providerId = EnumProviderCode.BLACK_FOREST_LABS.providerId
        let documentation = "https://docs.bfl.ai/quick_start/generating_images"
        let pricing = "https://docs.bfl.ai/quick_start/pricing"
        let verifiedAt = getDateFromString("2026-07-10")
        let dimensions = ["1024x1024", "1280x720", "720x1280", "1440x1024", "1024x1440"]

        return [
            ProviderModelData(
                providerId: providerId,
                modelCode: .BFL_FLUX_2_PRO,
                modelSetType: .IMAGE_GENERATE,
                modelName: "FLUX.2 Pro",
                modelDescription: "Generate detailed images for reproducible production workflows.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 32000,
                    supportedDimensions: dimensions,
                    supportedSafetyRange: IntRange(0, 6),
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-01-01"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .megapixel,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "Text generation starts at $0.03; editing starts at $0.045."
                ),
                modelGenerateBaseURL: "https://api.bfl.ai/v1/flux-2-pro",
                modelAPIDocumentationURL: documentation,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .BFL_FLUX_2_MAX,
                modelSetType: .IMAGE_GENERATE,
                modelName: "FLUX.2 Max",
                modelDescription: "Generate richly grounded images with maximum visual fidelity.",
                modelParams: ModelParams(
                    maxGenerations: 4,
                    maxPromptLength: 32000,
                    supportedDimensions: dimensions,
                    supportedSafetyRange: IntRange(0, 6),
                    supportsPromptEnhance: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2026-01-01"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .megapixel,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "Generation and editing start at $0.07."
                ),
                modelGenerateBaseURL: "https://api.bfl.ai/v1/flux-2-max",
                modelAPIDocumentationURL: documentation,
                active: true
            ),
        ]
    }
}
