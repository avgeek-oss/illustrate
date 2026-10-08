// MARK: - GenerateImageAdapterTests.swift

// Unit tests for GenerateImageAdapter and related types.
//
// Tests cover:
// - ImageSetResponse struct serialization
// - extractRawResponse() function
// - EnumGenerationStatus enum
// - EnumGenerationAdapterErrorCode enum
// - ImageGenerationResponse struct
// - getImageGenerationAdapter() factory function

import XCTest
@testable import Illustrate
@testable import IllustrateProviders

/// Use IllustrateProviders version of NetworkResponseData to avoid ambiguity
private typealias TestNetworkResponseData = IllustrateProviders.NetworkResponseData

final class GenerateImageAdapterTests: XCTestCase {
    // MARK: - EnumGenerationStatus Tests

    func testEnumGenerationStatus_allCases() {
        let allCases = EnumGenerationStatus.allCases

        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.GENERATED))
        XCTAssertTrue(allCases.contains(.FAILED))
    }

    func testEnumGenerationStatus_rawValues() {
        XCTAssertEqual(EnumGenerationStatus.GENERATED.rawValue, "GENERATED")
        XCTAssertEqual(EnumGenerationStatus.FAILED.rawValue, "FAILED")
    }

    func testEnumGenerationStatus_identifiable_id() {
        XCTAssertEqual(EnumGenerationStatus.GENERATED.id, "GENERATED")
        XCTAssertEqual(EnumGenerationStatus.FAILED.id, "FAILED")
    }

    func testEnumGenerationStatus_codable_generated() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(EnumGenerationStatus.GENERATED)
        let decoded = try decoder.decode(EnumGenerationStatus.self, from: data)

        XCTAssertEqual(decoded, .GENERATED)
    }

    func testEnumGenerationStatus_codable_failed() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(EnumGenerationStatus.FAILED)
        let decoded = try decoder.decode(EnumGenerationStatus.self, from: data)

        XCTAssertEqual(decoded, .FAILED)
    }

    // MARK: - EnumGenerationAdapterErrorCode Tests

    func testEnumGenerationAdapterErrorCode_generatorError() {
        let code = EnumGenerationAdapterErrorCode.GENERATOR_ERROR

        XCTAssertEqual(code.rawValue, "Internal Generator Error")
    }

    func testEnumGenerationAdapterErrorCode_modelError() {
        let code = EnumGenerationAdapterErrorCode.MODEL_ERROR

        XCTAssertEqual(code.rawValue, "Provider Model Error")
    }

    func testEnumGenerationAdapterErrorCode_adapterError() {
        let code = EnumGenerationAdapterErrorCode.ADAPTER_ERROR

        XCTAssertEqual(code.rawValue, "Internal Adapter Error")
    }

    func testEnumGenerationAdapterErrorCode_transformResponseError() {
        let code = EnumGenerationAdapterErrorCode.TRANSFORM_RESPONSE_ERROR

        XCTAssertEqual(code.rawValue, "Internal Response Transform Error")
    }

    func testEnumGenerationAdapterErrorCode_codable_roundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for errorCode in [
            EnumGenerationAdapterErrorCode.GENERATOR_ERROR,
            .MODEL_ERROR,
            .ADAPTER_ERROR,
            .TRANSFORM_RESPONSE_ERROR,
        ] {
            let data = try encoder.encode(errorCode)
            let decoded = try decoder.decode(EnumGenerationAdapterErrorCode.self, from: data)
            XCTAssertEqual(decoded, errorCode)
        }
    }

    // MARK: - ImageGenerationResponse Tests

    func testImageGenerationResponse_initialization_minimal() {
        let response = ImageGenerationResponse(status: .GENERATED)

        XCTAssertNil(response.generationId)
        XCTAssertEqual(response.status, .GENERATED)
        XCTAssertNil(response.base64)
        XCTAssertNil(response.size)
        XCTAssertNil(response.cost)
        XCTAssertNil(response.errorCode)
        XCTAssertNil(response.errorMessage)
    }

    func testImageGenerationResponse_initialization_success() {
        let id = UUID()
        let response = ImageGenerationResponse(
            generationId: id,
            status: .GENERATED,
            base64: "abc123",
            size: 1024,
            cost: 0.05,
            modelPrompt: "enhanced prompt",
            colorPalette: ["#FF0000", "#00FF00"]
        )

        XCTAssertEqual(response.generationId, id)
        XCTAssertEqual(response.status, .GENERATED)
        XCTAssertEqual(response.base64, "abc123")
        XCTAssertEqual(response.size, 1024)
        XCTAssertEqual(response.cost, 0.05)
        XCTAssertEqual(response.modelPrompt, "enhanced prompt")
        XCTAssertEqual(response.colorPalette, ["#FF0000", "#00FF00"])
    }

    func testImageGenerationResponse_initialization_failure() {
        let response = ImageGenerationResponse(
            status: .FAILED,
            errorCode: .GENERATOR_ERROR,
            errorMessage: "Model unavailable",
            rawResponse: "{\"error\": \"timeout\"}"
        )

        XCTAssertNil(response.generationId)
        XCTAssertEqual(response.status, .FAILED)
        XCTAssertEqual(response.errorCode, .GENERATOR_ERROR)
        XCTAssertEqual(response.errorMessage, "Model unavailable")
        XCTAssertEqual(response.rawResponse, "{\"error\": \"timeout\"}")
    }

    func testImageGenerationResponse_initialization_withMetadata() {
        let metadata = ["seed": "12345", "steps": "30"]
        let response = ImageGenerationResponse(
            status: .GENERATED,
            metadata: metadata,
            actualDimensions: "1024x1024"
        )

        XCTAssertEqual(response.metadata, metadata)
        XCTAssertEqual(response.actualDimensions, "1024x1024")
    }

    func testImageGenerationResponse_codable_roundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = ImageGenerationResponse(
            generationId: UUID(),
            status: .GENERATED,
            base64: nil,
            size: 2048,
            cost: 0.10,
            modelPrompt: "A beautiful sunset",
            colorPalette: ["#FFA500", "#FF4500"],
            metadata: ["guidance": "7.5"],
            actualDimensions: "512x512"
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ImageGenerationResponse.self, from: data)

        XCTAssertEqual(decoded.generationId, original.generationId)
        XCTAssertEqual(decoded.status, original.status)
        XCTAssertEqual(decoded.size, original.size)
        XCTAssertEqual(decoded.cost, original.cost)
        XCTAssertEqual(decoded.modelPrompt, original.modelPrompt)
        XCTAssertEqual(decoded.colorPalette, original.colorPalette)
        XCTAssertEqual(decoded.metadata, original.metadata)
        XCTAssertEqual(decoded.actualDimensions, original.actualDimensions)
    }

    func testImageGenerationResponse_codable_withErrorCode() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = ImageGenerationResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: "Invalid model ID"
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ImageGenerationResponse.self, from: data)

        XCTAssertEqual(decoded.status, .FAILED)
        XCTAssertEqual(decoded.errorCode, .MODEL_ERROR)
        XCTAssertEqual(decoded.errorMessage, "Invalid model ID")
    }

    // MARK: - ImageSetResponse Tests

    func testImageSetResponse_initialization_minimal() {
        let response = ImageSetResponse(status: .GENERATED)

        XCTAssertEqual(response.status, .GENERATED)
        XCTAssertNil(response.set)
        XCTAssertNil(response.generations)
        XCTAssertNil(response.errorCode)
        XCTAssertNil(response.errorMessage)
        XCTAssertNil(response.rawResponse)
    }

    func testImageSetResponse_initialization_failure() {
        let response = ImageSetResponse(
            status: .FAILED,
            errorCode: .GENERATOR_ERROR,
            errorMessage: "No generation was successful"
        )

        XCTAssertEqual(response.status, .FAILED)
        XCTAssertEqual(response.errorCode, .GENERATOR_ERROR)
        XCTAssertEqual(response.errorMessage, "No generation was successful")
    }

    func testImageSetResponse_initialization_withRawResponse() throws {
        let response = ImageSetResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: "API Error",
            rawResponse: "HTTP Status: 500\n\n{\"error\": \"internal\"}"
        )

        XCTAssertNotNil(response.rawResponse)
        XCTAssertTrue(try XCTUnwrap(response.rawResponse?.contains("500")))
    }

    func testImageSetResponse_codable_roundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = ImageSetResponse(
            status: .FAILED,
            errorCode: .ADAPTER_ERROR,
            errorMessage: "Parse error",
            rawResponse: "{\"data\": null}"
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ImageSetResponse.self, from: data)

        XCTAssertEqual(decoded.status, original.status)
        XCTAssertEqual(decoded.errorCode, original.errorCode)
        XCTAssertEqual(decoded.errorMessage, original.errorMessage)
        XCTAssertEqual(decoded.rawResponse, original.rawResponse)
    }

    // MARK: - extractRawResponse Tests

    func testExtractRawResponse_dictionary_basicFormat() throws {
        let data: [String: Any] = ["status": "ok"]
        let response = TestNetworkResponseData.dictionary(statusCode: 200, data: data)

        let extracted = extractRawResponse(from: response)

        XCTAssertNotNil(extracted)
        XCTAssertTrue(try XCTUnwrap(extracted?.contains("HTTP Status: 200")))
    }

    func testExtractRawResponse_dictionary_containsJsonData() throws {
        let data: [String: Any] = ["result": "success", "count": 5]
        let response = TestNetworkResponseData.dictionary(statusCode: 200, data: data)

        let extracted = extractRawResponse(from: response)

        XCTAssertNotNil(extracted)
        XCTAssertTrue(try XCTUnwrap(extracted?.contains("result")))
        XCTAssertTrue(try XCTUnwrap(extracted?.contains("success")))
    }

    func testExtractRawResponse_dictionary_errorStatusCode() throws {
        let data: [String: Any] = ["error": "Not found"]
        let response = TestNetworkResponseData.dictionary(statusCode: 404, data: data)

        let extracted = extractRawResponse(from: response)

        XCTAssertNotNil(extracted)
        XCTAssertTrue(try XCTUnwrap(extracted?.contains("HTTP Status: 404")))
        XCTAssertTrue(try XCTUnwrap(extracted?.contains("error")))
    }

    func testExtractRawResponse_dictionary_emptyData() throws {
        let response = TestNetworkResponseData.dictionary(statusCode: 204, data: [:])

        let extracted = extractRawResponse(from: response)

        XCTAssertNotNil(extracted)
        XCTAssertTrue(try XCTUnwrap(extracted?.contains("HTTP Status: 204")))
    }

    func testExtractRawResponse_array_basicFormat() throws {
        let data: [[String: Any]] = [["id": 1], ["id": 2]]
        let response = TestNetworkResponseData.array(statusCode: 200, data: data)

        let extracted = extractRawResponse(from: response)

        XCTAssertNotNil(extracted)
        XCTAssertTrue(try XCTUnwrap(extracted?.contains("HTTP Status: 200")))
    }

    func testExtractRawResponse_array_containsItems() throws {
        let data: [[String: Any]] = [["name": "first"], ["name": "second"]]
        let response = TestNetworkResponseData.array(statusCode: 200, data: data)

        let extracted = extractRawResponse(from: response)

        XCTAssertNotNil(extracted)
        XCTAssertTrue(try XCTUnwrap(extracted?.contains("first")))
        XCTAssertTrue(try XCTUnwrap(extracted?.contains("second")))
    }

    func testExtractRawResponse_array_empty() throws {
        let response = TestNetworkResponseData.array(statusCode: 200, data: [])

        let extracted = extractRawResponse(from: response)

        XCTAssertNotNil(extracted)
        XCTAssertTrue(try XCTUnwrap(extracted?.contains("HTTP Status: 200")))
    }

    func testExtractRawResponse_image_containsMimeType() throws {
        let response = TestNetworkResponseData.image(statusCode: 200, base64: "abc123", mimeType: "image/png")

        let extracted = extractRawResponse(from: response)

        XCTAssertNotNil(extracted)
        XCTAssertTrue(try XCTUnwrap(extracted?.contains("image/png")))
    }

    func testExtractRawResponse_image_containsStatusCode() throws {
        let response = TestNetworkResponseData.image(statusCode: 200, base64: "abc", mimeType: "image/jpeg")

        let extracted = extractRawResponse(from: response)

        XCTAssertNotNil(extracted)
        XCTAssertTrue(try XCTUnwrap(extracted?.contains("HTTP Status: 200")))
    }

    func testExtractRawResponse_image_indicatesBinaryResponse() throws {
        let response = TestNetworkResponseData.image(statusCode: 200, base64: "xyz", mimeType: "image/png")

        let extracted = extractRawResponse(from: response)

        XCTAssertNotNil(extracted)
        XCTAssertTrue(try XCTUnwrap(extracted?.contains("Binary image response")))
    }

    func testExtractRawResponse_image_doesNotContainBase64() throws {
        let longBase64 = String(repeating: "A", count: 1000)
        let response = TestNetworkResponseData.image(statusCode: 200, base64: longBase64, mimeType: "image/png")

        let extracted = extractRawResponse(from: response)

        XCTAssertNotNil(extracted)
        XCTAssertFalse(try XCTUnwrap(extracted?.contains(longBase64)))
    }

    // MARK: - getImageGenerationAdapter Tests

    func testGetImageGenerationAdapter_openaiDalle3_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .OPENAI_DALLE3)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_openaiGptImage1_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .OPENAI_GPT_IMAGE_1)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_openaiGptImage15_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .OPENAI_GPT_IMAGE_1_5)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_stabilityCore_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .STABILITY_CORE)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_stabilityUltra_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .STABILITY_ULTRA)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_stabilitySD3_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .STABILITY_SD3)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_stabilitySD35Large_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .STABILITY_SD35_LARGE)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_stabilityCreativeUpscale_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .STABILITY_CREATIVE_UPSCALE)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_stabilityFastUpscale_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .STABILITY_FAST_UPSCALE)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_stabilityInpaint_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .STABILITY_INPAINT)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_stabilityOutpaint_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .STABILITY_OUTPAINT)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_stabilityRemoveBackground_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .STABILITY_REMOVE_BACKGROUND)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_replicateFluxSchnell_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .REPLICATE_FLUX_SCHNELL)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_replicateFluxDev_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .REPLICATE_FLUX_DEV)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_replicateFluxPro_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .REPLICATE_FLUX_PRO)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_replicateFlux2Pro_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .REPLICATE_FLUX_2_PRO)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_falFluxSchnell_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .FAL_FLUX_SCHNELL)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_falFluxDev_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .FAL_FLUX_DEV)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_falFluxPro_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .FAL_FLUX_PRO)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_googleImagen3_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .GOOGLE_IMAGEN_3)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_googleImagen4Fast_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .GOOGLE_IMAGEN_4_FAST)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_googleGeminiFlashImage_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .GOOGLE_GEMINI_FLASH_IMAGE)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_googleNanoBanana2_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .GOOGLE_GEMINI_31_FLASH_IMAGE)

        XCTAssertNotNil(adapter)
    }

    func testGetImageGenerationAdapter_googleNanoBananaLite_returnsAdapter() {
        let adapter = getImageGenerationAdapter(modelCode: .GOOGLE_GEMINI_31_FLASH_LITE_IMAGE)

        XCTAssertNotNil(adapter)
    }

    /// Video models should return nil (not image adapters)
    func testGetImageGenerationAdapter_stabilityImageToVideo_returnsNil() {
        let adapter = getImageGenerationAdapter(modelCode: .STABILITY_IMAGE_TO_VIDEO)

        XCTAssertNil(adapter)
    }

    func testGetImageGenerationAdapter_openaiSora2_returnsNil() {
        let adapter = getImageGenerationAdapter(modelCode: .OPENAI_SORA_2)

        XCTAssertNil(adapter)
    }

    func testGetImageGenerationAdapter_replicateSeedance1Pro_returnsNil() {
        let adapter = getImageGenerationAdapter(modelCode: .REPLICATE_SEEDANCE_1_PRO)

        XCTAssertNil(adapter)
    }

    func testGetImageGenerationAdapter_replicateLumaRay_returnsNil() {
        let adapter = getImageGenerationAdapter(modelCode: .REPLICATE_LUMA_RAY)

        XCTAssertNil(adapter)
    }

    // MARK: - ProviderKeyInfo Tests

    func testProviderKeyInfo_initialization() {
        let providerId = UUID()
        let projectId = UUID()
        let keyInfo = ProviderKeyInfo(
            providerId: providerId,
            providerCode: .OPENAI,
            projectId: projectId
        )

        XCTAssertEqual(keyInfo.providerId, providerId)
        XCTAssertEqual(keyInfo.providerCode, .OPENAI)
        XCTAssertEqual(keyInfo.projectId, projectId)
    }

    func testProviderKeyInfo_codable_roundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = ProviderKeyInfo(
            providerId: UUID(),
            providerCode: .STABILITY_AI,
            projectId: UUID()
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ProviderKeyInfo.self, from: data)

        XCTAssertEqual(decoded.providerId, original.providerId)
        XCTAssertEqual(decoded.providerCode, original.providerCode)
        XCTAssertEqual(decoded.projectId, original.projectId)
    }

    // MARK: - ReferenceImageData Tests

    func testReferenceImageData_initialization_minimal() {
        let ref = ReferenceImageData(base64Image: "abc123")

        XCTAssertEqual(ref.base64Image, "abc123")
        XCTAssertEqual(ref.referenceType, "")
        XCTAssertNil(ref.cacheKey)
    }

    func testReferenceImageData_initialization_full() {
        let ref = ReferenceImageData(
            base64Image: "xyz789",
            referenceType: "style",
            cacheKey: "backdrop_16_9_1"
        )

        XCTAssertEqual(ref.base64Image, "xyz789")
        XCTAssertEqual(ref.referenceType, "style")
        XCTAssertEqual(ref.cacheKey, "backdrop_16_9_1")
    }

    func testReferenceImageData_codable_roundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = ReferenceImageData(
            base64Image: "test",
            referenceType: "asset",
            cacheKey: "my_key"
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ReferenceImageData.self, from: data)

        XCTAssertEqual(decoded.base64Image, original.base64Image)
        XCTAssertEqual(decoded.referenceType, original.referenceType)
        XCTAssertEqual(decoded.cacheKey, original.cacheKey)
    }

    // MARK: - ImageEditDirection Tests

    func testImageEditDirection_initialization() {
        let direction = ImageEditDirection(left: 100, right: 100, up: 50, down: 50)

        XCTAssertEqual(direction.left, 100)
        XCTAssertEqual(direction.right, 100)
        XCTAssertEqual(direction.up, 50)
        XCTAssertEqual(direction.down, 50)
    }

    func testImageEditDirection_codable_roundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = ImageEditDirection(left: 64, right: 128, up: 32, down: 64)

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ImageEditDirection.self, from: data)

        XCTAssertEqual(decoded.left, original.left)
        XCTAssertEqual(decoded.right, original.right)
        XCTAssertEqual(decoded.up, original.up)
        XCTAssertEqual(decoded.down, original.down)
    }

    func testImageEditDirection_allZeros() {
        let direction = ImageEditDirection(left: 0, right: 0, up: 0, down: 0)

        XCTAssertEqual(direction.left, 0)
        XCTAssertEqual(direction.right, 0)
        XCTAssertEqual(direction.up, 0)
        XCTAssertEqual(direction.down, 0)
    }

    // MARK: - ImageGenerationRequest Tests

    func testImageGenerationRequest_initialization_minimal() {
        let keyInfo = ProviderKeyInfo(
            providerId: UUID(),
            providerCode: .OPENAI,
            projectId: UUID()
        )
        let request = ImageGenerationRequest(
            modelId: "gpt-image-1",
            prompt: "A cat",
            dimensions: "1024x1024",
            providerKey: keyInfo,
            providerSecret: "sk-test"
        )

        XCTAssertEqual(request.modelId, "gpt-image-1")
        XCTAssertEqual(request.prompt, "A cat")
        XCTAssertEqual(request.dimensions, "1024x1024")
        XCTAssertEqual(request.numberOfImages, 1)
        XCTAssertNil(request.negativePrompt)
        XCTAssertNil(request.clientImage)
    }

    func testImageGenerationRequest_initialization_full() {
        let keyInfo = ProviderKeyInfo(
            providerId: UUID(),
            providerCode: .STABILITY_AI,
            projectId: UUID()
        )
        let request = ImageGenerationRequest(
            modelId: "stable-diffusion-3",
            prompt: "A dog",
            negativePrompt: "ugly, blurry",
            dimensions: "512x512",
            providerKey: keyInfo,
            providerSecret: "key123",
            numberOfImages: 4,
            steps: 30,
            guidance: 7.5,
            seed: 42
        )

        XCTAssertEqual(request.modelId, "stable-diffusion-3")
        XCTAssertEqual(request.negativePrompt, "ugly, blurry")
        XCTAssertEqual(request.numberOfImages, 4)
        XCTAssertEqual(request.steps, 30)
        XCTAssertEqual(request.guidance, 7.5)
        XCTAssertEqual(request.seed, 42)
    }

    func testImageRequestProviderLimits_xAIRejectsOverflowWithoutMutation() {
        let keyInfo = ProviderKeyInfo(
            providerId: EnumProviderCode.XAI.providerId,
            providerCode: .XAI,
            projectId: UUID()
        )
        let request = ImageGenerationRequest(
            modelId: EnumProviderModelCode.XAI_GROK_IMAGINE_IMAGE.modelId.uuidString,
            prompt: "Restyle the aircraft",
            dimensions: "16:9",
            clientImage: "source",
            clientReferenceImages: (0 ..< 3).map { index in
                ReferenceImageData(base64Image: "reference-\(index)")
            },
            providerKey: keyInfo,
            providerSecret: "test"
        )

        XCTAssertEqual(
            imageRequestProviderInputValidationMessage(request),
            "xAI image editing accepts at most three source and reference images combined."
        )
        XCTAssertEqual(request.clientReferenceImages?.count, 3)
    }

    func testImageRequestProviderLimits_bytePlusRejectsOverflowWithoutMutation() {
        let keyInfo = ProviderKeyInfo(
            providerId: EnumProviderCode.BYTEPLUS_MODELARK.providerId,
            providerCode: .BYTEPLUS_MODELARK,
            projectId: UUID()
        )
        let request = ImageGenerationRequest(
            modelId: EnumProviderModelCode.BYTEPLUS_DOLA_SEEDREAM_5_0_PRO.modelId.uuidString,
            prompt: "Restyle the aircraft",
            dimensions: "1:1",
            clientImage: "source",
            clientReferenceImages: (0 ..< 12).map { index in
                ReferenceImageData(base64Image: "reference-\(index)")
            },
            providerKey: keyInfo,
            providerSecret: "test"
        )

        XCTAssertEqual(
            imageRequestProviderInputValidationMessage(request),
            "BytePlus image generation accepts at most 10 source and reference images combined."
        )
        XCTAssertEqual(request.clientReferenceImages?.count, 12)
    }

    func testImageRequestProviderLimits_reveRejectsOverflowWithoutMutation() {
        let keyInfo = ProviderKeyInfo(
            providerId: EnumProviderCode.REPLICATE.providerId,
            providerCode: .REPLICATE,
            projectId: UUID()
        )
        let request = ImageGenerationRequest(
            modelId: EnumProviderModelCode.REPLICATE_REVE_2_1.modelId.uuidString,
            prompt: "Restyle the aircraft",
            dimensions: "4:1",
            clientImage: "source",
            clientReferenceImages: (0 ..< 8).map { index in
                ReferenceImageData(base64Image: "reference-\(index)")
            },
            providerKey: keyInfo,
            providerSecret: "test"
        )

        XCTAssertEqual(
            imageRequestProviderInputValidationMessage(request),
            "Reve 2.1 accepts at most eight source and reference images combined."
        )
        XCTAssertEqual(request.clientReferenceImages?.count, 8)
    }

    func testMaximumCombinedImageInputs_coversCombinedInputImageAdapters() {
        let expectedLimits: [(EnumProviderModelCode, Int)] = [
            (.REPLICATE_REVE_2_1, 8),
            (.REPLICATE_SEEDREAM_5_PRO, 10),
            (.REPLICATE_SEEDREAM_5_LITE, 14),
            (.REPLICATE_RIVERFLOW_2_5_PRO, 10),
            (.REPLICATE_RIVERFLOW_2_5_FAST, 4),
            (.LUMA_UNI_1, 9),
            (.LUMA_UNI_1_MAX, 9),
        ]

        for (modelCode, expectedLimit) in expectedLimits {
            XCTAssertEqual(
                maximumCombinedImageInputs(for: modelCode),
                expectedLimit,
                "\(modelCode.rawValue) should reserve source-image capacity"
            )
        }
    }

    func testImageRequestProviderLimits_preservesOtherProviders() {
        let keyInfo = ProviderKeyInfo(
            providerId: EnumProviderCode.OPENAI.providerId,
            providerCode: .OPENAI,
            projectId: UUID()
        )
        let request = ImageGenerationRequest(
            modelId: EnumProviderModelCode.OPENAI_GPT_IMAGE_1.modelId.uuidString,
            prompt: "Restyle the aircraft",
            dimensions: "1024x1024",
            clientImage: "source",
            clientReferenceImages: (0 ..< 4).map { index in
                ReferenceImageData(base64Image: "reference-\(index)")
            },
            providerKey: keyInfo,
            providerSecret: "test"
        )

        XCTAssertNil(imageRequestProviderInputValidationMessage(request))
        XCTAssertEqual(request.clientReferenceImages?.count, 4)
    }

    // MARK: - VideoGenerationResponse Tests

    func testVideoGenerationResponse_initialization_minimal() {
        let response = VideoGenerationResponse(status: .GENERATED)

        XCTAssertNil(response.generationId)
        XCTAssertEqual(response.status, .GENERATED)
        XCTAssertNil(response.videoUrl)
        XCTAssertNil(response.actualDuration)
    }

    func testVideoGenerationResponse_initialization_success() {
        let id = UUID()
        let response = VideoGenerationResponse(
            generationId: id,
            status: .GENERATED,
            videoUrl: "https://example.com/video.mp4",
            size: 5_000_000,
            cost: 0.25,
            actualDimensions: "1920x1080",
            actualDuration: 5
        )

        XCTAssertEqual(response.generationId, id)
        XCTAssertEqual(response.videoUrl, "https://example.com/video.mp4")
        XCTAssertEqual(response.size, 5_000_000)
        XCTAssertEqual(response.cost, 0.25)
        XCTAssertEqual(response.actualDimensions, "1920x1080")
        XCTAssertEqual(response.actualDuration, 5)
    }

    func testVideoGenerationResponse_initialization_failure() {
        let response = VideoGenerationResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: "Video generation timed out"
        )

        XCTAssertEqual(response.status, .FAILED)
        XCTAssertEqual(response.errorCode, .MODEL_ERROR)
        XCTAssertEqual(response.errorMessage, "Video generation timed out")
    }

    func testVideoGenerationResponse_codable_roundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = VideoGenerationResponse(
            generationId: UUID(),
            status: .GENERATED,
            videoUrl: "https://cdn.example.com/vid.mp4",
            size: 10_000_000,
            cost: 0.50,
            actualDimensions: "1280x720",
            actualDuration: 10
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(VideoGenerationResponse.self, from: data)

        XCTAssertEqual(decoded.generationId, original.generationId)
        XCTAssertEqual(decoded.status, original.status)
        XCTAssertEqual(decoded.videoUrl, original.videoUrl)
        XCTAssertEqual(decoded.actualDuration, original.actualDuration)
    }
}
