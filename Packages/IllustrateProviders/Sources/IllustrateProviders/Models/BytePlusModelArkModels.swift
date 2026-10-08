import Foundation

public enum BytePlusModelArkModels {
    private static let providerId = EnumProviderCode.BYTEPLUS_MODELARK.providerId
    private static let verifiedAt = getDateFromString("2026-07-10")
    private static let imageDocumentation = "https://docs.byteplus.com/en/docs/ModelArk/1541523"
    private static let videoDocumentation = "https://docs.byteplus.com/en/docs/modelark/1520757"
    private static let pricing = "https://docs.byteplus.com/en/docs/ModelArk/1544106"
    private static let imageURL = "https://ark.ap-southeast.bytepluses.com/api/v3/images/generations"
    private static let videoURL = "https://ark.ap-southeast.bytepluses.com/api/v3/contents/generations/tasks"
    private static let imageDimensions = ["1:1"]
    /// Adaptive output is intentionally excluded until preflight pricing can know the selected pixel dimensions.
    private static let videoDimensions = ["16:9", "9:16", "1:1", "4:3", "3:4", "21:9"]

    public static func createModels() -> [ProviderModelData] {
        [
            imageModel(
                code: .BYTEPLUS_DOLA_SEEDREAM_5_0_PRO,
                name: "Dola Seedream 5.0 Pro",
                description: "Create premium images with precise multi-reference consistency.",
                launch: "2026-06-28",
                references: 10,
                resolutions: ["1k", "2k"],
                pricingNotes: "$0.045 or $0.09 per image by output size; first input image free, then $0.003 each."
            ),
            imageModel(
                code: .BYTEPLUS_SEEDREAM_5_0_LITE,
                name: "Dola Seedream 5.0 Lite",
                description: "Create versatile images from text and visual references.",
                launch: "2026-01-28",
                references: 14,
                resolutions: ["2k", "3k", "4k"],
                pricingNotes: "$0.035 per generated image."
            ),
            imageModel(
                code: .BYTEPLUS_SEEDREAM_4_5,
                name: "Seedream 4.5",
                description: "Create refined images with strong reference fidelity.",
                launch: "2025-11-28",
                references: 14,
                resolutions: ["2k", "4k"],
                pricingNotes: "$0.04 per generated image."
            ),
            imageModel(
                code: .BYTEPLUS_SEEDREAM_4_0,
                name: "Seedream 4.0",
                description: "Create expressive images with flexible visual guidance.",
                launch: "2025-08-28",
                references: 14,
                resolutions: ["1k", "2k", "4k"],
                pricingNotes: "$0.03 per generated image."
            ),
            videoModel(
                code: .BYTEPLUS_DREAMINA_SEEDANCE_2_0,
                name: "Dreamina Seedance 2.0",
                description: "Create cinematic videos with synchronized audio and references.",
                launch: "2026-01-28",
                durations: Array(4 ... 15),
                resolutions: ["480p", "720p", "1080p", "4k"],
                references: 9,
                audio: true,
                lastFrame: true,
                seed: false,
                dimensions: videoDimensions,
                pricingNotes: "$7.00, $7.70, or $4.00 per million output tokens by resolution."
            ),
            videoModel(
                code: .BYTEPLUS_DREAMINA_SEEDANCE_2_0_FAST,
                name: "Dreamina Seedance 2.0 Fast",
                description: "Create fast audiovisual videos from multimodal references.",
                launch: "2026-01-28",
                durations: Array(4 ... 15),
                resolutions: ["480p", "720p"],
                references: 9,
                audio: true,
                lastFrame: true,
                seed: false,
                dimensions: videoDimensions,
                pricingNotes: "$5.60 per million output tokens."
            ),
            videoModel(
                code: .BYTEPLUS_DREAMINA_SEEDANCE_2_0_MINI,
                name: "Dreamina Seedance 2.0 Mini",
                description: "Create efficient audiovisual videos from multimodal references.",
                launch: "2026-06-15",
                durations: Array(4 ... 15),
                resolutions: ["480p", "720p"],
                references: 9,
                audio: true,
                lastFrame: true,
                seed: false,
                dimensions: videoDimensions,
                pricingNotes: "$3.50 per million output tokens."
            ),
            videoModel(
                code: .BYTEPLUS_SEEDANCE_1_5_PRO,
                name: "Seedance 1.5 Pro",
                description: "Create polished videos with optional synchronized audio.",
                launch: "2025-12-15",
                durations: Array(4 ... 12),
                resolutions: ["480p", "720p", "1080p"],
                references: 0,
                audio: true,
                lastFrame: true,
                seed: true,
                dimensions: videoDimensions,
                pricingNotes: "$2.40 per million audio tokens or $1.20 per million silent tokens."
            ),
            videoModel(
                code: .BYTEPLUS_SEEDANCE_1_0_PRO,
                name: "Seedance 1.0 Pro",
                description: "Create controlled silent videos from text or frames.",
                launch: "2025-05-28",
                durations: Array(2 ... 12),
                resolutions: ["480p", "720p", "1080p"],
                references: 0,
                audio: false,
                lastFrame: true,
                seed: true,
                dimensions: videoDimensions,
                pricingNotes: "$2.50 per million output tokens."
            ),
            videoModel(
                code: .BYTEPLUS_SEEDANCE_1_0_PRO_FAST,
                name: "Seedance 1.0 Pro Fast",
                description: "Create fast silent videos from text or images.",
                launch: "2025-10-15",
                durations: Array(2 ... 12),
                resolutions: ["480p", "720p", "1080p"],
                references: 0,
                audio: false,
                lastFrame: false,
                seed: true,
                dimensions: videoDimensions,
                pricingNotes: "$1.00 per million output tokens."
            ),
        ]
    }

