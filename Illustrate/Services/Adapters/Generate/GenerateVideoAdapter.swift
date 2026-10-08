// MARK: - GenerateVideoAdapter.swift

// Core adapter for video generation across all providers.
//
// Similar to GenerateImageAdapter but for video generation. Handles
// video-specific parameters like duration, FPS, audio generation,
// and video extension workflows.
//
// ## Architecture
// Same adapter pattern as image generation:
// 1. `VideoGenerationRequest`: Unified request format
// 2. `VideoGenerationProtocol`: Interface for provider adapters
// 3. `GenerateVideoAdapter`: Orchestrator for video generation
// 4. Provider implementations: G_STABILITY_IMAGE_TO_VIDEO, G_GOOGLE_VEO_*, etc.
//
// ## Video-Specific Handling
// - Duration and FPS parameters
// - Source video for extension workflows (clientVideo)
// - Last frame support for some models
// - Progress callbacks for long-running operations
// - First frame extraction for thumbnails
//
// ## Video Extension
// Some models (Veo, Sora) support extending videos:
// - `clientVideo`: Base64 video to extend
// - `sourceMetadata`: Provider-specific metadata from original generation
// - Required metadata keys vary by model
//
// ## File Storage
// Generated videos are saved to:
// - iCloud Documents: Full video files
// - Local Documents: Thumbnail frame, client assets

import CloudKit
import Foundation
import IllustrateProviders
import OSLog
import SwiftData

// MARK: - App-Specific Video Request Type

/// Unified request format for video generation across all providers.
///
/// Captures all parameters for video generation including duration,
/// resolution, audio, and video extension data.
/// Uses ProviderKeyInfo directly - convert ProviderKey at construction using `try providerKey.toProviderKeyInfo()`.
struct VideoGenerationRequest: Codable {
    var modelId: String
    var prompt: String?
    var searchPrompt: String?
    var negativePrompt: String?
    var dimensions: String
    var clientImage: String?
    var clientMask: String?
    var clientLastFrame: String?
    var clientVideo: String?
    var clientReferenceImages: [ReferenceImageData]?
    var providerKey: ProviderKeyInfo
    var providerSecret: String
    var numberOfVideos = 1
    var motion: Int?
    var stickyness: Int?
    var durationSeconds: Int?
    var resolution: String?
    var fps: Int?
    var generateAudio: Bool?
    var steps: Int?
    var guidance: Double?
    var seed: Int?
    var safetyTolerance: Int?
    var promptEnhance: Bool?
    var moderation: String?
    var sourceMetadata: [String: String]?
    var lumaHDR: Bool?
    var lumaEXRExport: Bool?
    var lumaLoop: Bool?

    /// App-specific callback for progress updates (not sent to providers)
    var progressCallback: ((Int) -> Void)?

    enum CodingKeys: String, CodingKey {
        case modelId, prompt, searchPrompt, negativePrompt, dimensions
        case clientImage, clientMask, clientLastFrame, clientVideo, clientReferenceImages
        case providerKey, providerSecret, numberOfVideos
        case motion, stickyness, durationSeconds, resolution, fps
        case generateAudio, steps, guidance, seed, safetyTolerance, promptEnhance
        case moderation
        case sourceMetadata
        case lumaHDR, lumaEXRExport, lumaLoop
    }

    /// Convert to package's VideoGenerationRequest type
    func toProviderRequest() -> IllustrateProviders.VideoGenerationRequest {
        IllustrateProviders.VideoGenerationRequest(
            modelId: modelId,
            prompt: prompt,
            searchPrompt: searchPrompt,
            negativePrompt: negativePrompt,
            dimensions: dimensions,
            clientImage: clientImage,
            clientMask: clientMask,
            clientLastFrame: clientLastFrame,
            clientVideo: clientVideo,
            clientReferenceImages: clientReferenceImages,
            providerKey: providerKey,
            providerSecret: providerSecret,
            numberOfVideos: numberOfVideos,
            motion: motion,
            stickyness: stickyness,
            durationSeconds: durationSeconds,
            resolution: resolution,
            fps: fps,
            generateAudio: generateAudio,
            steps: steps,
            guidance: guidance,
            seed: seed,
            safetyTolerance: safetyTolerance,
            promptEnhance: promptEnhance,
            moderation: moderation,
            sourceMetadata: sourceMetadata,
            lumaHDR: lumaHDR,
            lumaEXRExport: lumaEXRExport,
            lumaLoop: lumaLoop
        )
    }
}

struct VideoSetResponse: Codable {
    var status: EnumGenerationStatus
    var set: ImageSet?
    var generations: [Generation]?
    var errorCode: EnumGenerationAdapterErrorCode?
    var errorMessage: String?
    var rawResponse: String?
}

