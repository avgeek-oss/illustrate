// MARK: - ProviderDependenciesConfigTests.swift

// Tests for the conversion extensions in ProviderDependenciesConfig.swift.
//
// Covers:
// - ProviderModel.toProviderModelData() field preservation
// - ProviderModelData.toProviderModel() field preservation
// - Round-trip symmetry (Model→Data→Model, Data→Model→Data)
// - ProviderKey.toProviderKeyInfo() happy path and error handling

import XCTest
@testable import Illustrate
@testable import IllustrateProviders

final class ProviderDependenciesConfigTests: XCTestCase {
    // MARK: - Helpers

    private func makeProviderModel(
        providerId: UUID = EnumProviderCode.OPENAI.providerId,
        modelCode: EnumProviderModelCode = .OPENAI_GPT_IMAGE_1,
        active: Bool = true
    ) -> ProviderModel {
        ProviderModel(
            providerId: providerId,
            modelCode: modelCode,
            modelSetType: .IMAGE_GENERATE,
            modelName: "Test Model",
            modelDescription: "A test model description",
            modelParams: ModelParams(),
            modelLaunchDate: Date(timeIntervalSinceReferenceDate: 700_000_000),
            modelDeprecationDate: nil,
            modelVerificationDate: Date(timeIntervalSinceReferenceDate: 710_000_000),
            modelShutdownDate: Date(timeIntervalSinceReferenceDate: 900_000_000),
            replacementModelCode: .OPENAI_GPT_IMAGE_2,
            pricingMetadata: ProviderPricingMetadata(
                unit: .image,
                sourceURL: "https://api.example.com/pricing",
                verifiedAt: Date(timeIntervalSinceReferenceDate: 710_000_000)
            ),
            modelGenerateBaseURL: "https://api.example.com/generate",
            modelStatusBaseURL: "https://api.example.com/status",
            modelAPIDocumentationURL: "https://docs.example.com",
            active: active
        )
    }

    private func makeProviderModelData(
        providerId: UUID = EnumProviderCode.OPENAI.providerId,
        modelCode: EnumProviderModelCode = .OPENAI_GPT_IMAGE_1
    ) -> ProviderModelData {
        ProviderModelData(
            providerId: providerId,
            modelCode: modelCode,
            modelSetType: .IMAGE_GENERATE,
            modelName: "Test Data Model",
            modelDescription: "A test data model description",
            modelParams: ModelParams(),
            modelLaunchDate: Date(timeIntervalSinceReferenceDate: 700_000_000),
            modelDeprecationDate: Date(timeIntervalSinceReferenceDate: 800_000_000),
            modelVerificationDate: Date(timeIntervalSinceReferenceDate: 710_000_000),
            modelShutdownDate: Date(timeIntervalSinceReferenceDate: 900_000_000),
            replacementModelCode: .OPENAI_GPT_IMAGE_2,
            pricingMetadata: ProviderPricingMetadata(
                unit: .image,
                sourceURL: "https://api.example.com/pricing",
                verifiedAt: Date(timeIntervalSinceReferenceDate: 710_000_000)
            ),
            modelGenerateBaseURL: "https://api.example.com/generate",
            modelStatusBaseURL: "https://api.example.com/status",
            modelAPIDocumentationURL: "https://docs.example.com",
            active: true
        )
    }

    // MARK: - ProviderModel.toProviderModelData()

    func testToProviderModelData_preservesProviderId() {
        let model = makeProviderModel()
        let data = model.toProviderModelData()
        XCTAssertEqual(data.providerId, model.providerId)
    }

    func testToProviderModelData_preservesModelCode() {
        let model = makeProviderModel()
        let data = model.toProviderModelData()
        XCTAssertEqual(data.modelCode, model.modelCode)
    }

    func testToProviderModelData_preservesModelSetType() {
        let model = makeProviderModel()
        let data = model.toProviderModelData()
        XCTAssertEqual(data.modelSetType, model.modelSetType)
    }

    func testToProviderModelData_preservesModelName() {
        let model = makeProviderModel()
        let data = model.toProviderModelData()
        XCTAssertEqual(data.modelName, model.modelName)
    }

    func testToProviderModelData_preservesModelDescription() {
        let model = makeProviderModel()
        let data = model.toProviderModelData()
        XCTAssertEqual(data.modelDescription, model.modelDescription)
    }

    func testToProviderModelData_preservesAllFields() {
        let model = makeProviderModel()
        let data = model.toProviderModelData()

        XCTAssertEqual(data.providerId, model.providerId)
        XCTAssertEqual(data.modelCode, model.modelCode)
        XCTAssertEqual(data.modelSetType, model.modelSetType)
        XCTAssertEqual(data.modelName, model.modelName)
        XCTAssertEqual(data.modelDescription, model.modelDescription)
        XCTAssertEqual(data.modelLaunchDate, model.modelLaunchDate)
        XCTAssertEqual(data.modelDeprecationDate, model.modelDeprecationDate)
        XCTAssertEqual(data.modelVerificationDate, model.modelVerificationDate)
        XCTAssertEqual(data.modelShutdownDate, model.modelShutdownDate)
        XCTAssertEqual(data.replacementModelCode, model.replacementModelCode)
        XCTAssertEqual(data.pricingMetadata, model.pricingMetadata)
        XCTAssertEqual(data.modelGenerateBaseURL, model.modelGenerateBaseURL)
        XCTAssertEqual(data.modelStatusBaseURL, model.modelStatusBaseURL)
        XCTAssertEqual(data.modelAPIDocumentationURL, model.modelAPIDocumentationURL)
        XCTAssertEqual(data.active, model.active)
    }

