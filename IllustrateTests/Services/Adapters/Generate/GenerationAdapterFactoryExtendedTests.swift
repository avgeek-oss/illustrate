// MARK: - GenerationAdapterFactoryExtendedTests.swift

// Cross-factory validation tests for image and video adapter factories.
//
// GenerationAdapterFactoryTests covers: 3 image adapters, 2 image→nil,
// 3 video adapters, 1 video→nil, and createInvalidResponseError.
// VideoAdapterFactoryTests covers: all ~60 video model codes.
//
// This file adds: cross-factory exclusivity (video codes return nil from image factory),
// representative image model coverage per provider, and factory partition validation.

import IllustrateProviders
import XCTest
@testable import Illustrate

final class GenerationAdapterFactoryExtendedTests: XCTestCase {
    // MARK: - Cross-Factory: Video Models Return Nil From Image Factory

    func testImageFactory_stabilityVideo_returnsNil() {
        XCTAssertNil(getImageGenerationAdapter(modelCode: .STABILITY_IMAGE_TO_VIDEO))
    }

    func testImageFactory_openAISora2_returnsNil() {
        XCTAssertNil(getImageGenerationAdapter(modelCode: .OPENAI_SORA_2))
    }

    func testImageFactory_openAISora2Pro_returnsNil() {
        XCTAssertNil(getImageGenerationAdapter(modelCode: .OPENAI_SORA_2_PRO))
    }

    func testImageFactory_googleVeo2_returnsNil() {
        XCTAssertNil(getImageGenerationAdapter(modelCode: .GOOGLE_VEO_2))
    }

    func testImageFactory_googleVeo3_returnsNil() {
        XCTAssertNil(getImageGenerationAdapter(modelCode: .GOOGLE_VEO_3))
    }

    func testImageFactory_googleVeo31_returnsNil() {
        XCTAssertNil(getImageGenerationAdapter(modelCode: .GOOGLE_VEO_31))
    }

    func testImageFactory_replicateWan26T2V_returnsNil() {
        XCTAssertNil(getImageGenerationAdapter(modelCode: .REPLICATE_WAN_2_6_T2V))
    }

    func testImageFactory_replicateLumaRay_returnsNil() {
        XCTAssertNil(getImageGenerationAdapter(modelCode: .REPLICATE_LUMA_RAY))
    }

    func testImageFactory_lumaRay32_returnsNil() {
        XCTAssertNil(getImageGenerationAdapter(modelCode: .LUMA_RAY_3_2))
    }

    func testImageFactory_falVeo3_returnsNil() {
        XCTAssertNil(getImageGenerationAdapter(modelCode: .FAL_VEO_3))
    }

    func testImageFactory_falKlingV26Pro_returnsNil() {
        XCTAssertNil(getImageGenerationAdapter(modelCode: .FAL_KLING_V26_PRO_T2V))
    }

    func testImageFactory_falMinimaxHailuo_returnsNil() {
        XCTAssertNil(getImageGenerationAdapter(modelCode: .FAL_MINIMAX_HAILUO_23_PRO_T2V))
    }

    func testImageFactory_falSeedanceV15_returnsNil() {
        XCTAssertNil(getImageGenerationAdapter(modelCode: .FAL_SEEDANCE_V15_PRO_T2V))
    }

    // MARK: - Cross-Factory: Image Models Return Nil From Video Factory

    func testVideoFactory_openAIDalle3_returnsNil() {
        XCTAssertNil(getVideoGenerationAdapter(modelCode: .OPENAI_DALLE3))
    }

    func testVideoFactory_openAIGPTImage1_returnsNil() {
        XCTAssertNil(getVideoGenerationAdapter(modelCode: .OPENAI_GPT_IMAGE_1))
    }

    func testVideoFactory_stabilityCore_returnsNil() {
        XCTAssertNil(getVideoGenerationAdapter(modelCode: .STABILITY_CORE))
    }

    func testVideoFactory_stabilitySD35Large_returnsNil() {
        XCTAssertNil(getVideoGenerationAdapter(modelCode: .STABILITY_SD35_LARGE))
    }

    func testVideoFactory_googleGeminiFlashImage_returnsNil() {
        XCTAssertNil(getVideoGenerationAdapter(modelCode: .GOOGLE_GEMINI_FLASH_IMAGE))
    }