func getVideoGenerationAdapter(modelCode: EnumProviderModelCode) -> (any VideoGenerationProtocol)? {
    switch modelCode {
    case .STABILITY_IMAGE_TO_VIDEO:
        G_STABILITY_IMAGE_TO_VIDEO()
    case .OPENAI_SORA_2:
        G_OPENAI_SORA_2()
    case .OPENAI_SORA_2_REMIX:
        G_OPENAI_SORA_2_REMIX()
    case .OPENAI_SORA_2_PRO:
        G_OPENAI_SORA_2_PRO()
    case .OPENAI_SORA_2_PRO_REMIX:
        G_OPENAI_SORA_2_PRO_REMIX()
    case .GOOGLE_VEO_31:
        G_GOOGLE_VEO_31()
    case .GOOGLE_VEO_31_EXTEND:
        G_GOOGLE_VEO_31_EXTEND()
    case .GOOGLE_VEO_31_FAST:
        G_GOOGLE_VEO_31_FAST()
    case .GOOGLE_VEO_31_FAST_EXTEND:
        G_GOOGLE_VEO_31_FAST_EXTEND()
    case .GOOGLE_VEO_3:
        G_GOOGLE_VEO_3()
    case .GOOGLE_VEO_3_FAST:
        G_GOOGLE_VEO_3_FAST()
    case .GOOGLE_VEO_2:
        G_GOOGLE_VEO_2()
    case .GOOGLE_VEO_31_LITE:
        G_GOOGLE_VEO_31_LITE()
    case .GOOGLE_GEMINI_OMNI_FLASH_VIDEO:
        G_GOOGLE_GEMINI_OMNI_FLASH_VIDEO()
    case .GOOGLE_GEMINI_OMNI_FLASH_VIDEO_EDIT:
        G_GOOGLE_GEMINI_OMNI_FLASH_VIDEO_EDIT()
    case .REPLICATE_SEEDANCE_1_PRO:
        G_REPLICATE_SEEDANCE_1_PRO()
    case .REPLICATE_SEEDANCE_1_PRO_FAST:
        G_REPLICATE_SEEDANCE_1_PRO_FAST()
    case .REPLICATE_SEEDANCE_1_LITE:
        G_REPLICATE_SEEDANCE_1_LITE()
    case .REPLICATE_SEEDANCE_1_5_PRO:
        G_REPLICATE_SEEDANCE_1_5_PRO()
    case .REPLICATE_HAILUO_02:
        G_REPLICATE_HAILUO_02()
    case .REPLICATE_HAILUO_02_FAST:
        G_REPLICATE_HAILUO_02_FAST()
    case .REPLICATE_HAILUO_2_3:
        G_REPLICATE_HAILUO_2_3()
    case .REPLICATE_HAILUO_2_3_FAST:
        G_REPLICATE_HAILUO_2_3_FAST()
    case .REPLICATE_LUMA_RAY:
        G_REPLICATE_LUMA_RAY()
    case .REPLICATE_LUMA_RAY_2_540P:
        G_REPLICATE_LUMA_RAY_2_540P()
    case .REPLICATE_LUMA_RAY_2_720P:
        G_REPLICATE_LUMA_RAY_2_720P()
    case .REPLICATE_LUMA_RAY_FLASH_2_540P:
        G_REPLICATE_LUMA_RAY_FLASH_2_540P()
    case .REPLICATE_LUMA_RAY_FLASH_2_720P:
        G_REPLICATE_LUMA_RAY_FLASH_2_720P()
    case .REPLICATE_LUMA_MODIFY_VIDEO:
        G_REPLICATE_LUMA_MODIFY_VIDEO()
    case .REPLICATE_GOOGLE_VEO_3:
        G_REPLICATE_GOOGLE_VEO_3()
    case .REPLICATE_GOOGLE_VEO_3_FAST:
        G_REPLICATE_GOOGLE_VEO_3_FAST()
    case .REPLICATE_GOOGLE_VEO_3_1:
        G_REPLICATE_GOOGLE_VEO_3_1()
    case .REPLICATE_GOOGLE_VEO_3_1_FAST:
        G_REPLICATE_GOOGLE_VEO_3_1_FAST()
    case .REPLICATE_KLING_2_5_TURBO_PRO:
        G_REPLICATE_KLING_2_5_TURBO_PRO()
    case .REPLICATE_KLING_2_6:
        G_REPLICATE_KLING_2_6()
    case .REPLICATE_WAN_2_6_I2V:
        G_REPLICATE_WAN_2_6_I2V()
    case .REPLICATE_WAN_2_6_T2V:
        G_REPLICATE_WAN_2_6_T2V()
    case .REPLICATE_WAN_2_5_I2V:
        G_REPLICATE_WAN_2_5_I2V()
    case .REPLICATE_WAN_2_5_T2V:
        G_REPLICATE_WAN_2_5_T2V()
    case .REPLICATE_WAN_2_5_I2V_FAST:
        G_REPLICATE_WAN_2_5_I2V_FAST()
    case .REPLICATE_WAN_2_5_T2V_FAST:
        G_REPLICATE_WAN_2_5_T2V_FAST()
    case .REPLICATE_OPENAI_SORA_2:
        G_REPLICATE_OPENAI_SORA_2()
    case .REPLICATE_OPENAI_SORA_2_PRO:
        G_REPLICATE_OPENAI_SORA_2_PRO()
    case .FAL_VEO_3_FAST:
        G_FAL_VEO_3_FAST()
    case .FAL_VEO_3:
        G_FAL_VEO_3()
    case .FAL_VEO_3_I2V:
        G_FAL_VEO_3_I2V()
    case .FAL_VEO_3_FAST_I2V:
        G_FAL_VEO_3_FAST_I2V()
    case .FAL_VEO_31_FAST:
        G_FAL_VEO_31_FAST()
    case .FAL_VEO_31:
        G_FAL_VEO_31()
    case .FAL_VEO_31_LITE:
        G_FAL_VEO_31_LITE()
    case .FAL_VEO_31_I2V:
        G_FAL_VEO_31_I2V()
    case .FAL_VEO_31_FAST_I2V:
        G_FAL_VEO_31_FAST_I2V()
    case .FAL_VEO_31_LITE_I2V:
        G_FAL_VEO_31_LITE_I2V()
    case .FAL_VEO_31_REF_TO_VIDEO:
        G_FAL_VEO_31_REF_TO_VIDEO()
    case .FAL_VEO_31_FIRST_LAST_FRAME:
        G_FAL_VEO_31_FIRST_LAST_FRAME()
    case .FAL_VEO_31_FAST_FIRST_LAST_FRAME:
        G_FAL_VEO_31_FAST_FIRST_LAST_FRAME()
    case .FAL_VEO_31_LITE_FIRST_LAST_FRAME:
        G_FAL_VEO_31_LITE_FIRST_LAST_FRAME()
    case .FAL_VEO_31_EXTEND:
        G_FAL_VEO_31_EXTEND()
    case .FAL_VEO_31_FAST_EXTEND:
        G_FAL_VEO_31_FAST_EXTEND()
    case .FAL_VEO_2:
        G_FAL_VEO_2()
    case .FAL_VEO_2_I2V:
        G_FAL_VEO_2_I2V()
    case .FAL_GOOGLE_GEMINI_OMNI_FLASH_T2V:
        G_FAL_GOOGLE_GEMINI_OMNI_FLASH_T2V()
    case .FAL_GOOGLE_GEMINI_OMNI_FLASH_I2V:
        G_FAL_GOOGLE_GEMINI_OMNI_FLASH_I2V()
    case .FAL_GOOGLE_GEMINI_OMNI_FLASH_REF2V:
        G_FAL_GOOGLE_GEMINI_OMNI_FLASH_REF2V()
    case .FAL_GOOGLE_GEMINI_OMNI_FLASH_EDIT:
        G_FAL_GOOGLE_GEMINI_OMNI_FLASH_EDIT()
    case .FAL_SEEDANCE_V1_PRO_T2V:
        G_FAL_SEEDANCE_V1_PRO_T2V()
    case .FAL_SEEDANCE_V1_PRO_I2V:
        G_FAL_SEEDANCE_V1_PRO_I2V()
    case .FAL_SEEDANCE_V1_PRO_FAST_T2V:
        G_FAL_SEEDANCE_V1_PRO_FAST_T2V()
    case .FAL_SEEDANCE_V1_PRO_FAST_I2V:
        G_FAL_SEEDANCE_V1_PRO_FAST_I2V()
    case .FAL_SEEDANCE_V1_LITE_T2V:
        G_FAL_SEEDANCE_V1_LITE_T2V()
    case .FAL_SEEDANCE_V1_LITE_I2V:
        G_FAL_SEEDANCE_V1_LITE_I2V()
    case .FAL_SEEDANCE_V1_LITE_REF2V:
        G_FAL_SEEDANCE_V1_LITE_REF2V()
    case .FAL_SEEDANCE_V15_PRO_T2V:
        G_FAL_SEEDANCE_V15_PRO_T2V()
    case .FAL_SEEDANCE_V15_PRO_I2V:
        G_FAL_SEEDANCE_V15_PRO_I2V()
    case .FAL_SEEDANCE_V2_T2V:
        G_FAL_SEEDANCE_V2_T2V()
    case .FAL_SEEDANCE_V2_I2V:
        G_FAL_SEEDANCE_V2_I2V()
    case .FAL_SEEDANCE_V2_REF2V:
        G_FAL_SEEDANCE_V2_REF2V()
    case .FAL_SEEDANCE_V2_FAST_T2V:
        G_FAL_SEEDANCE_V2_FAST_T2V()
    case .FAL_SEEDANCE_V2_FAST_I2V:
        G_FAL_SEEDANCE_V2_FAST_I2V()
    case .FAL_SEEDANCE_V2_FAST_REF2V:
        G_FAL_SEEDANCE_V2_FAST_REF2V()
    case .FAL_SEEDANCE_V2_MINI_T2V:
        G_FAL_SEEDANCE_V2_MINI_T2V()
    case .FAL_SEEDANCE_V2_MINI_I2V:
        G_FAL_SEEDANCE_V2_MINI_I2V()
    case .FAL_SEEDANCE_V2_MINI_REF2V:
        G_FAL_SEEDANCE_V2_MINI_REF2V()
    case .FAL_LYNX:
        G_FAL_LYNX()
    case .FAL_BYTEDANCE_BERNINI_R_T2V:
        G_FAL_BYTEDANCE_BERNINI_R_T2V()
    case .FAL_BYTEDANCE_BERNINI_R_REF2V:
        G_FAL_BYTEDANCE_BERNINI_R_REF2V()
    case .FAL_BYTEDANCE_BERNINI_R_EDIT_VIDEO:
        G_FAL_BYTEDANCE_BERNINI_R_EDIT_VIDEO()
    case .FAL_BYTEDANCE_BERNINI_R_REFERENCE_EDIT_VIDEO:
        G_FAL_BYTEDANCE_BERNINI_R_REFERENCE_EDIT_VIDEO()
    case .FAL_BYTEDANCE_DREAMACTOR_V2:
        G_FAL_BYTEDANCE_DREAMACTOR_V2()
    case .FAL_BYTEDANCE_VIDEO_UPSCALER:
        G_FAL_BYTEDANCE_VIDEO_UPSCALER()
    case .FAL_BYTEDANCE_OMNIHUMAN_V15:
        G_FAL_BYTEDANCE_OMNIHUMAN_V15()
    case .FAL_LTX_23_EXTEND:
        G_FAL_LTX_23_EXTEND()
    case .FAL_WAN_27_T2V:
        G_FAL_WAN_27_T2V()
    case .FAL_WAN_27_I2V:
        G_FAL_WAN_27_I2V()
    case .FAL_WAN_22_A14B_T2V:
        G_FAL_WAN_22_A14B_T2V()
    case .FAL_WAN_22_A14B_I2V:
        G_FAL_WAN_22_A14B_I2V()
    case .FAL_WAN_22_A14B_TURBO_T2V:
        G_FAL_WAN_22_A14B_TURBO_T2V()
    case .FAL_WAN_22_A14B_TURBO_I2V:
        G_FAL_WAN_22_A14B_TURBO_I2V()
    case .FAL_WAN_22_5B_T2V:
        G_FAL_WAN_22_5B_T2V()
    case .FAL_WAN_22_5B_I2V:
        G_FAL_WAN_22_5B_I2V()
    case .FAL_WAN_21_T2V:
        G_FAL_WAN_21_T2V()
    case .FAL_WAN_21_I2V:
        G_FAL_WAN_21_I2V()
    case .FAL_WAN_21_FLF2V:
        G_FAL_WAN_21_FLF2V()
    case .FAL_WAN_PRO_T2V:
        G_FAL_WAN_PRO_T2V()
    case .FAL_WAN_PRO_I2V:
        G_FAL_WAN_PRO_I2V()
    case .FAL_PIKA_SCENES:
        G_FAL_PIKA_SCENES()
    case .FAL_KLING_V26_PRO_T2V:
        G_FAL_KLING_V26_PRO_T2V()
    case .FAL_KLING_V26_PRO_I2V:
        G_FAL_KLING_V26_PRO_I2V()
    case .FAL_KLING_V25_TURBO_PRO_T2V:
        G_FAL_KLING_V25_TURBO_PRO_T2V()
    case .FAL_KLING_V25_TURBO_PRO_I2V:
        G_FAL_KLING_V25_TURBO_PRO_I2V()
    case .FAL_KLING_V25_TURBO_STD_I2V:
        G_FAL_KLING_V25_TURBO_STD_I2V()
    case .FAL_KLING_V21_MASTER_T2V:
        G_FAL_KLING_V21_MASTER_T2V()
    case .FAL_KLING_V21_MASTER_I2V:
        G_FAL_KLING_V21_MASTER_I2V()
    case .FAL_KLING_V21_PRO_I2V:
        G_FAL_KLING_V21_PRO_I2V()
    case .FAL_KLING_V21_STD_I2V:
        G_FAL_KLING_V21_STD_I2V()
    case .FAL_KLING_V20_MASTER_T2V:
        G_FAL_KLING_V20_MASTER_T2V()
    case .FAL_KLING_V20_MASTER_I2V:
        G_FAL_KLING_V20_MASTER_I2V()
    case .FAL_KLING_V16_PRO_T2V:
        G_FAL_KLING_V16_PRO_T2V()
    case .FAL_KLING_V16_PRO_I2V:
        G_FAL_KLING_V16_PRO_I2V()
    case .FAL_KLING_V16_STD_T2V:
        G_FAL_KLING_V16_STD_T2V()
    case .FAL_KLING_V16_STD_I2V:
        G_FAL_KLING_V16_STD_I2V()
    case .FAL_KLING_V15_PRO_T2V:
        G_FAL_KLING_V15_PRO_T2V()
    case .FAL_KLING_V15_PRO_I2V:
        G_FAL_KLING_V15_PRO_I2V()
    case .FAL_KLING_V10_PRO_T2V:
        G_FAL_KLING_V10_PRO_T2V()
    case .FAL_KLING_V10_PRO_I2V:
        G_FAL_KLING_V10_PRO_I2V()
    case .FAL_KLING_V10_STD_T2V:
        G_FAL_KLING_V10_STD_T2V()
    case .FAL_KLING_V10_STD_I2V:
        G_FAL_KLING_V10_STD_I2V()
    case .FAL_KLING_O1_I2V:
        G_FAL_KLING_O1_I2V()
    case .FAL_KLING_V3_PRO_I2V:
        G_FAL_KLING_V3_PRO_I2V()
    case .FAL_KLING_V3_PRO_T2V:
        G_FAL_KLING_V3_PRO_T2V()
    case .FAL_KLING_V3_STD_T2V:
        G_FAL_KLING_V3_STD_T2V()
    case .FAL_KLING_V3_STD_I2V:
        G_FAL_KLING_V3_STD_I2V()
    case .FAL_KLING_O1_REF2V:
        G_FAL_KLING_O1_REF2V()
    case .FAL_KLING_LIPSYNC_A2V:
        G_FAL_KLING_LIPSYNC_A2V()
    case .FAL_KLING_LIPSYNC_T2V:
        G_FAL_KLING_LIPSYNC_T2V()
    case .FAL_SORA_2_PRO_T2V:
        G_FAL_SORA_2_PRO_T2V()
    case .FAL_SORA_2_PRO_I2V:
        G_FAL_SORA_2_PRO_I2V()
    case .FAL_SORA_2_T2V:
        G_FAL_SORA_2_T2V()
    case .FAL_SORA_2_I2V:
        G_FAL_SORA_2_I2V()
    case .FAL_MINIMAX_HAILUO_23_PRO_T2V:
        G_FAL_MINIMAX_HAILUO_23_PRO_T2V()
    case .FAL_MINIMAX_HAILUO_23_PRO_I2V:
        G_FAL_MINIMAX_HAILUO_23_PRO_I2V()
    case .FAL_MINIMAX_HAILUO_23_STD_T2V:
        G_FAL_MINIMAX_HAILUO_23_STD_T2V()
    case .FAL_MINIMAX_HAILUO_23_STD_I2V:
        G_FAL_MINIMAX_HAILUO_23_STD_I2V()
    case .FAL_MINIMAX_HAILUO_23_FAST_PRO_I2V:
        G_FAL_MINIMAX_HAILUO_23_FAST_PRO_I2V()
    case .FAL_MINIMAX_HAILUO_23_FAST_STD_I2V:
        G_FAL_MINIMAX_HAILUO_23_FAST_STD_I2V()
    case .FAL_MINIMAX_HAILUO_02_PRO_T2V:
        G_FAL_MINIMAX_HAILUO_02_PRO_T2V()
    case .FAL_MINIMAX_HAILUO_02_PRO_I2V:
        G_FAL_MINIMAX_HAILUO_02_PRO_I2V()
    case .FAL_MINIMAX_HAILUO_02_STD_T2V:
        G_FAL_MINIMAX_HAILUO_02_STD_T2V()
    case .FAL_MINIMAX_HAILUO_02_STD_I2V:
        G_FAL_MINIMAX_HAILUO_02_STD_I2V()
    case .FAL_MINIMAX_VIDEO_01_I2V:
        G_FAL_MINIMAX_VIDEO_01_I2V()
    case .FAL_MINIMAX_VIDEO_01_DIRECTOR:
        G_FAL_MINIMAX_VIDEO_01_DIRECTOR()
    case .FAL_MINIMAX_VIDEO_01_DIRECTOR_I2V:
        G_FAL_MINIMAX_VIDEO_01_DIRECTOR_I2V()
    case .FAL_MINIMAX_VIDEO_01_LIVE:
        G_FAL_MINIMAX_VIDEO_01_LIVE()
    case .FAL_MINIMAX_VIDEO_01_LIVE_I2V:
        G_FAL_MINIMAX_VIDEO_01_LIVE_I2V()
    case .FAL_MINIMAX_VIDEO_01_SUBJECT_REF:
        G_FAL_MINIMAX_VIDEO_01_SUBJECT_REF()
    case .FAL_PIXVERSE_V6_T2V:
        G_FAL_PIXVERSE_V6_T2V()
    case .FAL_PIXVERSE_V6_I2V:
        G_FAL_PIXVERSE_V6_I2V()
    case .FAL_HAPPY_HORSE_T2V:
        G_FAL_HAPPY_HORSE_T2V()
    case .FAL_HAPPY_HORSE_I2V:
        G_FAL_HAPPY_HORSE_I2V()
    case .FAL_HAPPY_HORSE_REF2V:
        G_FAL_HAPPY_HORSE_REF2V()
    case .FAL_HAPPY_HORSE_V11_I2V:
        G_FAL_HAPPY_HORSE_V11_I2V()
    case .FAL_HAPPY_HORSE_V11_REF2V:
        G_FAL_HAPPY_HORSE_V11_REF2V()
    case .FAL_KLING_V3_4K_T2V:
        G_FAL_KLING_V3_4K_T2V()
    case .FAL_KLING_V3_4K_I2V:
        G_FAL_KLING_V3_4K_I2V()
    case .FAL_KLING_O3_4K_T2V:
        G_FAL_KLING_O3_4K_T2V()
    case .FAL_KLING_O3_4K_I2V:
        G_FAL_KLING_O3_4K_I2V()
    case .FAL_KLING_O3_4K_REF2V:
        G_FAL_KLING_O3_4K_REF2V()
    case .FAL_VEO_31_FAST_REF_TO_VIDEO:
        G_FAL_VEO_31_FAST_REF_TO_VIDEO()
    case .REPLICATE_SEEDANCE_2:
        G_REPLICATE_SEEDANCE_2()
    case .REPLICATE_SEEDANCE_2_MINI:
        G_REPLICATE_SEEDANCE_2_MINI()
    case .REPLICATE_XAI_GROK_IMAGINE_VIDEO:
        G_REPLICATE_XAI_GROK_IMAGINE_VIDEO()
    case .REPLICATE_KLING_V3_OMNI:
        G_REPLICATE_KLING_V3_OMNI()
    case .REPLICATE_PIXVERSE_V6:
        G_REPLICATE_PIXVERSE_V6()
    case .REPLICATE_GOOGLE_VEO_3_1_LITE:
        G_REPLICATE_GOOGLE_VEO_3_1_LITE()
    case .REPLICATE_HAPPY_HORSE_1:
        G_REPLICATE_HAPPY_HORSE_1()
    case .REPLICATE_HAPPY_HORSE_1_1:
        G_REPLICATE_HAPPY_HORSE_1_1()
    case .REPLICATE_LUMA_RAY_3_2:
        G_REPLICATE_LUMA_RAY_3_2()
    case .REPLICATE_RUNWAY_GEN_4_5:
        G_REPLICATE_RUNWAY_GEN_4_5()
    case .REPLICATE_PRUNA_P_VIDEO:
        G_REPLICATE_PRUNA_P_VIDEO()
    case .REPLICATE_WAN_2_7_T2V:
        G_REPLICATE_WAN_2_7_T2V()
    case .REPLICATE_WAN_2_7_I2V:
        G_REPLICATE_WAN_2_7_I2V()
    case .REPLICATE_VIDU_Q3_PRO:
        G_REPLICATE_VIDU_Q3_PRO()
    case .REPLICATE_VIDU_Q3_TURBO:
        G_REPLICATE_VIDU_Q3_TURBO()
    case .REPLICATE_KLING_V3_VIDEO:
        G_REPLICATE_KLING_V3_VIDEO()
    case .REPLICATE_SEEDANCE_2_FAST:
        G_REPLICATE_SEEDANCE_2_FAST()
    case .REPLICATE_PIXVERSE_V5_6:
        G_REPLICATE_PIXVERSE_V5_6()
    case .REPLICATE_WAN_2_7_R2V:
        G_REPLICATE_WAN_2_7_R2V()
    case .REPLICATE_XAI_GROK_IMAGINE_VIDEO_1_5:
        G_REPLICATE_XAI_GROK_IMAGINE_VIDEO_1_5()
    case .REPLICATE_BYTEDANCE_DREAMACTOR_M2_0:
        G_REPLICATE_BYTEDANCE_DREAMACTOR_M2_0()
    case .REPLICATE_PRUNA_P_VIDEO_ANIMATE:
        G_REPLICATE_PRUNA_P_VIDEO_ANIMATE()
    case .REPLICATE_KLING_O1:
        G_REPLICATE_KLING_O1()
    case .TOGETHER_MINIMAX_DIRECTOR:
        G_TOGETHER_MINIMAX_DIRECTOR()
    case .TOGETHER_HAILUO_02:
        G_TOGETHER_HAILUO_02()
    case .TOGETHER_VEO_2:
        G_TOGETHER_VEO_2()
    case .TOGETHER_VEO_3_FAST:
        G_TOGETHER_VEO_3_FAST()
    case .TOGETHER_SEEDANCE_LITE:
        G_TOGETHER_SEEDANCE_LITE()
    case .TOGETHER_SEEDANCE_PRO:
        G_TOGETHER_SEEDANCE_PRO()
    case .TOGETHER_SEEDANCE_2:
        G_TOGETHER_SEEDANCE_2()
    case .TOGETHER_KLING_21_PRO:
        G_TOGETHER_KLING_21_PRO()
    case .TOGETHER_WAN_27_T2V:
        G_TOGETHER_WAN_27_T2V()
    case .TOGETHER_WAN_27_I2V:
        G_TOGETHER_WAN_27_I2V()
    case .TOGETHER_PIXVERSE_V6:
        G_TOGETHER_PIXVERSE_V6()
    case .TOGETHER_SORA_2:
        G_TOGETHER_SORA_2()
    case .TOGETHER_VEO_3:
        G_TOGETHER_VEO_3()
    case .TOGETHER_VEO_31:
        G_TOGETHER_VEO_31()
    case .TOGETHER_VEO_31_LITE:
        G_TOGETHER_VEO_31_LITE()
    case .TOGETHER_VEO_3_AUDIO:
        G_TOGETHER_VEO_3_AUDIO()
    case .TOGETHER_VEO_3_FAST_AUDIO:
        G_TOGETHER_VEO_3_FAST_AUDIO()
    case .TOGETHER_KLING_21_MASTER:
        G_TOGETHER_KLING_21_MASTER()
    case .TOGETHER_KLING_21_STD:
        G_TOGETHER_KLING_21_STD()
    case .TOGETHER_KLING_20_MASTER:
        G_TOGETHER_KLING_20_MASTER()
    case .TOGETHER_KLING_16_PRO:
        G_TOGETHER_KLING_16_PRO()
    case .TOGETHER_KLING_16_STD:
        G_TOGETHER_KLING_16_STD()
    case .TOGETHER_WAN_22_T2V:
        G_TOGETHER_WAN_22_T2V()
    case .TOGETHER_WAN_22_I2V:
        G_TOGETHER_WAN_22_I2V()
    case .TOGETHER_WAN_27_R2V:
        G_TOGETHER_WAN_27_R2V()
    case .TOGETHER_VIDU_20:
        G_TOGETHER_VIDU_20()
    case .TOGETHER_VIDU_Q1:
        G_TOGETHER_VIDU_Q1()
    case .TOGETHER_VIDU_Q3:
        G_TOGETHER_VIDU_Q3()
    case .TOGETHER_VIDU_Q3_TURBO:
        G_TOGETHER_VIDU_Q3_TURBO()
    case .TOGETHER_PIXVERSE_V5:
        G_TOGETHER_PIXVERSE_V5()
    case .TOGETHER_PIXVERSE_V56:
        G_TOGETHER_PIXVERSE_V56()
    case .TOGETHER_SORA_2_PRO:
        G_TOGETHER_SORA_2_PRO()
    case .TOGETHER_HAPPY_HORSE:
        G_TOGETHER_HAPPY_HORSE()
    case .LUMA_RAY_2:
        G_LUMA_RAY_2()
    case .LUMA_RAY_FLASH_2:
        G_LUMA_RAY_FLASH_2()
    case .LUMA_RAY_2_I2V:
        G_LUMA_RAY_2_I2V()
    case .LUMA_RAY_FLASH_2_I2V:
        G_LUMA_RAY_FLASH_2_I2V()
    case .LUMA_RAY_3_2:
        G_LUMA_RAY_3_2()
    case .LUMA_RAY_3_2_KEYFRAMES:
        G_LUMA_RAY_3_2_KEYFRAMES()
    case .LUMA_RAY_3_2_EXTEND:
        G_LUMA_RAY_3_2_EXTEND()
    case .LUMA_RAY_3_2_EDIT:
        G_LUMA_RAY_3_2_EDIT()
    case .LUMA_RAY_3_2_REFRAME:
        G_LUMA_RAY_3_2_REFRAME()
    case .RUNWAY_GEN_4_5:
        G_RUNWAY_GEN_4_5()
    case .RUNWAY_GEN_4_5_I2V:
        G_RUNWAY_GEN_4_5_I2V()
    case .LTX_2_3_FAST:
        G_LTX_2_3_FAST()
    case .LTX_2_3_PRO:
        G_LTX_2_3_PRO()
    case .VERTEX_VEO_3_1:
        G_VERTEX_VEO_3_1()
    case .VERTEX_VEO_3_1_FAST:
        G_VERTEX_VEO_3_1_FAST()
    case .AZURE_SORA_2:
        G_AZURE_SORA_2()
    case .ALIBABA_WAN_2_7_T2V:
        G_ALIBABA_WAN_2_7_T2V()
    case .ALIBABA_WAN_2_7_I2V:
        G_ALIBABA_WAN_2_7_I2V()
    case .MINIMAX_HAILUO_2_3_T2V:
        G_MINIMAX_HAILUO_2_3_T2V()
    case .MINIMAX_HAILUO_2_3_I2V:
        G_MINIMAX_HAILUO_2_3_I2V()
    case .MINIMAX_HAILUO_2_3_FAST_I2V:
        G_MINIMAX_HAILUO_2_3_FAST_I2V()
    case .KLING_VIDEO_3_0_T2V:
        G_KLING_VIDEO_3_0_T2V()
    case .KLING_VIDEO_3_0_I2V:
        G_KLING_VIDEO_3_0_I2V()
    case .XAI_GROK_IMAGINE_VIDEO:
        G_XAI_GROK_IMAGINE_VIDEO()
    case .XAI_GROK_IMAGINE_VIDEO_1_5:
        G_XAI_GROK_IMAGINE_VIDEO_1_5()
    case .BYTEPLUS_DREAMINA_SEEDANCE_2_0:
        G_BYTEPLUS_DREAMINA_SEEDANCE_2_0()
    case .BYTEPLUS_DREAMINA_SEEDANCE_2_0_FAST:
        G_BYTEPLUS_DREAMINA_SEEDANCE_2_0_FAST()
    case .BYTEPLUS_DREAMINA_SEEDANCE_2_0_MINI:
        G_BYTEPLUS_DREAMINA_SEEDANCE_2_0_MINI()
    case .BYTEPLUS_SEEDANCE_1_5_PRO:
        G_BYTEPLUS_SEEDANCE_1_5_PRO()
    case .BYTEPLUS_SEEDANCE_1_0_PRO:
        G_BYTEPLUS_SEEDANCE_1_0_PRO()
    case .BYTEPLUS_SEEDANCE_1_0_PRO_FAST:
        G_BYTEPLUS_SEEDANCE_1_0_PRO_FAST()
    case .VIDU_Q3_PRO:
        G_VIDU_Q3_PRO()
    case .VIDU_Q3_TURBO:
        G_VIDU_Q3_TURBO()
    case .PIXVERSE_C1:
        G_PIXVERSE_C1()
    case .PIXVERSE_V6:
        G_PIXVERSE_V6()
    default:
        nil
    }
}

