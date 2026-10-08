// MARK: - GenerateImageAdapter.swift

// Core adapter for image generation across all providers.
//
// This file defines the image generation request/response types and the
// adapter that orchestrates image generation across different AI providers.

import CloudKit
import Foundation
import IllustrateProviders
import OSLog
import SwiftData

// MARK: - Request Type Alias

/// Use the package's ImageGenerationRequest type directly.
/// At construction sites, convert ProviderKey using: `try providerKey.toProviderKeyInfo()`
typealias ImageGenerationRequest = IllustrateProviders.ImageGenerationRequest

struct ImageSetResponse: Codable {
    var status: EnumGenerationStatus
    var set: ImageSet?
    var generations: [Generation]?
    var errorCode: EnumGenerationAdapterErrorCode?
    var errorMessage: String?
    var rawResponse: String?
}

/// Creates an "Invalid response" error and logs the response data for debugging.
/// Use this helper when the API returns a response that doesn't match the expected format.
/// - Parameters:
///   - response: The NetworkResponseData that couldn't be parsed
///   - modelCode: The model code for log identification
///   - customMessage: Optional custom error message (defaults to "Invalid response")
func createInvalidResponseError(
    response: NetworkResponseData,
    modelCode: EnumProviderModelCode,
    customMessage: String = "Invalid response"
) -> ImageGenerationResponse {
    switch response {
    case let .dictionary(statusCode, _):
        AppLogger.provider
            .error(
                "[\(String(describing: modelCode), privacy: .public)] \(customMessage, privacy: .public) - Status: \(statusCode, privacy: .public)"
            )
    case let .array(statusCode, _):
        AppLogger.provider
            .error(
                "[\(String(describing: modelCode), privacy: .public)] \(customMessage, privacy: .public) - Status: \(statusCode, privacy: .public)"
            )
    case let .image(statusCode, _, mimeType):
        AppLogger.provider
            .error(
                "[\(String(describing: modelCode), privacy: .public)] \(customMessage, privacy: .public) - Status: \(statusCode, privacy: .public), mimeType: \(mimeType, privacy: .public)"
            )
    }

    return ImageGenerationResponse(
        status: .FAILED,
        errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
        errorMessage: customMessage,
        rawResponse: response.rawResponseString
    )
}

