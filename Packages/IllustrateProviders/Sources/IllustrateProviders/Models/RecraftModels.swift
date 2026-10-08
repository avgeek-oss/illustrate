// MARK: - RecraftModels.swift

import Foundation

public enum RecraftModels {
    public static func createModels() -> [ProviderModelData] {
        let providerId = EnumProviderCode.RECRAFT.providerId
        let endpoint = "https://external.api.recraft.ai/v1/images/generations/raster"
        let documentation = "https://www.recraft.ai/docs/api-reference/endpoints"
        let pricing = "https://www.recraft.ai/pricing?tab=api"
        let verifiedAt = getDateFromString("2026-07-10")
        let dimensions = ["1:1", "16:9", "9:16", "4:3", "3:4", "3:2", "2:3"]

        return [
            ProviderModelData(
                providerId: providerId,
                modelCode: .RECRAFT_V4_1,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Recraft V4.1",
                modelDescription: "Generate production-ready raster images with precise prompt rendering.",
                modelParams: ModelParams(
                    maxGenerations: 6,
                    maxPromptLength: 10000,
                    supportedDimensions: dimensions,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .image,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "$0.04 per standard raster image."
                ),
                modelGenerateBaseURL: endpoint,
                modelAPIDocumentationURL: documentation,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .RECRAFT_V4_1_PRO,
                modelSetType: .IMAGE_GENERATE,
                modelName: "Recraft V4.1 Pro",
                modelDescription: "Generate high-fidelity raster images with Recraft's professional model.",
                modelParams: ModelParams(
                    maxGenerations: 6,
                    maxPromptLength: 10000,
                    supportedDimensions: dimensions,
                    supportsSeed: true
                ),
                modelLaunchDate: getDateFromString("2026-06-01"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .image,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "$0.25 per Pro raster image."
                ),
                modelGenerateBaseURL: endpoint,
                modelAPIDocumentationURL: documentation,
                active: true
            ),
        ]
    }
}
