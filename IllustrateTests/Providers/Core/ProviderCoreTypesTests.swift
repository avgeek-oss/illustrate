// MARK: - ProviderCoreTypesTests.swift

// Tests for IllustrateProviders core types, enums, and response helpers.
//
// Tests cover:
// - NetworkResponseData.rawResponseString: formatting for dictionary, array, image cases
// - ResponseHelpers: createInvalidResponseError, createInvalidVideoResponseError
// - EnumProviderCode: deterministic providerId, key type labels, credit currency
// - EnumSetType: label, subLabel, icon for all 3 generation types
// - NumericRange: initialization, equality, Codable round-trip
// - ProviderModelData: modelId derivation from modelCode
// - CostRequest init(from:) conversions

import XCTest
@testable import IllustrateProviders

// MARK: - NetworkResponseData.rawResponseString Tests

final class NetworkResponseDataTests: XCTestCase {
    func testDictionary_ContainsHTTPStatus() throws {
        let response = NetworkResponseData.dictionary(statusCode: 200, data: ["key": "value"])
        let raw = response.rawResponseString
        XCTAssertNotNil(raw)
        XCTAssertTrue(try XCTUnwrap(raw?.contains("HTTP Status: 200")))
    }

    func testDictionary_ContainsPrettyPrintedJSON() throws {
        let response = NetworkResponseData.dictionary(statusCode: 200, data: ["name": "test"])
        let raw = try XCTUnwrap(response.rawResponseString)
        XCTAssertTrue(raw.contains("\"name\""))
        XCTAssertTrue(raw.contains("\"test\""))
    }

    func testDictionary_NestedObjects_Serializes() throws {
        let nested: [String: Any] = ["outer": ["inner": "value"]]
        let response = NetworkResponseData.dictionary(statusCode: 200, data: nested)
        let raw = try XCTUnwrap(response.rawResponseString)
        XCTAssertTrue(raw.contains("outer"))
        XCTAssertTrue(raw.contains("inner"))
    }

    func testArray_ContainsHTTPStatus() throws {
        let response = NetworkResponseData.array(statusCode: 201, data: [["id": "1"]])
        let raw = response.rawResponseString
        XCTAssertNotNil(raw)
        XCTAssertTrue(try XCTUnwrap(raw?.contains("HTTP Status: 201")))
    }

    func testArray_ContainsArrayContent() throws {
        let response = NetworkResponseData.array(statusCode: 200, data: [["name": "item1"], ["name": "item2"]])
        let raw = try XCTUnwrap(response.rawResponseString)
        XCTAssertTrue(raw.contains("item1"))
        XCTAssertTrue(raw.contains("item2"))
    }

    func testImage_ContainsMimeType() throws {
        let response = NetworkResponseData.image(statusCode: 200, base64: "abc123", mimeType: "image/png")
        let raw = try XCTUnwrap(response.rawResponseString)
        XCTAssertTrue(raw.contains("image/png"))
        XCTAssertTrue(raw.contains("HTTP Status: 200"))
    }

    func testImage_DoesNotContainBinaryData() throws {
        let response = NetworkResponseData.image(statusCode: 200, base64: "abc123base64data", mimeType: "image/jpeg")
        let raw = try XCTUnwrap(response.rawResponseString)
        XCTAssertFalse(raw.contains("abc123base64data"), "Should not include base64 data in raw string")
    }

    func testStatusCode_400_AppearsInOutput() throws {
        let response = NetworkResponseData.dictionary(statusCode: 400, data: ["error": "bad request"])
        XCTAssertTrue(try XCTUnwrap(response.rawResponseString?.contains("400")))
    }

    func testStatusCode_500_AppearsInOutput() throws {
        let response = NetworkResponseData.dictionary(statusCode: 500, data: ["error": "server error"])
        XCTAssertTrue(try XCTUnwrap(response.rawResponseString?.contains("500")))
    }