func getImageGenerationAdapter(modelCode: EnumProviderModelCode) -> (any ImageGenerationProtocol)? {
    switch modelCode {
    case .OPENAI_DALLE3:
        G_OPENAI_DALLE_3()
    case .OPENAI_GPT_IMAGE_1:
        G_OPENAI_GPT_IMAGE_1()
    case .OPENAI_GPT_IMAGE_1_MINI:
        G_OPENAI_GPT_IMAGE_1_MINI()
    case .OPENAI_GPT_IMAGE_1_5:
        G_OPENAI_GPT_IMAGE_1_5()
    case .OPENAI_GPT_IMAGE_2:
        G_OPENAI_GPT_IMAGE_2()
    case .STABILITY_CORE:
        G_STABILITY_CORE()
    case .STABILITY_SDXL:
        G_STABILITY_SDXL()
    case .STABILITY_ULTRA:
        G_STABILITY_ULTRA()
    case .STABILITY_SD3, .STABILITY_SD3_TURBO, .STABILITY_SD35_LARGE, .STABILITY_SD35_LARGE_TURBO,
         .STABILITY_SD35_MEDIUM, .STABILITY_SD35_FLASH:
        G_STABILITY_SD3(modelCode: modelCode)
    case .STABILITY_CREATIVE_UPSCALE:
        G_STABILITY_CREATIVE_UPSCALE()
    case .STABILITY_CONSERVATIVE_UPSCALE:
        G_STABILITY_CONSERVATIVE_UPSCALE()
    case .STABILITY_FAST_UPSCALE:
        G_STABILITY_FAST_UPSCALE()
    case .STABILITY_OUTPAINT:
        G_STABILITY_OUTPAINT()
    case .STABILITY_INPAINT:
        G_STABILITY_INPAINT()
    case .STABILITY_ERASE:
        G_STABILITY_ERASE()
    case .STABILITY_SEARCH_AND_REPLACE:
        G_STABILITY_SEARCH_AND_REPLACE()
    case .STABILITY_SEARCH_AND_RECOLOR:
        G_STABILITY_SEARCH_AND_RECOLOR()
    case .STABILITY_REMOVE_BACKGROUND:
        G_STABILITY_REMOVE_BACKGROUND()
    case .REPLICATE_FLUX_SCHNELL:
        G_REPLICATE_FLUX_SCHNELL()
    case .REPLICATE_FLUX_DEV:
        G_REPLICATE_FLUX_DEV()
    case .REPLICATE_FLUX_PRO:
        G_REPLICATE_FLUX_PRO()
    case .REPLICATE_SEEDREAM_3:
        G_REPLICATE_SEEDREAM_3()
    case .REPLICATE_SEEDREAM_4:
        G_REPLICATE_SEEDREAM_4()
    case .REPLICATE_SEEDREAM_4_5:
        G_REPLICATE_SEEDREAM_4_5()
    case .REPLICATE_DREAMINA_3_1:
        G_REPLICATE_DREAMINA_3_1()
    case .REPLICATE_FLUX_2_FLEX:
        G_REPLICATE_FLUX_2_FLEX()
    case .REPLICATE_FLUX_2_PRO:
        G_REPLICATE_FLUX_2_PRO()
    case .REPLICATE_FLUX_2_KLEIN:
        G_REPLICATE_FLUX_2_KLEIN()
    case .REPLICATE_FLUX_2_MAX:
        G_REPLICATE_FLUX_2_MAX()
    case .REPLICATE_FLUX_2_DEV:
        G_REPLICATE_FLUX_2_DEV()
    case .REPLICATE_FLUX_KREA_DEV:
        G_REPLICATE_FLUX_KREA_DEV()
    case .REPLICATE_KREA_2_MEDIUM:
        G_REPLICATE_KREA_2_MEDIUM()
    case .REPLICATE_KREA_2_LARGE:
        G_REPLICATE_KREA_2_LARGE()
    case .REPLICATE_FLUX_KONTEXT_MAX:
        G_REPLICATE_FLUX_KONTEXT_MAX()
    case .REPLICATE_FLUX_KONTEXT_DEV:
        G_REPLICATE_FLUX_KONTEXT_DEV()
    case .REPLICATE_FLUX_KONTEXT_PRO:
        G_REPLICATE_FLUX_KONTEXT_PRO()
    case .REPLICATE_QWEN_IMAGE:
        G_REPLICATE_QWEN_IMAGE()
    case .REPLICATE_QWEN_IMAGE_2:
        G_REPLICATE_QWEN_IMAGE_2()
    case .REPLICATE_QWEN_IMAGE_2_PRO:
        G_REPLICATE_QWEN_IMAGE_2_PRO()
    case .REPLICATE_REVE_2_1:
        G_REPLICATE_REVE_2_1()
    case .REPLICATE_QWEN_IMAGE_EDIT:
        G_REPLICATE_QWEN_IMAGE_EDIT()
    case .REPLICATE_QWEN_IMAGE_EDIT_PLUS:
        G_REPLICATE_QWEN_IMAGE_EDIT_PLUS()
    case .REPLICATE_QWEN_IMAGE_EDIT_2511:
        G_REPLICATE_QWEN_IMAGE_EDIT_2511()
    case .REPLICATE_QWEN_IMAGE_EDIT_2512:
        G_REPLICATE_QWEN_IMAGE_EDIT_2512()
    case .REPLICATE_MINIMAX_IMAGE_01:
        G_REPLICATE_MINIMAX_IMAGE_01()
    case .REPLICATE_LUMA_PHOTON:
        G_REPLICATE_LUMA_PHOTON()
    case .REPLICATE_LUMA_PHOTON_FLASH:
        G_REPLICATE_LUMA_PHOTON_FLASH()
    case .REPLICATE_STABLE_DIFFUSION_3:
        G_REPLICATE_STABLE_DIFFUSION_3()
    case .REPLICATE_STABLE_DIFFUSION_3_5_LARGE:
        G_REPLICATE_STABLE_DIFFUSION_3_5_LARGE()
    case .REPLICATE_STABLE_DIFFUSION_3_5_LARGE_TURBO:
        G_REPLICATE_STABLE_DIFFUSION_3_5_LARGE_TURBO()
    case .REPLICATE_STABLE_DIFFUSION_3_5_MEDIUM:
        G_REPLICATE_STABLE_DIFFUSION_3_5_MEDIUM()
    case .REPLICATE_GOOGLE_NANO_BANANA:
        G_REPLICATE_GOOGLE_NANO_BANANA()
    case .REPLICATE_GOOGLE_NANO_BANANA_PRO:
        G_REPLICATE_GOOGLE_NANO_BANANA_PRO()
    case .REPLICATE_GOOGLE_GEMINI_2_5_FLASH_IMAGE:
        G_REPLICATE_GOOGLE_GEMINI_2_5_FLASH_IMAGE()
    case .REPLICATE_GOOGLE_IMAGEN_3:
        G_REPLICATE_GOOGLE_IMAGEN_3()
    case .REPLICATE_GOOGLE_IMAGEN_3_FAST:
        G_REPLICATE_GOOGLE_IMAGEN_3_FAST()
    case .REPLICATE_GOOGLE_IMAGEN_4:
        G_REPLICATE_GOOGLE_IMAGEN_4()
    case .REPLICATE_GOOGLE_IMAGEN_4_FAST:
        G_REPLICATE_GOOGLE_IMAGEN_4_FAST()
    case .REPLICATE_GOOGLE_IMAGEN_4_ULTRA:
        G_REPLICATE_GOOGLE_IMAGEN_4_ULTRA()
    case .REPLICATE_PRUNA_P_IMAGE:
        G_REPLICATE_PRUNA_P_IMAGE()
    case .REPLICATE_PRUNA_P_IMAGE_EDIT:
        G_REPLICATE_PRUNA_P_IMAGE_EDIT()
    case .REPLICATE_PRUNA_FLUX_FAST:
        G_REPLICATE_PRUNA_FLUX_FAST()
    case .REPLICATE_PRUNA_FLUX_KONTEXT_FAST:
        G_REPLICATE_PRUNA_FLUX_KONTEXT_FAST()
    case .REPLICATE_PRUNA_Z_IMAGE_TURBO:
        G_REPLICATE_PRUNA_Z_IMAGE_TURBO()
    case .REPLICATE_PRUNA_Z_IMAGE_TURBO_I2I:
        G_REPLICATE_PRUNA_Z_IMAGE_TURBO_I2I()
    case .REPLICATE_OPENAI_GPT_IMAGE_1_5:
        G_REPLICATE_OPENAI_GPT_IMAGE_1_5()
    case .REPLICATE_OPENAI_GPT_IMAGE_2:
        G_REPLICATE_OPENAI_GPT_IMAGE_2()
    case .REPLICATE_OPENAI_DALL_E_3:
        G_REPLICATE_OPENAI_DALL_E_3()
    case .REPLICATE_OPENAI_DALL_E_2:
        G_REPLICATE_OPENAI_DALL_E_2()
    case .FAL_FLUX_SCHNELL:
        G_FAL_FLUX_SCHNELL()
    case .FAL_FLUX_DEV:
        G_FAL_FLUX_DEV()
    case .FAL_FLUX_PRO:
        G_FAL_FLUX_PRO()
    case .FAL_FLUX_DEV_IMAGE_TO_IMAGE:
        G_FAL_FLUX_DEV_IMAGE_TO_IMAGE()
    case .FAL_FLUX_DEV_REDUX:
        G_FAL_FLUX_DEV_REDUX()
    case .FAL_FLUX_SCHNELL_REDUX:
        G_FAL_FLUX_SCHNELL_REDUX()
    case .FAL_FLUX_2:
        G_FAL_FLUX_2()
    case .FAL_FLUX_2_PRO:
        G_FAL_FLUX_2_PRO()
    case .FAL_FLUX_2_PRO_EDIT:
        G_FAL_FLUX_2_PRO_EDIT()
    case .FAL_FLUX_2_EDIT:
        G_FAL_FLUX_2_EDIT()
    case .FAL_FLUX_2_FLEX:
        G_FAL_FLUX_2_FLEX()
    case .FAL_FLUX_2_FLEX_EDIT:
        G_FAL_FLUX_2_FLEX_EDIT()
    case .FAL_FLUX_2_MAX:
        G_FAL_FLUX_2_MAX()
    case .FAL_FLUX_2_MAX_EDIT:
        G_FAL_FLUX_2_MAX_EDIT()
    case .FAL_FLUX_2_TURBO:
        G_FAL_FLUX_2_TURBO()
    case .FAL_FLUX_2_TURBO_EDIT:
        G_FAL_FLUX_2_TURBO_EDIT()
    case .FAL_FLUX_2_KLEIN_4B:
        G_FAL_FLUX_2_KLEIN_4B()
    case .FAL_FLUX_2_KLEIN_4B_EDIT:
        G_FAL_FLUX_2_KLEIN_4B_EDIT()
    case .FAL_FLUX_2_KLEIN_9B:
        G_FAL_FLUX_2_KLEIN_9B()
    case .FAL_FLUX_2_FLASH:
        G_FAL_FLUX_2_FLASH()
    case .FAL_FLUX_2_FLASH_EDIT:
        G_FAL_FLUX_2_FLASH_EDIT()
    case .FAL_FLUX_KONTEXT_DEV:
        G_FAL_FLUX_KONTEXT_DEV()
    case .FAL_FLUX_PRO_KONTEXT:
        G_FAL_FLUX_PRO_KONTEXT()
    case .FAL_FLUX_PRO_KONTEXT_MAX:
        G_FAL_FLUX_PRO_KONTEXT_MAX()
    case .FAL_FLUX_PRO_KONTEXT_T2I:
        G_FAL_FLUX_PRO_KONTEXT_T2I()
    case .FAL_FLUX_PRO_KONTEXT_MAX_T2I:
        G_FAL_FLUX_PRO_KONTEXT_MAX_T2I()
    case .FAL_BRIA_FIBO_EDIT_REPLACE_OBJECT:
        G_FAL_BRIA_FIBO_EDIT_REPLACE_OBJECT()
    case .FAL_BRIA_FIBO_EDIT_SKETCH_TO_IMAGE:
        G_FAL_BRIA_FIBO_EDIT_SKETCH_TO_IMAGE()
    case .FAL_BRIA_FIBO_EDIT_RESTORE:
        G_FAL_BRIA_FIBO_EDIT_RESTORE()
    case .FAL_BRIA_FIBO_EDIT_RESEASON:
        G_FAL_BRIA_FIBO_EDIT_RESEASON()
    case .FAL_BRIA_FIBO_EDIT_RELIGHT:
        G_FAL_BRIA_FIBO_EDIT_RELIGHT()
    case .FAL_BRIA_FIBO_EDIT_RESTYLE:
        G_FAL_BRIA_FIBO_EDIT_RESTYLE()
    case .FAL_BRIA_FIBO_EDIT_REWRITE_TEXT:
        G_FAL_BRIA_FIBO_EDIT_REWRITE_TEXT()
    case .FAL_BRIA_FIBO_EDIT_ERASE_BY_TEXT:
        G_FAL_BRIA_FIBO_EDIT_ERASE_BY_TEXT()
    case .FAL_BRIA_FIBO_EDIT_EDIT:
        G_FAL_BRIA_FIBO_EDIT_EDIT()
    case .FAL_BRIA_FIBO_EDIT_ADD_OBJECT:
        G_FAL_BRIA_FIBO_EDIT_ADD_OBJECT()
    case .FAL_BRIA_FIBO_EDIT_BLEND:
        G_FAL_BRIA_FIBO_EDIT_BLEND()
    case .FAL_BRIA_FIBO_EDIT_COLORIZE:
        G_FAL_BRIA_FIBO_EDIT_COLORIZE()
    case .FAL_BRIA_FIBO_GENERATE:
        G_FAL_BRIA_FIBO_GENERATE()
    case .FAL_BRIA_REIMAGINE_3_2:
        G_FAL_BRIA_REIMAGINE_3_2()
    case .FAL_BRIA_REIMAGINE:
        G_FAL_BRIA_REIMAGINE()
    case .FAL_BRIA_BACKGROUND_REMOVE:
        G_FAL_BRIA_BACKGROUND_REMOVE()
    case .FAL_LUMA_PHOTON:
        G_FAL_LUMA_PHOTON()
    case .FAL_LUMA_PHOTON_FLASH:
        G_FAL_LUMA_PHOTON_FLASH()
    case .FAL_LUMA_PHOTON_MODIFY:
        G_FAL_LUMA_PHOTON_MODIFY()
    case .FAL_LUMA_PHOTON_FLASH_MODIFY:
        G_FAL_LUMA_PHOTON_FLASH_MODIFY()
    case .FAL_LUMA_PHOTON_REFRAME:
        G_FAL_LUMA_PHOTON_REFRAME()
    case .FAL_LUMA_PHOTON_FLASH_REFRAME:
        G_FAL_LUMA_PHOTON_FLASH_REFRAME()
    case .FAL_GLM_IMAGE:
        G_FAL_GLM_IMAGE()
    case .FAL_GLM_IMAGE_TO_IMAGE:
        G_FAL_GLM_IMAGE_TO_IMAGE()
    case .FAL_QWEN_IMAGE:
        G_FAL_QWEN_IMAGE()
    case .FAL_QWEN_IMAGE_2512:
        G_FAL_QWEN_IMAGE_2512()
    case .FAL_QWEN_IMAGE_TO_IMAGE:
        G_FAL_QWEN_IMAGE_TO_IMAGE()
    case .FAL_QWEN_IMAGE_EDIT:
        G_FAL_QWEN_IMAGE_EDIT()
    case .FAL_QWEN_IMAGE_EDIT_PLUS:
        G_FAL_QWEN_IMAGE_EDIT_PLUS()
    case .FAL_QWEN_IMAGE_EDIT_IMAGE_TO_IMAGE:
        G_FAL_QWEN_IMAGE_EDIT_IMAGE_TO_IMAGE()
    case .FAL_QWEN_IMAGE_EDIT_INPAINT:
        G_FAL_QWEN_IMAGE_EDIT_INPAINT()
    case .FAL_QWEN_IMAGE_LAYERED:
        G_FAL_QWEN_IMAGE_LAYERED()
    case .FAL_QWEN_IMAGE_EDIT_2511:
        G_FAL_QWEN_IMAGE_EDIT_2511()
    case .FAL_QWEN_IMAGE_EDIT_2511_MULTIPLE_ANGLES:
        G_FAL_QWEN_IMAGE_EDIT_2511_MULTIPLE_ANGLES()
    case .FAL_QWEN_IMAGE_EDIT_2509:
        G_FAL_QWEN_IMAGE_EDIT_2509()
    case .FAL_WAN_V26_TEXT_TO_IMAGE:
        G_FAL_WAN_V26_TEXT_TO_IMAGE()
    case .FAL_WAN_V26_IMAGE_TO_IMAGE:
        G_FAL_WAN_V26_IMAGE_TO_IMAGE()
    case .FAL_BYTEDANCE_SEEDREAM_V45_TEXT_TO_IMAGE:
        G_FAL_BYTEDANCE_SEEDREAM_V45_TEXT_TO_IMAGE()
    case .FAL_BYTEDANCE_SEEDREAM_V45_EDIT:
        G_FAL_BYTEDANCE_SEEDREAM_V45_EDIT()
    case .FAL_BYTEDANCE_SEEDREAM_V4_TEXT_TO_IMAGE:
        G_FAL_BYTEDANCE_SEEDREAM_V4_TEXT_TO_IMAGE()
    case .FAL_BYTEDANCE_SEEDREAM_V4_EDIT:
        G_FAL_BYTEDANCE_SEEDREAM_V4_EDIT()
    case .FAL_BYTEDANCE_SEEDREAM_V3_TEXT_TO_IMAGE:
        G_FAL_BYTEDANCE_SEEDREAM_V3_TEXT_TO_IMAGE()
    case .FAL_BYTEDANCE_DREAMINA_V31_TEXT_TO_IMAGE:
        G_FAL_BYTEDANCE_DREAMINA_V31_TEXT_TO_IMAGE()
    case .FAL_BYTEDANCE_BAGEL:
        G_FAL_BYTEDANCE_BAGEL()
    case .FAL_BYTEDANCE_BAGEL_EDIT:
        G_FAL_BYTEDANCE_BAGEL_EDIT()
    case .FAL_BYTEDANCE_SEEDREAM_V5_PRO_TEXT_TO_IMAGE:
        G_FAL_BYTEDANCE_SEEDREAM_V5_PRO_TEXT_TO_IMAGE()
    case .FAL_BYTEDANCE_SEEDREAM_V5_PRO_EDIT:
        G_FAL_BYTEDANCE_SEEDREAM_V5_PRO_EDIT()
    case .FAL_BYTEDANCE_SEEDREAM_V5_LITE_TEXT_TO_IMAGE:
        G_FAL_BYTEDANCE_SEEDREAM_V5_LITE_TEXT_TO_IMAGE()
    case .FAL_BYTEDANCE_SEEDREAM_V5_LITE_EDIT:
        G_FAL_BYTEDANCE_SEEDREAM_V5_LITE_EDIT()
    case .FAL_BYTEDANCE_BERNINI_R_EDIT_IMAGE:
        G_FAL_BYTEDANCE_BERNINI_R_EDIT_IMAGE()
    case .FAL_KLING_IMAGE_O1:
        G_FAL_KLING_IMAGE_O1()
    case .FAL_GPT_IMAGE_1_MINI:
        G_FAL_GPT_IMAGE_1_MINI()
    case .FAL_GPT_IMAGE_1_MINI_EDIT:
        G_FAL_GPT_IMAGE_1_MINI_EDIT()
    case .FAL_GPT_IMAGE_1:
        G_FAL_GPT_IMAGE_1()
    case .FAL_GPT_IMAGE_1_EDIT:
        G_FAL_GPT_IMAGE_1_EDIT()
    case .FAL_GPT_IMAGE_15:
        G_FAL_GPT_IMAGE_15()
    case .FAL_GPT_IMAGE_15_EDIT:
        G_FAL_GPT_IMAGE_15_EDIT()
    case .FAL_GPT_IMAGE_2:
        G_FAL_GPT_IMAGE_2()
    case .FAL_GPT_IMAGE_2_EDIT:
        G_FAL_GPT_IMAGE_2_EDIT()
    case .FAL_ZIMAGE_TURBO:
        G_FAL_ZIMAGE_TURBO()
    case .FAL_ZIMAGE_TURBO_IMAGE_TO_IMAGE:
        G_FAL_ZIMAGE_TURBO_IMAGE_TO_IMAGE()
    case .FAL_ZIMAGE_TURBO_INPAINT:
        G_FAL_ZIMAGE_TURBO_INPAINT()
    case .FAL_ZIMAGE_TURBO_INPAINT_LORA:
        G_FAL_ZIMAGE_TURBO_INPAINT_LORA()
    case .FAL_KREA_2_TURBO:
        G_FAL_KREA_2_TURBO()
    case .FAL_IDEOGRAM_V4:
        G_FAL_IDEOGRAM_V4()
    case .FAL_IDEOGRAM_V4_FAST:
        G_FAL_IDEOGRAM_V4_FAST()
    case .FAL_IDEOGRAM_V4_INSTANT:
        G_FAL_IDEOGRAM_V4_INSTANT()
    case .FAL_GOOGLE_GEMINI_3_PRO_IMAGE:
        G_FAL_GOOGLE_GEMINI_3_PRO_IMAGE()
    case .FAL_GOOGLE_GEMINI_3_PRO_IMAGE_EDIT:
        G_FAL_GOOGLE_GEMINI_3_PRO_IMAGE_EDIT()
    case .FAL_GOOGLE_NANO_BANANA_PRO:
        G_FAL_GOOGLE_NANO_BANANA_PRO()
    case .FAL_GOOGLE_NANO_BANANA_PRO_EDIT:
        G_FAL_GOOGLE_NANO_BANANA_PRO_EDIT()
    case .FAL_GOOGLE_GEMINI_25_FLASH_IMAGE:
        G_FAL_GOOGLE_GEMINI_25_FLASH_IMAGE()
    case .FAL_GOOGLE_GEMINI_25_FLASH_IMAGE_EDIT:
        G_FAL_GOOGLE_GEMINI_25_FLASH_IMAGE_EDIT()
    case .FAL_GOOGLE_NANO_BANANA:
        G_FAL_GOOGLE_NANO_BANANA()
    case .FAL_GOOGLE_NANO_BANANA_EDIT:
        G_FAL_GOOGLE_NANO_BANANA_EDIT()
    case .FAL_GOOGLE_NANO_BANANA_2:
        G_FAL_GOOGLE_NANO_BANANA_2()
    case .FAL_GOOGLE_NANO_BANANA_2_EDIT:
        G_FAL_GOOGLE_NANO_BANANA_2_EDIT()
    case .FAL_GOOGLE_NANO_BANANA_LITE:
        G_FAL_GOOGLE_NANO_BANANA_LITE()
    case .FAL_GOOGLE_NANO_BANANA_LITE_EDIT:
        G_FAL_GOOGLE_NANO_BANANA_LITE_EDIT()
    case .FAL_GOOGLE_NANO_BANANA_2_LITE:
        G_FAL_GOOGLE_NANO_BANANA_2_LITE()
    case .FAL_GOOGLE_IMAGEN4_PREVIEW:
        G_FAL_GOOGLE_IMAGEN4_PREVIEW()
    case .FAL_GOOGLE_IMAGEN4_PREVIEW_FAST:
        G_FAL_GOOGLE_IMAGEN4_PREVIEW_FAST()
    case .FAL_GOOGLE_IMAGEN4_PREVIEW_ULTRA:
        G_FAL_GOOGLE_IMAGEN4_PREVIEW_ULTRA()
    case .FAL_HALFMOON_AI_HOME_STYLE:
        G_FAL_HALFMOON_AI_HOME_STYLE()
    case .FAL_HALFMOON_AI_HOME_EDIT:
        G_FAL_HALFMOON_AI_HOME_EDIT()
    case .FAL_RECRAFT_V3:
        G_FAL_RECRAFT_V3()
    case .FAL_RECRAFT_V4_1:
        G_FAL_RECRAFT_V4_1()
    case .FAL_RECRAFT_V4_1_EDIT:
        G_FAL_RECRAFT_V4_1_EDIT()
    case .FAL_RECRAFT_V4_1_ULTRA:
        G_FAL_RECRAFT_V4_1_ULTRA()
    case .FAL_RECRAFT_V4_1_ULTRA_EDIT:
        G_FAL_RECRAFT_V4_1_ULTRA_EDIT()
    case .GOOGLE_GEMINI_FLASH_IMAGE:
        G_GOOGLE_GEMINI_FLASH_IMAGE()
    case .GOOGLE_GEMINI_31_FLASH_IMAGE:
        G_GOOGLE_GEMINI_31_FLASH_IMAGE()
    case .GOOGLE_GEMINI_31_FLASH_LITE_IMAGE:
        G_GOOGLE_GEMINI_31_FLASH_LITE_IMAGE()
    case .GOOGLE_GEMINI_PRO_IMAGE:
        G_GOOGLE_GEMINI_PRO_IMAGE()
    case .GOOGLE_IMAGEN_3:
        G_GOOGLE_IMAGEN_3()
    case .GOOGLE_IMAGEN_4_FAST:
        G_GOOGLE_IMAGEN_4_FAST()
    case .GOOGLE_IMAGEN_4_STANDARD:
        G_GOOGLE_IMAGEN_4_STANDARD()
    case .GOOGLE_IMAGEN_4_ULTRA:
        G_GOOGLE_IMAGEN_4_ULTRA()
    case .FAL_XAI_GROK_IMAGINE_IMAGE:
        G_FAL_XAI_GROK_IMAGINE_IMAGE()
    case .FAL_XAI_GROK_IMAGINE_IMAGE_EDIT:
        G_FAL_XAI_GROK_IMAGINE_IMAGE_EDIT()
    case .FAL_XAI_GROK_IMAGINE_IMAGE_QUALITY:
        G_FAL_XAI_GROK_IMAGINE_IMAGE_QUALITY()
    case .FAL_XAI_GROK_IMAGINE_IMAGE_QUALITY_EDIT:
        G_FAL_XAI_GROK_IMAGINE_IMAGE_QUALITY_EDIT()
    case .FAL_HIDREAM_O1_IMAGE:
        G_FAL_HIDREAM_O1_IMAGE()
    case .FAL_HIDREAM_O1_IMAGE_DEV:
        G_FAL_HIDREAM_O1_IMAGE_DEV()
    case .FAL_HIDREAM_O1_IMAGE_EDIT:
        G_FAL_HIDREAM_O1_IMAGE_EDIT()
    case .FAL_HIDREAM_O1_IMAGE_DEV_EDIT:
        G_FAL_HIDREAM_O1_IMAGE_DEV_EDIT()
    case .FAL_ERNIE_IMAGE_LORA:
        G_FAL_ERNIE_IMAGE_LORA()
    case .FAL_ERNIE_IMAGE_LORA_TURBO:
        G_FAL_ERNIE_IMAGE_LORA_TURBO()
    case .REPLICATE_GOOGLE_NANO_BANANA_2:
        G_REPLICATE_GOOGLE_NANO_BANANA_2()
    case .REPLICATE_SEEDREAM_5_PRO:
        G_REPLICATE_SEEDREAM_5_PRO()
    case .REPLICATE_SEEDREAM_5_LITE:
        G_REPLICATE_SEEDREAM_5_LITE()
    case .REPLICATE_XAI_GROK_IMAGINE_IMAGE:
        G_REPLICATE_XAI_GROK_IMAGINE_IMAGE()
    case .REPLICATE_XAI_GROK_IMAGINE_IMAGE_QUALITY:
        G_REPLICATE_XAI_GROK_IMAGINE_IMAGE_QUALITY()
    case .REPLICATE_RECRAFT_V4_1:
        G_REPLICATE_RECRAFT_V4_1()
    case .REPLICATE_RECRAFT_V4_1_PRO:
        G_REPLICATE_RECRAFT_V4_1_PRO()
    case .REPLICATE_IDEOGRAM_V3:
        G_REPLICATE_IDEOGRAM_V3()
    case .REPLICATE_IDEOGRAM_V3_QUALITY:
        G_REPLICATE_IDEOGRAM_V3_QUALITY()
    case .REPLICATE_IDEOGRAM_V3_FAST:
        G_REPLICATE_IDEOGRAM_V3_FAST()
    case .REPLICATE_IDEOGRAM_V4_TURBO:
        G_REPLICATE_IDEOGRAM_V4_TURBO()
    case .REPLICATE_IDEOGRAM_V4_BALANCED:
        G_REPLICATE_IDEOGRAM_V4_BALANCED()
    case .REPLICATE_IDEOGRAM_V4_QUALITY:
        G_REPLICATE_IDEOGRAM_V4_QUALITY()
    case .REPLICATE_RECRAFT_V4:
        G_REPLICATE_RECRAFT_V4()
    case .REPLICATE_RECRAFT_V4_PRO:
        G_REPLICATE_RECRAFT_V4_PRO()
    case .REPLICATE_FLUX_11_PRO_ULTRA:
        G_REPLICATE_FLUX_11_PRO_ULTRA()
    case .REPLICATE_HIDREAM_L1_FAST:
        G_REPLICATE_HIDREAM_L1_FAST()
    case .REPLICATE_WAN_2_7_IMAGE:
        G_REPLICATE_WAN_2_7_IMAGE()
    case .REPLICATE_WAN_2_7_IMAGE_PRO:
        G_REPLICATE_WAN_2_7_IMAGE_PRO()
    case .REPLICATE_HUNYUAN_IMAGE_3:
        G_REPLICATE_HUNYUAN_IMAGE_3()
    case .REPLICATE_FLUX_FILL_PRO:
        G_REPLICATE_FLUX_FILL_PRO()
    case .REPLICATE_BRIA_FIBO:
        G_REPLICATE_BRIA_FIBO()
    case .REPLICATE_BRIA_FIBO_EDIT:
        G_REPLICATE_BRIA_FIBO_EDIT()
    case .REPLICATE_BRIA_IMAGE_3_2:
        G_REPLICATE_BRIA_IMAGE_3_2()
    case .REPLICATE_BRIA_ERASER:
        G_REPLICATE_BRIA_ERASER()
    case .REPLICATE_BRIA_GENFILL:
        G_REPLICATE_BRIA_GENFILL()
    case .REPLICATE_BRIA_EXPAND_IMAGE:
        G_REPLICATE_BRIA_EXPAND_IMAGE()
    case .REPLICATE_BRIA_GENERATE_BACKGROUND:
        G_REPLICATE_BRIA_GENERATE_BACKGROUND()
    case .REPLICATE_RIVERFLOW_2_5_PRO:
        G_REPLICATE_RIVERFLOW_2_5_PRO()
    case .REPLICATE_RIVERFLOW_2_5_FAST:
        G_REPLICATE_RIVERFLOW_2_5_FAST()
    case .TOGETHER_FLUX_SCHNELL:
        G_TOGETHER_FLUX_SCHNELL()
    case .TOGETHER_FLUX_11_PRO:
        G_TOGETHER_FLUX_11_PRO()
    case .TOGETHER_FLUX_2_PRO:
        G_TOGETHER_FLUX_2_PRO()
    case .TOGETHER_FLUX_2_DEV:
        G_TOGETHER_FLUX_2_DEV()
    case .TOGETHER_FLUX_2_MAX:
        G_TOGETHER_FLUX_2_MAX()
    case .TOGETHER_FLUX_KONTEXT_PRO:
        G_TOGETHER_FLUX_KONTEXT_PRO()
    case .TOGETHER_FLUX_KONTEXT_MAX:
        G_TOGETHER_FLUX_KONTEXT_MAX()
    case .TOGETHER_SD3:
        G_TOGETHER_SD3()
    case .TOGETHER_SDXL:
        G_TOGETHER_SDXL()
    case .TOGETHER_IMAGEN_4_FAST:
        G_TOGETHER_IMAGEN_4_FAST()
    case .TOGETHER_IMAGEN_4_ULTRA:
        G_TOGETHER_IMAGEN_4_ULTRA()
    case .TOGETHER_SEEDREAM_4:
        G_TOGETHER_SEEDREAM_4()
    case .TOGETHER_IDEOGRAM_3:
        G_TOGETHER_IDEOGRAM_3()
    case .TOGETHER_QWEN_IMAGE:
        G_TOGETHER_QWEN_IMAGE()
    case .TOGETHER_HIDREAM_FULL:
        G_TOGETHER_HIDREAM_FULL()
    case .TOGETHER_FLUX_2_FLEX:
        G_TOGETHER_FLUX_2_FLEX()
    case .TOGETHER_FLUX_KREA_DEV:
        G_TOGETHER_FLUX_KREA_DEV()
    case .TOGETHER_IMAGEN_4_PREVIEW:
        G_TOGETHER_IMAGEN_4_PREVIEW()
    case .TOGETHER_FLASH_IMAGE_25:
        G_TOGETHER_FLASH_IMAGE_25()
    case .TOGETHER_GEMINI_3_PRO_IMAGE:
        G_TOGETHER_GEMINI_3_PRO_IMAGE()
    case .TOGETHER_FLASH_IMAGE_31:
        G_TOGETHER_FLASH_IMAGE_31()
    case .TOGETHER_SEEDREAM_3:
        G_TOGETHER_SEEDREAM_3()
    case .TOGETHER_QWEN_IMAGE_PRO:
        G_TOGETHER_QWEN_IMAGE_PRO()
    case .TOGETHER_HIDREAM_DEV:
        G_TOGETHER_HIDREAM_DEV()
    case .TOGETHER_HIDREAM_FAST:
        G_TOGETHER_HIDREAM_FAST()
    case .TOGETHER_WAN_26_IMAGE:
        G_TOGETHER_WAN_26_IMAGE()
    case .TOGETHER_GPT_IMAGE_15:
        G_TOGETHER_GPT_IMAGE_15()
    case .TOGETHER_GROK_IMAGINE_PRO:
        G_TOGETHER_GROK_IMAGINE_PRO()
    case .TOGETHER_QWEN_IMAGE_BASE:
        G_TOGETHER_QWEN_IMAGE_BASE()
    case .TOGETHER_JUGGERNAUT_PRO_FLUX:
        G_TOGETHER_JUGGERNAUT_PRO_FLUX()
    case .TOGETHER_JUGGERNAUT_LIGHTNING_FLUX:
        G_TOGETHER_JUGGERNAUT_LIGHTNING_FLUX()
    case .TOGETHER_DREAMSHAPER:
        G_TOGETHER_DREAMSHAPER()
    case .LUMA_PHOTON:
        G_LUMA_PHOTON()
    case .LUMA_PHOTON_FLASH:
        G_LUMA_PHOTON_FLASH()
    case .LUMA_UNI_1:
        G_LUMA_UNI_1()
    case .LUMA_UNI_1_MAX:
        G_LUMA_UNI_1_MAX()
    case .CLOUDFLARE_FLUX_2_KLEIN_9B:
        G_CLOUDFLARE_FLUX_2_KLEIN_9B()
    case .CLOUDFLARE_FLUX_2_KLEIN_4B:
        G_CLOUDFLARE_FLUX_2_KLEIN_4B()
    case .CLOUDFLARE_FLUX_2_DEV:
        G_CLOUDFLARE_FLUX_2_DEV()
    case .CLOUDFLARE_LUCID_ORIGIN:
        G_CLOUDFLARE_LUCID_ORIGIN()
    case .CLOUDFLARE_PHOENIX_1:
        G_CLOUDFLARE_PHOENIX_1()
    case .CLOUDFLARE_FLUX_1_SCHNELL:
        G_CLOUDFLARE_FLUX_1_SCHNELL()
    case .CLOUDFLARE_SD_XL_BASE:
        G_CLOUDFLARE_SD_XL_BASE()
    case .CLOUDFLARE_SD_15_IMG2IMG:
        G_CLOUDFLARE_SD_15_IMG2IMG()
    case .CLOUDFLARE_DREAMSHAPER_8_LCM:
        G_CLOUDFLARE_DREAMSHAPER_8_LCM()
    case .RECRAFT_V4_1:
        G_RECRAFT_V4_1()
    case .RECRAFT_V4_1_PRO:
        G_RECRAFT_V4_1_PRO()
    case .IDEOGRAM_V4_TURBO:
        G_IDEOGRAM_V4_TURBO()
    case .IDEOGRAM_V4_DEFAULT:
        G_IDEOGRAM_V4_DEFAULT()
    case .IDEOGRAM_V4_QUALITY:
        G_IDEOGRAM_V4_QUALITY()
    case .BFL_FLUX_2_PRO:
        G_BFL_FLUX_2_PRO()
    case .BFL_FLUX_2_MAX:
        G_BFL_FLUX_2_MAX()
    case .BRIA_FIBO:
        G_BRIA_FIBO()
    case .RUNWAY_GEN_4_IMAGE_TURBO:
        G_RUNWAY_GEN_4_IMAGE_TURBO()
    case .VERTEX_GEMINI_3_1_FLASH_IMAGE:
        G_VERTEX_GEMINI_3_1_FLASH_IMAGE()
    case .AZURE_GPT_IMAGE_2:
        G_AZURE_GPT_IMAGE_2()
    case .BEDROCK_STABLE_IMAGE_ULTRA_1_1:
        G_BEDROCK_STABLE_IMAGE_ULTRA_1_1()
    case .BEDROCK_STABLE_IMAGE_CORE_1_1:
        G_BEDROCK_STABLE_IMAGE_CORE_1_1()
    case .ALIBABA_WAN_2_7_IMAGE_PRO:
        G_ALIBABA_WAN_2_7_IMAGE_PRO()
    case .ALIBABA_WAN_2_7_IMAGE:
        G_ALIBABA_WAN_2_7_IMAGE()
    case .MINIMAX_IMAGE_01:
        G_MINIMAX_IMAGE_01()
    case .KLING_IMAGE_3_0:
        G_KLING_IMAGE_3_0()
    case .KLING_IMAGE_3_0_OMNI:
        G_KLING_IMAGE_3_0_OMNI()
    case .XAI_GROK_IMAGINE_IMAGE:
        G_XAI_GROK_IMAGINE_IMAGE()
    case .XAI_GROK_IMAGINE_IMAGE_QUALITY:
        G_XAI_GROK_IMAGINE_IMAGE_QUALITY()
    case .BYTEPLUS_DOLA_SEEDREAM_5_0_PRO:
        G_BYTEPLUS_DOLA_SEEDREAM_5_0_PRO()
    case .BYTEPLUS_SEEDREAM_5_0_LITE:
        G_BYTEPLUS_SEEDREAM_5_0_LITE()
    case .BYTEPLUS_SEEDREAM_4_5:
        G_BYTEPLUS_SEEDREAM_4_5()
    case .BYTEPLUS_SEEDREAM_4_0:
        G_BYTEPLUS_SEEDREAM_4_0()
    case .DEEPINFRA_FLUX_2_KLEIN_4B:
        G_DEEPINFRA_FLUX_2_KLEIN_4B()
    case .DEEPINFRA_FLUX_2_KLEIN_9B:
        G_DEEPINFRA_FLUX_2_KLEIN_9B()
    case .NOVITA_QWEN_IMAGE:
        G_NOVITA_QWEN_IMAGE()
    default:
        nil
    }
}

