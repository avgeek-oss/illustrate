// MARK: - ProviderServiceTests.swift

// Unit tests for ProviderService - the central model registry for AI providers.
//
// Tests cover:
// - Model loading and availability
// - Query methods (allModels, activeModels)
// - Filtering by set type
// - Filtering by provider ID
// - Lookup by model ID (UUID string)
// - Lookup by model code (enum)

import IllustrateProviders
import XCTest
@testable import Illustrate

final class ProviderServiceTests: XCTestCase {
    // MARK: - Properties

    private var service: ProviderService!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        service = ProviderService.shared
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - Model Loading Tests

    func testProviderService_allModels_notEmpty() {
        let models = service.allModels

        XCTAssertFalse(models.isEmpty, "ProviderService should have loaded models")
    }

    func testProviderService_activeModels_notEmpty() {
        let models = service.activeModels

        XCTAssertFalse(models.isEmpty, "ProviderService should have active models")
    }

    func testProviderService_activeModels_allAreActive() {
        let activeModels = service.activeModels

        for model in activeModels {
            XCTAssertTrue(model.active, "All models in activeModels should have active=true")
        }
    }

    func testProviderService_activeModels_subsetOfAllModels() {
        let allCount = service.allModels.count
        let activeCount = service.activeModels.count

        XCTAssertLessThanOrEqual(activeCount, allCount, "Active models should be subset of all models")
    }

    // MARK: - Filter by Set Type Tests

    func testProviderService_modelsForSetType_imageGenerate() {
        let imageModels = service.models(for: .IMAGE_GENERATE)

        XCTAssertFalse(imageModels.isEmpty, "Should have image generation models")

        for model in imageModels {
            XCTAssertEqual(model.modelSetType, .IMAGE_GENERATE)
            XCTAssertTrue(model.active, "Filtered models should be active")
        }
    }

    func testProviderService_modelsForSetType_videoGenerate() {
        let videoModels = service.models(for: .VIDEO_GENERATE)

        // Video generation might be empty depending on provider configuration
        // But if we have any, they should match the filter
        for model in videoModels {
            XCTAssertEqual(model.modelSetType, .VIDEO_GENERATE)
            XCTAssertTrue(model.active, "Filtered models should be active")
        }
    }

    func testProviderService_modelsForSetType_videoExtend() {
        let extendModels = service.models(for: .VIDEO_EXTEND)

        for model in extendModels {
            XCTAssertEqual(model.modelSetType, .VIDEO_EXTEND)
            XCTAssertTrue(model.active, "Filtered models should be active")
        }
    }

    func testProviderService_modelsForSetType_onlyReturnsActive() {
        let allImageModels = service.allModels.filter { $0.modelSetType == .IMAGE_GENERATE }
        let activeImageModels = service.models(for: .IMAGE_GENERATE)

        // The filtered result should only include active models
        let activeFromAll = allImageModels.filter(\.active)
        XCTAssertEqual(activeImageModels.count, activeFromAll.count)
    }

    // MARK: - Filter by Provider ID Tests

    func testProviderService_modelsForProviderId_returnsMatchingModels() {
        // Get a known provider ID from the first available model
        guard let firstModel = service.activeModels.first else {
            XCTFail("No active models available")
            return
        }

        let providerId = firstModel.providerId
        let providerModels = service.models(for: providerId)

        XCTAssertFalse(providerModels.isEmpty, "Should have models for the provider")

        for model in providerModels {
            XCTAssertEqual(model.providerId, providerId)
            XCTAssertTrue(model.active, "Filtered models should be active")
        }
    }

    func testProviderService_modelsForProviderId_unknownProvider_returnsEmpty() {
        let unknownProviderId = UUID()
        let models = service.models(for: unknownProviderId)

        XCTAssertTrue(models.isEmpty, "Unknown provider should return empty array")
    }

    func testProviderService_modelsForProviderId_onlyReturnsActive() {
        guard let firstModel = service.activeModels.first else {
            XCTFail("No active models available")
            return
        }

        let providerId = firstModel.providerId
        let providerModels = service.models(for: providerId)

        for model in providerModels {
            XCTAssertTrue(model.active, "All returned models should be active")
        }
    }

    // MARK: - Lookup by Model ID Tests

    func testProviderService_modelByModelId_existingModel() {
        guard let firstModel = service.allModels.first else {
            XCTFail("No models available")
            return
        }

        let modelIdString = firstModel.modelId.uuidString
        let foundModel = service.model(by: modelIdString)

        XCTAssertNotNil(foundModel)
        XCTAssertEqual(foundModel?.modelId, firstModel.modelId)
    }

