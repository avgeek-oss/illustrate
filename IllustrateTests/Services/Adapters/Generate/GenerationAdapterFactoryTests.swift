// MARK: - GenerationAdapterFactoryTests.swift

// Unit tests for image and video generation adapter factory routing.
//
// Tests cover:
// - getImageGenerationAdapter(modelCode:) returns non-nil for known image models
// - getImageGenerationAdapter(modelCode:) returns nil for video/unknown models
// - getVideoGenerationAdapter(modelCode:) returns non-nil for known video models
// - getVideoGenerationAdapter(modelCode:) returns nil for image/unknown models
// - createInvalidResponseError() returns a failed ImageGenerationResponse

import XCTest
@testable import Illustrate
@testable import IllustrateProviders

/// Use the package's NetworkResponseData to avoid module ambiguity
private typealias TestNetworkResponseData = IllustrateProviders.NetworkResponseData

final class GenerationAdapterFactoryTests: XCTestCase {
    // MARK: - Image Adapter Factory: Known Models

    func testGetImageGenerationAdapter_OpenAIDalle3_ReturnsNonNil() {
        let adapter = getImageGenerationAdapter(modelCode: .OPENAI_DALLE3)
        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_StabilityCore_ReturnsNonNil() {
        let adapter = getImageGenerationAdapter(modelCode: .STABILITY_CORE)
        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_GoogleGeminiFlashImage_ReturnsNonNil() {
        let adapter = getImageGenerationAdapter(modelCode: .GOOGLE_GEMINI_FLASH_IMAGE)
        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_GoogleNanoBanana2_ReturnsNonNil() {
        let adapter = getImageGenerationAdapter(modelCode: .GOOGLE_GEMINI_31_FLASH_IMAGE)
        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_GoogleNanoBananaLite_ReturnsNonNil() {
        let adapter = getImageGenerationAdapter(modelCode: .GOOGLE_GEMINI_31_FLASH_LITE_IMAGE)
        XCTAssertNotNil(adapter)
    }

    // MARK: - Image Adapter Factory: Unknown/Video Models Return Nil

    func testGetImageGenerationAdapter_VideoModel_ReturnsNil() {
        let adapter = getImageGenerationAdapter(modelCode: .OPENAI_SORA_2)
        XCTAssertNil(adapter)
    }

    func testGetImageGenerationAdapter_StabilityVideo_ReturnsNil() {
        let adapter = getImageGenerationAdapter(modelCode: .STABILITY_IMAGE_TO_VIDEO)
        XCTAssertNil(adapter)
    }

    // MARK: - Video Adapter Factory: Known Models

    func testGetVideoGenerationAdapter_OpenAISora2_ReturnsNonNil() {
        let adapter = getVideoGenerationAdapter(modelCode: .OPENAI_SORA_2)
        XCTAssertNotNil(adapter)
    }

    func testGetVideoGenerationAdapter_GoogleVeo2_ReturnsNonNil() {
        let adapter = getVideoGenerationAdapter(modelCode: .GOOGLE_VEO_2)
        XCTAssertNotNil(adapter)
    }

    func testGetVideoGenerationAdapter_GoogleGeminiOmniFlash_ReturnsNonNil() {
        let adapter = getVideoGenerationAdapter(modelCode: .GOOGLE_GEMINI_OMNI_FLASH_VIDEO)
        XCTAssertNotNil(adapter)
    }

    func testGetVideoGenerationAdapter_GoogleGeminiOmniFlashEdit_ReturnsNonNil() {
        let adapter = getVideoGenerationAdapter(modelCode: .GOOGLE_GEMINI_OMNI_FLASH_VIDEO_EDIT)
        XCTAssertNotNil(adapter)
    }

    func testGetVideoGenerationAdapter_StabilityImageToVideo_ReturnsNonNil() {
        let adapter = getVideoGenerationAdapter(modelCode: .STABILITY_IMAGE_TO_VIDEO)
        XCTAssertNotNil(adapter)
    }

    // MARK: - Video Adapter Factory: Unknown/Image Models Return Nil

    func testGetVideoGenerationAdapter_ImageModel_ReturnsNil() {
        let adapter = getVideoGenerationAdapter(modelCode: .OPENAI_DALLE3)
        XCTAssertNil(adapter)
    }

    // MARK: - createInvalidResponseError Tests

    func testCreateInvalidResponseError_Dictionary_ReturnsFailed() {
        let response = TestNetworkResponseData.dictionary(
            statusCode: 422,
            data: ["error": "Invalid parameters"]
        )

        let result: ImageGenerationResponse = IllustrateProviders.createInvalidResponseError(
            response: response,
            modelCode: .OPENAI_DALLE3
        )

        XCTAssertEqual(result.status, EnumGenerationStatus.FAILED)
        XCTAssertEqual(result.errorCode, EnumGenerationAdapterErrorCode.MODEL_ERROR)
        XCTAssertEqual(result.errorMessage, "Invalid response")
        XCTAssertNotNil(result.rawResponse)
    }

    func testCreateInvalidResponseError_CustomMessage_UsesCustomMessage() {
        let response = TestNetworkResponseData.array(
            statusCode: 400,
            data: [["error": "bad request"]]
        )

        let result: ImageGenerationResponse = IllustrateProviders.createInvalidResponseError(
            response: response,
            modelCode: .STABILITY_CORE,
            customMessage: "Custom error text"
        )

        XCTAssertEqual(result.status, EnumGenerationStatus.FAILED)
        XCTAssertEqual(result.errorMessage, "Custom error text")
    }
}
