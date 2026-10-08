// MARK: - OnboardingSubtitleView.swift

// Subtitle text component for onboarding items.

import SwiftUI

/// Styled subtitle for onboarding items.
struct OnboardingSubtitleView: View {
    let subtitle: String

    init(_ subtitle: String) {
        self.subtitle = subtitle
    }

    var body: some View {
        Text(subtitle)
            .font(.callout)
            .fontWeight(.medium)
    }
}