func getImageGenerationAdapter(imageGenerationRequest: ImageGenerationRequest) throws
    -> any ImageGenerationProtocol
{
    guard let model = ProviderService.shared.model(by: imageGenerationRequest.modelId) else {
        throw NSError(
            domain: "GenerateImageAdapterError",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: "Invalid model ID: \(imageGenerationRequest.modelId)",
                "ErrorCode": EnumGenerationAdapterErrorCode.MODEL_ERROR,
            ]
        )
    }

    guard let adapter = getImageGenerationAdapter(modelCode: model.modelCode) else {
        throw NSError(domain: "Unknown model", code: -1, userInfo: nil)
    }
    return adapter
}

func maximumCombinedImageInputs(for modelCode: EnumProviderModelCode) -> Int? {
    switch modelCode {
    case .XAI_GROK_IMAGINE_IMAGE, .XAI_GROK_IMAGINE_IMAGE_QUALITY:
        3
    case .BYTEPLUS_DOLA_SEEDREAM_5_0_PRO:
        10
    case .BYTEPLUS_SEEDREAM_5_0_LITE, .BYTEPLUS_SEEDREAM_4_5, .BYTEPLUS_SEEDREAM_4_0:
        14
    case .REPLICATE_REVE_2_1:
        8
    case .REPLICATE_SEEDREAM_5_PRO, .REPLICATE_RIVERFLOW_2_5_PRO:
        10
    case .REPLICATE_SEEDREAM_5_LITE:
        14
    case .REPLICATE_RIVERFLOW_2_5_FAST:
        4
    case .LUMA_UNI_1, .LUMA_UNI_1_MAX:
        9
    default:
        nil
    }
}

