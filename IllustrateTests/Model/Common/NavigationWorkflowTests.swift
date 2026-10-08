// MARK: - NavigationWorkflowTests.swift

// Workflow tests for navigation item definitions, section mapping,
// label/icon helpers, and ImageSet helper functions.
//
// Tests cover:
// - EnumNavigationItem.id: simple cases and associated-data cases
// - sectionItems(): section count, content, uniqueness
// - labelForItem(): representative items from each section
// - iconForItem(): representative items
// - setTypeForItem() and ImageSet helper functions

import AvgeekLocalizationCore
import XCTest
@testable import Illustrate
@testable import IllustrateProviders

final class NavigationWorkflowTests: XCTestCase {
    private var previousAppLanguage: String?

    override func setUp() {
        super.setUp()
        previousAppLanguage = UserDefaults.standard.string(forKey: SupportedLanguage.storageKey)
        UserDefaults.standard.set(SupportedLanguage.english.rawValue, forKey: SupportedLanguage.storageKey)
    }

    override func tearDown() {
        if let previousAppLanguage {
            UserDefaults.standard.set(previousAppLanguage, forKey: SupportedLanguage.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: SupportedLanguage.storageKey)
        }
        super.tearDown()
    }

    // MARK: - EnumNavigationItem.id Tests

    func testNavigationItem_Id_SimpleCase_Dashboard() {
        XCTAssertEqual(EnumNavigationItem.dashboard.id, "dashboard")
    }

    func testNavigationItem_Id_SimpleCase_Settings() {
        XCTAssertEqual(EnumNavigationItem.settingsProviders.id, "settingsProviders")
    }

    func testNavigationItem_Id_AssociatedData_GenerationImage_ContainsUUID() {
        let uuid = UUID()
        let item = EnumNavigationItem.generationImage(setId: uuid)
        XCTAssertTrue(item.id.contains(uuid.uuidString))
        XCTAssertTrue(item.id.hasPrefix("generationImage-"))
    }

    func testNavigationItem_Id_AssociatedData_GenerationVideo_ContainsUUID() {
        let uuid = UUID()
        let item = EnumNavigationItem.generationVideo(setId: uuid)
        XCTAssertTrue(item.id.contains(uuid.uuidString))
        XCTAssertTrue(item.id.hasPrefix("generationVideo-"))
    }

    func testNavigationItem_Id_AssociatedData_AddProvider_ContainsUUID() {
        let uuid = UUID()
        let item = EnumNavigationItem.addProvider(providerId: uuid)
        XCTAssertTrue(item.id.contains(uuid.uuidString))
        XCTAssertTrue(item.id.hasPrefix("addProvider-"))
    }

    func testNavigationItem_Id_DifferentUUIDs_ProduceDifferentIds() {
        let id1 = EnumNavigationItem.generationImage(setId: UUID())
        let id2 = EnumNavigationItem.generationImage(setId: UUID())
        XCTAssertNotEqual(id1.id, id2.id)
    }

    // MARK: - sectionItems() Tests

    func testSectionItems_AllSectionsHaveItems() {
        for section in EnumNavigationSection.allCases {
            let items = sectionItems(section: section)
            XCTAssertFalse(items.isEmpty, "\(section) should have items")
        }
    }

    func testSectionItems_SectionCount_Is5() {
        XCTAssertEqual(EnumNavigationSection.allCases.count, 5)
    }

    func testSectionItems_Workspace_ContainsDashboard() {
        let items = sectionItems(section: .Workspace)
        XCTAssertTrue(items.contains(.dashboard))
    }

    func testSectionItems_Workspace_ContainsAgentCanvas() {
        let items = sectionItems(section: .Workspace)
        XCTAssertTrue(items.contains(.agentCanvas))
    }

    func testSectionItems_Brand_ContainsBrandKit() {
        let items = sectionItems(section: .Brand)
        XCTAssertTrue(items.contains(.brandKit))
    }

    func testSectionItems_QuickActions_ContainsImageGenerate() {
        let items = sectionItems(section: .QuickActions)
        XCTAssertTrue(items.contains(.imageGenerate))
    }

    func testSectionItems_QuickActions_ContainsVideoGenerate() {
        let items = sectionItems(section: .QuickActions)
        XCTAssertTrue(items.contains(.videoGenerate))
    }

    func testSectionItems_History_ContainsImageGallery() {
        let items = sectionItems(section: .History)
        XCTAssertTrue(items.contains(.historyImageGallery))
    }

    func testSectionItems_Connections_ContainsProviders() {
        let items = sectionItems(section: .Project)
        XCTAssertTrue(items.contains(.settingsProviders))
    }

    // MARK: - EnumNavigationSection Tests

    func testNavigationSection_RawValue_Workspace() {
        XCTAssertEqual(EnumNavigationSection.Workspace.rawValue, "Workspace")
    }

    func testNavigationSection_RawValue_QuickActions() {
        XCTAssertEqual(EnumNavigationSection.QuickActions.rawValue, "Quick Actions")
    }

    func testNavigationSection_RawValue_Connections() {
        XCTAssertEqual(EnumNavigationSection.Project.rawValue, "Project")
    }

