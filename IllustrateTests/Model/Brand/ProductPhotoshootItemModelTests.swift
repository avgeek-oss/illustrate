// MARK: - ProductPhotoshootItemModelTests.swift

// Tests for ProductPhotoshootItem model and PhotoshootItemStatus enum.
//
// Tests cover:
// - PhotoshootItemStatus raw values and backward-compatible decoding
// - ProductPhotoshootItem initialization with defaults and custom values
// - Backdrop field handling (asset name, custom file name)
// - imageGenerationConfiguration accessor round-trip
// - Codable round-trip serialization
// - Decode with missing optional fields

import Foundation
import XCTest
@testable import Illustrate

// MARK: - PhotoshootItemStatus Tests

final class PhotoshootItemStatusTests: XCTestCase {
    // MARK: - Raw Values

    func testPhotoshootItemStatus_rawValue_processing() {
        XCTAssertEqual(PhotoshootItemStatus.PROCESSING.rawValue, "PROCESSING")
    }

    func testPhotoshootItemStatus_rawValue_generated() {
        XCTAssertEqual(PhotoshootItemStatus.GENERATED.rawValue, "GENERATED")
    }

    func testPhotoshootItemStatus_rawValue_failed() {
        XCTAssertEqual(PhotoshootItemStatus.FAILED.rawValue, "FAILED")
    }

    // MARK: - Backward Compatible Decoding

    func testPhotoshootItemStatus_decode_lowercase_processing() throws {
        let decoded = try JSONDecoder().decode(
            PhotoshootItemStatus.self,
            from: Data("\"processing\"".utf8)
        )
        XCTAssertEqual(decoded, .PROCESSING)
    }

    func testPhotoshootItemStatus_decode_uppercase_processing() throws {
        let decoded = try JSONDecoder().decode(
            PhotoshootItemStatus.self,
            from: Data("\"PROCESSING\"".utf8)
        )
        XCTAssertEqual(decoded, .PROCESSING)
    }

    func testPhotoshootItemStatus_decode_lowercase_generated() throws {
        let decoded = try JSONDecoder().decode(
            PhotoshootItemStatus.self,
            from: Data("\"generated\"".utf8)
        )
        XCTAssertEqual(decoded, .GENERATED)
    }

    func testPhotoshootItemStatus_decode_lowercase_failed() throws {
        let decoded = try JSONDecoder().decode(
            PhotoshootItemStatus.self,
            from: Data("\"failed\"".utf8)
        )
        XCTAssertEqual(decoded, .FAILED)
    }

    func testPhotoshootItemStatus_decode_unknownValue_throws() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                PhotoshootItemStatus.self,
                from: Data("\"invalid\"".utf8)
            )
        )
    }
}

// MARK: - ProductPhotoshootItem Model Tests

final class ProductPhotoshootItemModelTests: XCTestCase {
    // MARK: - Initialization

    func testProductPhotoshootItem_init_setsPhotoshootId() {
        let photoshootId = UUID()
        let item = ProductPhotoshootItem(photoshootId: photoshootId)
        XCTAssertEqual(item.photoshootId, photoshootId)
    }

    func testProductPhotoshootItem_init_defaultProjectId() {
        let item = ProductPhotoshootItem(photoshootId: UUID())
        XCTAssertEqual(item.projectId, Project.defaultProjectId)
    }

    func testProductPhotoshootItem_init_defaultStatusIsProcessing() {
        let item = ProductPhotoshootItem(photoshootId: UUID())
        XCTAssertEqual(item.status, .PROCESSING)
    }

    func testProductPhotoshootItem_init_defaultBackdropAssetNameNil() {
        let item = ProductPhotoshootItem(photoshootId: UUID())
        XCTAssertNil(item.backdropAssetName)
    }

    func testProductPhotoshootItem_init_defaultCustomBackdropFileNameNil() {
        let item = ProductPhotoshootItem(photoshootId: UUID())
        XCTAssertNil(item.customBackdropFileName)
    }

    func testProductPhotoshootItem_init_optionalFieldsNil() {
        let item = ProductPhotoshootItem(photoshootId: UUID())
        XCTAssertNil(item.generationId)
        XCTAssertNil(item.errorMessage)
        XCTAssertNil(item.configurationData)
        XCTAssertNil(item.queueItemId)
    }

    func testProductPhotoshootItem_init_customProjectId() {
        let projectId = UUID()
        let item = ProductPhotoshootItem(photoshootId: UUID(), projectId: projectId)
        XCTAssertEqual(item.projectId, projectId)
    }