    func testProviderService_modelByModelId_unknownId_returnsNil() {
        let unknownId = UUID().uuidString
        let foundModel = service.model(by: unknownId)

        XCTAssertNil(foundModel, "Unknown model ID should return nil")
    }

    func testProviderService_modelByModelId_emptyString_returnsNil() {
        let foundModel = service.model(by: "")

        XCTAssertNil(foundModel, "Empty string should return nil")
    }

    func testProviderService_modelByModelId_invalidUUID_returnsNil() {
        let foundModel = service.model(by: "not-a-uuid")

        XCTAssertNil(foundModel, "Invalid UUID string should return nil")
    }

    // MARK: - Lookup by Model Code Tests

    func testProviderService_modelByCode_dalleThree() {
        let model = service.model(by: EnumProviderModelCode.OPENAI_DALLE3)

        // DALL-E 3 should be a well-known model
        if model != nil {
            XCTAssertEqual(model?.modelCode, EnumProviderModelCode.OPENAI_DALLE3)
        }
        // Model might not exist in test configuration, so nil is acceptable
    }

    func testProviderService_modelByCode_returnsCorrectModel() {
        // Get a model code from an existing model
        guard let firstModel = service.allModels.first else {
            XCTFail("No models available")
            return
        }

        let foundModel = service.model(by: firstModel.modelCode)

        XCTAssertNotNil(foundModel)
        XCTAssertEqual(foundModel?.modelCode, firstModel.modelCode)
    }

    func testProviderService_googleCloudNanoBananaModels_areActivePickerModels() {
        let nanoBanana = service.model(by: EnumProviderModelCode.GOOGLE_GEMINI_FLASH_IMAGE)
        let nanoBanana2 = service.model(by: EnumProviderModelCode.GOOGLE_GEMINI_31_FLASH_IMAGE)
        let lite = service.model(by: EnumProviderModelCode.GOOGLE_GEMINI_31_FLASH_LITE_IMAGE)
        let pro = service.model(by: EnumProviderModelCode.GOOGLE_GEMINI_PRO_IMAGE)

        XCTAssertEqual(nanoBanana?.modelName, "Nano Banana")
        XCTAssertEqual(nanoBanana2?.modelName, "Nano Banana 2")
        XCTAssertEqual(nanoBanana2?.modelGenerateBaseURL, GeminiInteractionsService.defaultBaseURL.absoluteString)
        XCTAssertEqual(nanoBanana2?.modelParams.supportedImageQualities.first, "1K")
        XCTAssertTrue(nanoBanana2?.modelParams.supportedTools.contains("google_search") == true)
        XCTAssertTrue(nanoBanana2?.active == true)

        XCTAssertEqual(lite?.modelName, "Nano Banana 2 Lite")
        XCTAssertEqual(lite?.modelGenerateBaseURL, GeminiInteractionsService.defaultBaseURL.absoluteString)
        XCTAssertEqual(lite?.modelParams.supportedImageQualities, ["1K"])
        XCTAssertFalse(lite?.modelParams.supportsTools == true)
        XCTAssertTrue(lite?.active == true)

        XCTAssertEqual(pro?.modelName, "Nano Banana Pro")
        XCTAssertEqual(pro?.modelGenerateBaseURL, GeminiInteractionsService.defaultBaseURL.absoluteString)
        XCTAssertEqual(pro?.modelAPIDocumentationURL, "https://ai.google.dev/gemini-api/docs/models/gemini-3-pro-image")
        XCTAssertEqual(pro?.modelParams.supportedImageQualities, ["2K", "4K", "1K"])
        XCTAssertEqual(pro?.modelParams.supportedTools, ["google_search"])
        XCTAssertFalse(pro?.modelGenerateBaseURL.contains("preview") == true)
        XCTAssertTrue(pro?.active == true)
    }

