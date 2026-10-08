// MARK: - NovitaAIModels.swift

import Foundation

public enum NovitaAIModels {
    public static func createModels() -> [ProviderModelData] {
        let verifiedAt = getDateFromString("2026-07-10")
        return [
            ProviderModelData(
                providerId: EnumProviderCode.NOVITA_AI.providerId,
                modelCode: .NOVITA_QWEN_IMAGE,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Qwen-Image",
                modelDescription: "Text-focused image generation for posters and creative layouts.",
                modelParams: ModelParams(
                    maxGenerations: 1,
                    supportedDimensions: [
                        "1024x1024", "1344x768", "768x1344", "1152x896", "896x1152",
                        "1216x832", "832x1216",
                    ]
                ),
                modelLaunchDate: getDateFromString("2025-08-06"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .image,
                    sourceURL: "https://novita.ai/pricing",
                    verifiedAt: verifiedAt,
                    notes: "$0.02 per generated image."
                ),
                modelGenerateBaseURL: "https://api.novita.ai/v3/async/qwen-image-txt2img",
                modelStatusBaseURL: "https://api.novita.ai/v3/async/task-result",
                modelAPIDocumentationURL: "https://novita.ai/docs/api-reference/model-apis-qwen-image-txt2img",
                active: true
            ),
        ]
    }
}