func getVideoGenerationAdapter(videoGenerationRequest: VideoGenerationRequest) throws
    -> any VideoGenerationProtocol
{
    guard let model = ProviderService.shared.model(by: videoGenerationRequest.modelId) else {
        throw NSError(domain: "Unknown model", code: -1, userInfo: nil)
    }

    guard let adapter = getVideoGenerationAdapter(modelCode: model.modelCode) else {
        throw NSError(domain: "Unknown model", code: -1, userInfo: nil)
    }
    return adapter
}

class GenerateVideoAdapter {
    let videoGenerationRequest: VideoGenerationRequest
    let modelContext: ModelContext

    init(videoGenerationRequest: VideoGenerationRequest, modelContext: ModelContext) {
        self.videoGenerationRequest = videoGenerationRequest
        self.modelContext = modelContext
    }

    func atomicRequest(
        videoGenerationRequest: VideoGenerationRequest,
        generationAdapter: any VideoGenerationProtocol
    ) async -> VideoGenerationResponse {
        AppLogger.generation
            .debug("Video atomic request started for model: \(videoGenerationRequest.modelId, privacy: .public)")

        do {
            let generation = try await generationAdapter
                .makeRequest(request: videoGenerationRequest.toProviderRequest())
            if generation.base64 == nil {
                AppLogger.generation
                    .error(
                        "Video generation returned no video data: \(generation.errorMessage ?? "unknown error", privacy: .public)"
                    )
                return VideoGenerationResponse(
                    status: EnumGenerationStatus.FAILED,
                    errorCode: generation.errorCode != nil ? generation.errorCode : EnumGenerationAdapterErrorCode
                        .GENERATOR_ERROR,
                    errorMessage: generation.errorMessage != nil ? generation.errorMessage : "Failed with unknown error"
                )
            }

            if let videoData = Data(base64Encoded: generation.base64!) {
                let uuid = UUID()
                saveVideoToiCloud(videoData: videoData, fileName: uuid.uuidString)

                let fileUrl: URL? = saveVideoToDocumentsDirectory(videoData: videoData, withName: uuid.uuidString)
                if let fileUrl {
                    if let frameImage = await extractFirstFrameFromVideoData(videoData) {
                        if let pngData = frameImage.toPNGData() {
                            _ = saveImageToDocumentsDirectory(
                                imageData: pngData,
                                withName: "\(uuid)"
                            )
                        }
                        frameImage.saveToiCloud(fileName: "\(uuid)")
                        await MediaGenerationHelper.saveOptimizedImageVersions(image: frameImage, uuid: uuid)
                    }

                    MediaGenerationHelper.saveVideoClientAssets(
                        clientImage: videoGenerationRequest.clientImage,
                        clientMask: videoGenerationRequest.clientMask,
                        clientLastFrame: videoGenerationRequest.clientLastFrame,
                        clientReferenceImages: videoGenerationRequest.clientReferenceImages,
                        clientVideo: videoGenerationRequest.clientVideo,
                        uuid: uuid
                    )

                    let actualDimensions = await getActualVideoDimensions(videoURL: fileUrl)

                    AppLogger.generation
                        .debug(
                            "Video atomic request complete - id: \(uuid.uuidString, privacy: .public), dimensions: \(actualDimensions ?? "unknown", privacy: .public)"
                        )

                    return VideoGenerationResponse(
                        generationId: uuid,
                        status: EnumGenerationStatus.GENERATED,
                        base64: nil,
                        size: getVideoSizeInBytes(videoURL: fileUrl),
                        cost: generation.cost,
                        modelPrompt: generation.modelPrompt,
                        colorPalette: [],

                        metadata: generation.metadata,
                        actualDimensions: actualDimensions
                    )
                } else {
                    AppLogger.generation.error("Failed to save video to documents directory")
                    return VideoGenerationResponse(
                        status: EnumGenerationStatus.FAILED,
                        errorCode: .GENERATOR_ERROR,
                        errorMessage: "Could not save video"
                    )
                }
            } else {
                AppLogger.generation.error("Failed to decode base64 video data")
                return VideoGenerationResponse(
                    status: EnumGenerationStatus.FAILED,
                    errorCode: .GENERATOR_ERROR,
                    errorMessage: "Could not decode base64"
                )
            }
        } catch {
            AppLogger.generation.error("Video atomic request failed: \(error.localizedDescription, privacy: .public)")
            return VideoGenerationResponse(
                status: EnumGenerationStatus.FAILED,
                errorCode: EnumGenerationAdapterErrorCode.GENERATOR_ERROR,
                errorMessage: "Failed with error: \(error.localizedDescription)"
            )
        }
    }

