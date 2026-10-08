// MARK: - ViduModels.swift

import Foundation

public enum ViduModels {
    public static func createModels() -> [ProviderModelData] {
        let providerId = EnumProviderCode.VIDU.providerId
        let verifiedAt = getDateFromString("2026-07-10")
        let documentation = "https://platform.vidu.com/docs/text-to-video"
        let pricing = "https://platform.vidu.com/docs/pricing"
        let statusURL = "https://api.vidu.com/ent/v2/tasks"
        let params = ModelParams(
            maxGenerations: 1,
            maxPromptLength: 5000,
            supportedDimensions: ["16:9", "9:16", "3:4", "4:3", "1:1"],
            supportedVideoDurations: Array(1 ... 16),
            supportedVideoResolutions: ["540p", "720p", "1080p"],
            supportsAudio: true,
            supportsSeed: true
        )

        return [
            ProviderModelData(
                providerId: providerId,
                modelCode: .VIDU_Q3_PRO,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Vidu Q3 Pro",
                modelDescription: "Create audio-synchronized video with Vidu's quality-focused model.",
                modelParams: params,
                modelLaunchDate: getDateFromString("2026-01-27"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .second,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "$0.045, $0.10, or $0.12 per second for 540p, 720p, or 1080p normal generation."
                ),
                modelGenerateBaseURL: "https://api.vidu.com/ent/v2/text2video",
                modelStatusBaseURL: statusURL,
                modelAPIDocumentationURL: documentation,
                active: true
            ),
            ProviderModelData(
                providerId: providerId,
                modelCode: .VIDU_Q3_TURBO,
                modelSetType: .VIDEO_GENERATE,
                modelName: "Vidu Q3 Turbo",
                modelDescription: "Create audio-synchronized video with Vidu's faster model.",
                modelParams: params,
                modelLaunchDate: getDateFromString("2026-02-11"),
                modelVerificationDate: verifiedAt,
                pricingMetadata: ProviderPricingMetadata(
                    unit: .second,
                    sourceURL: pricing,
                    verifiedAt: verifiedAt,
                    notes: "$0.035, $0.055, or $0.065 per second for 540p, 720p, or 1080p normal generation."
                ),
                modelGenerateBaseURL: "https://api.vidu.com/ent/v2/text2video",
                modelStatusBaseURL: statusURL,
                modelAPIDocumentationURL: documentation,
                active: true
            ),
        ]
    }
}
