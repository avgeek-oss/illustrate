// MARK: - InfoTooltip.swift

// Simple info icon with hover tooltip.
//
// Displays an info circle icon that shows help text on hover
// (macOS) or tap (iOS).
//
// ## Usage
// ```swift
// InfoTooltip("This setting controls...")
// ```

import SwiftUI

/// Info icon with tooltip help text.
struct InfoTooltip: View {
    let helpText: Text

    var body: some View {
        Image(systemName: "info.circle")
            .foregroundStyle(.secondary)
            .help(helpText)
            .accessibilityLabel(helpText)
            .accessibilityHint("Information")
    }
}

extension InfoTooltip {
    init(_ helpText: String) {
        self.init(helpText: Text(helpText))
    }
}
