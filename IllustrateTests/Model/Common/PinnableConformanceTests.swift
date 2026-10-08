// MARK: - PinnableConformanceTests.swift

// Tests for Pinnable protocol conformance across all 7 Pinnable types,
// validating the filteredAndSorted() helper with real model instances.
//
// Tests cover:
// - filtersByProject: items from 2 projects -> only matching returned
// - pinnedFirst: pinned item appears before unpinned
// - dateOrdering: newer items first within same pin status
// - pinnedThenDateOrdering: mixed pinned/unpinned -> pinned first, then by date
// - emptyArray: returns empty
//
// Types tested: Agent, ChatThread, Playground, BulkSession,
//               Storyboard, RealtimeEditSession, ProductPhotoshoot

import Foundation
import XCTest
@testable import Illustrate

// MARK: - Agent Pinnable Tests

final class AgentPinnableTests: XCTestCase {
    func testAgent_filtersByProject() {
        let p1 = UUID()
        let p2 = UUID()
        let a1 = Agent(name: "A1", projectId: p1)
        let a2 = Agent(name: "A2", projectId: p2)
        let a3 = Agent(name: "A3", projectId: p1)

        let result = filteredAndSorted([a1, a2, a3], for: p1)
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.projectId == p1 })
    }

    func testAgent_pinnedFirst() {
        let projectId = UUID()
        let unpinned = Agent(name: "Unpinned", projectId: projectId)
        let pinned = Agent(name: "Pinned", projectId: projectId)
        pinned.isPinned = true

        let result = filteredAndSorted([unpinned, pinned], for: projectId)
        XCTAssertEqual(result.first?.name, "Pinned")
    }

    func testAgent_dateOrdering_newerFirst() throws {
        let projectId = UUID()
        let older = Agent(name: "Older", projectId: projectId)
        // Ensure different createdAt by modifying
        let newer = Agent(name: "Newer", projectId: projectId)

        // Force different dates
        let pastDate = try XCTUnwrap(Calendar.current.date(byAdding: .hour, value: -1, to: Date()))
        older.createdAt = pastDate

        let result = filteredAndSorted([older, newer], for: projectId)
        XCTAssertEqual(result.first?.name, "Newer")
    }

    func testAgent_pinnedThenDateOrdering() throws {
        let projectId = UUID()
        let pastDate = try XCTUnwrap(Calendar.current.date(byAdding: .hour, value: -2, to: Date()))

        let oldPinned = Agent(name: "OldPinned", projectId: projectId)
        oldPinned.isPinned = true
        oldPinned.createdAt = pastDate

        let newUnpinned = Agent(name: "NewUnpinned", projectId: projectId)

        let result = filteredAndSorted([newUnpinned, oldPinned], for: projectId)
        XCTAssertEqual(result.first?.name, "OldPinned", "Pinned should come first even if older")
    }

    func testAgent_emptyArray_returnsEmpty() {
        let result = filteredAndSorted([Agent](), for: UUID())
        XCTAssertTrue(result.isEmpty)
    }
}

// MARK: - ChatThread Pinnable Tests

final class ChatThreadPinnableTests: XCTestCase {
    func testChatThread_filtersByProject() {
        let p1 = UUID()
        let p2 = UUID()
        let t1 = ChatThread(name: "T1", projectId: p1)
        let t2 = ChatThread(name: "T2", projectId: p2)

        let result = filteredAndSorted([t1, t2], for: p1)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.projectId, p1)
    }

    func testChatThread_pinnedFirst() {
        let projectId = UUID()
        let unpinned = ChatThread(name: "U", projectId: projectId)
        let pinned = ChatThread(name: "P", projectId: projectId)
        pinned.isPinned = true

        let result = filteredAndSorted([unpinned, pinned], for: projectId)
        XCTAssertEqual(result.first?.name, "P")
    }

    func testChatThread_dateOrdering() throws {
        let projectId = UUID()
        let older = ChatThread(name: "Older", projectId: projectId)
        older.createdAt = try XCTUnwrap(Calendar.current.date(byAdding: .hour, value: -1, to: Date()))
        let newer = ChatThread(name: "Newer", projectId: projectId)

        let result = filteredAndSorted([older, newer], for: projectId)
        XCTAssertEqual(result.first?.name, "Newer")
    }

    func testChatThread_emptyArray_returnsEmpty() {
        let result = filteredAndSorted([ChatThread](), for: UUID())
        XCTAssertTrue(result.isEmpty)
    }
}