    func testVideoFactory_googleImagen3_returnsNil() {
        XCTAssertNil(getVideoGenerationAdapter(modelCode: .GOOGLE_IMAGEN_3))
    }

    func testVideoFactory_replicateFluxSchnell_returnsNil() {
        XCTAssertNil(getVideoGenerationAdapter(modelCode: .REPLICATE_FLUX_SCHNELL))
    }

    func testVideoFactory_replicateFluxPro_returnsNil() {
        XCTAssertNil(getVideoGenerationAdapter(modelCode: .REPLICATE_FLUX_PRO))
    }

    func testVideoFactory_falFluxSchnell_returnsNil() {
        XCTAssertNil(getVideoGenerationAdapter(modelCode: .FAL_FLUX_SCHNELL))
    }

    func testVideoFactory_falFlux2Pro_returnsNil() {
        XCTAssertNil(getVideoGenerationAdapter(modelCode: .FAL_FLUX_2_PRO))
    }

    // MARK: - Image Factory: Representative Provider Coverage

    /// OpenAI
    func testImageFactory_openAIGPTImage1_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .OPENAI_GPT_IMAGE_1))
    }

    func testImageFactory_openAIGPTImage1Mini_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .OPENAI_GPT_IMAGE_1_MINI))
    }

    func testImageFactory_openAIGPTImage15_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .OPENAI_GPT_IMAGE_1_5))
    }

    /// Stability AI
    func testImageFactory_stabilityUltra_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .STABILITY_ULTRA))
    }

    func testImageFactory_stabilitySD3_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .STABILITY_SD3))
    }

    func testImageFactory_stabilityInpaint_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .STABILITY_INPAINT))
    }

    func testImageFactory_stabilityRemoveBackground_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .STABILITY_REMOVE_BACKGROUND))
    }

    /// Google
    func testImageFactory_googleGeminiProImage_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .GOOGLE_GEMINI_PRO_IMAGE))
    }

    func testImageFactory_googleImagen4Fast_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .GOOGLE_IMAGEN_4_FAST))
    }

    func testImageFactory_googleImagen4Ultra_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .GOOGLE_IMAGEN_4_ULTRA))
    }

    /// Replicate
    func testImageFactory_replicateFluxDev_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .REPLICATE_FLUX_DEV))
    }

    func testImageFactory_replicateFluxKontextPro_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .REPLICATE_FLUX_KONTEXT_PRO))
    }

    func testImageFactory_replicateSeedream4_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .REPLICATE_SEEDREAM_4))
    }

    func testImageFactory_replicateQwenImage_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .REPLICATE_QWEN_IMAGE))
    }

    func testImageFactory_replicateQwenImage2_returnsAdapters() {
        let modelCodes: [EnumProviderModelCode] = [
            .REPLICATE_QWEN_IMAGE_2,
            .REPLICATE_QWEN_IMAGE_2_PRO,
        ]

        for modelCode in modelCodes {
            XCTAssertNotNil(getImageGenerationAdapter(modelCode: modelCode), "\(modelCode) should resolve")
        }
    }

    func testImageFactory_replicateReve21_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .REPLICATE_REVE_2_1))
    }

    func testImageFactory_replicateGoogleGemini25FlashImage_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .REPLICATE_GOOGLE_GEMINI_2_5_FLASH_IMAGE))
    }

    func testImageFactory_replicateKrea2_returnsAdapters() {
        let modelCodes: [EnumProviderModelCode] = [
            .REPLICATE_KREA_2_MEDIUM,
            .REPLICATE_KREA_2_LARGE,
        ]

        for modelCode in modelCodes {
            XCTAssertNotNil(getImageGenerationAdapter(modelCode: modelCode), "\(modelCode) should resolve")
        }
    }

    func testImageFactory_replicateIdeogramV4_returnsAdapters() {
        let modelCodes: [EnumProviderModelCode] = [
            .REPLICATE_IDEOGRAM_V4_TURBO,
            .REPLICATE_IDEOGRAM_V4_BALANCED,
            .REPLICATE_IDEOGRAM_V4_QUALITY,
        ]

        for modelCode in modelCodes {
            XCTAssertNotNil(getImageGenerationAdapter(modelCode: modelCode), "\(modelCode) should resolve")
        }
    }

    /// Fal
    func testImageFactory_falFluxPro_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .FAL_FLUX_PRO))
    }

    func testImageFactory_falFlux2_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .FAL_FLUX_2))
    }

    func testImageFactory_falFluxKontextDev_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .FAL_FLUX_KONTEXT_DEV))
    }

    func testImageFactory_falBriaFiboGenerate_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .FAL_BRIA_FIBO_GENERATE))
    }

    func testImageFactory_falQwenImage_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .FAL_QWEN_IMAGE))
    }

    func testImageFactory_falRecraftV3_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .FAL_RECRAFT_V3))
    }

    func testImageFactory_replicateRecraftV41Pro_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .REPLICATE_RECRAFT_V4_1_PRO))
    }

    func testImageFactory_falSeedreamV45_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .FAL_BYTEDANCE_SEEDREAM_V45_TEXT_TO_IMAGE))
    }

    func testImageFactory_falGoogleGemini3ProImage_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .FAL_GOOGLE_GEMINI_3_PRO_IMAGE))
    }

    func testImageFactory_falSimpleImageEndpoints_returnAdapters() {
        let modelCodes: [EnumProviderModelCode] = [
            .FAL_FLUX_2_KLEIN_9B,
            .FAL_KREA_2_TURBO,
            .FAL_IDEOGRAM_V4,
            .FAL_GOOGLE_NANO_BANANA_LITE,
            .FAL_GOOGLE_NANO_BANANA_LITE_EDIT,
            .FAL_GOOGLE_NANO_BANANA_2_LITE,
        ]

        for modelCode in modelCodes {
            XCTAssertNotNil(getImageGenerationAdapter(modelCode: modelCode), "\(modelCode) should resolve")
        }
    }

    func testImageFactory_lumaAgentsUni_returnAdapters() {
        let modelCodes: [EnumProviderModelCode] = [
            .LUMA_UNI_1,
            .LUMA_UNI_1_MAX,
        ]

        for modelCode in modelCodes {
            XCTAssertNotNil(getImageGenerationAdapter(modelCode: modelCode), "\(modelCode) should resolve")
        }
    }

    func testImageFactory_briaFibo_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .BRIA_FIBO))
    }

    func testImageFactory_runwayGen4ImageTurbo_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .RUNWAY_GEN_4_IMAGE_TURBO))
    }

    func testImageFactory_alibabaWan27_returnsAdapters() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .ALIBABA_WAN_2_7_IMAGE_PRO))
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .ALIBABA_WAN_2_7_IMAGE))
    }

    func testImageFactory_minimaxImage01_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .MINIMAX_IMAGE_01))
    }

    func testImageFactory_klingImage30_returnsAdapters() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .KLING_IMAGE_3_0))
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .KLING_IMAGE_3_0_OMNI))
    }

    func testImageFactory_xAIGrokImagine_returnsAdapters() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .XAI_GROK_IMAGINE_IMAGE))
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .XAI_GROK_IMAGINE_IMAGE_QUALITY))
    }

    func testImageFactory_bytePlusSeedream_returnsAdapters() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .BYTEPLUS_DOLA_SEEDREAM_5_0_PRO))
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .BYTEPLUS_SEEDREAM_5_0_LITE))
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .BYTEPLUS_SEEDREAM_4_5))
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .BYTEPLUS_SEEDREAM_4_0))
    }

    func testImageFactory_deepInfraFlux2Klein_returnsAdapters() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .DEEPINFRA_FLUX_2_KLEIN_4B))
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .DEEPINFRA_FLUX_2_KLEIN_9B))
    }

    func testImageFactory_novitaQwenImage_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .NOVITA_QWEN_IMAGE))
    }

    func testImageFactory_vertexGemini31FlashImage_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .VERTEX_GEMINI_3_1_FLASH_IMAGE))
    }

    func testImageFactory_azureGPTImage2_returnsAdapter() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .AZURE_GPT_IMAGE_2))
    }

    func testImageFactory_bedrockStableImageModels_returnAdapters() {
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .BEDROCK_STABLE_IMAGE_ULTRA_1_1))
        XCTAssertNotNil(getImageGenerationAdapter(modelCode: .BEDROCK_STABLE_IMAGE_CORE_1_1))
    }
}
