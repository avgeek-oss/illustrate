// MARK: - DateAdapter.swift

// Date formatting utilities with cached formatters for performance.

import Foundation

/// Cached date formatters for performance.
public enum DateFormatters {
    public nonisolated(unsafe) static let yearMonthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    public nonisolated(unsafe) static let iso8601 = ISO8601DateFormatter()
}

/// Parse a date from a "yyyy-MM-dd" string.
public func getDateFromString(_ dateString: String) -> Date {
    DateFormatters.yearMonthDay.date(from: dateString) ?? Date()
}