func imageRequestProviderInputValidationMessage(_ request: ImageGenerationRequest) -> String? {
    guard let selectedModelId = UUID(uuidString: request.modelId),
          let modelCode = EnumProviderModelCode.allCases.first(where: { $0.modelId == selectedModelId }),
          let maximumInputs = maximumCombinedImageInputs(for: modelCode)
    else {
        return nil
    }

    let sourceImageCount = request.clientImage?.isEmpty == false ? 1 : 0
    let referenceImageCount = request.clientReferenceImages?.count ?? 0
    guard sourceImageCount + referenceImageCount > maximumInputs else { return nil }

    switch modelCode {
    case .XAI_GROK_IMAGINE_IMAGE, .XAI_GROK_IMAGINE_IMAGE_QUALITY:
        return "xAI image editing accepts at most three source and reference images combined."
    case .BYTEPLUS_DOLA_SEEDREAM_5_0_PRO,
         .BYTEPLUS_SEEDREAM_5_0_LITE,
         .BYTEPLUS_SEEDREAM_4_5,
         .BYTEPLUS_SEEDREAM_4_0:
        return "BytePlus image generation accepts at most \(maximumInputs) source and reference images combined."
    case .REPLICATE_REVE_2_1:
        return "Reve 2.1 accepts at most eight source and reference images combined."
    case .REPLICATE_SEEDREAM_5_PRO,
         .REPLICATE_SEEDREAM_5_LITE,
         .REPLICATE_RIVERFLOW_2_5_PRO,
         .REPLICATE_RIVERFLOW_2_5_FAST:
        return "Replicate image generation accepts at most \(maximumInputs) source and reference images combined."
    case .LUMA_UNI_1, .LUMA_UNI_1_MAX:
        return "Luma image generation accepts at most nine source and reference images combined."
    default:
        return "Image generation accepts at most \(maximumInputs) source and reference images combined."
    }
}

