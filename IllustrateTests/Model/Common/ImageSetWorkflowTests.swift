// MARK: - ImageSetWorkflowTests.swift

// Tests for ImageSet helper functions, model Codable, and PinnableHelper sorting.
//
// Tests cover:
// - setTypeForItem(): EnumNavigationItem → EnumSetType mapping
// - labelForSetType/subLabelForSetType/iconForSetType: delegation to EnumSetType
// - ImageSet Codable: encode/decode round-trip, optional field defaults
// - PinnableHelper filteredAndSorted(): project filtering, pin-first sorting,
//   date-based ordering, empty/single/mixed scenarios

import AvgeekLocalizationCore
import XCTest
@testable import Illustrate
@testable import IllustrateProviders

// MARK: - Set Type Mapping Tests

final class SetTypeMappingTests: XCTestCase {
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

    func testSetTypeForItem_ImageGenerate_ReturnsImageGenerate() {
        let result = setTypeForItem(.imageGenerate)
        XCTAssertEqual(result, .IMAGE_GENERATE)
    }

    func testSetTypeForItem_VideoGenerate_ReturnsVideoGenerate() {
        let result = setTypeForItem(.videoGenerate)
        XCTAssertEqual(result, .VIDEO_GENERATE)
    }

    func testSetTypeForItem_Dashboard_DefaultsToImageGenerate() {
        let result = setTypeForItem(.dashboard)
        XCTAssertEqual(result, .IMAGE_GENERATE)
    }

    func testSetTypeForItem_FlowCanvas_DefaultsToImageGenerate() {
        let result = setTypeForItem(.flowCanvas)
        XCTAssertEqual(result, .IMAGE_GENERATE)
    }

    func testLabelForSetType_DelegatesToEnumSetType() {
        for setType in EnumSetType.allCases {
            XCTAssertEqual(labelForSetType(setType), setType.label)
        }
    }

    func testSubLabelForSetType_DelegatesToEnumSetType() {
        for setType in EnumSetType.allCases {
            XCTAssertEqual(subLabelForSetType(setType), setType.subLabel)
        }
    }

    func testIconForSetType_DelegatesToEnumSetType() {
        for setType in EnumSetType.allCases {
            XCTAssertEqual(iconForSetType(setType), setType.icon)
        }
    }
}

// MARK: - ImageSet Codable Tests

final class ImageSetCodableTests: XCTestCase {
    private func makeImageSet(
        prompt: String = "test prompt",
        modelId: String = "model-1",
        dimensions: String = "1024x1024",
        setType: EnumSetType = .IMAGE_GENERATE
    ) -> ImageSet {
        ImageSet(
            prompt: prompt,
            modelId: modelId,
            dimensions: dimensions,
            setType: setType
        )
    }

    func testCodable_RoundTrip_PreservesAllFields() throws {
        let original = makeImageSet(prompt: "a sunset", dimensions: "1920x1080", setType: .VIDEO_GENERATE)
        original.starred = true
        original.negativePrompt = "blur"
        original.searchPrompt = "replace sky"

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let restored = try decoder.decode(ImageSet.self, from: data)

        XCTAssertEqual(restored.id, original.id)
        XCTAssertEqual(restored.projectId, original.projectId)
        XCTAssertEqual(restored.prompt, "a sunset")
        XCTAssertTrue(restored.starred)
        XCTAssertEqual(restored.modelId, "model-1")
        XCTAssertEqual(restored.dimensions, "1920x1080")
        XCTAssertEqual(restored.setType, .VIDEO_GENERATE)
        XCTAssertEqual(restored.negativePrompt, "blur")
        XCTAssertEqual(restored.searchPrompt, "replace sky")
    }

    func testCodable_NilOptionals_DecodesCorrectly() throws {
        let original = makeImageSet()
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let restored = try decoder.decode(ImageSet.self, from: data)

        XCTAssertNil(restored.negativePrompt)
        XCTAssertNil(restored.searchPrompt)
    }

    func testInit_DefaultValues() {
        let imageSet = makeImageSet()
        XCTAssertEqual(imageSet.style, "Natural")
        XCTAssertEqual(imageSet.variant, "Normal")
        XCTAssertFalse(imageSet.starred)
        XCTAssertNil(imageSet.negativePrompt)
        XCTAssertNil(imageSet.searchPrompt)
    }

    func testInit_CustomSetType_Preserved() {
        let videoSet = makeImageSet(setType: .VIDEO_GENERATE)
        XCTAssertEqual(videoSet.setType, .VIDEO_GENERATE)
    }
}

// MARK: - PinnableHelper Tests

/// Test double conforming to Pinnable for testing filteredAndSorted().
private class TestPinnableItem: Pinnable {
    var id: UUID
    var name: String
    var isPinned: Bool
    var createdAt: Date
    var projectId: UUID

    init(
        id: UUID = UUID(),
        name: String = "Item",
        isPinned: Bool = false,
        createdAt: Date = Date(),
        projectId: UUID
    ) {
        self.id = id
        self.name = name
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.projectId = projectId
    }
}

final class PinnableHelperTests: XCTestCase {
    private let projectA = UUID()
    private let projectB = UUID()

    private func makeItem(
        name: String = "Item",
        isPinned: Bool = false,
        daysAgo: Int = 0,
        project: UUID? = nil
    ) -> TestPinnableItem {
        TestPinnableItem(
            name: name,
            isPinned: isPinned,
            createdAt: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            projectId: project ?? projectA
        )
    }

