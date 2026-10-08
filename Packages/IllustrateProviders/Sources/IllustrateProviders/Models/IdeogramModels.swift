// MARK: - IdeogramModels.swift

import Foundation

public enum IdeogramModels {
    public static func createModels() -> [ProviderModelData] {
        let providerId = EnumProviderCode.IDEOGRAM.providerId
        let endpoint = "https://api.ideogram.ai/v1/ideogram-v4/generate"
        let documentation = "https://developer.ideogram.ai/api-reference/api-reference/generate-v4"
        let pricing = "https://ideogram.ai/api-pricing/"
        let verifiedAt = getDateFromString("2026-07-10")
        let dimensions = [
            "2048x2048", "1440x2880", "2880x1440", "1664x2496", "2496x1664",
            "1792x2240", "2240x1792", "1440x2560", "2560x1440", "1728x2304", "2304x1728",
        ]

        return [
            model(
                providerId: providerId,
                code: .IDEOGRAM_V4_TURBO,
                name: "Ideogram V4 Turbo",
                description: "Create typography-rich images with fast visual iteration.",
                price: 0.03,
                priceNote: "$0.03 per Turbo image.",
                endpoint: endpoint,
                documentation: documentation,
                pricing: pricing,
                dimensions: dimensions,
                verifiedAt: verifiedAt
            ),
            model(
                providerId: providerId,
                code: .IDEOGRAM_V4_DEFAULT,
                name: "Ideogram V4 Default",
                description: "Create typography-rich images with balanced visual detail.",
                price: 0.06,
                priceNote: "$0.06 per Default image.",
                endpoint: endpoint,
                documentation: documentation,
                pricing: pricing,
                dimensions: dimensions,
                verifiedAt: verifiedAt
            ),
            model(
                providerId: providerId,
                code: .IDEOGRAM_V4_QUALITY,
                name: "Ideogram V4 Quality",
                description: "Create typography-rich images with refined visual detail.",
                price: 0.10,
                priceNote: "$0.10 per Quality image.",
                endpoint: endpoint,
                documentation: documentation,
                pricing: pricing,
                dimensions: dimensions,
                verifiedAt: verifiedAt
            ),
        ]
    }

    private static func model(
        providerId: UUID,
        code: EnumProviderModelCode,
        name: String,
        description: String,
        price _: Double,
        priceNote: String,
        endpoint: String,
        documentation: String,
        pricing: String,
        dimensions: [String],
        verifiedAt: Date
    ) -> ProviderModelData {
        ProviderModelData(
            providerId: providerId,
            modelCode: code,
            modelSetType: .IMAGE_GENERATE,
            modelName: name,
            modelDescription: description,
            modelParams: ModelParams(
                maxGenerations: 4,
                maxPromptLength: 8000,
                supportedDimensions: dimensions
            ),
            modelLaunchDate: getDateFromString("2026-06-03"),
            modelVerificationDate: verifiedAt,
            pricingMetadata: ProviderPricingMetadata(
                unit: .image,
                sourceURL: pricing,
                verifiedAt: verifiedAt,
                notes: priceNote
            ),
            modelGenerateBaseURL: endpoint,
            modelAPIDocumentationURL: documentation,
            active: true
        )
    }
}