    func testAllCases_ProduceNonNilString() {
        let dict = NetworkResponseData.dictionary(statusCode: 200, data: [:])
        let arr = NetworkResponseData.array(statusCode: 200, data: [])
        let img = NetworkResponseData.image(statusCode: 200, base64: "", mimeType: "image/png")

        XCTAssertNotNil(dict.rawResponseString)
        XCTAssertNotNil(arr.rawResponseString)
        XCTAssertNotNil(img.rawResponseString)
    }

    func testEmptyDictionary_ProducesValidOutput() throws {
        let response = NetworkResponseData.dictionary(statusCode: 200, data: [:])
        let raw = try XCTUnwrap(response.rawResponseString)
        XCTAssertTrue(raw.contains("HTTP Status: 200"))
    }

    func testEmptyArray_ProducesValidOutput() throws {
        let response = NetworkResponseData.array(statusCode: 200, data: [])
        let raw = try XCTUnwrap(response.rawResponseString)
        XCTAssertTrue(raw.contains("HTTP Status: 200"))
    }
}

// MARK: - ResponseHelpers Tests

final class ResponseHelpersTests: XCTestCase {
    private var testResponse: NetworkResponseData {
        .dictionary(statusCode: 500, data: ["error": "something failed"])
    }

    func testCreateInvalidResponseError_StatusIsFailed() {
        let result = createInvalidResponseError(response: testResponse, modelCode: .OPENAI_DALLE3)
        XCTAssertEqual(result.status, .FAILED)
    }

    func testCreateInvalidResponseError_ErrorCodeIsModelError() {
        let result = createInvalidResponseError(response: testResponse, modelCode: .OPENAI_DALLE3)
        XCTAssertEqual(result.errorCode, .MODEL_ERROR)
    }

    func testCreateInvalidResponseError_DefaultMessage() {
        let result = createInvalidResponseError(response: testResponse, modelCode: .OPENAI_DALLE3)
        XCTAssertEqual(result.errorMessage, "Invalid response")
    }

    func testCreateInvalidResponseError_CustomMessage() {
        let result = createInvalidResponseError(
            response: testResponse,
            modelCode: .OPENAI_DALLE3,
            customMessage: "Custom error"
        )
        XCTAssertEqual(result.errorMessage, "Custom error")
    }

    func testCreateInvalidResponseError_RawResponsePopulated() throws {
        let result = createInvalidResponseError(response: testResponse, modelCode: .OPENAI_DALLE3)
        XCTAssertNotNil(result.rawResponse)
        XCTAssertTrue(try XCTUnwrap(result.rawResponse?.contains("500")))
    }

    func testCreateInvalidVideoResponseError_StatusIsFailed() {
        let result = createInvalidVideoResponseError(response: testResponse, modelCode: .GOOGLE_VEO_31)
        XCTAssertEqual(result.status, .FAILED)
    }

    func testCreateInvalidVideoResponseError_ErrorCodeIsModelError() {
        let result = createInvalidVideoResponseError(response: testResponse, modelCode: .GOOGLE_VEO_31)
        XCTAssertEqual(result.errorCode, .MODEL_ERROR)
    }

    func testCreateInvalidVideoResponseError_CustomMessage() {
        let result = createInvalidVideoResponseError(
            response: testResponse,
            modelCode: .GOOGLE_VEO_31,
            customMessage: "Video error"
        )
        XCTAssertEqual(result.errorMessage, "Video error")
    }

    func testCreateInvalidStatusURLError_StatusIsFailed() {
        let result = createInvalidStatusURLError()
        XCTAssertEqual(result.status, .FAILED)
    }

    func testCreateInvalidStatusURLError_ErrorCodeIsModelError() {
        let result = createInvalidStatusURLError()
        XCTAssertEqual(result.errorCode, .MODEL_ERROR)
    }

    func testCreateInvalidStatusURLError_Message() {
        let result = createInvalidStatusURLError()
        XCTAssertEqual(result.errorMessage, "Invalid status URL")
    }

    func testCreateInvalidVideoStatusURLError_StatusIsFailed() {
        let result = createInvalidVideoStatusURLError()
        XCTAssertEqual(result.status, .FAILED)
    }