    // MARK: - ProviderModelData.toProviderModel()

    func testToProviderModel_preservesAllFields() {
        let data = makeProviderModelData()
        let model = data.toProviderModel()

        XCTAssertEqual(model.providerId, data.providerId)
        XCTAssertEqual(model.modelCode, data.modelCode)
        XCTAssertEqual(model.modelSetType, data.modelSetType)
        XCTAssertEqual(model.modelName, data.modelName)
        XCTAssertEqual(model.modelDescription, data.modelDescription)
        XCTAssertEqual(model.modelLaunchDate, data.modelLaunchDate)
        XCTAssertEqual(model.modelDeprecationDate, data.modelDeprecationDate)
        XCTAssertEqual(model.modelVerificationDate, data.modelVerificationDate)
        XCTAssertEqual(model.modelShutdownDate, data.modelShutdownDate)
        XCTAssertEqual(model.replacementModelCode, data.replacementModelCode)
        XCTAssertEqual(model.pricingMetadata, data.pricingMetadata)
        XCTAssertEqual(model.modelGenerateBaseURL, data.modelGenerateBaseURL)
        XCTAssertEqual(model.modelStatusBaseURL, data.modelStatusBaseURL)
        XCTAssertEqual(model.modelAPIDocumentationURL, data.modelAPIDocumentationURL)
        XCTAssertEqual(model.active, data.active)
    }

    // MARK: - Round-Trip Symmetry

    func testRoundTrip_modelToDataToModel_symmetry() {
        let original = makeProviderModel()
        let data = original.toProviderModelData()
        let restored = data.toProviderModel()

        XCTAssertEqual(restored.providerId, original.providerId)
        XCTAssertEqual(restored.modelCode, original.modelCode)
        XCTAssertEqual(restored.modelSetType, original.modelSetType)
        XCTAssertEqual(restored.modelName, original.modelName)
        XCTAssertEqual(restored.modelDescription, original.modelDescription)
        XCTAssertEqual(restored.modelLaunchDate, original.modelLaunchDate)
        XCTAssertEqual(restored.modelDeprecationDate, original.modelDeprecationDate)
        XCTAssertEqual(restored.modelVerificationDate, original.modelVerificationDate)
        XCTAssertEqual(restored.modelShutdownDate, original.modelShutdownDate)
        XCTAssertEqual(restored.replacementModelCode, original.replacementModelCode)
        XCTAssertEqual(restored.pricingMetadata, original.pricingMetadata)
        XCTAssertEqual(restored.modelGenerateBaseURL, original.modelGenerateBaseURL)
        XCTAssertEqual(restored.modelStatusBaseURL, original.modelStatusBaseURL)
        XCTAssertEqual(restored.modelAPIDocumentationURL, original.modelAPIDocumentationURL)
        XCTAssertEqual(restored.active, original.active)
    }

    func testRoundTrip_dataToModelToData_symmetry() {
        let original = makeProviderModelData()
        let model = original.toProviderModel()
        let restored = model.toProviderModelData()

        XCTAssertEqual(restored.providerId, original.providerId)
        XCTAssertEqual(restored.modelCode, original.modelCode)
        XCTAssertEqual(restored.modelSetType, original.modelSetType)
        XCTAssertEqual(restored.modelName, original.modelName)
        XCTAssertEqual(restored.modelDescription, original.modelDescription)
        XCTAssertEqual(restored.modelLaunchDate, original.modelLaunchDate)
        XCTAssertEqual(restored.modelDeprecationDate, original.modelDeprecationDate)
        XCTAssertEqual(restored.modelVerificationDate, original.modelVerificationDate)
        XCTAssertEqual(restored.modelShutdownDate, original.modelShutdownDate)
        XCTAssertEqual(restored.replacementModelCode, original.replacementModelCode)
        XCTAssertEqual(restored.pricingMetadata, original.pricingMetadata)
        XCTAssertEqual(restored.modelGenerateBaseURL, original.modelGenerateBaseURL)
        XCTAssertEqual(restored.modelStatusBaseURL, original.modelStatusBaseURL)
        XCTAssertEqual(restored.modelAPIDocumentationURL, original.modelAPIDocumentationURL)
        XCTAssertEqual(restored.active, original.active)
    }

    func testRoundTrip_preservesNilOptionals() {
        let model = makeProviderModel()
        // modelDeprecationDate is nil, modelStatusBaseURL is set
        XCTAssertNil(model.modelDeprecationDate)

        let data = model.toProviderModelData()
        XCTAssertNil(data.modelDeprecationDate)

        let restored = data.toProviderModel()
        XCTAssertNil(restored.modelDeprecationDate)
    }

