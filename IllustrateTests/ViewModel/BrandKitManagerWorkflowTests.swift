// MARK: - BrandKitManagerWorkflowTests.swift

// Workflow tests for BrandKit model and BrandKitManager operations.
//
// Tests cover:
// - BrandColorType enum: cases, defaultColor, displayName
// - ModelAsset computed properties: thumbFileName, largeThumbFileName
// - BrandKit color(for:) and setColor helpers
// - BrandKit modelAssets serialization round-trip
// - BrandKitManager ensureBrandKitExists with in-memory SwiftData
// - BrandKitManager updateBrandAbout (500 char limit)
// - BrandKitManager updateBrandPersonality (160 char limit)
// - Color normalization behavior

import SwiftData
import XCTest
@testable import Illustrate

@MainActor
final class BrandKitManagerWorkflowTests: XCTestCase {
    private var mgr: BrandKitManager!

    override func setUp() async throws {
        try await super.setUp()
        mgr = BrandKitManager.shared
        // Reset state before each test
        mgr.currentBrandKit = nil
    }

    override func tearDown() async throws {
        mgr.currentBrandKit = nil
        mgr = nil
        try await super.tearDown()
    }

    // MARK: - BrandColorType Tests

    func testBrandColorType_AllCasesCount() {
        XCTAssertEqual(BrandColorType.allCases.count, 5)
    }

    func testBrandColorType_DefaultColor_Primary() {
        XCTAssertEqual(BrandColorType.primary.defaultColor, "#007AFF")
    }

    func testBrandColorType_DefaultColor_Secondary() {
        XCTAssertEqual(BrandColorType.secondary.defaultColor, "#5856D6")
    }

    func testBrandColorType_DefaultColor_Accent() {
        XCTAssertEqual(BrandColorType.accent.defaultColor, "#FF9500")
    }

    func testBrandColorType_DefaultColor_Background() {
        XCTAssertEqual(BrandColorType.background.defaultColor, "#FFFFFF")
    }

    func testBrandColorType_DefaultColor_Text() {
        XCTAssertEqual(BrandColorType.text.defaultColor, "#000000")
    }

    func testBrandColorType_DisplayName_Text() {
        XCTAssertEqual(BrandColorType.text.displayName, "Text/Label")
    }

    func testBrandColorType_DisplayName_Primary() {
        XCTAssertEqual(BrandColorType.primary.displayName, "Primary")
    }

    // MARK: - ModelAsset Computed Properties Tests

    func testModelAsset_ThumbFileName() {
        let asset = ModelAsset(fileName: "test_photo")
        XCTAssertEqual(asset.thumbFileName, "test_photo_thumb")
    }

    func testModelAsset_LargeThumbFileName() {
        let asset = ModelAsset(fileName: "test_photo")
        XCTAssertEqual(asset.largeThumbFileName, "test_photo_thumb_large")
    }

    // MARK: - BrandKit color(for:) / setColor Tests

    func testBrandKit_ColorForType_ReturnsDefault_WhenNotSet() {
        let kit = BrandKit()
        XCTAssertEqual(kit.color(for: .primary), "#007AFF")
    }

    func testBrandKit_SetColor_UpdatesColor() {
        let kit = BrandKit()
        kit.setColor("#FF0000", for: .primary)
        XCTAssertEqual(kit.color(for: .primary), "#FF0000")
    }

    func testBrandKit_SetColor_OverwritesPrevious() {
        let kit = BrandKit(brandColors: ["accent": "#111111"])
        kit.setColor("#222222", for: .accent)
        XCTAssertEqual(kit.color(for: .accent), "#222222")
    }

    // MARK: - BrandKit modelAssets Serialization Round-Trip

    func testBrandKit_ModelAssets_RoundTrip() {
        let kit = BrandKit()
        let id1 = UUID()
        let id2 = UUID()

        let assets = [
            ModelAsset(id: id1, fileName: "asset_a"),
            ModelAsset(id: id2, fileName: "asset_b"),
        ]
        kit.modelAssets = assets

        let retrieved = kit.modelAssets
        XCTAssertEqual(retrieved.count, 2)
        XCTAssertEqual(retrieved[0].id, id1)
        XCTAssertEqual(retrieved[0].fileName, "asset_a")
        XCTAssertEqual(retrieved[1].id, id2)
        XCTAssertEqual(retrieved[1].fileName, "asset_b")
    }

