// MARK: - NumericRange.swift

import Foundation

// MARK: - Numeric Range Type

/// A generic range type for model parameter constraints.
///
/// Used to define valid ranges for numeric parameters like guidance strength,
/// steps, safety tolerance, etc. The UI uses these ranges to configure
/// sliders and validate user input.
///
/// - Note: Generic over any Codable, Comparable & Sendable type for flexibility
public struct NumericRange<T: Codable & Comparable & Sendable>: Codable, Equatable, Sendable {
    /// Minimum allowed value (inclusive)
    public var min: T
    /// Maximum allowed value (inclusive)
    public var max: T

    public init(_ min: T, _ max: T) {
        self.min = min
        self.max = max
    }
}

/// Integer range for discrete parameters (steps, safety level)
public typealias IntRange = NumericRange<Int>
/// Double range for continuous parameters (guidance, motion)
public typealias DoubleRange = NumericRange<Double>