    private static func imageModel(
        code: EnumProviderModelCode,
        name: String,
        description: String,
        launch: String,
        references: Int,
        resolutions: [String],
        pricingNotes: String
    ) -> ProviderModelData {
        ProviderModelData(
            providerId: providerId,
            modelCode: code,
            modelSetType: .IMAGE_GENERATE,
            modelName: name,
            modelDescription: description,
            modelParams: ModelParams(
                maxGenerations: 1,
                maxPromptLength: 6000,
                maxReferenceImages: references,
                supportedDimensions: imageDimensions,
                supportedImageResolutions: resolutions,
                supportsSourceImage: true
            ),
            modelLaunchDate: getDateFromString(launch),
            modelVerificationDate: verifiedAt,
            pricingMetadata: ProviderPricingMetadata(
                unit: .image,
                sourceURL: pricing,
                verifiedAt: verifiedAt,
                notes: pricingNotes
            ),
            modelGenerateBaseURL: imageURL,
            modelAPIDocumentationURL: imageDocumentation,
            active: true
        )
    }

    private static func videoModel(
        code: EnumProviderModelCode,
        name: String,
        description: String,
        launch: String,
        durations: [Int],
        resolutions: [String],
        references: Int,
        audio: Bool,
        lastFrame: Bool,
        seed: Bool,
        dimensions: [String],
        pricingNotes: String
    ) -> ProviderModelData {
        ProviderModelData(
            providerId: providerId,
            modelCode: code,
            modelSetType: .VIDEO_GENERATE,
            modelName: name,
            modelDescription: description,
            modelParams: ModelParams(
                maxGenerations: 1,
                maxPromptLength: 6000,
                maxReferenceImages: references,
                supportedDimensions: dimensions,
                supportedVideoDurations: durations,
                supportedVideoFPS: [24],
                supportedVideoResolutions: resolutions,
                supportsAudio: audio,
                supportsCameraFixed: seed,
                supportsLastFrame: lastFrame,
                supportsSeed: seed,
                supportsSourceImage: true
            ),
            modelLaunchDate: getDateFromString(launch),
            modelVerificationDate: verifiedAt,
            pricingMetadata: ProviderPricingMetadata(
                unit: .token,
                sourceURL: pricing,
                verifiedAt: verifiedAt,
                notes: pricingNotes
            ),
            modelGenerateBaseURL: videoURL,
            modelStatusBaseURL: videoURL,
            modelAPIDocumentationURL: videoDocumentation,
            active: true
        )
    }
}
