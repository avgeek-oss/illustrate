// MARK: - CostFormatter.swift

// Utility for formatting generation costs as human-readable currency strings.

import Foundation

/// Formats a cost value as a currency string.
///
/// This function intelligently formats costs based on their magnitude:
/// - Zero → "Free"
/// - Small amounts (< $0.01) → Up to 4 decimal places (e.g., "$0.0025")
/// - Normal amounts → Up to 2 decimal places (e.g., "$0.04")
///
/// Trailing zeros are trimmed for cleaner display.
///
/// - Parameter cost: The cost value in dollars
/// - Returns: Formatted currency string with $ prefix
public func formatEstimatedCost(_ cost: Double) -> String {
    // Special case for free/zero cost
    if cost == 0 { return "Free" }

    // Use more precision for sub-cent amounts
    let maxDecimals = cost < 0.01 ? 4 : 2
    let formatted = String(format: "%.\(maxDecimals)f", cost)

    // Trim trailing zeros for cleaner display
    var result = formatted
    while result.contains("."), result.hasSuffix("0") {
        result.removeLast()
    }
    // Remove trailing decimal point if no decimals remain
    if result.hasSuffix(".") {
        result.removeLast()
    }

    return "$\(result)"
}