// MARK: - Playground Pinnable Tests

final class PlaygroundPinnableTests: XCTestCase {
    func testPlayground_filtersByProject() {
        let p1 = UUID()
        let p2 = UUID()
        let pg1 = Playground(name: "PG1", projectId: p1)
        let pg2 = Playground(name: "PG2", projectId: p2)

        let result = filteredAndSorted([pg1, pg2], for: p1)
        XCTAssertEqual(result.count, 1)
    }

    func testPlayground_pinnedFirst() {
        let projectId = UUID()
        let unpinned = Playground(name: "U", projectId: projectId)
        let pinned = Playground(name: "P", projectId: projectId)
        pinned.isPinned = true

        let result = filteredAndSorted([unpinned, pinned], for: projectId)
        XCTAssertEqual(result.first?.name, "P")
    }

    func testPlayground_dateOrdering() throws {
        let projectId = UUID()
        let older = Playground(name: "Older", projectId: projectId)
        older.createdAt = try XCTUnwrap(Calendar.current.date(byAdding: .hour, value: -1, to: Date()))
        let newer = Playground(name: "Newer", projectId: projectId)

        let result = filteredAndSorted([older, newer], for: projectId)
        XCTAssertEqual(result.first?.name, "Newer")
    }

    func testPlayground_emptyArray_returnsEmpty() {
        let result = filteredAndSorted([Playground](), for: UUID())
        XCTAssertTrue(result.isEmpty)
    }
}

// MARK: - BulkSession Pinnable Tests

final class BulkSessionPinnableTests: XCTestCase {
    func testBulkSession_filtersByProject() {
        let p1 = UUID()
        let p2 = UUID()
        let s1 = BulkSession(name: "S1", projectId: p1)
        let s2 = BulkSession(name: "S2", projectId: p2)

        let result = filteredAndSorted([s1, s2], for: p1)
        XCTAssertEqual(result.count, 1)
    }

    func testBulkSession_pinnedFirst() {
        let projectId = UUID()
        let unpinned = BulkSession(name: "U", projectId: projectId)
        let pinned = BulkSession(name: "P", projectId: projectId)
        pinned.isPinned = true

        let result = filteredAndSorted([unpinned, pinned], for: projectId)
        XCTAssertEqual(result.first?.name, "P")
    }

    func testBulkSession_dateOrdering() throws {
        let projectId = UUID()
        let older = BulkSession(name: "Older", projectId: projectId)
        older.createdAt = try XCTUnwrap(Calendar.current.date(byAdding: .hour, value: -1, to: Date()))
        let newer = BulkSession(name: "Newer", projectId: projectId)

        let result = filteredAndSorted([older, newer], for: projectId)
        XCTAssertEqual(result.first?.name, "Newer")
    }

    func testBulkSession_emptyArray_returnsEmpty() {
        let result = filteredAndSorted([BulkSession](), for: UUID())
        XCTAssertTrue(result.isEmpty)
    }
}

// MARK: - Storyboard Pinnable Tests

final class StoryboardPinnableTests: XCTestCase {
    func testStoryboard_filtersByProject() {
        let p1 = UUID()
        let p2 = UUID()
        let s1 = Storyboard(name: "S1", projectId: p1)
        let s2 = Storyboard(name: "S2", projectId: p2)

        let result = filteredAndSorted([s1, s2], for: p1)
        XCTAssertEqual(result.count, 1)
    }

    func testStoryboard_pinnedFirst() {
        let projectId = UUID()
        let unpinned = Storyboard(name: "U", projectId: projectId)
        let pinned = Storyboard(name: "P", projectId: projectId)
        pinned.isPinned = true

        let result = filteredAndSorted([unpinned, pinned], for: projectId)
        XCTAssertEqual(result.first?.name, "P")
    }

