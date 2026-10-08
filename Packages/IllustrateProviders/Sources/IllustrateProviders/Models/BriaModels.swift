// MARK: - BriaModels.swift

import Foundation

public enum BriaModels {
    public static func createModels() -> [ProviderModelData] {
        let verifiedAt = getDateFromString("2026-07-10")

        return [
            ProviderModelData(
                providerId: EnumProviderCode.BRIA.providerId,
                modelCode: .BRIA_FIBO,
                modelSetType: .IMAGE_GENERATE,
                modelName: "FIBO",
                modelDescription: "Generate controllable images from text or reference imagery.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    maxPromptLength: 8000,
                    maxReferenceImages: 1,
                    supportedDimensions: [
                        "1024x1024", "832x1248", "1248x832", "768x1024", "1024x768",
                        "832x1040", "1040x832", "576x1024", "1024x576",
                    ],
                    supportedImageResolutions: ["1MP", "4MP"],
                    supportedStepsRange: IntRange(35, 50),
                    supportsNegativePrompt: true,
                    supportsSeed: true,
                    supportsSourceImage: true
                ),
                modelLaunchDate: getDateFromString("2025-11-11"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .image,
                    sourceURL: "https://bria.ai/pricing",
                    verifiedAt: verifiedAt,
                    notes: "$0.03 per FIBO image on the Development plan."
                ),
                modelGenerateBaseURL: "https://engine.prod.bria-api.com/v2/image/generate",
                modelStatusBaseURL: "https://engine.prod.bria-api.com/v2/status",
                modelAPIDocumentationURL: "https://docs.bria.ai/image-generation/endpoints/image-generate",
                active: true
            ),
        ]
    }
}
