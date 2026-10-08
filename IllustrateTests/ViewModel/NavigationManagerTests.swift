// MARK: - NavigationManagerTests.swift

// Unit tests for NavigationManager and related types.
//
// Tests cover:
// - GenerateImagePreload struct
// - ExtendVideoPreload struct
// - NavigationManager navigation methods
// - NavigationManager preload management
// - EnumNavigationItem properties
// - EnumNavigationSection cases
// - Navigation helper functions

import XCTest
@testable import Illustrate

final class NavigationManagerTests: XCTestCase {
    // MARK: - EnumNavigationItem Tests

    func testEnumNavigationItem_id_staticItems() {
        XCTAssertEqual(EnumNavigationItem.dashboard.id, "dashboard")
        XCTAssertEqual(EnumNavigationItem.agentCanvas.id, "agentCanvas")
        XCTAssertEqual(EnumNavigationItem.flowCanvas.id, "flowCanvas")
        XCTAssertEqual(EnumNavigationItem.realtimeEdit.id, "realtimeEdit")
        XCTAssertEqual(EnumNavigationItem.bulkSessions.id, "bulkSessions")
        XCTAssertEqual(EnumNavigationItem.chatThreads.id, "chatThreads")
        XCTAssertEqual(EnumNavigationItem.storyboard.id, "storyboard")
    }

    func testEnumNavigationItem_id_brandItems() {
        XCTAssertEqual(EnumNavigationItem.brandKit.id, "brandKit")
        XCTAssertEqual(EnumNavigationItem.creativeStudio.id, "creativeStudio")
        XCTAssertEqual(EnumNavigationItem.productPhotoshoots.id, "productPhotoshoots")
        XCTAssertEqual(EnumNavigationItem.promptGallery.id, "promptGallery")
    }

    func testEnumNavigationItem_id_quickActionItems() {
        XCTAssertEqual(EnumNavigationItem.imageGenerate.id, "imageGenerate")
        XCTAssertEqual(EnumNavigationItem.videoGenerate.id, "videoGenerate")
        XCTAssertEqual(EnumNavigationItem.videoExtend.id, "videoExtend")
    }

    func testEnumNavigationItem_id_historyItems() {
        XCTAssertEqual(EnumNavigationItem.historyRequests.id, "historyRequests")
        XCTAssertEqual(EnumNavigationItem.historyFailedRequests.id, "historyFailedRequests")
        XCTAssertEqual(EnumNavigationItem.historyImageGallery.id, "historyImageGallery")
        XCTAssertEqual(EnumNavigationItem.historyVideoGallery.id, "historyVideoGallery")
    }

    func testEnumNavigationItem_id_settingsItems() {
        XCTAssertEqual(EnumNavigationItem.settingsProviders.id, "settingsProviders")
        XCTAssertEqual(EnumNavigationItem.settingsStorage.id, "settingsStorage")
        XCTAssertEqual(EnumNavigationItem.settingsUsageMetrics.id, "settingsUsageMetrics")
    }

    func testEnumNavigationItem_id_generationImageWithSetId() {
        let setId = UUID()
        let item = EnumNavigationItem.generationImage(setId: setId)

        XCTAssertEqual(item.id, "generationImage-\(setId.uuidString)")
    }

    func testEnumNavigationItem_id_generationVideoWithSetId() {
        let setId = UUID()
        let item = EnumNavigationItem.generationVideo(setId: setId)

        XCTAssertEqual(item.id, "generationVideo-\(setId.uuidString)")
    }

    func testEnumNavigationItem_id_addProviderWithProviderId() {
        let providerId = UUID()
        let item = EnumNavigationItem.addProvider(providerId: providerId)

        XCTAssertEqual(item.id, "addProvider-\(providerId.uuidString)")
    }

    func testEnumNavigationItem_hashable() {
        let setId = UUID()
        let item1 = EnumNavigationItem.generationImage(setId: setId)
        let item2 = EnumNavigationItem.generationImage(setId: setId)
        let item3 = EnumNavigationItem.generationImage(setId: UUID())

        XCTAssertEqual(item1, item2)
        XCTAssertNotEqual(item1, item3)
    }