    func testBrandKit_ModelAssets_EmptyByDefault() {
        let kit = BrandKit()
        XCTAssertTrue(kit.modelAssets.isEmpty)
    }

    // MARK: - BrandKitManager ensureBrandKitExists Tests

    func testEnsureBrandKitExists_CreatesNewKit() async throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext
        let projectId = UUID()

        mgr.ensureBrandKitExists(modelContext: context, projectId: projectId)

        // Allow the internal Task to complete
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertNotNil(mgr.currentBrandKit)
        XCTAssertEqual(mgr.currentBrandKit?.projectId, projectId)
    }

    func testEnsureBrandKitExists_FindsExistingKit() async throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext
        let projectId = UUID()

        // Pre-create a brand kit
        let existingKit = BrandKit(projectId: projectId, brandName: "Existing Brand")
        context.insert(existingKit)
        try context.save()

        mgr.ensureBrandKitExists(modelContext: context, projectId: projectId)

        // Allow the internal Task to complete
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertNotNil(mgr.currentBrandKit)
        XCTAssertEqual(mgr.currentBrandKit?.brandName, "Existing Brand")
    }

    // MARK: - BrandKitManager updateBrandAbout Tests

    func testUpdateBrandAbout_UnderLimit_PreservesFullText() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let kit = BrandKit(projectId: UUID())
        context.insert(kit)
        try context.save()
        mgr.currentBrandKit = kit

        let text = String(repeating: "a", count: 400)
        mgr.updateBrandAbout(text, modelContext: context)

        XCTAssertEqual(kit.brandAbout.count, 400)
    }

    func testUpdateBrandAbout_OverLimit_TruncatesTo500() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let kit = BrandKit(projectId: UUID())
        context.insert(kit)
        try context.save()
        mgr.currentBrandKit = kit

        let text = String(repeating: "x", count: 700)
        mgr.updateBrandAbout(text, modelContext: context)

        XCTAssertEqual(kit.brandAbout.count, 500)
    }

    // MARK: - BrandKitManager updateBrandPersonality Tests

    func testUpdateBrandPersonality_UnderLimit_PreservesFullText() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let kit = BrandKit(projectId: UUID())
        context.insert(kit)
        try context.save()
        mgr.currentBrandKit = kit

        let text = String(repeating: "b", count: 100)
        mgr.updateBrandPersonality(text, modelContext: context)

        XCTAssertEqual(kit.brandPersonality.count, 100)
    }

    func testUpdateBrandPersonality_OverLimit_TruncatesTo160() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let kit = BrandKit(projectId: UUID())
        context.insert(kit)
        try context.save()
        mgr.currentBrandKit = kit

        let text = String(repeating: "c", count: 250)
        mgr.updateBrandPersonality(text, modelContext: context)

        XCTAssertEqual(kit.brandPersonality.count, 160)
    }

    // MARK: - Color Normalization Tests

    func testUpdateBrandColor_NormalizesLowercaseToUppercase() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let kit = BrandKit(projectId: UUID())
        context.insert(kit)
        try context.save()
        mgr.currentBrandKit = kit

        mgr.updateBrandColor("ff0000", for: BrandColorType.primary, modelContext: context)

        XCTAssertEqual(kit.color(for: .primary), "#FF0000")
    }

    func testUpdateBrandColor_PreservesHashPrefix() throws {
        let container = try makeTestModelContainer()
        let context = container.mainContext

        let kit = BrandKit(projectId: UUID())
        context.insert(kit)
        try context.save()
        mgr.currentBrandKit = kit

        mgr.updateBrandColor("#AABBCC", for: BrandColorType.secondary, modelContext: context)

        XCTAssertEqual(kit.color(for: .secondary), "#AABBCC")
    }
}