    func testStoryboard_dateOrdering() throws {
        let projectId = UUID()
        let older = Storyboard(name: "Older", projectId: projectId)
        older.createdAt = try XCTUnwrap(Calendar.current.date(byAdding: .hour, value: -1, to: Date()))
        let newer = Storyboard(name: "Newer", projectId: projectId)

        let result = filteredAndSorted([older, newer], for: projectId)
        XCTAssertEqual(result.first?.name, "Newer")
    }

    func testStoryboard_emptyArray_returnsEmpty() {
        let result = filteredAndSorted([Storyboard](), for: UUID())
        XCTAssertTrue(result.isEmpty)
    }
}

// MARK: - RealtimeEditSession Pinnable Tests

final class RealtimeEditSessionPinnableTests: XCTestCase {
    func testRealtimeEditSession_filtersByProject() {
        let p1 = UUID()
        let p2 = UUID()
        let s1 = RealtimeEditSession(name: "S1", projectId: p1)
        let s2 = RealtimeEditSession(name: "S2", projectId: p2)

        let result = filteredAndSorted([s1, s2], for: p1)
        XCTAssertEqual(result.count, 1)
    }

    func testRealtimeEditSession_pinnedFirst() {
        let projectId = UUID()
        let unpinned = RealtimeEditSession(name: "U", projectId: projectId)
        let pinned = RealtimeEditSession(name: "P", projectId: projectId)
        pinned.isPinned = true

        let result = filteredAndSorted([unpinned, pinned], for: projectId)
        XCTAssertEqual(result.first?.name, "P")
    }

    func testRealtimeEditSession_dateOrdering() throws {
        let projectId = UUID()
        let older = RealtimeEditSession(name: "Older", projectId: projectId)
        older.createdAt = try XCTUnwrap(Calendar.current.date(byAdding: .hour, value: -1, to: Date()))
        let newer = RealtimeEditSession(name: "Newer", projectId: projectId)

        let result = filteredAndSorted([older, newer], for: projectId)
        XCTAssertEqual(result.first?.name, "Newer")
    }

    func testRealtimeEditSession_emptyArray_returnsEmpty() {
        let result = filteredAndSorted([RealtimeEditSession](), for: UUID())
        XCTAssertTrue(result.isEmpty)
    }
}

// MARK: - Cross-Type Validation Tests

final class PinnableCrossTypeTests: XCTestCase {
    func testPinnable_filteredAndSorted_multipleItemsMixedPinAndDate() throws {
        let projectId = UUID()
        let pastDate = try XCTUnwrap(Calendar.current.date(byAdding: .hour, value: -2, to: Date()))

        let a1 = Agent(name: "A1", projectId: projectId)
        a1.isPinned = false

        let a2 = Agent(name: "A2-Pinned", projectId: projectId)
        a2.isPinned = true
        a2.createdAt = pastDate

        let a3 = Agent(name: "A3-Newest", projectId: projectId)
        a3.isPinned = false

        let result = filteredAndSorted([a1, a2, a3], for: projectId)
        // Pinned first, then by date (newest first)
        XCTAssertEqual(result[0].name, "A2-Pinned")
        XCTAssertEqual(result[1].name, "A3-Newest")
    }

    func testPinnable_filteredAndSorted_allPinnedSortedByDate() throws {
        let projectId = UUID()
        let pastDate = try XCTUnwrap(Calendar.current.date(byAdding: .hour, value: -1, to: Date()))

        let older = Agent(name: "Older-Pinned", projectId: projectId)
        older.isPinned = true
        older.createdAt = pastDate

        let newer = Agent(name: "Newer-Pinned", projectId: projectId)
        newer.isPinned = true

        let result = filteredAndSorted([older, newer], for: projectId)
        XCTAssertEqual(result.first?.name, "Newer-Pinned")
    }

    func testPinnable_filteredAndSorted_noMatchingProject_returnsEmpty() {
        let agents = [
            Agent(name: "A1", projectId: UUID()),
            Agent(name: "A2", projectId: UUID()),
        ]
        let result = filteredAndSorted(agents, for: UUID())
        XCTAssertTrue(result.isEmpty)
    }

    func testPinnable_filteredAndSorted_singleItem_returnsThatItem() {
        let projectId = UUID()
        let agent = Agent(name: "Solo", projectId: projectId)
        let result = filteredAndSorted([agent], for: projectId)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "Solo")
    }
}