    // MARK: - Backdrop Fields

    func testProductPhotoshootItem_init_withBackdropAssetName() {
        let item = ProductPhotoshootItem(photoshootId: UUID(), backdropAssetName: "studio_white")
        XCTAssertEqual(item.backdropAssetName, "studio_white")
    }

    func testProductPhotoshootItem_init_withCustomBackdropFileName() {
        let item = ProductPhotoshootItem(photoshootId: UUID(), customBackdropFileName: "my_backdrop.png")
        XCTAssertEqual(item.customBackdropFileName, "my_backdrop.png")
    }

    func testProductPhotoshootItem_init_bothBackdropFields_coexist() {
        let item = ProductPhotoshootItem(
            photoshootId: UUID(),
            backdropAssetName: "studio_white",
            customBackdropFileName: "custom.png"
        )
        XCTAssertEqual(item.backdropAssetName, "studio_white")
        XCTAssertEqual(item.customBackdropFileName, "custom.png")
    }

    // MARK: - imageGenerationConfiguration Accessor

    func testProductPhotoshootItem_imageConfig_nilData_returnsDefault() {
        let item = ProductPhotoshootItem(photoshootId: UUID())
        let config = item.imageGenerationConfiguration
        XCTAssertEqual(config.prompt, "")
        XCTAssertEqual(config.selectedModelId, "")
    }

    func testProductPhotoshootItem_imageConfig_setAndGet_roundTrip() {
        let item = ProductPhotoshootItem(photoshootId: UUID())
        var config = ImageGenerationConfiguration()
        config.prompt = "Product on white backdrop"
        config.selectedModelId = "stability-core"
        item.imageGenerationConfiguration = config

        let retrieved = item.imageGenerationConfiguration
        XCTAssertEqual(retrieved.prompt, "Product on white backdrop")
        XCTAssertEqual(retrieved.selectedModelId, "stability-core")
    }

    func testProductPhotoshootItem_imageConfig_corruptData_returnsDefault() {
        let item = ProductPhotoshootItem(photoshootId: UUID())
        item.configurationData = Data("bad data".utf8)
        let config = item.imageGenerationConfiguration
        XCTAssertEqual(config.prompt, "")
    }

    // MARK: - Codable Round-Trip

    func testProductPhotoshootItem_codableRoundTrip_preservesAllFields() throws {
        let photoshootId = UUID()
        let projectId = UUID()
        let item = ProductPhotoshootItem(
            photoshootId: photoshootId,
            projectId: projectId,
            backdropAssetName: "marble",
            customBackdropFileName: "custom_bg.png"
        )
        let genId = UUID()
        item.generationId = genId
        item.status = .GENERATED

        let data = try JSONEncoder().encode(item)
        let restored = try JSONDecoder().decode(ProductPhotoshootItem.self, from: data)

        XCTAssertEqual(restored.id, item.id)
        XCTAssertEqual(restored.photoshootId, photoshootId)
        XCTAssertEqual(restored.projectId, projectId)
        XCTAssertEqual(restored.status, .GENERATED)
        XCTAssertEqual(restored.generationId, genId)
        XCTAssertEqual(restored.backdropAssetName, "marble")
        XCTAssertEqual(restored.customBackdropFileName, "custom_bg.png")
    }

    func testProductPhotoshootItem_codableRoundTrip_withErrorMessage() throws {
        let item = ProductPhotoshootItem(photoshootId: UUID())
        item.status = .FAILED
        item.errorMessage = "Generation failed"

        let data = try JSONEncoder().encode(item)
        let restored = try JSONDecoder().decode(ProductPhotoshootItem.self, from: data)

        XCTAssertEqual(restored.status, .FAILED)
        XCTAssertEqual(restored.errorMessage, "Generation failed")
    }

    func testProductPhotoshootItem_codableRoundTrip_nilBackdrops() throws {
        let item = ProductPhotoshootItem(photoshootId: UUID())

        let data = try JSONEncoder().encode(item)
        let restored = try JSONDecoder().decode(ProductPhotoshootItem.self, from: data)

        XCTAssertNil(restored.backdropAssetName)
        XCTAssertNil(restored.customBackdropFileName)
    }

    // MARK: - Identifiable

    func testProductPhotoshootItem_twoInstances_haveDifferentIds() {
        let photoshootId = UUID()
        let i1 = ProductPhotoshootItem(photoshootId: photoshootId)
        let i2 = ProductPhotoshootItem(photoshootId: photoshootId)
        XCTAssertNotEqual(i1.id, i2.id)
    }
}