    // MARK: - labelForItem() Tests

    func testLabelForItem_Dashboard() {
        XCTAssertEqual(labelForItem(.dashboard), "Dashboard")
    }

    func testLabelForItem_BrandKit() {
        XCTAssertEqual(labelForItem(.brandKit), "Brand Kit")
    }

    func testLabelForItem_ImageGenerate() {
        // Delegates through labelForSetType(.IMAGE_GENERATE)
        XCTAssertEqual(labelForItem(.imageGenerate), "Generate Image")
    }

    func testLabelForItem_VideoGenerate() {
        XCTAssertEqual(labelForItem(.videoGenerate), "Generate Video")
    }

    func testLabelForItem_AgentCanvas() {
        XCTAssertEqual(labelForItem(.agentCanvas), "Agent Builder")
    }

    func testLabelForItem_Storyboard() {
        XCTAssertEqual(labelForItem(.storyboard), "Storyboards")
    }

    func testLabelForItem_SettingsProviders() {
        XCTAssertEqual(labelForItem(.settingsProviders), "Manage Providers")
    }

    func testLabelForItem_BulkSessions() {
        XCTAssertEqual(labelForItem(.bulkSessions), "Bulk Generate")
    }

    // MARK: - subLabelForItem() Tests

    func testSubLabelForItem_Dashboard_NonEmpty() {
        XCTAssertFalse(subLabelForItem(.dashboard).isEmpty)
    }

    func testSubLabelForItem_ImageGenerate_DelegatesToSetType() {
        XCTAssertEqual(subLabelForItem(.imageGenerate), subLabelForSetType(.IMAGE_GENERATE))
    }

    // MARK: - iconForItem() Tests

    func testIconForItem_Dashboard() {
        XCTAssertEqual(iconForItem(.dashboard), "house")
    }

    func testIconForItem_ImageGenerate_DelegatesToSetType() {
        XCTAssertEqual(iconForItem(.imageGenerate), iconForSetType(.IMAGE_GENERATE))
    }

    func testIconForItem_Settings() {
        XCTAssertEqual(iconForItem(.settingsProviders), "link")
    }

    func testIconForItem_BrandKit() {
        XCTAssertEqual(iconForItem(.brandKit), "briefcase")
    }

    func testIconForItem_Storyboard() {
        XCTAssertEqual(iconForItem(.storyboard), "movieclapper")
    }

    func testIconForItem_AssociatedData_GenerationImage() {
        let icon = iconForItem(.generationImage(setId: UUID()))
        XCTAssertEqual(icon, "wand.and.sparkles")
    }

    func testIconForItem_AllItems_NonEmpty() {
        let staticItems: [EnumNavigationItem] = [
            .dashboard, .agentCanvas, .flowCanvas, .realtimeEdit,
            .bulkSessions, .chatThreads, .storyboard,
            .brandKit, .creativeStudio, .productPhotoshoots,
            .imageGenerate, .videoGenerate, .videoExtend,
            .historyRequests, .historyFailedRequests,
            .historyImageGallery, .historyVideoGallery,
            .settingsProviders, .settingsStorage, .settingsUsageMetrics,
        ]
        for item in staticItems {
            XCTAssertFalse(iconForItem(item).isEmpty, "Icon for \(item) should not be empty")
        }
    }

    // MARK: - setTypeForItem() Tests

    func testSetTypeForItem_ImageGenerate() {
        XCTAssertEqual(setTypeForItem(.imageGenerate), .IMAGE_GENERATE)
    }

    func testSetTypeForItem_VideoGenerate() {
        XCTAssertEqual(setTypeForItem(.videoGenerate), .VIDEO_GENERATE)
    }

    func testSetTypeForItem_DefaultCase_ReturnsImageGenerate() {
        XCTAssertEqual(setTypeForItem(.dashboard), .IMAGE_GENERATE)
    }

    // MARK: - ImageSet Helper Function Tests

    func testLabelForSetType_ImageGenerate() {
        XCTAssertEqual(labelForSetType(.IMAGE_GENERATE), "Generate Image")
    }

    func testLabelForSetType_VideoGenerate() {
        XCTAssertEqual(labelForSetType(.VIDEO_GENERATE), "Generate Video")
    }

    func testLabelForSetType_VideoExtend() {
        XCTAssertEqual(labelForSetType(.VIDEO_EXTEND), "Extend Video")
    }

    func testIconForSetType_ImageGenerate() {
        XCTAssertEqual(iconForSetType(.IMAGE_GENERATE), "wand.and.sparkles")
    }

    func testIconForSetType_VideoGenerate() {
        XCTAssertEqual(iconForSetType(.VIDEO_GENERATE), "play")
    }

    func testIconForSetType_VideoExtend() {
        XCTAssertEqual(iconForSetType(.VIDEO_EXTEND), "forward.end")
    }

    func testSubLabelForSetType_AllCases_NonEmpty() {
        for setType in EnumSetType.allCases {
            XCTAssertFalse(subLabelForSetType(setType).isEmpty, "\(setType) subLabel should not be empty")
        }
    }
}