    func testProviderService_googleCloudImagen4Models_areHistoricalOnly() {
        let retiredCodes: [EnumProviderModelCode] = [
            .GOOGLE_IMAGEN_4_FAST,
            .GOOGLE_IMAGEN_4_STANDARD,
            .GOOGLE_IMAGEN_4_ULTRA,
        ]
        let pickerCodes = Set(service.models(for: .IMAGE_GENERATE).map(\.modelCode))

        for code in retiredCodes {
            let model = service.model(by: code)

            XCTAssertNotNil(model, "Historical model metadata must remain decodable for \(code)")
            XCTAssertFalse(model?.active == true)
            XCTAssertEqual(
                model?.modelDeprecationDate,
                IllustrateProviders.getDateFromString("2026-06-15")
            )
            XCTAssertEqual(
                model?.modelVerificationDate,
                IllustrateProviders.getDateFromString("2026-07-10")
            )
            XCTAssertEqual(model?.modelShutdownDate, IllustrateProviders.getDateFromString("2026-08-17"))
            XCTAssertEqual(model?.replacementModelCode, .GOOGLE_GEMINI_31_FLASH_IMAGE)
            XCTAssertFalse(pickerCodes.contains(code), "Retired models must not appear in new-generation queries")
            XCTAssertNotNil(
                getImageGenerationAdapter(modelCode: code),
                "Historical generations must retain adapter resolution for \(code)"
            )
        }
    }

    func testProviderService_googleCloudGeminiOmniFlashVideo_isActivePickerModel() {
        let omni = service.model(by: EnumProviderModelCode.GOOGLE_GEMINI_OMNI_FLASH_VIDEO)

        XCTAssertEqual(omni?.modelName, "Gemini Omni Flash")
        XCTAssertEqual(omni?.modelSetType, .VIDEO_GENERATE)
        XCTAssertEqual(omni?.modelGenerateBaseURL, GeminiInteractionsService.defaultBaseURL.absoluteString)
        XCTAssertEqual(omni?.modelParams.supportedDimensions, ["16:9", "9:16"])
        XCTAssertEqual(omni?.modelParams.supportedVideoDurations, [3, 4, 5, 6, 7, 8, 9, 10])
        XCTAssertEqual(omni?.modelParams.supportedVideoResolutions, ["720p"])
        XCTAssertEqual(omni?.modelParams.maxReferenceImages, 3)
        XCTAssertTrue(omni?.modelParams.supportsSourceImage == true)
        XCTAssertFalse(omni?.modelParams.supportsNegativePrompt == true)
        XCTAssertFalse(omni?.modelParams.supportsAudio == true)
        XCTAssertFalse(omni?.modelParams.supportsVideoUpload == true)
        XCTAssertTrue(omni?.active == true)

        let edit = service.model(by: EnumProviderModelCode.GOOGLE_GEMINI_OMNI_FLASH_VIDEO_EDIT)
        XCTAssertEqual(edit?.modelName, "Gemini Omni Flash")
        XCTAssertEqual(edit?.modelSetType, .VIDEO_EXTEND)
        XCTAssertEqual(edit?.modelGenerateBaseURL, GeminiInteractionsService.defaultBaseURL.absoluteString)
        XCTAssertEqual(edit?.modelParams.requiredMetadata, [GeminiInteractionMetadataKey.interactionId])
        XCTAssertEqual(edit?.modelParams.supportedDimensions, ["16:9", "9:16"])
        XCTAssertTrue(edit?.active == true)
    }

    func testProviderService_googleCloudVideoPickerModels_includeGeminiOmniFlash() {
        let googleVideoModels = service.models(for: .VIDEO_GENERATE).filter {
            $0.providerId == EnumProviderCode.GOOGLE_CLOUD.providerId
        }

        XCTAssertEqual(googleVideoModels.first?.modelName, "Gemini Omni Flash")
        XCTAssertTrue(googleVideoModels.contains { $0.modelCode == .GOOGLE_GEMINI_OMNI_FLASH_VIDEO })
    }