class GenerateImageAdapter {
    let imageGenerationRequest: ImageGenerationRequest
    let modelContext: ModelContext

    /// Optional realtime session ID. When set:
    /// - Skips ImageSet creation
    /// - Sets generation.realtimeSessionId
    /// - Sets generation.isHidden = true
    let realtimeSessionId: UUID?

    init(
        imageGenerationRequest: ImageGenerationRequest,
        modelContext: ModelContext,
        realtimeSessionId: UUID? = nil
    ) {
        self.imageGenerationRequest = imageGenerationRequest
        self.modelContext = modelContext
        self.realtimeSessionId = realtimeSessionId
    }

    func atomicRequest(
        imageGenerationRequest: ImageGenerationRequest,
        generationAdapter: any ImageGenerationProtocol
    ) async -> ImageGenerationResponse {
        AppLogger.generation
            .debug("Atomic request started for model: \(imageGenerationRequest.modelId, privacy: .public)")

        do {
            let generation = try await generationAdapter
                .makeRequest(request: imageGenerationRequest)
            if generation.base64 == nil {
                AppLogger.generation
                    .error(
                        "Generation returned no image data: \(generation.errorMessage ?? "unknown error", privacy: .public)"
                    )
                return ImageGenerationResponse(
                    status: EnumGenerationStatus.FAILED,
                    errorCode: generation.errorCode != nil ? generation.errorCode : EnumGenerationAdapterErrorCode
                        .GENERATOR_ERROR,
                    errorMessage: generation.errorMessage != nil ? generation
                        .errorMessage : "Failed with unknown error",

                    rawResponse: generation.rawResponse
                )
            }

            if let base64String = generation.base64,
               let imageData = Data(base64Encoded: base64String)
            {
                let uuid = UUID()
                let image = toPlatformImage(from: imageData)
                image?.saveToiCloud(fileName: uuid.uuidString)

                let fileUrl = saveImageToDocumentsDirectory(imageData: imageData, withName: uuid.uuidString)
                if let fileUrl, let image {
                    await MediaGenerationHelper.saveOptimizedImageVersions(image: image, uuid: uuid)
                    MediaGenerationHelper.saveClientAssets(
                        clientImage: imageGenerationRequest.clientImage,
                        clientMask: imageGenerationRequest.clientMask,
                        clientReferenceImages: imageGenerationRequest.clientReferenceImages,
                        uuid: uuid
                    )

                    let actualSize = image.pixelSize
                    let actualDimensions = "\(Int(actualSize.width))x\(Int(actualSize.height))"

                    var metadata = generation.metadata ?? [:]

                    if actualDimensions != imageGenerationRequest.dimensions {
                        metadata["requested_dimensions"] = imageGenerationRequest.dimensions
                    }
                    if let resolution = imageGenerationRequest.resolution {
                        metadata["resolution"] = resolution
                    }
                    if let steps = imageGenerationRequest.steps {
                        metadata["steps"] = String(steps)
                    }
                    if let guidance = imageGenerationRequest.guidance {
                        metadata["guidance"] = String(format: "%.2f", guidance)
                    }
                    if let seed = imageGenerationRequest.seed {
                        metadata["seed"] = String(seed)
                    }
                    if let safetyTolerance = imageGenerationRequest.safetyTolerance {
                        metadata["safety_tolerance"] = String(safetyTolerance)
                    }
                    if let promptEnhance = imageGenerationRequest.promptEnhance {
                        metadata["prompt_enhance"] = promptEnhance ? "Yes" : "No"
                    }
                    if let background = imageGenerationRequest.background {
                        metadata["background"] = background
                    }
                    if let inputFidelity = imageGenerationRequest.inputFidelity {
                        metadata["input_fidelity"] = inputFidelity
                    }
                    if let moderation = imageGenerationRequest.moderation {
                        metadata["moderation"] = moderation
                    }
                    if let growMask = imageGenerationRequest.growMask {
                        metadata["grow_mask"] = String(growMask)
                    }
                    if let selectedTools = imageGenerationRequest.selectedTools, !selectedTools.isEmpty {
                        metadata["selected_tools"] = selectedTools.joined(separator: ", ")
                    }

                    AppLogger.generation
                        .debug(
                            "Atomic request complete - id: \(uuid.uuidString, privacy: .public), dimensions: \(actualDimensions, privacy: .public)"
                        )

                    return ImageGenerationResponse(
                        generationId: uuid,
                        status: EnumGenerationStatus.GENERATED,
                        base64: nil,
                        size: getImageSizeInBytes(imageURL: fileUrl),
                        cost: generation.cost,
                        modelPrompt: generation.modelPrompt,
                        colorPalette: getDominantColors(from: image),

                        metadata: metadata,
                        actualDimensions: actualDimensions
                    )
                } else {
                    AppLogger.generation.error("Failed to save image to documents directory")
                    return ImageGenerationResponse(
                        status: EnumGenerationStatus.FAILED,
                        errorCode: .GENERATOR_ERROR,
                        errorMessage: "Could not save image"
                    )
                }
            } else {
                AppLogger.generation.error("Failed to decode base64 image data")
                return ImageGenerationResponse(
                    status: EnumGenerationStatus.FAILED,
                    errorCode: .GENERATOR_ERROR,
                    errorMessage: "Could not decode base64"
                )
            }
        } catch {
            AppLogger.generation.error("Atomic request failed: \(error.localizedDescription, privacy: .public)")
            return ImageGenerationResponse(
                status: EnumGenerationStatus.FAILED,
                errorCode: EnumGenerationAdapterErrorCode.GENERATOR_ERROR,
                errorMessage: "Failed with error: \(error.localizedDescription)",
                rawResponse: "Error: \(error.localizedDescription)"
            )
        }
    }

