// MARK: - CreativeStudioItemModelTests.swift

// Tests for CreativeStudioItem model and CreativeStudioItemStatus enum.
//
// Tests cover:
// - CreativeStudioItemStatus raw values and backward-compatible decoding
// - CreativeStudioItem initialization with defaults and custom values
// - assetTypeEnum computed property (including unknown rawValue fallback)
// - imageGenerationConfiguration accessor round-trip and corrupt data
// - Codable round-trip serialization
// - Decode with missing optional fields (decodeIfPresent defaults)

import Foundation
import XCTest
@testable import Illustrate

// MARK: - CreativeStudioItemStatus Tests

final class CreativeStudioItemStatusTests: XCTestCase {
    // MARK: - Raw Values

    func testCreativeStudioItemStatus_rawValue_processing() {
        XCTAssertEqual(CreativeStudioItemStatus.PROCESSING.rawValue, "PROCESSING")
    }

    func testCreativeStudioItemStatus_rawValue_generated() {
        XCTAssertEqual(CreativeStudioItemStatus.GENERATED.rawValue, "GENERATED")
    }

    func testCreativeStudioItemStatus_rawValue_failed() {
        XCTAssertEqual(CreativeStudioItemStatus.FAILED.rawValue, "FAILED")
    }

    // MARK: - Backward Compatible Decoding

    func testCreativeStudioItemStatus_decode_lowercase_processing() throws {
        let decoded = try JSONDecoder().decode(
            CreativeStudioItemStatus.self,
            from: Data("\"processing\"".utf8)
        )
        XCTAssertEqual(decoded, .PROCESSING)
    }

    func testCreativeStudioItemStatus_decode_uppercase_processing() throws {
        let decoded = try JSONDecoder().decode(
            CreativeStudioItemStatus.self,
            from: Data("\"PROCESSING\"".utf8)
        )
        XCTAssertEqual(decoded, .PROCESSING)
    }

    func testCreativeStudioItemStatus_decode_lowercase_generated() throws {
        let decoded = try JSONDecoder().decode(
            CreativeStudioItemStatus.self,
            from: Data("\"generated\"".utf8)
        )
        XCTAssertEqual(decoded, .GENERATED)
    }

    func testCreativeStudioItemStatus_decode_uppercase_generated() throws {
        let decoded = try JSONDecoder().decode(
            CreativeStudioItemStatus.self,
            from: Data("\"GENERATED\"".utf8)
        )
        XCTAssertEqual(decoded, .GENERATED)
    }

    func testCreativeStudioItemStatus_decode_lowercase_failed() throws {
        let decoded = try JSONDecoder().decode(
            CreativeStudioItemStatus.self,
            from: Data("\"failed\"".utf8)
        )
        XCTAssertEqual(decoded, .FAILED)
    }

    func testCreativeStudioItemStatus_decode_uppercase_failed() throws {
        let decoded = try JSONDecoder().decode(
            CreativeStudioItemStatus.self,
            from: Data("\"FAILED\"".utf8)
        )
        XCTAssertEqual(decoded, .FAILED)
    }

    func testCreativeStudioItemStatus_decode_unknownValue_throws() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                CreativeStudioItemStatus.self,
                from: Data("\"invalid\"".utf8)
            )
        )
    }
}

// MARK: - CreativeStudioItem Model Tests

final class CreativeStudioItemModelTests: XCTestCase {
    // MARK: - Initialization

    func testCreativeStudioItem_init_setsStudioId() {
        let studioId = UUID()
        let item = CreativeStudioItem(studioId: studioId)
        XCTAssertEqual(item.studioId, studioId)
    }

    func testCreativeStudioItem_init_defaultProjectId() {
        let item = CreativeStudioItem(studioId: UUID())
        XCTAssertEqual(item.projectId, Project.defaultProjectId)
    }

    func testCreativeStudioItem_init_defaultStatusIsProcessing() {
        let item = CreativeStudioItem(studioId: UUID())
        XCTAssertEqual(item.status, .PROCESSING)
    }

    func testCreativeStudioItem_init_defaultAssetTypeIsGeneralPurpose() {
        let item = CreativeStudioItem(studioId: UUID())
        XCTAssertEqual(item.assetType, CreativeAssetType.generalPurpose.rawValue)
    }

    func testCreativeStudioItem_init_defaultUserPromptIsEmpty() {
        let item = CreativeStudioItem(studioId: UUID())
        XCTAssertEqual(item.userPrompt, "")
    }

    func testCreativeStudioItem_init_defaultFullPromptIsEmpty() {
        let item = CreativeStudioItem(studioId: UUID())
        XCTAssertEqual(item.fullPrompt, "")
    }

    func testCreativeStudioItem_init_optionalFieldsNil() {
        let item = CreativeStudioItem(studioId: UUID())
        XCTAssertNil(item.generationId)
        XCTAssertNil(item.errorMessage)
        XCTAssertNil(item.configurationData)
        XCTAssertNil(item.queueItemId)
    }