    func testProviderService_googleCloudVeo31Models_areCurrentPickerModels() {
        let googleVideoModels = service.models(for: .VIDEO_GENERATE).filter {
            $0.providerId == EnumProviderCode.GOOGLE_CLOUD.providerId
        }
        let googleVideoCodes = Set(googleVideoModels.map(\.modelCode))

        XCTAssertTrue(googleVideoCodes.contains(.GOOGLE_VEO_31))
        XCTAssertTrue(googleVideoCodes.contains(.GOOGLE_VEO_31_FAST))
        XCTAssertTrue(googleVideoCodes.contains(.GOOGLE_VEO_31_LITE))
        XCTAssertFalse(googleVideoCodes.contains(.GOOGLE_VEO_3))
        XCTAssertFalse(googleVideoCodes.contains(.GOOGLE_VEO_3_FAST))
        XCTAssertFalse(googleVideoCodes.contains(.GOOGLE_VEO_2))

        let standard = service.model(by: EnumProviderModelCode.GOOGLE_VEO_31)
        XCTAssertEqual(standard?.modelParams.supportedVideoResolutions, ["720p", "1080p", "4k"])
        XCTAssertTrue(standard?.modelParams.supportsAudio == true)
        XCTAssertEqual(standard?.modelAPIDocumentationURL, "https://ai.google.dev/gemini-api/docs/veo")

        let fast = service.model(by: EnumProviderModelCode.GOOGLE_VEO_31_FAST)
        XCTAssertEqual(fast?.modelParams.supportedVideoResolutions, ["720p", "1080p", "4k"])
        XCTAssertTrue(fast?.modelParams.supportsAudio == true)
        XCTAssertEqual(fast?.modelParams.maxReferenceImages, 3)

        let lite = service.model(by: EnumProviderModelCode.GOOGLE_VEO_31_LITE)
        XCTAssertEqual(lite?.modelParams.supportedVideoResolutions, ["720p", "1080p"])
        XCTAssertTrue(lite?.modelParams.supportsAudio == true)

        XCTAssertFalse(service.model(by: EnumProviderModelCode.GOOGLE_VEO_3)?.active == true)
        XCTAssertFalse(service.model(by: EnumProviderModelCode.GOOGLE_VEO_3_FAST)?.active == true)
        XCTAssertFalse(service.model(by: EnumProviderModelCode.GOOGLE_VEO_2)?.active == true)
    }

    func testProviderService_googleCloudNanoBananaLite_isRealtimeEditEligibleWithoutSeedControl() {
        let lite = service.model(by: EnumProviderModelCode.GOOGLE_GEMINI_31_FLASH_LITE_IMAGE)

        XCTAssertNotNil(lite)
        XCTAssertEqual(lite?.modelName, "Nano Banana 2 Lite")
        XCTAssertTrue(lite.map(RealtimeEditModelSupport.supportsRealtimeEdit) ?? false)
        XCTAssertFalse(RealtimeEditModelSupport.showsSeedControl(for: lite))
    }

    func testRealtimeEditModelSupport_requiresCanvasInputOrExplicitRealtimeModel() {
        let textToImageOnly = ProviderModel(
            providerId: EnumProviderCode.GOOGLE_CLOUD.providerId,
            modelCode: EnumProviderModelCode.GOOGLE_IMAGEN_4_FAST,
            modelSetType: .IMAGE_GENERATE,
            modelName: "Text to Image Only",
            modelDescription: "Seeded image generation without canvas input.",
            modelParams: ModelParams(supportsSeed: true),
            modelLaunchDate: Date(),
            modelGenerateBaseURL: "https://example.com",
            modelAPIDocumentationURL: "https://example.com",
            active: true
        )

        XCTAssertFalse(RealtimeEditModelSupport.supportsRealtimeEdit(textToImageOnly))
    }

    // MARK: - Singleton Tests

    func testProviderService_singleton_sameInstance() {
        let instance1 = ProviderService.shared
        let instance2 = ProviderService.shared

        XCTAssertTrue(instance1 === instance2, "Singleton should return same instance")
    }

    func testProviderService_singleton_consistentModelCount() {
        let count1 = ProviderService.shared.allModels.count
        let count2 = ProviderService.shared.allModels.count

        XCTAssertEqual(count1, count2, "Model count should be consistent")
    }

    // MARK: - Model Properties Tests

    func testProviderService_allModels_haveRequiredProperties() {
        for model in service.allModels {
            XCTAssertFalse(model.modelName.isEmpty, "Model should have a name")
            XCTAssertNotEqual(model.modelId, UUID(), "Model should have valid ID")
            XCTAssertNotEqual(model.providerId, UUID(), "Model should have valid provider ID")
        }
    }

    func testProviderService_models_haveValidSetType() {
        let validSetTypes: Set<EnumSetType> = [.IMAGE_GENERATE, .VIDEO_GENERATE, .VIDEO_EXTEND]

        for model in service.allModels {
            XCTAssertTrue(
                validSetTypes.contains(model.modelSetType),
                "Model \(model.modelName) has invalid set type: \(model.modelSetType)"
            )
        }
    }

    // MARK: - Coverage Tests

    func testProviderService_hasImageGenerationModels() {
        let imageModels = service.models(for: .IMAGE_GENERATE)

        XCTAssertGreaterThan(imageModels.count, 0, "Should have at least one image generation model")
    }

    func testProviderService_multipleProviders() {
        let allModels = service.allModels
        let providerIds = Set(allModels.map(\.providerId))

        XCTAssertGreaterThan(providerIds.count, 1, "Should have models from multiple providers")
    }
}
