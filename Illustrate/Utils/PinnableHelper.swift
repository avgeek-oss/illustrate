// MARK: - PinnableHelper.swift

// Provides common functionality for pinnable items (Agents, Flow Canvas, ChatThreads).
//
// This protocol and helper function reduce code duplication across views that
// display lists of pinnable items with consistent filtering and sorting behavior.

import Foundation

// MARK: - Pinnable Protocol

/// Protocol for items that can be pinned to the top of a list.
///
/// Conforming types gain access to the `filteredAndSorted(for:)` helper
/// which provides consistent filtering by project and sorting with
/// pinned items first, then by date.
protocol Pinnable: AnyObject, Identifiable where ID == UUID {
    var id: UUID { get }
    var name: String { get set }
    var isPinned: Bool { get set }
    var createdAt: Date { get }
    var projectId: UUID { get }
}

// MARK: - Helper Functions

/// Filters items by project and sorts with pinned items first, then by date (newest first).
///
/// - Parameters:
///   - items: The collection of pinnable items to filter and sort
///   - projectId: The project ID to filter by
/// - Returns: Filtered and sorted array of items
func filteredAndSorted<T: Pinnable>(_ items: [T], for projectId: UUID) -> [T] {
    items
        .filter { $0.projectId == projectId }
        .sorted { lhs, rhs in
            // Pinned items first, then by date (newest first)
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            return lhs.createdAt > rhs.createdAt
        }
}
