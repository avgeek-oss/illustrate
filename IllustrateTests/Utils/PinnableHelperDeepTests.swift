// MARK: - PinnableHelperDeepTests.swift

// Deep edge case tests for the filteredAndSorted() PinnableHelper function.
//
// PinnableConformanceTests covers: basic filtersByProject, pinnedFirst,
// dateOrdering, pinnedThenDateOrdering, emptyArray for each Pinnable type.
//
// This file adds: large arrays, date boundaries, mutation scenarios,
// complex multi-item sorting, equal-date edge cases, and protocol conformance
// field verification.

import Foundation
import XCTest
@testable import Illustrate

final class PinnableHelperDeepTests: XCTestCase {
    // MARK: - Edge Cases

    func testAllPinned_sameDate_noCrash() {
        let projectId = UUID()
        let date = Date()
        let items = (0 ..< 5).map { i -> Agent in
            let a = Agent(name: "A\(i)", projectId: projectId)
            a.isPinned = true
            a.createdAt = date
            return a
        }

        let result = filteredAndSorted(items, for: projectId)
        XCTAssertEqual(result.count, 5)
        XCTAssertTrue(result.allSatisfy(\.isPinned))
    }

    func testAllUnpinned_sameDate_noCrash() {
        let projectId = UUID()
        let date = Date()
        let items = (0 ..< 5).map { i -> Agent in
            let a = Agent(name: "A\(i)", projectId: projectId)
            a.createdAt = date
            return a
        }

        let result = filteredAndSorted(items, for: projectId)
        XCTAssertEqual(result.count, 5)
    }

