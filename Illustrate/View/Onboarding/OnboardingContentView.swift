// MARK: - OnboardingContentView.swift

// Text content component for onboarding items.
//
// Simple styled text for onboarding descriptions.

import SwiftUI

/// Styled text content for onboarding items.
struct OnboardingContentView: View {
    let content: String

    init(_ content: String) {
        self.content = content
    }

    var body: some View {
        Text(content)
            .font(.callout)
            .opacity(0.7)
    }
}