    func testCreativeStudioItem_init_customAssetType() {
        let item = CreativeStudioItem(studioId: UUID(), assetType: .poster)
        XCTAssertEqual(item.assetType, CreativeAssetType.poster.rawValue)
    }

    func testCreativeStudioItem_init_customPrompts() {
        let item = CreativeStudioItem(
            studioId: UUID(),
            userPrompt: "A sunset",
            fullPrompt: "Brand styled sunset with warm tones"
        )
        XCTAssertEqual(item.userPrompt, "A sunset")
        XCTAssertEqual(item.fullPrompt, "Brand styled sunset with warm tones")
    }

    func testCreativeStudioItem_init_customProjectId() {
        let projectId = UUID()
        let item = CreativeStudioItem(studioId: UUID(), projectId: projectId)
        XCTAssertEqual(item.projectId, projectId)
    }

    // MARK: - assetTypeEnum Computed Property

    func testCreativeStudioItem_assetTypeEnum_returnsCorrectType() {
        let item = CreativeStudioItem(studioId: UUID(), assetType: .poster)
        XCTAssertEqual(item.assetTypeEnum, .poster)
    }

    func testCreativeStudioItem_assetTypeEnum_generalPurpose() {
        let item = CreativeStudioItem(studioId: UUID())
        XCTAssertEqual(item.assetTypeEnum, .generalPurpose)
    }

    func testCreativeStudioItem_assetTypeEnum_unknownRawValue_defaultsToGeneralPurpose() {
        let item = CreativeStudioItem(studioId: UUID())
        item.assetType = "unknown_type"
        XCTAssertEqual(item.assetTypeEnum, .generalPurpose)
    }

    // MARK: - imageGenerationConfiguration Accessor

    func testCreativeStudioItem_imageConfig_nilData_returnsDefault() {
        let item = CreativeStudioItem(studioId: UUID())
        let config = item.imageGenerationConfiguration
        XCTAssertEqual(config.prompt, "")
        XCTAssertEqual(config.selectedModelId, "")
    }

    func testCreativeStudioItem_imageConfig_setAndGet_roundTrip() {
        let item = CreativeStudioItem(studioId: UUID())
        var config = ImageGenerationConfiguration()
        config.prompt = "Brand poster"
        config.selectedModelId = "dall-e-3"
        item.imageGenerationConfiguration = config

        let retrieved = item.imageGenerationConfiguration
        XCTAssertEqual(retrieved.prompt, "Brand poster")
        XCTAssertEqual(retrieved.selectedModelId, "dall-e-3")
    }

    func testCreativeStudioItem_imageConfig_corruptData_returnsDefault() {
        let item = CreativeStudioItem(studioId: UUID())
        item.configurationData = Data("not json".utf8)
        let config = item.imageGenerationConfiguration
        XCTAssertEqual(config.prompt, "")
    }

    // MARK: - Codable Round-Trip

    func testCreativeStudioItem_codableRoundTrip_preservesAllFields() throws {
        let studioId = UUID()
        let projectId = UUID()
        let item = CreativeStudioItem(
            studioId: studioId,
            projectId: projectId,
            assetType: .banner,
            userPrompt: "A banner",
            fullPrompt: "Full brand banner"
        )
        let genId = UUID()
        item.generationId = genId
        item.status = .GENERATED

        let data = try JSONEncoder().encode(item)
        let restored = try JSONDecoder().decode(CreativeStudioItem.self, from: data)

        XCTAssertEqual(restored.id, item.id)
        XCTAssertEqual(restored.studioId, studioId)
        XCTAssertEqual(restored.projectId, projectId)
        XCTAssertEqual(restored.status, .GENERATED)
        XCTAssertEqual(restored.assetType, CreativeAssetType.banner.rawValue)
        XCTAssertEqual(restored.userPrompt, "A banner")
        XCTAssertEqual(restored.fullPrompt, "Full brand banner")
        XCTAssertEqual(restored.generationId, genId)
    }

    func testCreativeStudioItem_codableRoundTrip_withErrorMessage() throws {
        let item = CreativeStudioItem(studioId: UUID())
        item.status = .FAILED
        item.errorMessage = "Rate limited"

        let data = try JSONEncoder().encode(item)
        let restored = try JSONDecoder().decode(CreativeStudioItem.self, from: data)

        XCTAssertEqual(restored.status, .FAILED)
        XCTAssertEqual(restored.errorMessage, "Rate limited")
    }

    // MARK: - Identifiable

    func testCreativeStudioItem_twoInstances_haveDifferentIds() {
        let studioId = UUID()
        let i1 = CreativeStudioItem(studioId: studioId)
        let i2 = CreativeStudioItem(studioId: studioId)
        XCTAssertNotEqual(i1.id, i2.id)
    }
}
