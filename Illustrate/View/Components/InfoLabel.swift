// MARK: - InfoLabel.swift

// Pill-shaped info badge for displaying hints.
//
// Shows an info icon with text in a rounded badge.
// Used for inline tips and hints in forms.

import AvgeekLocalizationCore
import AvgeekLocalizationUI
import SwiftUI

/// Pill-shaped info badge with icon and text.
struct InfoLabel: View {
    let label: String

    @AppLocalized private var localize

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
            Text(localize(label))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(.thinMaterial)
        .cornerRadius(8)
    }
}

extension InfoLabel {
    init(_ label: String) {
        self.init(label: label)
    }
}