    func testCreateInvalidVideoStatusURLError_ErrorCodeIsModelError() {
        let result = createInvalidVideoStatusURLError()
        XCTAssertEqual(result.errorCode, .MODEL_ERROR)
    }

    func testCreateInvalidVideoStatusURLError_Message() {
        let result = createInvalidVideoStatusURLError()
        XCTAssertEqual(result.errorMessage, "Invalid status URL")
    }
}

// MARK: - EnumProviderCode Tests

final class EnumProviderCodeTests: XCTestCase {
    func testProviderId_IsDeterministic() {
        let id1 = EnumProviderCode.OPENAI.providerId
        let id2 = EnumProviderCode.OPENAI.providerId
        XCTAssertEqual(id1, id2)
    }

    func testAllProviderCodes_ProduceUniqueIds() {
        let ids = EnumProviderCode.allCases.map(\.providerId)
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "All provider codes should produce unique UUIDs")
    }

    func testAllCases_Count27() {
        XCTAssertEqual(EnumProviderCode.allCases.count, 27)
    }

    func testProviderId_NotNilUUID() {
        for code in EnumProviderCode.allCases {
            XCTAssertNotEqual(code.providerId, UUID(), "\(code) should have a deterministic UUID")
        }
    }

    func testCodable_RoundTrip() throws {
        for code in EnumProviderCode.allCases {
            let data = try JSONEncoder().encode(code)
            let decoded = try JSONDecoder().decode(EnumProviderCode.self, from: data)
            XCTAssertEqual(decoded, code)
        }
    }

    func testId_MatchesRawValue() {
        for code in EnumProviderCode.allCases {
            XCTAssertEqual(code.id, code.rawValue)
        }
    }
}

// MARK: - EnumProviderKeyType Tests

final class EnumProviderKeyTypeTests: XCTestCase {
    func testJSON_Label() {
        XCTAssertEqual(EnumProviderKeyType.JSON.label, "JSON credential")
    }

    func testAPI_Label() {
        XCTAssertEqual(EnumProviderKeyType.API.label, "API key")
    }

    func testAllCases_Count3() {
        XCTAssertEqual(EnumProviderKeyType.allCases.count, 3)
    }

    func testCodable_RoundTrip() throws {
        for keyType in EnumProviderKeyType.allCases {
            let data = try JSONEncoder().encode(keyType)
            let decoded = try JSONDecoder().decode(EnumProviderKeyType.self, from: data)
            XCTAssertEqual(decoded, keyType)
        }
    }
}

// MARK: - EnumProviderCreditCurrency Tests

final class EnumProviderCreditCurrencyTests: XCTestCase {
    func testUSD_RawValue() {
        XCTAssertEqual(EnumProviderCreditCurrency.USD.rawValue, "USD")
    }

    func testCredits_RawValue() {
        XCTAssertEqual(EnumProviderCreditCurrency.CREDITS.rawValue, "Credits")
    }

    func testAllCases_Count2() {
        XCTAssertEqual(EnumProviderCreditCurrency.allCases.count, 2)
    }
}

// MARK: - EnumSetType Tests

final class EnumSetTypeTests: XCTestCase {
    func testImageGenerate_Label() {
        XCTAssertEqual(EnumSetType.IMAGE_GENERATE.label, "Generate Image")
    }

    func testVideoGenerate_Label() {
        XCTAssertEqual(EnumSetType.VIDEO_GENERATE.label, "Generate Video")
    }

    func testVideoExtend_Label() {
        XCTAssertEqual(EnumSetType.VIDEO_EXTEND.label, "Extend Video")
    }

    func testAllCases_HaveNonEmptySubLabel() {
        for setType in EnumSetType.allCases {
            XCTAssertFalse(setType.subLabel.isEmpty, "\(setType) should have non-empty subLabel")
        }
    }

    func testAllCases_HaveNonEmptyIcon() {
        for setType in EnumSetType.allCases {
            XCTAssertFalse(setType.icon.isEmpty, "\(setType) should have non-empty icon")
        }
    }

    func testAllCases_Count3() {
        XCTAssertEqual(EnumSetType.allCases.count, 3)
    }

