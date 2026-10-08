// MARK: - BackgroundColors.swift

// Cross-platform semantic color definitions.
//
// Provides platform-agnostic access to system colors:
// - label/secondaryLabel: Text colors
// - systemBackground/secondarySystemBackground: View backgrounds
// - systemFill variants: Fill colors for controls
//
// ## Platform Mapping
// - macOS: NSColor -> Color
// - iOS: UIColor -> Color
//
// ## Dark Mode
// All colors automatically adapt to light/dark appearance.

import AvgeekDesignSystem
import SwiftUI

/// Primary label color (adapts to dark mode).
var label: Color {
    ApplePlatformColor.label
}

var secondaryLabel: Color {
    ApplePlatformColor.secondaryLabel
}

var systemBackground: Color {
    ApplePlatformColor.background
}

var secondarySystemBackground: Color {
    ApplePlatformColor.secondaryBackground
}

var systemFill: Color {
    ApplePlatformColor.fill
}

var secondarySystemFill: Color {
    ApplePlatformColor.secondaryFill
}

var tertiarySystemFill: Color {
    ApplePlatformColor.tertiaryFill
}

var quaternarySystemFill: Color {
    ApplePlatformColor.quaternaryFill
}
