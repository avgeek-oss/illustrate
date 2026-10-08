// MARK: - VideoAdapterFactoryTests.swift

// Tests for getVideoGenerationAdapter(modelCode:) factory function.
//
// Validates that all video model codes return non-nil adapters and that
// image-only model codes return nil. Covers all 5 providers:
// Stability AI, OpenAI, Google, Replicate, and Fal.

import IllustrateProviders
import XCTest
@testable import Illustrate

final class VideoAdapterFactoryTests: XCTestCase {
    // MARK: - Stability AI

    func testFactory_StabilityImageToVideo_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .STABILITY_IMAGE_TO_VIDEO))
    }

    // MARK: - OpenAI

    func testFactory_OpenAISora2_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .OPENAI_SORA_2))
    }

    func testFactory_OpenAISora2Extend_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .OPENAI_SORA_2_REMIX))
    }

    func testFactory_OpenAISora2Pro_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .OPENAI_SORA_2_PRO))
    }

    func testFactory_OpenAISora2ProExtend_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .OPENAI_SORA_2_PRO_REMIX))
    }

    // MARK: - Google

    func testFactory_GoogleVeo31_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .GOOGLE_VEO_31))
    }

    func testFactory_GoogleVeo31Extend_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .GOOGLE_VEO_31_EXTEND))
    }

    func testFactory_GoogleVeo31Fast_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .GOOGLE_VEO_31_FAST))
    }

    func testFactory_GoogleVeo31FastExtend_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .GOOGLE_VEO_31_FAST_EXTEND))
    }

    func testFactory_GoogleVeo3_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .GOOGLE_VEO_3))
    }

    func testFactory_GoogleVeo3Fast_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .GOOGLE_VEO_3_FAST))
    }

    func testFactory_GoogleVeo2_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .GOOGLE_VEO_2))
    }

    func testFactory_GoogleGeminiOmniFlash_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .GOOGLE_GEMINI_OMNI_FLASH_VIDEO))
    }

    func testFactory_GoogleGeminiOmniFlashEdit_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .GOOGLE_GEMINI_OMNI_FLASH_VIDEO_EDIT))
    }

    // MARK: - Replicate Seedance

    func testFactory_ReplicateSeedance1Pro_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_SEEDANCE_1_PRO))
    }

    func testFactory_ReplicateSeedance1ProFast_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_SEEDANCE_1_PRO_FAST))
    }

    func testFactory_ReplicateSeedance1Lite_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_SEEDANCE_1_LITE))
    }

    func testFactory_ReplicateSeedance15Pro_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_SEEDANCE_1_5_PRO))
    }

    // MARK: - Replicate Hailuo

    func testFactory_ReplicateHailuo02_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_HAILUO_02))
    }

    func testFactory_ReplicateHailuo02Fast_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_HAILUO_02_FAST))
    }

    func testFactory_ReplicateHailuo23_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_HAILUO_2_3))
    }

    func testFactory_ReplicateHailuo23Fast_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_HAILUO_2_3_FAST))
    }

    // MARK: - Replicate Luma

    func testFactory_ReplicateLumaRay_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_LUMA_RAY))
    }

    func testFactory_ReplicateLumaRay2540p_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_LUMA_RAY_2_540P))
    }

    func testFactory_ReplicateLumaRay2720p_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_LUMA_RAY_2_720P))
    }

    func testFactory_ReplicateLumaRay32_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_LUMA_RAY_3_2))
    }

    func testFactory_ReplicateLumaModifyVideo_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_LUMA_MODIFY_VIDEO))
    }

    // MARK: - Luma AI

    func testFactory_LumaRay32_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .LUMA_RAY_3_2))
    }

    func testFactory_LumaRay32Keyframes_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .LUMA_RAY_3_2_KEYFRAMES))
    }

    func testFactory_LumaRay32Extend_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .LUMA_RAY_3_2_EXTEND))
    }

    func testFactory_LumaRay32Edit_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .LUMA_RAY_3_2_EDIT))
    }

    func testFactory_LumaRay32Reframe_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .LUMA_RAY_3_2_REFRAME))
    }

    // MARK: - Replicate Kling & Wan

    func testFactory_ReplicateKling26_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_KLING_2_6))
    }

    func testFactory_ReplicateWan26T2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_WAN_2_6_T2V))
    }

    func testFactory_ReplicateWan26I2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_WAN_2_6_I2V))
    }

    func testFactory_ReplicateWan25T2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_WAN_2_5_T2V))
    }

    func testFactory_ReplicateWan25I2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_WAN_2_5_I2V))
    }

    // MARK: - Replicate 2026 Video Refresh

    func testFactory_ReplicateSeedance2Mini_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_SEEDANCE_2_MINI))
    }

    func testFactory_ReplicateHappyHorse11_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_HAPPY_HORSE_1_1))
    }

    func testFactory_ReplicateViduQ3Turbo_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_VIDU_Q3_TURBO))
    }

    // MARK: - Replicate Google & OpenAI via Replicate

    func testFactory_ReplicateGoogleVeo3_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_GOOGLE_VEO_3))
    }

    func testFactory_ReplicateGoogleVeo31_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_GOOGLE_VEO_3_1))
    }

    func testFactory_ReplicateOpenAISora2_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_OPENAI_SORA_2))
    }

    func testFactory_ReplicateOpenAISora2Pro_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .REPLICATE_OPENAI_SORA_2_PRO))
    }

    // MARK: - Together AI

    func testFactory_TogetherSeedance20_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .TOGETHER_SEEDANCE_2))
    }

    func testFactory_TogetherWan27_ReturnsAdapters() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .TOGETHER_WAN_27_T2V))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .TOGETHER_WAN_27_I2V))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .TOGETHER_WAN_27_R2V))
    }

    func testFactory_TogetherVeo31_ReturnsAdapters() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .TOGETHER_VEO_31))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .TOGETHER_VEO_31_LITE))
    }

    // MARK: - Fal VEO

    func testFactory_FalVeo3_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_VEO_3))
    }

    func testFactory_FalVeo3Fast_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_VEO_3_FAST))
    }

    func testFactory_FalVeo3I2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_VEO_3_I2V))
    }

    func testFactory_FalVeo31_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_VEO_31))
    }

    func testFactory_FalVeo31Fast_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_VEO_31_FAST))
    }

    func testFactory_FalVeo31LiteAndExtend_ReturnsAdapters() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_VEO_31_LITE))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_VEO_31_LITE_I2V))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_VEO_31_LITE_FIRST_LAST_FRAME))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_VEO_31_EXTEND))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_VEO_31_FAST_EXTEND))
    }

    func testFactory_FalVeo2_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_VEO_2))
    }

    func testFactory_FalGoogleGeminiOmniFlash_ReturnsAdapters() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_GOOGLE_GEMINI_OMNI_FLASH_I2V))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_GOOGLE_GEMINI_OMNI_FLASH_REF2V))
    }

    // MARK: - Fal Seedance

    func testFactory_FalSeedanceV1ProT2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_SEEDANCE_V1_PRO_T2V))
    }

    func testFactory_FalSeedanceV15ProT2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_SEEDANCE_V15_PRO_T2V))
    }

    func testFactory_FalSeedanceV15ProI2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_SEEDANCE_V15_PRO_I2V))
    }

    func testFactory_FalSeedanceV2MiniT2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_SEEDANCE_V2_MINI_T2V))
    }

    func testFactory_FalSeedanceV2MiniI2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_SEEDANCE_V2_MINI_I2V))
    }

    func testFactory_FalSeedanceV2MiniRef2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_SEEDANCE_V2_MINI_REF2V))
    }

    // MARK: - Fal Kling

    func testFactory_FalKlingV26ProT2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_KLING_V26_PRO_T2V))
    }

    func testFactory_FalKlingV26ProI2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_KLING_V26_PRO_I2V))
    }

    func testFactory_FalKlingV25TurboProT2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_KLING_V25_TURBO_PRO_T2V))
    }

    func testFactory_FalKlingV21MasterT2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_KLING_V21_MASTER_T2V))
    }

    func testFactory_FalKlingO1I2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_KLING_O1_I2V))
    }

    func testFactory_FalKlingLipsyncA2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_KLING_LIPSYNC_A2V))
    }

    // MARK: - Fal Wan

    func testFactory_FalWan27_ReturnsAdapters() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_WAN_27_T2V))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_WAN_27_I2V))
    }

    func testFactory_FalWan22A14BT2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_WAN_22_A14B_T2V))
    }

    func testFactory_FalWan21T2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_WAN_21_T2V))
    }

    func testFactory_FalWanProT2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_WAN_PRO_T2V))
    }

    // MARK: - Fal Minimax/Hailuo

    func testFactory_FalMinimaxHailuo23ProT2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_MINIMAX_HAILUO_23_PRO_T2V))
    }

    func testFactory_FalMinimaxHailuo23ProI2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_MINIMAX_HAILUO_23_PRO_I2V))
    }

    func testFactory_FalMinimaxHailuo02ProT2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_MINIMAX_HAILUO_02_PRO_T2V))
    }

    func testFactory_FalMinimaxVideo01I2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_MINIMAX_VIDEO_01_I2V))
    }

    // MARK: - Fal Other

    func testFactory_FalPikaScenes_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_PIKA_SCENES))
    }

    func testFactory_FalLynx_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_LYNX))
    }

    func testFactory_FalSora2ProT2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_SORA_2_PRO_T2V))
    }

    func testFactory_FalSora2T2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_SORA_2_T2V))
    }

    func testFactory_FalPixverseV6T2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_PIXVERSE_V6_T2V))
    }

    func testFactory_FalHappyHorseV11I2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_HAPPY_HORSE_V11_I2V))
    }

    func testFactory_FalHappyHorseV11Ref2V_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .FAL_HAPPY_HORSE_V11_REF2V))
    }

    // MARK: - Runway

    func testFactory_RunwayGen45_ReturnsAdapters() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .RUNWAY_GEN_4_5))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .RUNWAY_GEN_4_5_I2V))
    }

    // MARK: - LTX

    func testFactory_LTX23_ReturnsAdapters() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .LTX_2_3_FAST))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .LTX_2_3_PRO))
    }

    func testFactory_AlibabaWan27_ReturnsAdapters() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .ALIBABA_WAN_2_7_T2V))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .ALIBABA_WAN_2_7_I2V))
    }

    func testFactory_MiniMaxHailuo23_ReturnsAdapters() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .MINIMAX_HAILUO_2_3_T2V))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .MINIMAX_HAILUO_2_3_I2V))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .MINIMAX_HAILUO_2_3_FAST_I2V))
    }

    func testFactory_KlingVideo30_ReturnsAdapters() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .KLING_VIDEO_3_0_T2V))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .KLING_VIDEO_3_0_I2V))
    }

    // MARK: - xAI

    func testFactory_XAIGrokImagineVideo_ReturnsAdapters() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .XAI_GROK_IMAGINE_VIDEO))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .XAI_GROK_IMAGINE_VIDEO_1_5))
    }

    func testFactory_BytePlusSeedance_ReturnsAdapters() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .BYTEPLUS_DREAMINA_SEEDANCE_2_0))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .BYTEPLUS_DREAMINA_SEEDANCE_2_0_FAST))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .BYTEPLUS_DREAMINA_SEEDANCE_2_0_MINI))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .BYTEPLUS_SEEDANCE_1_5_PRO))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .BYTEPLUS_SEEDANCE_1_0_PRO))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .BYTEPLUS_SEEDANCE_1_0_PRO_FAST))
    }

    func testFactory_ViduQ3_ReturnsAdapters() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .VIDU_Q3_PRO))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .VIDU_Q3_TURBO))
    }

    func testFactory_PixVerse_ReturnsAdapters() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .PIXVERSE_C1))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .PIXVERSE_V6))
    }

    func testFactory_VertexVeo31_ReturnsAdapters() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .VERTEX_VEO_3_1))
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .VERTEX_VEO_3_1_FAST))
    }

    func testFactory_AzureSora2_ReturnsAdapter() {
        XCTAssertNotNil(getVideoGenerationAdapter(modelCode: .AZURE_SORA_2))
    }

    // MARK: - Image-Only Model Codes Return Nil

    func testFactory_ImageOnlyModel_DallE3_ReturnsNil() {
        XCTAssertNil(getVideoGenerationAdapter(modelCode: .OPENAI_DALLE3))
    }

    func testFactory_ImageOnlyModel_StabilitySD35_ReturnsNil() {
        XCTAssertNil(getVideoGenerationAdapter(modelCode: .STABILITY_SD35_LARGE))
    }

    func testFactory_ImageOnlyModel_GoogleImagen3_ReturnsNil() {
        XCTAssertNil(getVideoGenerationAdapter(modelCode: .GOOGLE_IMAGEN_3))
    }
}
