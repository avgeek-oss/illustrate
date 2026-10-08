// MARK: - WelcomeView.swift

// First-launch welcome screen with app introduction.
//
// Shown as a sheet on first app launch (tracked by AppVersionManager).
// Introduces key features and privacy commitments:
// - Generative AI sandbox capabilities
// - iCloud sync for generated content
// - Privacy-first approach (no data collection)
//
// ## OnboardingUI
// Uses the OnboardingUI library for consistent Apple-style onboarding.

import OnboardingUI
import SwiftUI

/// First-launch welcome screen with feature highlights.
struct WelcomeView: View {
    var action: () -> Void

    var body: some View {
        OnboardingSheetView {
            OnboardingTitleView("Welcome to\nIllustrate")
        } content: {
            OnboardingItem(systemName: "wand.and.sparkles", primary: .accentColor) {
                OnboardingSubtitleView("Generative AI Sandbox")
                OnboardingContentView(
                    "Generate, enhance and edit images with your secure private sandbox. All data calls are processed on-device."
                )
            }

            OnboardingItem(systemName: "icloud", primary: .accentColor) {
                OnboardingSubtitleView("Synced to your iCloud")
                OnboardingContentView(
                    "The images you generate are synced privately in your iCloud account and can be accessed across your devices."
                )
            }

            OnboardingItem(systemName: "hand.raised", primary: .accentColor) {
                OnboardingSubtitleView("Transparent about privacy")
                OnboardingContentView(
                    "We don't collect any of the data from this application, be it for analytics or data processing. This is forever, period."
                )
            }
        } link: {
            Link("Read more on privacy...", destination: URL(string: PRIVACY_URL)!)
                .foregroundStyle(Color.accentColor)
        } button: {
            ContinueButton(color: .accentColor, action: action)
        }
    }
}
