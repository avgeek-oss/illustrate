// MARK: - ProviderModelCostWorkflowTests.swift

// Workflow tests for EnumProviderModelCode cost calculation extensions.
//
// Tests cover:
// - formattedImageCost() for known image models (DALL-E 3, Stability Core, Gemini)
// - rawImageCost() for known image models
// - formattedVideoCost() for known video models (Sora 2, Veo 2)
// - rawVideoCost() for known video models
// - Cross-type fallback: video model → "Free" for image cost, vice versa

import XCTest
@testable import Illustrate
@testable import IllustrateProviders

final class ProviderModelCostWorkflowTests: XCTestCase {
    // MARK: - formattedImageCost() Tests

    func testFormattedImageCost_Dalle3_Standard_1024x1024() {
        let cost = EnumProviderModelCode.OPENAI_DALLE3.formattedImageCost(
            quality: "standard",
            dimensions: "1024x1024"
        )
        XCTAssertEqual(cost, "$0.04")
    }

    func testFormattedImageCost_Dalle3_HD_1024x1792_HigherCost() {
        let standardCost = EnumProviderModelCode.OPENAI_DALLE3.rawImageCost(
            quality: "standard",
            dimensions: "1024x1024"
        )
        let hdCost = EnumProviderModelCode.OPENAI_DALLE3.rawImageCost(
            quality: "hd",
            dimensions: "1024x1792"
        )
        XCTAssertGreaterThan(hdCost, standardCost)
    }

    func testFormattedImageCost_StabilityCore_ReturnsCredits() {
        let cost = EnumProviderModelCode.STABILITY_CORE.formattedImageCost()
        XCTAssertTrue(cost.contains("credits"), "Stability Core should return credits-based format, got: \(cost)")
    }

    func testFormattedImageCost_GeminiFlashImage_SubCentFormat() {
        let cost = EnumProviderModelCode.GOOGLE_GEMINI_FLASH_IMAGE.formattedImageCost()
        // Gemini Flash Image costs ~$0.0387 per image, formatted with 4 decimals
        XCTAssertTrue(cost.hasPrefix("$0.0"), "Expected sub-cent format, got: \(cost)")
    }

    func testFormattedImageCost_VideoModel_ReturnsFree() {
        // A video-only model should return "Free" for image cost
        let cost = EnumProviderModelCode.OPENAI_SORA_2.formattedImageCost()
        XCTAssertEqual(cost, "Free")
    }

    func testFormattedImageCost_StabilityVideoModel_ReturnsFree() {
        let cost = EnumProviderModelCode.STABILITY_IMAGE_TO_VIDEO.formattedImageCost()
        XCTAssertEqual(cost, "Free")
    }

    // MARK: - rawImageCost() Tests

    func testRawImageCost_Dalle3_Standard_1024x1024() {
        let cost = EnumProviderModelCode.OPENAI_DALLE3.rawImageCost(
            quality: "standard",
            dimensions: "1024x1024"
        )
        XCTAssertEqual(cost, 0.04, accuracy: 0.001)
    }

    func testRawImageCost_Dalle3_MultipleImages() {
        let single = EnumProviderModelCode.OPENAI_DALLE3.rawImageCost(
            quality: "standard",
            dimensions: "1024x1024",
            numberOfImages: 1
        )
        let double = EnumProviderModelCode.OPENAI_DALLE3.rawImageCost(
            quality: "standard",
            dimensions: "1024x1024",
            numberOfImages: 2
        )
        XCTAssertEqual(double, single * 2, accuracy: 0.001)
    }

    func testRawImageCost_VideoModel_ReturnsZero() {
        let cost = EnumProviderModelCode.OPENAI_SORA_2.rawImageCost()
        XCTAssertEqual(cost, 0)
    }

    func testRawImageCost_GeminiFlashImage_PositiveValue() {
        let cost = EnumProviderModelCode.GOOGLE_GEMINI_FLASH_IMAGE.rawImageCost()
        XCTAssertGreaterThan(cost, 0)
        XCTAssertLessThan(cost, 0.10, "Gemini Flash Image should be sub-dime")
    }

    func testRawImageCost_GoogleNanoBanana2AndLite_UsePublishedStandardPricing() {
        let nanoBanana2 = EnumProviderModelCode.GOOGLE_GEMINI_31_FLASH_IMAGE.rawImageCost(quality: "1K")
        let lite = EnumProviderModelCode.GOOGLE_GEMINI_31_FLASH_LITE_IMAGE.rawImageCost(quality: "1K")

        XCTAssertEqual(nanoBanana2, 0.0672, accuracy: 0.0001)
        XCTAssertEqual(lite, 0.0336, accuracy: 0.0001)
        XCTAssertGreaterThan(nanoBanana2, lite)
    }

