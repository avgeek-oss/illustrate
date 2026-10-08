// MARK: - OnboardingTitleView.swift

// Title component for onboarding sheet.

import SwiftUI

/// Large title for onboarding views.
struct OnboardingTitleView: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.title)
            .fontWeight(.semibold)
            .multilineTextAlignment(.center)
    }
}