    func makeRequest() async -> ImageSetResponse {
        if let validationMessage = imageRequestProviderInputValidationMessage(imageGenerationRequest) {
            return ImageSetResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: validationMessage
            )
        }

        // Provider adapters validate their own input limits before issuing a paid
        // create. Preserve the complete request so invalid inputs fail closed.
        let effectiveRequest = imageGenerationRequest
        let modelId = effectiveRequest.modelId
        let dimensions = effectiveRequest.dimensions
        let count = effectiveRequest.numberOfImages
        AppLogger.generation
            .info(
                "Starting image generation - model: \(modelId, privacy: .public), dimensions: \(dimensions, privacy: .public), count: \(count, privacy: .public)"
            )

        do {
            let generationAdapter: any ImageGenerationProtocol =
                try getImageGenerationAdapter(imageGenerationRequest: effectiveRequest)

            var imageGenerationResponses: [ImageGenerationResponse] = []
            await withTaskGroup(of: ImageGenerationResponse?.self) { group in
                for _ in 0 ..< effectiveRequest.numberOfImages {
                    group.addTask {
                        await self.atomicRequest(
                            imageGenerationRequest: effectiveRequest,
                            generationAdapter: generationAdapter
                        )
                    }
                }

                for await generation in group {
                    if let generation {
                        imageGenerationResponses.append(generation)
                    }
                }
            }

            if imageGenerationResponses.isEmpty {
                AppLogger.generation.error("No generations were successful")
                return ImageSetResponse(
                    status: EnumGenerationStatus.FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.GENERATOR_ERROR,
                    errorMessage: "No generation was successful"
                )
            }

            for generation in imageGenerationResponses {
                if generation.status == EnumGenerationStatus.FAILED || generation.generationId == nil {
                    AppLogger.generation
                        .error("Generation failed: \(generation.errorMessage ?? "unknown error", privacy: .public)")
                    return ImageSetResponse(
                        status: EnumGenerationStatus.FAILED,
                        errorCode: generation.errorCode ?? EnumGenerationAdapterErrorCode.GENERATOR_ERROR,
                        errorMessage: generation.errorMessage ?? "Failed with unknown error",

                        rawResponse: generation.rawResponse
                    )
                }
            }

            guard let usedModel = ProviderService.shared.model(by: effectiveRequest.modelId) else {
                AppLogger.generation.error("Model not found: \(modelId, privacy: .public)")
                return ImageSetResponse(
                    status: EnumGenerationStatus.FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "Model not found for ID: \(effectiveRequest.modelId)"
                )
            }

            // Prepare generation data for MainActor
            let generationData: [(
                id: UUID,
                actualDimensions: String,
                size: Int,
                cost: Double,
                status: EnumGenerationStatus,
                colorPalette: [String],
                modelPrompt: String?,
                metadata: [String: String]
            )] = imageGenerationResponses.compactMap { gen in
                guard let generationId = gen.generationId else { return nil }
                return (
                    id: generationId,
                    actualDimensions: gen.actualDimensions ?? effectiveRequest.dimensions,
                    size: gen.size ?? 0,
                    cost: gen.cost ?? 0,
                    status: gen.status,
                    colorPalette: gen.colorPalette ?? [],
                    modelPrompt: gen.modelPrompt,
                    metadata: gen.metadata ?? [:]
                )
            }

            let setType = usedModel.modelSetType
            let request = effectiveRequest
            let realtimeId = realtimeSessionId

            return await MainActor.run {
                // Create ImageSet only for non-realtime generations
                let set: ImageSet?
                if realtimeId == nil {
                    set = ImageSet(
                        prompt: request.prompt,
                        projectId: request.providerKey.projectId,
                        modelId: request.modelId,
                        style: request.style,
                        variant: request.variant,
                        dimensions: request.dimensions,
                        setType: setType,
                        negativePrompt: request.negativePrompt,
                        searchPrompt: request.searchPrompt
                    )
                    modelContext.insert(set!)
                } else {
                    set = nil
                }

                let generations: [Generation] = generationData.map { data in
                    let generation = Generation(
                        id: data.id,
                        setId: set?.id ?? UUID(),
                        projectId: request.providerKey.projectId,
                        modelId: request.modelId,
                        prompt: request.prompt,
                        promptEnhanceOpted: request.promptEnhance ?? false,
                        promptAfterEnhance: "",
                        style: request.style,
                        variant: request.variant,
                        quality: request.quality,
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
                        contentType: EnumGenerationContentType.IMAGE_2D,
                        metadata: data.metadata
                    )

                    // Handle realtime session: link to session and hide from main gallery
                    if let sessionId = realtimeId {
                        generation.realtimeSessionId = sessionId
                        generation.isHidden = true
                    }

                    modelContext.insert(generation)
                    return generation
                }

                // Only notify gallery for non-realtime generations
                if realtimeId == nil {
                    NotificationCenter.default.post(name: .generationCreated, object: nil)
                }

                let logSetId = set?.id.uuidString ?? "realtime"
                AppLogger.generation
                    .notice(
                        "Image generation complete - setId: \(logSetId, privacy: .public), count: \(generations.count, privacy: .public)"
                    )

                return ImageSetResponse(
                    status: EnumGenerationStatus.GENERATED,
                    set: set,
                    generations: generations
                )
            }

        } catch {
            AppLogger.generation.error("Image generation failed: \(error.localizedDescription, privacy: .public)")
            return ImageSetResponse(
                status: EnumGenerationStatus.FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Failed with error: \(error.localizedDescription)"
            )
        }
    }
}