    func testRawImageCost_XAIQuality_UsesResolutionAndRepeatedInputs() {
        let cost = EnumProviderModelCode.XAI_GROK_IMAGINE_IMAGE_QUALITY.rawImageCost(
            dimensions: "16:9",
            resolution: "2k",
            numberOfImages: 2,
            hasSourceImage: true,
            referenceImageCount: 2
        )
        XCTAssertEqual(cost, 0.20, accuracy: 0.000_001)
    }

    func testRawImageCost_BytePlusPro_UsesResolutionAndCombinedInputs() {
        let cost = EnumProviderModelCode.BYTEPLUS_DOLA_SEEDREAM_5_0_PRO.rawImageCost(
            dimensions: "1:1",
            resolution: "2k",
            numberOfImages: 1,
            hasSourceImage: true,
            referenceImageCount: 2
        )
        XCTAssertEqual(cost, 0.096, accuracy: 0.000_001)
    }

    // MARK: - formattedVideoCost() Tests

    func testFormattedVideoCost_Sora2_4Seconds() {
        let cost = EnumProviderModelCode.OPENAI_SORA_2.formattedVideoCost(
            durationSeconds: 4
        )
        XCTAssertTrue(cost.hasPrefix("$"), "Expected dollar format, got: \(cost)")
        XCTAssertNotEqual(cost, "Free")
    }

    func testFormattedVideoCost_Veo2_8Seconds() {
        let cost = EnumProviderModelCode.GOOGLE_VEO_2.formattedVideoCost(
            durationSeconds: 8
        )
        XCTAssertTrue(cost.hasPrefix("$"), "Expected dollar format, got: \(cost)")
        XCTAssertNotEqual(cost, "Free")
    }

    func testFormattedVideoCost_ImageModel_ReturnsFree() {
        // An image-only model should return "Free" for video cost
        let cost = EnumProviderModelCode.OPENAI_DALLE3.formattedVideoCost(
            durationSeconds: 5
        )
        XCTAssertEqual(cost, "Free")
    }

    func testFormattedVideoCost_StabilityImageModel_ReturnsFree() {
        let cost = EnumProviderModelCode.STABILITY_CORE.formattedVideoCost(
            durationSeconds: 5
        )
        XCTAssertEqual(cost, "Free")
    }

    // MARK: - rawVideoCost() Tests

    func testRawVideoCost_Sora2_PositiveValue() {
        let cost = EnumProviderModelCode.OPENAI_SORA_2.rawVideoCost(
            durationSeconds: 4
        )
        XCTAssertGreaterThan(cost, 0)
    }

    func testRawVideoCost_Sora2_LongerDuration_CostsMore() {
        let short = EnumProviderModelCode.OPENAI_SORA_2.rawVideoCost(durationSeconds: 4)
        let long = EnumProviderModelCode.OPENAI_SORA_2.rawVideoCost(durationSeconds: 10)
        XCTAssertGreaterThan(long, short)
    }

    func testRawVideoCost_ImageModel_ReturnsZero() {
        let cost = EnumProviderModelCode.OPENAI_DALLE3.rawVideoCost(
            durationSeconds: 5
        )
        XCTAssertEqual(cost, 0)
    }

    func testRawVideoCost_Veo2_PositiveValue() {
        let cost = EnumProviderModelCode.GOOGLE_VEO_2.rawVideoCost(
            durationSeconds: 8
        )
        XCTAssertGreaterThan(cost, 0)
    }

    func testRawVideoCost_XAI_UsesResolutionAndImageInputs() {
        let standard = EnumProviderModelCode.XAI_GROK_IMAGINE_VIDEO.rawVideoCost(
            durationSeconds: 5,
            numberOfVideos: 2,
            dimensions: "16:9",
            resolution: "720p",
            referenceImageCount: 2
        )
        XCTAssertEqual(standard, 0.708, accuracy: 0.000_001)

        let video15 = EnumProviderModelCode.XAI_GROK_IMAGINE_VIDEO_1_5.rawVideoCost(
            durationSeconds: 4,
            dimensions: "16:9",
            resolution: "1080p",
            hasSourceImage: true
        )
        XCTAssertEqual(video15, 1.01, accuracy: 0.000_001)
    }

    func testRawVideoCost_BytePlus_UsesTokenFormulaAndAudioTier() {
        let standard = EnumProviderModelCode.BYTEPLUS_DREAMINA_SEEDANCE_2_0.rawVideoCost(
            durationSeconds: 5,
            dimensions: "16:9",
            resolution: "720p",
            generateAudio: true
        )
        XCTAssertEqual(standard, 0.756, accuracy: 0.000_001)

        let audio = EnumProviderModelCode.BYTEPLUS_SEEDANCE_1_5_PRO.rawVideoCost(
            durationSeconds: 4,
            dimensions: "16:9",
            resolution: "720p",
            generateAudio: true
        )
        XCTAssertEqual(audio, 0.20736, accuracy: 0.000_001)
    }
}