    func testEnumNavigationItem_identifiable() {
        let item = EnumNavigationItem.dashboard
        XCTAssertNotNil(item.id)
    }

    // MARK: - EnumNavigationSection Tests

    func testEnumNavigationSection_rawValues() {
        XCTAssertEqual(EnumNavigationSection.Workspace.rawValue, "Workspace")
        XCTAssertEqual(EnumNavigationSection.Brand.rawValue, "Brand")
        XCTAssertEqual(EnumNavigationSection.QuickActions.rawValue, "Quick Actions")
        XCTAssertEqual(EnumNavigationSection.History.rawValue, "History")
        XCTAssertEqual(EnumNavigationSection.Project.rawValue, "Project")
    }

    func testEnumNavigationSection_id() {
        XCTAssertEqual(EnumNavigationSection.Workspace.id, "Workspace")
        XCTAssertEqual(EnumNavigationSection.Brand.id, "Brand")
        XCTAssertEqual(EnumNavigationSection.QuickActions.id, "Quick Actions")
    }

    func testEnumNavigationSection_allCases() {
        let allCases = EnumNavigationSection.allCases

        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.Workspace))
        XCTAssertTrue(allCases.contains(.Brand))
        XCTAssertTrue(allCases.contains(.QuickActions))
        XCTAssertTrue(allCases.contains(.History))
        XCTAssertTrue(allCases.contains(.Project))
    }

    func testEnumNavigationSection_codable() throws {
        let sections = EnumNavigationSection.allCases

        let data = try JSONEncoder().encode(sections)
        let decoded = try JSONDecoder().decode([EnumNavigationSection].self, from: data)

        XCTAssertEqual(decoded, sections)
    }

    // MARK: - sectionItems Helper Tests

    func testSectionItems_workspace() {
        let items = sectionItems(section: .Workspace)

        XCTAssertTrue(items.contains(.dashboard))
        XCTAssertTrue(items.contains(.agentCanvas))
        XCTAssertTrue(items.contains(.chatThreads))
        XCTAssertTrue(items.contains(.flowCanvas))
        XCTAssertTrue(items.contains(.realtimeEdit))
        XCTAssertTrue(items.contains(.bulkSessions))
        XCTAssertTrue(items.contains(.bulkEdits))
        XCTAssertTrue(items.contains(.storyboard))
        XCTAssertTrue(items.contains(.productPhotoshoots))
    }

    func testSectionItems_brand() {
        let items = sectionItems(section: .Brand)

        XCTAssertEqual(items.count, 4)
        XCTAssertTrue(items.contains(.brandKit))
        XCTAssertTrue(items.contains(.creativeStudio))
        XCTAssertTrue(items.contains(.promptGallery))
        XCTAssertTrue(items.contains(.productGallery))
    }

    func testSectionItems_quickActions() {
        let items = sectionItems(section: .QuickActions)

        XCTAssertEqual(items.count, 3)
        XCTAssertTrue(items.contains(.imageGenerate))
        XCTAssertTrue(items.contains(.videoGenerate))
        XCTAssertTrue(items.contains(.videoExtend))
    }

    func testSectionItems_history() {
        let items = sectionItems(section: .History)

        XCTAssertTrue(items.contains(.historyImageGallery))
        XCTAssertTrue(items.contains(.historyVideoGallery))
        XCTAssertTrue(items.contains(.historyFailedRequests))
    }

    func testSectionItems_connections() {
        let items = sectionItems(section: .Project)

        XCTAssertEqual(items.count, 3)
        XCTAssertTrue(items.contains(.settingsProviders))
        XCTAssertTrue(items.contains(.settingsStorage))
        XCTAssertTrue(items.contains(.settingsUsageMetrics))
    }

    // MARK: - labelForItem Helper Tests

    func testLabelForItem_dashboard() {
        XCTAssertEqual(labelForItem(.dashboard), "Dashboard")
    }

    func testLabelForItem_brandKit() {
        XCTAssertEqual(labelForItem(.brandKit), "Brand Kit")
    }

    func testLabelForItem_agentCanvas() {
        XCTAssertEqual(labelForItem(.agentCanvas), "Agent Builder")
    }

    func testLabelForItem_flowCanvas() {
        XCTAssertEqual(labelForItem(.flowCanvas), "Flow Canvas")
    }

    func testLabelForItem_realtimeEdit() {
        XCTAssertEqual(labelForItem(.realtimeEdit), "Realtime Edit")
    }

    func testLabelForItem_chatThreads() {
        XCTAssertEqual(labelForItem(.chatThreads), "Chat Threads")
    }

    func testLabelForItem_storyboard() {
        XCTAssertEqual(labelForItem(.storyboard), "Storyboards")
    }

    func testLabelForItem_bulkSessions() {
        XCTAssertEqual(labelForItem(.bulkSessions), "Bulk Generate")
    }

    func testLabelForItem_historyFailedRequests() {
        XCTAssertEqual(labelForItem(.historyFailedRequests), "Failed Requests")
    }

    func testLabelForItem_settingsProviders() {
        XCTAssertEqual(labelForItem(.settingsProviders), "Manage Providers")
    }

    func testLabelForItem_generationImage() {
        let setId = UUID()
        XCTAssertEqual(labelForItem(.generationImage(setId: setId)), "Image Generation")
    }

    func testLabelForItem_generationVideo() {
        let setId = UUID()
        XCTAssertEqual(labelForItem(.generationVideo(setId: setId)), "Video Generation")
    }

    func testLabelForItem_addProvider() {
        let providerId = UUID()
        XCTAssertEqual(labelForItem(.addProvider(providerId: providerId)), "Add Provider")
    }

    // MARK: - iconForItem Helper Tests

    func testIconForItem_dashboard() {
        XCTAssertEqual(iconForItem(.dashboard), "house")
    }

    func testIconForItem_brandKit() {
        XCTAssertEqual(iconForItem(.brandKit), "briefcase")
    }

    func testIconForItem_agentCanvas() {
        XCTAssertEqual(iconForItem(.agentCanvas), "square.and.pencil")
    }

    func testIconForItem_storyboard() {
        XCTAssertEqual(iconForItem(.storyboard), "movieclapper")
    }

    func testIconForItem_historyImageGallery() {
        XCTAssertEqual(iconForItem(.historyImageGallery), "photo")
    }

    func testIconForItem_historyVideoGallery() {
        XCTAssertEqual(iconForItem(.historyVideoGallery), "film")
    }

    func testIconForItem_settingsProviders() {
        XCTAssertEqual(iconForItem(.settingsProviders), "link")
    }

    // MARK: - subLabelForItem Helper Tests

    func testSubLabelForItem_dashboard() {
        XCTAssertEqual(subLabelForItem(.dashboard), "Your go-to workplace dashboard")
    }

    func testSubLabelForItem_brandKit() {
        XCTAssertEqual(subLabelForItem(.brandKit), "Manage your brand colors and logos")
    }

    func testSubLabelForItem_agentCanvas() {
        XCTAssertEqual(subLabelForItem(.agentCanvas), "Build agents to automate your workflows")
    }

    func testSubLabelForItem_storyboard() {
        XCTAssertEqual(subLabelForItem(.storyboard), "Create multi-scene movies with seamless transitions")
    }

    // MARK: - NavigationManager Tests

    func testNavigationManager_initialState() {
        let manager = NavigationManager()

        XCTAssertNil(manager.selectedNavigationItem)
        XCTAssertNil(manager.detailNavigationItem)
        XCTAssertNil(manager.generateImagePreload)
        XCTAssertNil(manager.extendVideoPreload)
    }

    func testNavigationManager_navigate() {
        let manager = NavigationManager()

        manager.navigate(to: .dashboard)

        XCTAssertEqual(manager.selectedNavigationItem, .dashboard)
    }

    func testNavigationManager_navigate_changeDestination() {
        let manager = NavigationManager()

        manager.navigate(to: .dashboard)
        manager.navigate(to: .agentCanvas)

        XCTAssertEqual(manager.selectedNavigationItem, .agentCanvas)
    }

    func testNavigationManager_navigateToGeneration() {
        let manager = NavigationManager()
        let setId = UUID()

        manager.navigateToGeneration(setId: setId)

        XCTAssertEqual(manager.selectedNavigationItem, .generationImage(setId: setId))
    }

    func testNavigationManager_pushDetail() {
        let manager = NavigationManager()

        manager.pushDetail(.historyImageGallery)

        XCTAssertEqual(manager.detailNavigationItem, .historyImageGallery)
    }

    func testNavigationManager_clearDetailNavigation() {
        let manager = NavigationManager()
        manager.pushDetail(.historyImageGallery)

        manager.clearDetailNavigation()

        XCTAssertNil(manager.detailNavigationItem)
    }

    func testNavigationManager_clearGenerateImagePreload() {
        let manager = NavigationManager()

        manager.clearGenerateImagePreload()

        XCTAssertNil(manager.generateImagePreload)
    }

    func testNavigationManager_clearExtendVideoPreload() {
        let manager = NavigationManager()

        manager.clearExtendVideoPreload()

        XCTAssertNil(manager.extendVideoPreload)
    }

    // MARK: - GenerateImagePreload Tests

    func testGenerateImagePreload_initialization() {
        #if os(macOS)
        let image = NSImage()
        #else
        let image = UIImage()
        #endif

        let preload = GenerateImagePreload(
            image: image,
            colorPalette: ["#FF0000", "#00FF00", "#0000FF"],
            dimensions: "1024x1024",
            prompt: "A beautiful landscape",
            negativePrompt: "blurry, low quality"
        )

        XCTAssertNotNil(preload.image)
        XCTAssertEqual(preload.colorPalette.count, 3)
        XCTAssertEqual(preload.dimensions, "1024x1024")
        XCTAssertEqual(preload.prompt, "A beautiful landscape")
        XCTAssertEqual(preload.negativePrompt, "blurry, low quality")
    }

    func testGenerateImagePreload_nilPrompts() {
        #if os(macOS)
        let image = NSImage()
        #else
        let image = UIImage()
        #endif

        let preload = GenerateImagePreload(
            image: image,
            colorPalette: [],
            dimensions: "512x512",
            prompt: nil,
            negativePrompt: nil
        )

        XCTAssertNil(preload.prompt)
        XCTAssertNil(preload.negativePrompt)
    }

    // MARK: - ExtendVideoPreload Tests

    func testExtendVideoPreload_initialization() {
        let preload = ExtendVideoPreload(
            videoId: "test-video-123",
            colorPalette: ["#FFFFFF", "#000000"],
            dimensions: "1920x1080",
            prompt: "Extend this video",
            negativePrompt: nil,
            generation: nil
        )

        XCTAssertEqual(preload.videoId, "test-video-123")
        XCTAssertEqual(preload.colorPalette.count, 2)
        XCTAssertEqual(preload.dimensions, "1920x1080")
        XCTAssertEqual(preload.prompt, "Extend this video")
        XCTAssertNil(preload.negativePrompt)
        XCTAssertNil(preload.generation)
    }

    func testExtendVideoPreload_conformsToGenerateVideoPreload() {
        let preload: GenerateVideoPreload = ExtendVideoPreload(
            videoId: "test-id",
            colorPalette: [],
            dimensions: "1280x720",
            prompt: nil,
            negativePrompt: nil,
            generation: nil
        )

        XCTAssertEqual(preload.videoId, "test-id")
        XCTAssertEqual(preload.dimensions, "1280x720")
    }
}