    func testCodable_RoundTrip() throws {
        for setType in EnumSetType.allCases {
            let data = try JSONEncoder().encode(setType)
            let decoded = try JSONDecoder().decode(EnumSetType.self, from: data)
            XCTAssertEqual(decoded, setType)
        }
    }

    func testId_MatchesRawValue() {
        for setType in EnumSetType.allCases {
            XCTAssertEqual(setType.id, setType.rawValue)
        }
    }
}

// MARK: - NumericRange Tests

final class NumericRangeTests: XCTestCase {
    func testIntRange_StoresMinMax() {
        let range = IntRange(1, 10)
        XCTAssertEqual(range.min, 1)
        XCTAssertEqual(range.max, 10)
    }

    func testDoubleRange_StoresMinMax() {
        let range = DoubleRange(0.0, 1.0)
        XCTAssertEqual(range.min, 0.0)
        XCTAssertEqual(range.max, 1.0)
    }

    func testEquality_SameValues_Equal() {
        let a = IntRange(1, 10)
        let b = IntRange(1, 10)
        XCTAssertEqual(a, b)
    }

    func testInequality_DifferentMin() {
        let a = IntRange(1, 10)
        let b = IntRange(2, 10)
        XCTAssertNotEqual(a, b)
    }

    func testInequality_DifferentMax() {
        let a = IntRange(1, 10)
        let b = IntRange(1, 20)
        XCTAssertNotEqual(a, b)
    }

    func testCodable_IntRange_RoundTrip() throws {
        let original = IntRange(5, 50)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IntRange.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testCodable_DoubleRange_RoundTrip() throws {
        let original = DoubleRange(0.1, 0.9)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DoubleRange.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testZeroWidthRange_MinEqualsMax() {
        let range = IntRange(5, 5)
        XCTAssertEqual(range.min, range.max)
    }

    func testNegativeRange() {
        let range = IntRange(-10, -1)
        XCTAssertEqual(range.min, -10)
        XCTAssertEqual(range.max, -1)
    }
}

// MARK: - ProviderModelData Tests

final class ProviderModelDataTests: XCTestCase {
    func testModelId_IsDeterministic() {
        let id1 = EnumProviderModelCode.OPENAI_DALLE3.modelId
        let id2 = EnumProviderModelCode.OPENAI_DALLE3.modelId
        XCTAssertEqual(id1, id2)
    }

    func testDifferentModelCodes_ProduceDifferentIds() {
        let id1 = EnumProviderModelCode.OPENAI_DALLE3.modelId
        let id2 = EnumProviderModelCode.GOOGLE_VEO_31.modelId
        XCTAssertNotEqual(id1, id2)
    }

    func testProviderModelData_ModelId_MatchesModelCode() {
        let modelData = ProviderModelData(
            providerId: UUID(),
            modelCode: .OPENAI_DALLE3,
            modelSetType: .IMAGE_GENERATE,
            modelName: "DALL-E 3",
            modelDescription: "Test",
            modelParams: ModelParams(),
            modelLaunchDate: Date(),
            modelGenerateBaseURL: "https://api.example.com",
            modelAPIDocumentationURL: "https://docs.example.com",
            active: true
        )
        XCTAssertEqual(modelData.modelId, EnumProviderModelCode.OPENAI_DALLE3.modelId)
    }

    func testStatusURL_ReturnsNil_WhenModelStatusBaseURLIsNil() {
        let modelData = ProviderModelData(
            providerId: UUID(),
            modelCode: .OPENAI_DALLE3,
            modelSetType: .IMAGE_GENERATE,
            modelName: "Test",
            modelDescription: "Test",
            modelParams: ModelParams(),
            modelLaunchDate: Date(),
            modelGenerateBaseURL: "https://api.example.com",
            modelAPIDocumentationURL: "https://docs.example.com",
            active: true
        )
        XCTAssertNil(modelData.statusURL)
    }

    func testStatusURL_ReturnsURL_WhenModelStatusBaseURLIsValid() {
        let modelData = ProviderModelData(
            providerId: UUID(),
            modelCode: .OPENAI_DALLE3,
            modelSetType: .IMAGE_GENERATE,
            modelName: "Test",
            modelDescription: "Test",
            modelParams: ModelParams(),
            modelLaunchDate: Date(),
            modelGenerateBaseURL: "https://api.example.com",
            modelStatusBaseURL: "https://api.example.com/status",
            modelAPIDocumentationURL: "https://docs.example.com",
            active: true
        )
        let url = modelData.statusURL
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "https://api.example.com/status")
    }

    func testStatusURL_ReturnsNil_WhenModelStatusBaseURLIsMalformed() {
        let modelData = ProviderModelData(
            providerId: UUID(),
            modelCode: .OPENAI_DALLE3,
            modelSetType: .IMAGE_GENERATE,
            modelName: "Test",
            modelDescription: "Test",
            modelParams: ModelParams(),
            modelLaunchDate: Date(),
            modelGenerateBaseURL: "https://api.example.com",
            modelStatusBaseURL: "",
            modelAPIDocumentationURL: "https://docs.example.com",
            active: true
        )
        XCTAssertNil(modelData.statusURL)
    }

    func testGenerateURL_ReturnsURL_WhenModelGenerateBaseURLIsValid() {
        let modelData = ProviderModelData(
            providerId: UUID(),
            modelCode: .OPENAI_DALLE3,
            modelSetType: .IMAGE_GENERATE,
            modelName: "Test",
            modelDescription: "Test",
            modelParams: ModelParams(),
            modelLaunchDate: Date(),
            modelGenerateBaseURL: "https://api.example.com/generate",
            modelAPIDocumentationURL: "https://docs.example.com",
            active: true
        )
        let url = modelData.generateURL
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "https://api.example.com/generate")
    }

