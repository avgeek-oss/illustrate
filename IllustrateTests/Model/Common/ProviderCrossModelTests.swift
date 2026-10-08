// MARK: - ProviderCrossModelTests.swift

// Cross-model integration tests verifying Provider data flows correctly
// across ProviderKey, ProviderModel, ProviderModelData, and ProviderKeyInfo.
//
// Covers:
// - Provider and ProviderKey interaction workflows
// - Provider and ProviderModel conversion workflows
// - Cross-model lookup workflows
// - Provider JSON interop with missing optionals
// - ProviderModel conversion field details

import XCTest
@testable import Illustrate
@testable import IllustrateProviders

final class ProviderCrossModelTests: XCTestCase {
    // MARK: - Provider and ProviderKey Interaction

    func testProviderKey_validProviderId_convertsToKeyInfo() throws {
        let key = ProviderKey(providerId: EnumProviderCode.OPENAI.providerId)
        let info = try key.toProviderKeyInfo()
        XCTAssertEqual(info.providerCode, .OPENAI)
        XCTAssertEqual(info.providerId, EnumProviderCode.OPENAI.providerId)
    }

    func testProviderKey_invalidProviderId_throws() {
        let key = ProviderKey(providerId: UUID())
        XCTAssertThrowsError(try key.toProviderKeyInfo())
    }

    func testAllProviders_createKey_convert_verify() throws {
        for code in EnumProviderCode.allCases {
            let key = ProviderKey(providerId: code.providerId)
            let info = try key.toProviderKeyInfo()
            XCTAssertEqual(info.providerCode, code, "ProviderKey→KeyInfo failed for \(code)")
        }
    }

    // MARK: - Provider and ProviderModel Conversion

    func testProviderModel_toData_toModel_preservesAllFields() {
        let original = ProviderModel(
            providerId: EnumProviderCode.OPENAI.providerId,
            modelCode: .OPENAI_GPT_IMAGE_1,
            modelSetType: .IMAGE_GENERATE,
            modelName: "GPT Image 1",
            modelDescription: "OpenAI image generation model",
            modelParams: ModelParams(),
            modelLaunchDate: Date(timeIntervalSinceReferenceDate: 700_000_000),
            modelDeprecationDate: nil,
            modelGenerateBaseURL: "https://api.openai.com/v1/images",
            modelStatusBaseURL: nil,
            modelAPIDocumentationURL: "https://platform.openai.com/docs",
            active: true
        )

        let data = original.toProviderModelData()
        let restored = data.toProviderModel()

        XCTAssertEqual(restored.providerId, original.providerId)
        XCTAssertEqual(restored.modelCode, original.modelCode)
        XCTAssertEqual(restored.modelName, original.modelName)
        XCTAssertEqual(restored.active, original.active)
    }

    func testProviderModelData_toModel_toData_preservesAllFields() {
        let original = ProviderModelData(
            providerId: EnumProviderCode.STABILITY_AI.providerId,
            modelCode: .STABILITY_CORE,
            modelSetType: .IMAGE_GENERATE,
            modelName: "Stability Core",
            modelDescription: "Stability AI core model",
            modelParams: ModelParams(),
            modelLaunchDate: Date(timeIntervalSinceReferenceDate: 700_000_000),
            modelDeprecationDate: Date(timeIntervalSinceReferenceDate: 800_000_000),
            modelGenerateBaseURL: "https://api.stability.ai/v1/generate",
            modelStatusBaseURL: "https://api.stability.ai/v1/status",
            modelAPIDocumentationURL: "https://platform.stability.ai/docs",
            active: true
        )

        let model = original.toProviderModel()
        let restored = model.toProviderModelData()

        XCTAssertEqual(restored.providerId, original.providerId)
        XCTAssertEqual(restored.modelCode, original.modelCode)
        XCTAssertEqual(restored.modelName, original.modelName)
        XCTAssertEqual(restored.modelDeprecationDate, original.modelDeprecationDate)
    }

    // MARK: - Cross-Model Lookup Workflow

    func testGetProviderFromKey_providerId() {
        let key = ProviderKey(providerId: EnumProviderCode.OPENAI.providerId)
        let provider = getProvider(providerId: key.providerId)
        XCTAssertNotNil(provider)
        XCTAssertEqual(provider?.providerCode, .OPENAI)
    }

    func testAllProviders_findableByProviderId() {
        for code in EnumProviderCode.allCases {
            let provider = getProvider(providerId: code.providerId)
            XCTAssertNotNil(provider, "Provider not found for code: \(code)")
            XCTAssertEqual(provider?.providerCode, code)
        }
    }

    func testProviderIds_areDeterministic() {
        // Verify provider IDs match across multiple access points
        for provider in providers {
            XCTAssertEqual(
                provider.providerId,
                provider.providerCode.providerId,
                "Provider ID mismatch for \(provider.providerCode)"
            )
        }
    }

    // MARK: - Provider JSON Interop

    func testDecode_removeSupportsBalanceCheck_decodeBackWithDefault() throws {
        for provider in providers {
            let data = try JSONEncoder().encode(provider)
            var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            json.removeValue(forKey: "supportsBalanceCheck")

            let modifiedData = try JSONSerialization.data(withJSONObject: json)
            let decoded = try JSONDecoder().decode(Provider.self, from: modifiedData)
            XCTAssertFalse(decoded.supportsBalanceCheck)
        }
    }

    func testDecode_removeBalanceEndpoint_decodeBackWithNil() throws {
        let stability = try XCTUnwrap(providers.first(where: { $0.providerCode == .STABILITY_AI }))
        let data = try JSONEncoder().encode(stability)
        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "balanceEndpoint")