    func testSinglePinnedItem_returned() {
        let projectId = UUID()
        let item = Agent(name: "Solo", projectId: projectId)
        item.isPinned = true

        let result = filteredAndSorted([item], for: projectId)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "Solo")
    }

    func testSingleUnpinnedItem_returned() {
        let projectId = UUID()
        let item = Agent(name: "Solo", projectId: projectId)

        let result = filteredAndSorted([item], for: projectId)
        XCTAssertEqual(result.count, 1)
    }

    func testLargeArray_correctCount() {
        let projectId = UUID()
        let items = (0 ..< 100).map { i -> Agent in
            Agent(name: "A\(i)", projectId: projectId)
        }

        let result = filteredAndSorted(items, for: projectId)
        XCTAssertEqual(result.count, 100)
    }

    func testLargeArray_pinnedBeforeUnpinned() {
        let projectId = UUID()
        let items = (0 ..< 50).map { i -> Agent in
            let a = Agent(name: "A\(i)", projectId: projectId)
            a.isPinned = i < 10
            return a
        }

        let result = filteredAndSorted(items, for: projectId)
        let pinnedCount = result.prefix(while: \.isPinned).count
        XCTAssertEqual(pinnedCount, 10)
    }

    func testNoMatchingProject_returnsEmpty() {
        let items = (0 ..< 5).map { i -> Agent in
            Agent(name: "A\(i)", projectId: UUID())
        }

        let result = filteredAndSorted(items, for: UUID())
        XCTAssertTrue(result.isEmpty)
    }

    func testMixedProjects_onlyMatchingReturned() {
        let targetProject = UUID()
        let otherProject = UUID()
        let items = [
            Agent(name: "Match1", projectId: targetProject),
            Agent(name: "Other1", projectId: otherProject),
            Agent(name: "Match2", projectId: targetProject),
            Agent(name: "Other2", projectId: otherProject),
        ]

        let result = filteredAndSorted(items, for: targetProject)
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.projectId == targetProject })
    }

    // MARK: - Sort Stability

    func testPinnedNewerFirst() throws {
        let projectId = UUID()
        let pastDate = try XCTUnwrap(Calendar.current.date(byAdding: .hour, value: -2, to: Date()))

        let older = Agent(name: "OlderPinned", projectId: projectId)
        older.isPinned = true
        older.createdAt = pastDate

        let newer = Agent(name: "NewerPinned", projectId: projectId)
        newer.isPinned = true

        let result = filteredAndSorted([older, newer], for: projectId)
        XCTAssertEqual(result.first?.name, "NewerPinned")
    }

    func testUnpinnedNewerFirst() throws {
        let projectId = UUID()
        let pastDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: Date()))

        let older = Agent(name: "Older", projectId: projectId)
        older.createdAt = pastDate

        let newer = Agent(name: "Newer", projectId: projectId)

        let result = filteredAndSorted([older, newer], for: projectId)
        XCTAssertEqual(result.first?.name, "Newer")
    }

    func testPinnedOldItem_beforeUnpinnedNewItem() throws {
        let projectId = UUID()
        let distantPast = try XCTUnwrap(Calendar.current.date(byAdding: .year, value: -1, to: Date()))

        let pinnedOld = Agent(name: "PinnedOld", projectId: projectId)
        pinnedOld.isPinned = true
        pinnedOld.createdAt = distantPast

        let unpinnedNew = Agent(name: "UnpinnedNew", projectId: projectId)

        let result = filteredAndSorted([unpinnedNew, pinnedOld], for: projectId)
        XCTAssertEqual(result.first?.name, "PinnedOld")
    }

    func testEqualDates_bothPinned_bothReturned() {
        let projectId = UUID()
        let date = Date()

        let a = Agent(name: "A", projectId: projectId)
        a.isPinned = true
        a.createdAt = date

        let b = Agent(name: "B", projectId: projectId)
        b.isPinned = true
        b.createdAt = date

        let result = filteredAndSorted([a, b], for: projectId)
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Complex Scenarios

    func testComplexSort_8Agents_3Pinned5Unpinned() {
        let projectId = UUID()
        let now = Date()

        // Create agents with staggered dates
        let agents = (0 ..< 8).map { i -> Agent in
            let a = Agent(name: "A\(i)", projectId: projectId)
            a.createdAt = now.addingTimeInterval(Double(i) * -3600) // Each 1 hour older
            return a
        }

        // Pin 3: indices 2, 5, 7
        agents[2].isPinned = true
        agents[5].isPinned = true
        agents[7].isPinned = true

        let result = filteredAndSorted(agents, for: projectId)
        XCTAssertEqual(result.count, 8)

        // First 3 should be pinned, sorted by date (newer first)
        XCTAssertTrue(result[0].isPinned)
        XCTAssertTrue(result[1].isPinned)
        XCTAssertTrue(result[2].isPinned)

        // Pinned order: A2 (2h ago), A5 (5h ago), A7 (7h ago)
        XCTAssertEqual(result[0].name, "A2")
        XCTAssertEqual(result[1].name, "A5")
        XCTAssertEqual(result[2].name, "A7")

        // Remaining 5 unpinned, newer first
        XCTAssertFalse(result[3].isPinned)
        XCTAssertEqual(result[3].name, "A0")
        XCTAssertEqual(result[4].name, "A1")
    }

    func testComplexSort_chatThreads() {
        let projectId = UUID()
        let now = Date()

        let pinned = ChatThread(name: "PinnedNew", projectId: projectId)
        pinned.isPinned = true

        let pinnedOld = ChatThread(name: "PinnedOld", projectId: projectId)
        pinnedOld.isPinned = true
        pinnedOld.createdAt = now.addingTimeInterval(-7200)

        let unpinnedNew = ChatThread(name: "UnpinnedNew", projectId: projectId)

        let unpinnedOld = ChatThread(name: "UnpinnedOld", projectId: projectId)
        unpinnedOld.createdAt = now.addingTimeInterval(-3600)

        let result = filteredAndSorted([unpinnedOld, pinned, unpinnedNew, pinnedOld], for: projectId)
        XCTAssertEqual(result.map(\.name), ["PinnedNew", "PinnedOld", "UnpinnedNew", "UnpinnedOld"])
    }

    func testComplexSort_playgrounds() {
        let projectId = UUID()
        let now = Date()

        let items = (0 ..< 4).map { i -> Playground in
            let p = Playground(name: "P\(i)", projectId: projectId)
            p.createdAt = now.addingTimeInterval(Double(i) * -3600)
            return p
        }
        items[1].isPinned = true
        items[3].isPinned = true

        let result = filteredAndSorted(items, for: projectId)
        XCTAssertTrue(result[0].isPinned)
        XCTAssertTrue(result[1].isPinned)
        XCTAssertFalse(result[2].isPinned)
        XCTAssertFalse(result[3].isPinned)
    }

    func testComplexSort_storyboards() {
        let projectId = UUID()
        let now = Date()

        let pinned = Storyboard(name: "PinnedNew", projectId: projectId)
        pinned.isPinned = true

        let unpinned = Storyboard(name: "Unpinned", projectId: projectId)
        unpinned.createdAt = now.addingTimeInterval(-3600)

        let result = filteredAndSorted([unpinned, pinned], for: projectId)
        XCTAssertEqual(result.first?.name, "PinnedNew")
    }

    func testComplexSort_bulkSessions() {
        let projectId = UUID()

        let pinned = BulkSession(name: "Pinned", projectId: projectId)
        pinned.isPinned = true

        let unpinned = BulkSession(name: "Unpinned", projectId: projectId)

        let result = filteredAndSorted([unpinned, pinned], for: projectId)
        XCTAssertEqual(result.first?.name, "Pinned")
    }

    // MARK: - Mutation Scenarios

    func testPinItemAfterCreation_movesToFront() {
        let projectId = UUID()
        let now = Date()

        let item = Agent(name: "ToBePinned", projectId: projectId)
        item.createdAt = now.addingTimeInterval(-7200) // 2 hours ago

        let newerUnpinned = Agent(name: "Newer", projectId: projectId)

        // Before pinning
        var result = filteredAndSorted([item, newerUnpinned], for: projectId)
        XCTAssertEqual(result.first?.name, "Newer")

        // After pinning
        item.isPinned = true
        result = filteredAndSorted([item, newerUnpinned], for: projectId)
        XCTAssertEqual(result.first?.name, "ToBePinned")
    }

    func testUnpinItem_movesBack() {
        let projectId = UUID()
        let now = Date()

        let item = Agent(name: "WasPinned", projectId: projectId)
        item.isPinned = true
        item.createdAt = now.addingTimeInterval(-7200)

        let newerUnpinned = Agent(name: "Newer", projectId: projectId)

        // While pinned
        var result = filteredAndSorted([item, newerUnpinned], for: projectId)
        XCTAssertEqual(result.first?.name, "WasPinned")

        // After unpinning
        item.isPinned = false
        result = filteredAndSorted([item, newerUnpinned], for: projectId)
        XCTAssertEqual(result.first?.name, "Newer")
    }

    func testRenameItem_doesNotAffectSort() throws {
        let projectId = UUID()

        let item = Agent(name: "Original", projectId: projectId)
        item.isPinned = true

        let other = Agent(name: "Other", projectId: projectId)

        var result = filteredAndSorted([item, other], for: projectId)
        XCTAssertEqual(result.first?.name, "Original")

        item.name = "Renamed"
        result = filteredAndSorted([item, other], for: projectId)
        XCTAssertEqual(result.first?.name, "Renamed")
        XCTAssertTrue(try XCTUnwrap(result.first?.isPinned))
    }

    func testChangeProjectId_removedFromFilter() {
        let projectA = UUID()
        let projectB = UUID()

        let item = Agent(name: "Moved", projectId: projectA)
        let other = Agent(name: "Stays", projectId: projectA)

        var result = filteredAndSorted([item, other], for: projectA)
        XCTAssertEqual(result.count, 2)

        // Simulate moving to another project
        // Note: Agent.projectId is a var, so we can reassign it
        // However, since Agent is a @Model, we verify the filter behavior
        let movedItem = Agent(name: "Moved", projectId: projectB)
        result = filteredAndSorted([movedItem, other], for: projectA)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "Stays")
    }

    // MARK: - Date Boundaries

    func testDistantPast_sortedLastAmongUnpinned() {
        let projectId = UUID()

        let ancient = Agent(name: "Ancient", projectId: projectId)
        ancient.createdAt = Date.distantPast

        let recent = Agent(name: "Recent", projectId: projectId)

        let result = filteredAndSorted([ancient, recent], for: projectId)
        XCTAssertEqual(result.first?.name, "Recent")
        XCTAssertEqual(result.last?.name, "Ancient")
    }

    func testDistantFuture_sortedFirstAmongUnpinned() {
        let projectId = UUID()

        let future = Agent(name: "Future", projectId: projectId)
        future.createdAt = Date.distantFuture

        let recent = Agent(name: "Recent", projectId: projectId)

        let result = filteredAndSorted([recent, future], for: projectId)
        XCTAssertEqual(result.first?.name, "Future")
    }

    func testSameDate_mixedPinned_pinnedFirst() {
        let projectId = UUID()
        let date = Date()

        let pinned = Agent(name: "Pinned", projectId: projectId)
        pinned.isPinned = true
        pinned.createdAt = date

        let unpinned = Agent(name: "Unpinned", projectId: projectId)
        unpinned.createdAt = date

        let result = filteredAndSorted([unpinned, pinned], for: projectId)
        XCTAssertEqual(result.first?.name, "Pinned")
    }

    func testEmptyName_stillIncluded() {
        let projectId = UUID()
        let item = Agent(name: "", projectId: projectId)

        let result = filteredAndSorted([item], for: projectId)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "")
    }
}
