// MARK: - AmazonBedrockModels.swift

import Foundation

public enum AmazonBedrockModels {
    public static func createModels() -> [ProviderModelData] {
        let providerId = EnumProviderCode.AMAZON_BEDROCK.providerId
        let verifiedAt = getDateFromString("2026-07-10")
        let pricing = "https://aws.amazon.com/bedrock/pricing/"
        let ratios = ["16:9", "1:1", "21:9", "2:3", "3:2", "4:5", "5:4", "9:16", "9:21"]

        return [
            stabilityModel(
                providerId: providerId,
                code: .BEDROCK_STABLE_IMAGE_ULTRA_1_1,
                name: "Stable Image Ultra 1.1",
                description: "Create polished images through AWS-hosted Stability inference.",
                upstreamId: "stability.stable-image-ultra-v1:1",
                price: 0.14,
                ratios: ratios,
                verifiedAt: verifiedAt,
                pricing: pricing,
                documentation: "https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters-diffusion-stable-ultra-text-image-request-response.html"
            ),
            stabilityModel(
                providerId: providerId,
                code: .BEDROCK_STABLE_IMAGE_CORE_1_1,
                name: "Stable Image Core 1.1",
                description: "Create rapid concept images through AWS-hosted inference.",
                upstreamId: "stability.stable-image-core-v1:1",
                price: 0.04,
                ratios: ratios,
                verifiedAt: verifiedAt,
                pricing: pricing,
                documentation: "https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters-diffusion-stable-image-core-text-image-request-response.html"
            ),
        ]
    }

    private static func stabilityModel(
        providerId: UUID,
        code: EnumProviderModelCode,
        name: String,
        description: String,
        upstreamId: String,
        price: Double,
        ratios: [String],
        verifiedAt: Date,
        pricing: String,
        documentation: String
    ) -> ProviderModelData {
        ProviderModelData(
            providerId: providerId,
            modelCode: code,
            modelSetType: .IMAGE_GENERATE,
            modelName: name,
            modelDescription: description,
            modelParams: ModelParams(
                maxGenerations: 1,
                maxPromptLength: 10000,
                supportedDimensions: ratios,
                supportsNegativePrompt: true,
                supportsSeed: true
            ),
            modelLaunchDate: getDateFromString("2024-09-04"),
            modelVerificationDate: verifiedAt,
            pricingMetadata: ProviderPricingMetadata(
                unit: .image,
                sourceURL: pricing,
                verifiedAt: verifiedAt,
                notes: "AWS Bedrock on-demand estimate per generated image."
            ),
            modelGenerateBaseURL: "https://bedrock-runtime.us-west-2.amazonaws.com/model/\(upstreamId)/invoke",
            modelStatusBaseURL: nil,
            modelAPIDocumentationURL: documentation,
            active: true
        )
    }
}