        let modifiedData = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(Provider.self, from: modifiedData)
        XCTAssertNil(decoded.balanceEndpoint)
    }

    func testAllProviders_codableRoundTrip_fieldEquality() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for provider in providers {
            let data = try encoder.encode(provider)
            let restored = try decoder.decode(Provider.self, from: data)

            XCTAssertEqual(restored.providerId, provider.providerId)
            XCTAssertEqual(restored.providerCode, provider.providerCode)
            XCTAssertEqual(restored.providerName, provider.providerName)
            XCTAssertEqual(restored.keyStructure, provider.keyStructure)
            XCTAssertEqual(restored.creditCurrency, provider.creditCurrency)
            XCTAssertEqual(restored.supportsBalanceCheck, provider.supportsBalanceCheck)
            XCTAssertEqual(restored.balanceEndpoint, provider.balanceEndpoint)
        }
    }

    // MARK: - ProviderModel Conversion Field Details

    func testConversion_preservesModelId() {
        let model = ProviderModel(
            providerId: EnumProviderCode.OPENAI.providerId,
            modelCode: .OPENAI_GPT_IMAGE_1,
            modelSetType: .IMAGE_GENERATE,
            modelName: "Test",
            modelDescription: "Test desc",
            modelParams: ModelParams(),
            modelLaunchDate: Date(),
            modelGenerateBaseURL: "https://example.com",
            modelAPIDocumentationURL: "https://docs.example.com",
            active: true
        )

        let data = model.toProviderModelData()
        // modelId is computed from modelCode, so both should derive the same value
        XCTAssertEqual(data.modelId, model.modelId)
    }

    func testConversion_preservesLaunchAndDeprecationDates() {
        let launchDate = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let deprecationDate = Date(timeIntervalSinceReferenceDate: 800_000_000)

        let model = ProviderModel(
            providerId: EnumProviderCode.OPENAI.providerId,
            modelCode: .OPENAI_DALLE3,
            modelSetType: .IMAGE_GENERATE,
            modelName: "DALL-E 3",
            modelDescription: "Desc",
            modelParams: ModelParams(),
            modelLaunchDate: launchDate,
            modelDeprecationDate: deprecationDate,
            modelGenerateBaseURL: "https://example.com",
            modelAPIDocumentationURL: "https://docs.example.com",
            active: true
        )

        let data = model.toProviderModelData()
        XCTAssertEqual(data.modelLaunchDate, launchDate)
        XCTAssertEqual(data.modelDeprecationDate, deprecationDate)
    }

    func testConversion_preservesAllURLFields() {
        let model = ProviderModel(
            providerId: EnumProviderCode.OPENAI.providerId,
            modelCode: .OPENAI_GPT_IMAGE_1,
            modelSetType: .IMAGE_GENERATE,
            modelName: "Test",
            modelDescription: "Desc",
            modelParams: ModelParams(),
            modelLaunchDate: Date(),
            modelGenerateBaseURL: "https://generate.example.com",
            modelStatusBaseURL: "https://status.example.com",
            modelAPIDocumentationURL: "https://docs.example.com",
            active: true
        )

        let data = model.toProviderModelData()
        XCTAssertEqual(data.modelGenerateBaseURL, "https://generate.example.com")
        XCTAssertEqual(data.modelStatusBaseURL, "https://status.example.com")
        XCTAssertEqual(data.modelAPIDocumentationURL, "https://docs.example.com")
    }

    func testConversion_preservesActiveFlag_whenFalse() {
        let model = ProviderModel(
            providerId: EnumProviderCode.OPENAI.providerId,
            modelCode: .OPENAI_GPT_IMAGE_1,
            modelSetType: .IMAGE_GENERATE,
            modelName: "Inactive",
            modelDescription: "Desc",
            modelParams: ModelParams(),
            modelLaunchDate: Date(),
            modelGenerateBaseURL: "https://example.com",
            modelAPIDocumentationURL: "https://docs.example.com",
            active: false
        )

        let data = model.toProviderModelData()
        XCTAssertFalse(data.active)

        let restored = data.toProviderModel()
        XCTAssertFalse(restored.active)
    }

    func testConversion_preservesNilStatusBaseURL() {
        let model = ProviderModel(
            providerId: EnumProviderCode.OPENAI.providerId,
            modelCode: .OPENAI_GPT_IMAGE_1,
            modelSetType: .IMAGE_GENERATE,
            modelName: "Test",
            modelDescription: "Desc",
            modelParams: ModelParams(),
            modelLaunchDate: Date(),
            modelGenerateBaseURL: "https://example.com",
            modelStatusBaseURL: nil,
            modelAPIDocumentationURL: "https://docs.example.com",
            active: true
        )

        let data = model.toProviderModelData()
        XCTAssertNil(data.modelStatusBaseURL)
    }

    func testConversion_preservesNilDeprecationDate() {
        let model = ProviderModel(
            providerId: EnumProviderCode.OPENAI.providerId,
            modelCode: .OPENAI_GPT_IMAGE_1,
            modelSetType: .IMAGE_GENERATE,
            modelName: "Test",
            modelDescription: "Desc",
            modelParams: ModelParams(),
            modelLaunchDate: Date(),
            modelDeprecationDate: nil,
            modelGenerateBaseURL: "https://example.com",
            modelAPIDocumentationURL: "https://docs.example.com",
            active: true
        )

        let data = model.toProviderModelData()
        XCTAssertNil(data.modelDeprecationDate)
    }
}
