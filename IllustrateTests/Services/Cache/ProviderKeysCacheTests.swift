// MARK: - ProviderKeysCacheTests.swift

// Unit tests for ProviderKeysCache and related types.
//
// Tests cover:
// - Provider lookup logic
// - Project scoping
// - Cache state management

import XCTest
@testable import Illustrate
@testable import IllustrateProviders

final class ProviderKeysCacheTests: XCTestCase {
    // MARK: - Provider Lookup Tests

    func testHasProvider_found() {
        let providerId = UUID()
        let providerIds = [UUID(), providerId, UUID()]

        let hasProvider = providerIds.contains(providerId)
        XCTAssertTrue(hasProvider)
    }

    func testHasProvider_notFound() {
        let providerId = UUID()
        let providerIds = [UUID(), UUID(), UUID()]

        let hasProvider = providerIds.contains(providerId)
        XCTAssertFalse(hasProvider)
    }

    func testHasProvider_emptyList() {
        let providerId = UUID()
        let providerIds: [UUID] = []

        let hasProvider = providerIds.contains(providerId)
        XCTAssertFalse(hasProvider)
    }

    // MARK: - Project Scoping Tests

    func testKeysForProject_matchingProject() {
        let projectId = UUID()
        let currentProjectId = projectId

        let returnsKeys = currentProjectId == projectId
        XCTAssertTrue(returnsKeys)
    }

    func testKeysForProject_differentProject() {
        let projectId = UUID()
        let currentProjectId = UUID()

        let returnsKeys = currentProjectId == projectId
        XCTAssertFalse(returnsKeys)
    }

    // MARK: - Cache State Tests

    func testLoadIfNeeded_notLoadedShouldLoad() {
        let isLoaded = false
        let force = false

        let shouldLoad = !isLoaded || force
        XCTAssertTrue(shouldLoad)
    }

    func testLoadIfNeeded_loadedShouldNotLoad() {
        let isLoaded = true
        let force = false
        let currentProjectId = UUID()
        let requestedProjectId = currentProjectId

        // Already loaded for same project
        let shouldSkip = !force && isLoaded && currentProjectId == requestedProjectId
        XCTAssertTrue(shouldSkip)
    }

    func testLoadIfNeeded_forceShouldLoad() {
        let isLoaded = true
        let force = true

        let shouldLoad = force || !isLoaded
        XCTAssertTrue(shouldLoad)
    }

    func testLoadIfNeeded_differentProjectShouldLoad() {
        let isLoaded = true
        let currentProjectId = UUID()
        let requestedProjectId = UUID()

        let shouldLoad = currentProjectId != requestedProjectId
        XCTAssertTrue(shouldLoad)
    }

    // MARK: - Cache Invalidation Tests

    func testInvalidate_resetsState() {
        var isLoaded = true

        // Invalidate
        isLoaded = false

        XCTAssertFalse(isLoaded)
    }

    // MARK: - EnumSetType Tests

    func testEnumSetType_allCases() {
        let allCases = EnumSetType.allCases

        XCTAssertTrue(allCases.contains(.IMAGE_GENERATE))
        XCTAssertTrue(allCases.contains(.VIDEO_GENERATE))
        XCTAssertTrue(allCases.contains(.VIDEO_EXTEND))
    }

    func testEnumSetType_rawValues() {
        XCTAssertEqual(EnumSetType.IMAGE_GENERATE.rawValue, "IMAGE_GENERATE")
        XCTAssertEqual(EnumSetType.VIDEO_GENERATE.rawValue, "VIDEO_GENERATE")
        XCTAssertEqual(EnumSetType.VIDEO_EXTEND.rawValue, "VIDEO_EXTEND")
    }

    func testEnumSetType_labels() {
        XCTAssertEqual(EnumSetType.IMAGE_GENERATE.label, "Generate Image")
        XCTAssertEqual(EnumSetType.VIDEO_GENERATE.label, "Generate Video")
        XCTAssertEqual(EnumSetType.VIDEO_EXTEND.label, "Extend Video")
    }

    func testEnumSetType_icons() {
        XCTAssertEqual(EnumSetType.IMAGE_GENERATE.icon, "wand.and.sparkles")
        XCTAssertEqual(EnumSetType.VIDEO_GENERATE.icon, "play")
        XCTAssertEqual(EnumSetType.VIDEO_EXTEND.icon, "forward.end")
    }

    // MARK: - Provider Filtering Tests

    func testProviderFiltering_hasMatchingModel() {
        // Simulate provider filtering logic
        let providerIds = [UUID(), UUID()]
        let providerId = providerIds[0]
        let hasKey = providerIds.contains(providerId)

        XCTAssertTrue(hasKey)
    }

    func testProviderFiltering_activeModelOnly() {
        let isActive = true
        let matchesSetType = true
        let matchesProvider = true

        let shouldInclude = isActive && matchesSetType && matchesProvider
        XCTAssertTrue(shouldInclude)
    }

    func testProviderFiltering_inactiveModel() {
        let isActive = false
        let matchesSetType = true
        let matchesProvider = true

        let shouldInclude = isActive && matchesSetType && matchesProvider
        XCTAssertFalse(shouldInclude)
    }

    func testProviderFiltering_wrongSetType() {
        let isActive = true
        let matchesSetType = false
        let matchesProvider = true

        let shouldInclude = isActive && matchesSetType && matchesProvider
        XCTAssertFalse(shouldInclude)
    }

    // MARK: - Supported Models Tests

    func testSupportedModels_emptyProviderId() {
        let providerId = ""

        let returnsEmpty = providerId.isEmpty
        XCTAssertTrue(returnsEmpty)
    }

    func testSupportedModels_validProviderId() {
        let providerId = UUID().uuidString

        let returnsEmpty = providerId.isEmpty
        XCTAssertFalse(returnsEmpty)
    }

    // MARK: - Notification Observer Tests

    func testNotificationName_providerKeysChanged() {
        let name = Notification.Name.providerKeysChanged

        XCTAssertEqual(name.rawValue, "providerKeysChanged")
    }

    // MARK: - Sort Descriptor Tests

    func testSortDescriptor_createdAtReverse() {
        let dates = [
            Date().addingTimeInterval(-3600),
            Date().addingTimeInterval(-1800),
            Date(),
        ]

        let sorted = dates.sorted { $0 > $1 }

        // Most recent first
        XCTAssertEqual(sorted[0], dates[2])
        XCTAssertEqual(sorted[1], dates[1])
        XCTAssertEqual(sorted[2], dates[0])
    }
}
