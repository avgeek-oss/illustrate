// MARK: - AspectRatioHelpers.swift

// Utility functions for converting between pixel dimensions and aspect ratios.

import Foundation

/// Calculates the Greatest Common Divisor using Euclidean algorithm.
///
/// Used to simplify dimension ratios.
/// Example: gcd(1920, 1080) = 120, giving 16:9 ratio.
///
/// - Parameters:
///   - a: First integer
///   - b: Second integer
/// - Returns: Greatest common divisor of a and b
public func gcd(_ a: Int, _ b: Int) -> Int {
    var a = a
    var b = b
    while b != 0 {
        let temp = b
        b = a % b
        a = temp
    }
    return a
}

/// Converts dimensions to aspect ratio format.
///
/// This function handles two input formats:
/// 1. **Aspect ratio** (e.g., "16:9"): Returned unchanged
/// 2. **Pixel dimensions** (e.g., "1920x1080"): Converted using GCD
///
/// ## Example Conversions
/// - "1920x1080" → "16:9"
/// - "1024x1024" → "1:1"
/// - "1280x720" → "16:9"
/// - "16:9" → "16:9" (unchanged)
///
/// - Parameter dimensions: Input string in either format
/// - Returns: Aspect ratio string (e.g., "16:9", "1:1")
/// - Note: Returns "1:1" if parsing fails
public func convertToAspectRatio(_ dimensions: String) -> String {
    // If already in aspect ratio format, return as-is
    if dimensions.contains(":") {
        return dimensions
    }

    // Parse pixel dimensions (case-insensitive for 'x' or 'X')
    let parts = dimensions.lowercased().split(separator: "x")
    if parts.count == 2,
       let width = Int(parts[0]),
       let height = Int(parts[1]),
       width > 0,
       height > 0
    {
        // Use GCD to find the simplified aspect ratio
        let gcdValue = gcd(width, height)
        return "\(width / gcdValue):\(height / gcdValue)"
    }

    // Default fallback for invalid input
    return "1:1"
}

/// Gets the aspect ratio from dimensions string.
///
/// This is an alias for convertToAspectRatio for compatibility.
///
/// - Parameter dimensions: Input string in either format
/// - Returns: Aspect ratio string (e.g., "16:9", "1:1")
public func getAspectRatio(_ dimensions: String) -> String {
    convertToAspectRatio(dimensions)
}

/// Aspect ratio result with ratio dimensions and actual pixel dimensions.
public struct AspectRatioResult {
    /// The aspect ratio string (e.g., "16:9")
    public let ratio: String
    /// Simplified ratio width (e.g., 16 for "16:9")
    public let width: Int
    /// Simplified ratio height (e.g., 9 for "16:9")
    public let height: Int
    /// Actual pixel width (e.g., 1920 for "1920x1080")
    public let actualWidth: Int
    /// Actual pixel height (e.g., 1080 for "1920x1080")
    public let actualHeight: Int

    public init(ratio: String, width: Int, height: Int, actualWidth: Int, actualHeight: Int) {
        self.ratio = ratio
        self.width = width
        self.height = height
        self.actualWidth = actualWidth
        self.actualHeight = actualHeight
    }
}

/// Gets the aspect ratio from dimensions string with labeled parameter.
///
/// - Parameter dimension: Input string in either format
/// - Returns: AspectRatioResult with ratio string and both ratio/actual dimensions
public func getAspectRatio(dimension: String) -> AspectRatioResult {
    let ratio = convertToAspectRatio(dimension)

    // Parse dimensions
    var ratioWidth = 1
    var ratioHeight = 1
    var actualWidth = 0
    var actualHeight = 0

    if dimension.contains(":") {
        // Parse aspect ratio format (e.g., "16:9")
        let parts = dimension.split(separator: ":")
        if parts.count == 2,
           let w = Int(parts[0]),
           let h = Int(parts[1])
        {
            ratioWidth = w
            ratioHeight = h
            // For ratio input, calculate actual dimensions at 1080p equivalent
            let baseSize = 1080
            if w >= h {
                actualHeight = baseSize
                actualWidth = baseSize * w / h
            } else {
                actualWidth = baseSize
                actualHeight = baseSize * h / w
            }
        }
    } else if dimension.lowercased().contains("x") {
        // Parse pixel dimensions (e.g., "1920x1080")
        let parts = dimension.lowercased().split(separator: "x")
        if parts.count == 2,
           let w = Int(parts[0]),
           let h = Int(parts[1])
        {
            actualWidth = w
            actualHeight = h
            // Calculate ratio dimensions using GCD
            let gcdValue = gcd(w, h)
            ratioWidth = w / gcdValue
            ratioHeight = h / gcdValue
        }
    }

    return AspectRatioResult(
        ratio: ratio,
        width: ratioWidth,
        height: ratioHeight,
        actualWidth: actualWidth,
        actualHeight: actualHeight
    )
}
