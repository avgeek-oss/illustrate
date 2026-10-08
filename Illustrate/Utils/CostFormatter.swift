// MARK: - CostFormatter.swift

// Utility for formatting generation costs as human-readable currency strings.
//
// AI generation has varying costs from fractions of a cent to several dollars.
// This formatter handles the display of these costs appropriately:
// - Zero cost shows as "Free"
// - Small amounts show more decimal places for precision
// - Trailing zeros are trimmed for cleaner display

import Foundation

/// Formats a cost value as a currency string.
///
/// This function intelligently formats costs based on their magnitude:
/// - Zero → "Free"
/// - Small amounts (< $0.01) → Up to 4 decimal places (e.g., "$0.0025")
/// - Normal amounts → Up to 2 decimal places (e.g., "$0.04")
///
/// Trailing zeros are trimmed for cleaner display:
/// - "$0.0400" → "$0.04"
/// - "$1.00" → "$1"
///
/// ## Examples
/// ```swift
/// formatEstimatedCost(0.0)     // "Free"
/// formatEstimatedCost(0.0025)  // "$0.0025"
/// formatEstimatedCost(0.04)    // "$0.04"
/// formatEstimatedCost(1.50)    // "$1.5"
/// formatEstimatedCost(5.0)     // "$5"
/// ```
///
/// - Parameter cost: The cost value in dollars
/// - Returns: Formatted currency string with $ prefix
func formatEstimatedCost(_ cost: Double) -> String {
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
