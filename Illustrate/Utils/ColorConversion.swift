// MARK: - ColorConversion.swift

// Utility functions for converting between Color and hex strings.
//
// Supports both macOS (NSColor) and iOS (UIColor) platforms.

import SwiftUI

// MARK: - Hex to Color

/// Converts a hex string to a SwiftUI Color.
///
/// Accepts formats: "FF0000", "#FF0000"
///
/// - Parameter hex: Hex color string (6 characters, with or without #)
/// - Returns: SwiftUI Color, defaults to black for invalid input
func colorFromHex(_ hex: String) -> Color {
    var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    if hexString.hasPrefix("#") {
        hexString.remove(at: hexString.startIndex)
    }

    guard hexString.count == 6 else { return .black }

    var rgbValue: UInt64 = 0
    Scanner(string: hexString).scanHexInt64(&rgbValue)

    let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
    let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
    let b = Double(rgbValue & 0x0000FF) / 255.0

    return Color(red: r, green: g, blue: b)
}

// MARK: - Color to Hex

/// Converts a SwiftUI Color to a hex string.
///
/// - Parameter color: SwiftUI Color to convert
/// - Returns: Hex string without # prefix (e.g., "FF0000")
func hexFromColor(_ color: Color) -> String {
    #if os(macOS)
    let nsColor = NSColor(color)
    guard let rgbColor = nsColor.usingColorSpace(.sRGB) else { return "000000" }
    let r = Int(round(rgbColor.redComponent * 255))
    let g = Int(round(rgbColor.greenComponent * 255))
    let b = Int(round(rgbColor.blueComponent * 255))
    return String(format: "%02X%02X%02X", r, g, b)
    #else
    let uiColor = UIColor(color)
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
    return String(format: "%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    #endif
}

// MARK: - Hex Input Filter

/// Filters input to only allow valid hex characters.
///
/// - Parameter input: Raw input string
/// - Returns: Filtered string with only 0-9, A-F characters (max 6)
func filterHexInput(_ input: String) -> String {
    let allowed = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
    let filtered = String(input.unicodeScalars.filter { allowed.contains($0) })
    return String(filtered.prefix(6)).uppercased()
}
