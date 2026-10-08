// MARK: - DateAdapter.swift

// Date formatting utilities with cached formatters for performance.
//
// DateFormatter creation is expensive, so formatters are cached as static
// properties. This file provides common date formats used throughout the app.

import Foundation
import OSLog

/// Cached date formatters for performance.
///
/// DateFormatter creation is expensive (~1ms each), so we cache them
/// as static properties for reuse across the app.
enum DateFormatters {
    static let yearMonthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let iso8601 = ISO8601DateFormatter()
}

func getDateFromString(_ dateString: String) -> Date {
    DateFormatters.yearMonthDay.date(from: dateString) ?? Date()
}