    // MARK: - Empty & Single

    func testFilteredAndSorted_EmptyArray_ReturnsEmpty() {
        let result = filteredAndSorted([TestPinnableItem](), for: projectA)
        XCTAssertTrue(result.isEmpty)
    }

    func testFilteredAndSorted_SingleMatchingItem_ReturnsThatItem() {
        let item = makeItem(name: "Only", project: projectA)
        let result = filteredAndSorted([item], for: projectA)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "Only")
    }

    // MARK: - Project Filtering

    func testFilteredAndSorted_DifferentProject_FiltersOut() {
        let itemA = makeItem(name: "A", project: projectA)
        let itemB = makeItem(name: "B", project: projectB)
        let result = filteredAndSorted([itemA, itemB], for: projectA)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "A")
    }

    func testFilteredAndSorted_NoMatchingProject_ReturnsEmpty() {
        let items = [
            makeItem(name: "X", project: projectB),
            makeItem(name: "Y", project: projectB),
        ]
        let result = filteredAndSorted(items, for: projectA)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Pin Ordering

    func testFilteredAndSorted_PinnedItemsAppearFirst() {
        let unpinned = makeItem(name: "Unpinned", isPinned: false, daysAgo: 0, project: projectA)
        let pinned = makeItem(name: "Pinned", isPinned: true, daysAgo: 5, project: projectA)
        let result = filteredAndSorted([unpinned, pinned], for: projectA)
        XCTAssertEqual(result.map(\.name), ["Pinned", "Unpinned"])
    }

    func testFilteredAndSorted_MultiplePinned_SortedByDateNewestFirst() {
        let olderPinned = makeItem(name: "OlderPinned", isPinned: true, daysAgo: 10, project: projectA)
        let newerPinned = makeItem(name: "NewerPinned", isPinned: true, daysAgo: 1, project: projectA)
        let result = filteredAndSorted([olderPinned, newerPinned], for: projectA)
        XCTAssertEqual(result.map(\.name), ["NewerPinned", "OlderPinned"])
    }

    func testFilteredAndSorted_MultipleUnpinned_SortedByDateNewestFirst() {
        let older = makeItem(name: "Older", isPinned: false, daysAgo: 10, project: projectA)
        let newer = makeItem(name: "Newer", isPinned: false, daysAgo: 1, project: projectA)
        let result = filteredAndSorted([older, newer], for: projectA)
        XCTAssertEqual(result.map(\.name), ["Newer", "Older"])
    }

    // MARK: - Mixed Pinned/Unpinned

    func testFilteredAndSorted_Mixed_PinnedFirstThenUnpinnedByDate() {
        let unpinnedNew = makeItem(name: "UnpinnedNew", isPinned: false, daysAgo: 0, project: projectA)
        let pinnedOld = makeItem(name: "PinnedOld", isPinned: true, daysAgo: 10, project: projectA)
        let pinnedNew = makeItem(name: "PinnedNew", isPinned: true, daysAgo: 1, project: projectA)
        let unpinnedOld = makeItem(name: "UnpinnedOld", isPinned: false, daysAgo: 5, project: projectA)

        let result = filteredAndSorted([unpinnedNew, pinnedOld, pinnedNew, unpinnedOld], for: projectA)

        // Pinned group first (newest first), then unpinned group (newest first)
        XCTAssertEqual(result.map(\.name), ["PinnedNew", "PinnedOld", "UnpinnedNew", "UnpinnedOld"])
    }

    // MARK: - Filtering + Sorting Combined

    func testFilteredAndSorted_CombinedFilterAndSort() {
        let items = [
            makeItem(name: "B-Unpinned", isPinned: false, daysAgo: 0, project: projectB),
            makeItem(name: "A-Pinned", isPinned: true, daysAgo: 5, project: projectA),
            makeItem(name: "A-Unpinned", isPinned: false, daysAgo: 1, project: projectA),
            makeItem(name: "B-Pinned", isPinned: true, daysAgo: 0, project: projectB),
        ]

        let result = filteredAndSorted(items, for: projectA)
        XCTAssertEqual(result.count, 2, "Should only include projectA items")
        XCTAssertEqual(result.map(\.name), ["A-Pinned", "A-Unpinned"])
    }

    func testFilteredAndSorted_AllPinned_SortedByDate() {
        let items = [
            makeItem(name: "Oldest", isPinned: true, daysAgo: 30, project: projectA),
            makeItem(name: "Newest", isPinned: true, daysAgo: 0, project: projectA),
            makeItem(name: "Middle", isPinned: true, daysAgo: 15, project: projectA),
        ]
        let result = filteredAndSorted(items, for: projectA)
        XCTAssertEqual(result.map(\.name), ["Newest", "Middle", "Oldest"])
    }

    func testFilteredAndSorted_AllUnpinned_SortedByDate() {
        let items = [
            makeItem(name: "Oldest", isPinned: false, daysAgo: 30, project: projectA),
            makeItem(name: "Newest", isPinned: false, daysAgo: 0, project: projectA),
            makeItem(name: "Middle", isPinned: false, daysAgo: 15, project: projectA),
        ]
        let result = filteredAndSorted(items, for: projectA)
        XCTAssertEqual(result.map(\.name), ["Newest", "Middle", "Oldest"])
    }
}