    func testRoundTrip_preservesSetOptionals() {
        let data = makeProviderModelData()
        // modelDeprecationDate is set
        XCTAssertNotNil(data.modelDeprecationDate)

        let model = data.toProviderModel()
        XCTAssertNotNil(model.modelDeprecationDate)

        let restored = model.toProviderModelData()
        XCTAssertEqual(restored.modelDeprecationDate, data.modelDeprecationDate)
    }

    func testRoundTrip_preservesActiveFlag() {
        let model = makeProviderModel(active: false)
        let data = model.toProviderModelData()
        XCTAssertFalse(data.active)

        let restored = data.toProviderModel()
        XCTAssertFalse(restored.active)
    }

    func testRoundTrip_preservesURLStrings() {
        let model = makeProviderModel()
        let data = model.toProviderModelData()

        XCTAssertEqual(data.modelGenerateBaseURL, "https://api.example.com/generate")
        XCTAssertEqual(data.modelStatusBaseURL, "https://api.example.com/status")
        XCTAssertEqual(data.modelAPIDocumentationURL, "https://docs.example.com")
    }

    func testRoundTrip_preservesDates() {
        let data = makeProviderModelData()
        let model = data.toProviderModel()

        XCTAssertEqual(
            model.modelLaunchDate.timeIntervalSinceReferenceDate,
            data.modelLaunchDate.timeIntervalSinceReferenceDate,
            accuracy: 0.001
        )
    }

    // MARK: - ProviderKey.toProviderKeyInfo()

    func testToProviderKeyInfo_validProvider_returnsInfo() throws {
        let key = ProviderKey(providerId: EnumProviderCode.OPENAI.providerId)
        let info = try key.toProviderKeyInfo()
        XCTAssertEqual(info.providerCode, .OPENAI)
    }

    func testToProviderKeyInfo_preservesProviderId() throws {
        let providerId = EnumProviderCode.OPENAI.providerId
        let key = ProviderKey(providerId: providerId)
        let info = try key.toProviderKeyInfo()
        XCTAssertEqual(info.providerId, providerId)
    }

    func testToProviderKeyInfo_preservesProjectId() throws {
        let projectId = UUID()
        let key = ProviderKey(providerId: EnumProviderCode.OPENAI.providerId, projectId: projectId)
        let info = try key.toProviderKeyInfo()
        XCTAssertEqual(info.projectId, projectId)
    }

    func testToProviderKeyInfo_invalidProvider_throwsError() {
        let key = ProviderKey(providerId: UUID())
        XCTAssertThrowsError(try key.toProviderKeyInfo()) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "ProviderKeyError")
            XCTAssertEqual(nsError.code, -1)
        }
    }

    func testToProviderKeyInfo_errorDescription_containsUUID() {
        let randomId = UUID()
        let key = ProviderKey(providerId: randomId)
        XCTAssertThrowsError(try key.toProviderKeyInfo()) { error in
            let nsError = error as NSError
            let description = nsError.userInfo[NSLocalizedDescriptionKey] as? String ?? ""
            XCTAssertTrue(description.contains(randomId.uuidString))
        }
    }

    func testToProviderKeyInfo_openAI_mapsToOpenAI() throws {
        let key = ProviderKey(providerId: EnumProviderCode.OPENAI.providerId)
        let info = try key.toProviderKeyInfo()
        XCTAssertEqual(info.providerCode, .OPENAI)
    }

    func testToProviderKeyInfo_stabilityAI_mapsToStabilityAI() throws {
        let key = ProviderKey(providerId: EnumProviderCode.STABILITY_AI.providerId)
        let info = try key.toProviderKeyInfo()
        XCTAssertEqual(info.providerCode, .STABILITY_AI)
    }

    func testToProviderKeyInfo_googleCloud_mapsToGoogleCloud() throws {
        let key = ProviderKey(providerId: EnumProviderCode.GOOGLE_CLOUD.providerId)
        let info = try key.toProviderKeyInfo()
        XCTAssertEqual(info.providerCode, .GOOGLE_CLOUD)
    }

    func testToProviderKeyInfo_replicate_mapsToReplicate() throws {
        let key = ProviderKey(providerId: EnumProviderCode.REPLICATE.providerId)
        let info = try key.toProviderKeyInfo()
        XCTAssertEqual(info.providerCode, .REPLICATE)
    }

    func testToProviderKeyInfo_falAI_mapsToFalAI() throws {
        let key = ProviderKey(providerId: EnumProviderCode.FAL_AI.providerId)
        let info = try key.toProviderKeyInfo()
        XCTAssertEqual(info.providerCode, .FAL_AI)
    }

    func testToProviderKeyInfo_firecrawl_mapsToFirecrawl() throws {
        let key = ProviderKey(providerId: EnumProviderCode.FIRECRAWL.providerId)
        let info = try key.toProviderKeyInfo()
        XCTAssertEqual(info.providerCode, .FIRECRAWL)
    }
}