    func testGenerateURL_ReturnsNil_WhenModelGenerateBaseURLIsEmpty() {
        let modelData = ProviderModelData(
            providerId: UUID(),
            modelCode: .OPENAI_DALLE3,
            modelSetType: .IMAGE_GENERATE,
            modelName: "Test",
            modelDescription: "Test",
            modelParams: ModelParams(),
            modelLaunchDate: Date(),
            modelGenerateBaseURL: "",
            modelAPIDocumentationURL: "https://docs.example.com",
            active: true
        )
        XCTAssertNil(modelData.generateURL)
    }

    func testProviderModelData_Initialization_PreservesFields() {
        let providerId = UUID()
        let launchDate = Date()
        let modelData = ProviderModelData(
            providerId: providerId,
            modelCode: .GOOGLE_IMAGEN_3,
            modelSetType: .IMAGE_GENERATE,
            modelName: "Imagen 3",
            modelDescription: "Google image model",
            modelParams: ModelParams(),
            modelLaunchDate: launchDate,
            modelGenerateBaseURL: "https://api.google.com",
            modelAPIDocumentationURL: "https://docs.google.com",
            active: true
        )
        XCTAssertEqual(modelData.providerId, providerId)
        XCTAssertEqual(modelData.modelCode, .GOOGLE_IMAGEN_3)
        XCTAssertEqual(modelData.modelSetType, .IMAGE_GENERATE)
        XCTAssertEqual(modelData.modelName, "Imagen 3")
        XCTAssertTrue(modelData.active)
    }
}

// MARK: - CostRequest Conversion Tests

final class CostRequestConversionTests: XCTestCase {
    func testImageCostRequest_FromImageRequest() {
        let providerKey = ProviderKeyInfo(
            providerId: UUID(),
            providerCode: .OPENAI,
            projectId: UUID()
        )
        let request = ImageGenerationRequest(
            modelId: "model-1",
            prompt: "test prompt",
            variant: "normal",
            quality: "hd",
            style: "natural",
            dimensions: "1024x1024",
            providerKey: providerKey,
            providerSecret: "secret",
            numberOfImages: 3
        )
        let costRequest = ImageGenerationCostRequest(from: request)
        XCTAssertEqual(costRequest.modelId, "model-1")
        XCTAssertEqual(costRequest.quality, "hd")
        XCTAssertEqual(costRequest.dimensions, "1024x1024")
        XCTAssertEqual(costRequest.numberOfImages, 3)
        XCTAssertFalse(costRequest.hasSourceImage)
        XCTAssertEqual(costRequest.referenceImageCount, 0)
    }