    func makeRequest() async -> VideoSetResponse {
        let modelId = videoGenerationRequest.modelId
        let dimensions = videoGenerationRequest.dimensions
        let count = videoGenerationRequest.numberOfVideos
        AppLogger.generation
            .info(
                "Starting video generation - model: \(modelId, privacy: .public), dimensions: \(dimensions, privacy: .public), count: \(count, privacy: .public)"
            )

        do {
            let generationAdapter: any VideoGenerationProtocol =
                try getVideoGenerationAdapter(videoGenerationRequest: videoGenerationRequest)

            var videoGenerationResponses: [VideoGenerationResponse] = []
            await withTaskGroup(of: VideoGenerationResponse?.self) { group in
                for _ in 0 ..< videoGenerationRequest.numberOfVideos {
                    group.addTask {
                        await self.atomicRequest(
                            videoGenerationRequest: self.videoGenerationRequest,
                            generationAdapter: generationAdapter
                        )
                    }
                }

                for await generation in group {
                    if let generation {
                        videoGenerationResponses.append(generation)
                    }
                }
            }

            if videoGenerationResponses.isEmpty {
                AppLogger.generation.error("No video generations were successful")
                return VideoSetResponse(
                    status: EnumGenerationStatus.FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.GENERATOR_ERROR,
                    errorMessage: "No generation was successful"
                )
            }

            for generation in videoGenerationResponses {
                if generation.status == EnumGenerationStatus.FAILED || generation.generationId == nil {
                    AppLogger.generation
                        .error(
                            "Video generation failed: \(generation.errorMessage ?? "unknown error", privacy: .public)"
                        )
                    return VideoSetResponse(
                        status: EnumGenerationStatus.FAILED,
                        errorCode: generation.errorCode ?? EnumGenerationAdapterErrorCode.GENERATOR_ERROR,
                        errorMessage: generation.errorMessage ?? "Failed with unknown error"
                    )
                }
            }

            guard let usedModel = ProviderService.shared.model(by: videoGenerationRequest.modelId) else {
                AppLogger.generation.error("Model not found: \(modelId, privacy: .public)")
                return VideoSetResponse(
                    status: EnumGenerationStatus.FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "Model not found for ID: \(videoGenerationRequest.modelId)"
                )
            }

            // Prepare generation data for MainActor (all Sendable types)
            let generationData: [(
                id: UUID,
                actualDimensions: String,
                size: Int,
                cost: Double,
                status: EnumGenerationStatus,
                colorPalette: [String],
                modelPrompt: String?,
                metadata: [String: String]
            )] = videoGenerationResponses.map { gen in
                var mergedMetadata = gen.metadata ?? [:]

                if let previousInteractionId = videoGenerationRequest
                    .sourceMetadata?[GeminiInteractionMetadataKey.interactionId]
                {
                    mergedMetadata[GeminiInteractionMetadataKey.previousInteractionId] = previousInteractionId
                }

                for key in ["source_generation_id", "source_generation_set_id", "source_model_code"] {
                    if let value = videoGenerationRequest.sourceMetadata?[key], !value.isEmpty {
                        mergedMetadata[key] = value
                    }
                }

                if let actualDims = gen.actualDimensions, actualDims != videoGenerationRequest.dimensions {
                    mergedMetadata["requested_dimensions"] = videoGenerationRequest.dimensions
                }
                if let durationSeconds = videoGenerationRequest.durationSeconds {
                    mergedMetadata["duration_seconds"] = String(durationSeconds)
                }
                if let resolution = videoGenerationRequest.resolution {
                    mergedMetadata["resolution"] = resolution
                }
                if let fps = videoGenerationRequest.fps {
                    mergedMetadata["fps"] = String(fps)
                }
                if let motion = videoGenerationRequest.motion {
                    mergedMetadata["motion"] = String(motion)
                }
                if let stickyness = videoGenerationRequest.stickyness {
                    mergedMetadata["stickyness"] = String(stickyness)
                }
                if let generateAudio = videoGenerationRequest.generateAudio {
                    mergedMetadata["audio_generated"] = generateAudio ? "Yes" : "No"
                }
                if let seed = videoGenerationRequest.seed {
                    mergedMetadata["seed"] = String(seed)
                }
                if let steps = videoGenerationRequest.steps {
                    mergedMetadata["steps"] = String(steps)
                }
                if let guidance = videoGenerationRequest.guidance {
                    mergedMetadata["guidance"] = String(format: "%.2f", guidance)
                }
                if let safetyTolerance = videoGenerationRequest.safetyTolerance {
                    mergedMetadata["safety_tolerance"] = String(safetyTolerance)
                }
                if let promptEnhance = videoGenerationRequest.promptEnhance {
                    mergedMetadata["prompt_enhance"] = promptEnhance ? "Yes" : "No"
                }

                return (
                    id: gen.generationId!,
                    actualDimensions: gen.actualDimensions ?? videoGenerationRequest.dimensions,
                    size: gen.size ?? 0,
                    cost: gen.cost ?? 0,
                    status: gen.status,
                    colorPalette: gen.colorPalette ?? [],
                    modelPrompt: gen.modelPrompt,
                    metadata: mergedMetadata
                )
            }

            let setType = usedModel.modelSetType
            let request = videoGenerationRequest

            return await MainActor.run {
                let set = ImageSet(
                    prompt: request.prompt ?? "",
                    projectId: request.providerKey.projectId,
                    modelId: request.modelId,
                    dimensions: request.dimensions,
                    setType: setType,
                    negativePrompt: request.negativePrompt,
                    searchPrompt: request.searchPrompt
                )

                modelContext.insert(set)

                let generations: [Generation] = generationData.map { data in
                    let generation = Generation(
                        id: data.id,
                        setId: set.id,
                        projectId: request.providerKey.projectId,
                        modelId: request.modelId,
                        prompt: request.prompt ?? "",
                        promptEnhanceOpted: request.promptEnhance ?? false,
                        promptAfterEnhance: "",
                        dimensions: data.actualDimensions,
                        size: data.size,
                        creditUsed: data.cost,
                        status: data.status,
                        colorPalette: data.colorPalette,
                        modelRevisedPrompt: data.modelPrompt,
                        clientImage: request.clientImage,
                        clientMask: nil,
                        clientReferenceImagesCount: request.clientReferenceImages?.count ?? 0,
                        negativePrompt: request.negativePrompt,
                        searchPrompt: request.searchPrompt,
                        contentType: EnumGenerationContentType.VIDEO,
                        // Not stored to reduce database size
                        metadata: data.metadata
                    )
                    modelContext.insert(generation)
                    return generation
                }

                // Let SwiftData's autosave handle persistence to reduce WAL checkpoint contention
                // The autosave batches changes efficiently, avoiding the "Database busy" issues
                // that occur with frequent explicit saves during concurrent operations
                NotificationCenter.default.post(name: .generationCreated, object: nil)

                AppLogger.generation
                    .notice(
                        "Video generation complete - setId: \(set.id.uuidString, privacy: .public), count: \(generations.count, privacy: .public)"
                    )

                return VideoSetResponse(
                    status: EnumGenerationStatus.GENERATED,
                    set: set,
                    generations: generations
                )
            }

        } catch {
            AppLogger.generation.error("Video generation failed: \(error.localizedDescription, privacy: .public)")
            return VideoSetResponse(
                status: EnumGenerationStatus.FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Failed with error: \(error.localizedDescription)"
            )
        }
    }
}