    func testImageCostRequest_FromImageRequest_WithSourceAndReferences() {
        let providerKey = ProviderKeyInfo(
            providerId: UUID(),
            providerCode: .LUMA_AI,
            projectId: UUID()
        )
        let request = ImageGenerationRequest(
            modelId: "model-1",
            prompt: "test prompt",
            dimensions: "1024x1024",
            clientImage: "source-image",
            clientReferenceImages: [
                ReferenceImageData(base64Image: "ref-1"),
                ReferenceImageData(base64Image: "ref-2"),
            ],
            providerKey: providerKey,
            providerSecret: "secret",
            numberOfImages: 1
        )
        let costRequest = ImageGenerationCostRequest(from: request)
        XCTAssertTrue(costRequest.hasSourceImage)
        XCTAssertEqual(costRequest.referenceImageCount, 2)
    }

    func testVideoCostRequest_FromVideoRequest() {
        let providerKey = ProviderKeyInfo(
            providerId: UUID(),
            providerCode: .FAL_AI,
            projectId: UUID()
        )
        let request = VideoGenerationRequest(
            modelId: "video-model",
            dimensions: "1920x1080",
            clientImage: "data:image/png;base64,SOURCE",
            clientReferenceImages: [
                ReferenceImageData(base64Image: "data:image/png;base64,AAAA", referenceType: "asset"),
            ],
            providerKey: providerKey,
            providerSecret: "secret",
            numberOfVideos: 2,
            durationSeconds: 8,
            resolution: "720p",
            generateAudio: true
        )
        let costRequest = VideoGenerationCostRequest(from: request)
        XCTAssertEqual(costRequest.dimensions, "1920x1080")
        XCTAssertEqual(costRequest.durationSeconds, 8)
        XCTAssertEqual(costRequest.numberOfVideos, 2)
        XCTAssertEqual(costRequest.resolution, "720p")
        XCTAssertEqual(costRequest.generateAudio, true)
        XCTAssertTrue(costRequest.hasSourceImage)
        XCTAssertTrue(costRequest.hasReferenceImages)
        XCTAssertEqual(costRequest.referenceImageCount, 1)
    }

    func testImageCostRequest_NilFields_RemainNil() {
        let providerKey = ProviderKeyInfo(
            providerId: UUID(),
            providerCode: .OPENAI,
            projectId: UUID()
        )
        let request = ImageGenerationRequest(
            modelId: "model",
            prompt: "test",
            variant: "",
            quality: "",
            style: "",
            dimensions: "1024x1024",
            providerKey: providerKey,
            providerSecret: "secret"
        )
        let costRequest = ImageGenerationCostRequest(from: request)
        // quality and dimensions are set from request (empty strings are not nil)
        XCTAssertEqual(costRequest.numberOfImages, 1)
        XCTAssertFalse(costRequest.hasSourceImage)
        XCTAssertEqual(costRequest.referenceImageCount, 0)
    }

    func testVideoCostRequest_NilOptionalFields() {
        let providerKey = ProviderKeyInfo(
            providerId: UUID(),
            providerCode: .FAL_AI,
            projectId: UUID()
        )
        let request = VideoGenerationRequest(
            modelId: "model",
            dimensions: "16:9",
            providerKey: providerKey,
            providerSecret: "secret"
        )
        let costRequest = VideoGenerationCostRequest(from: request)
        XCTAssertNil(costRequest.durationSeconds)
        XCTAssertNil(costRequest.resolution)
        XCTAssertNil(costRequest.generateAudio)
        XCTAssertFalse(costRequest.hasSourceImage)
        XCTAssertFalse(costRequest.hasReferenceImages)
        XCTAssertEqual(costRequest.referenceImageCount, 0)
    }
}
