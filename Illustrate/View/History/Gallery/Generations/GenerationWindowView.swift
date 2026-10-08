// MARK: - GenerationWindowView.swift

// Standalone window view for displaying generation details.
//
// This view wraps GenerationImageView or GenerationVideoView for display
// in a separate macOS window without navigation chrome.
//
// ## Features
// - Opens in a new window with close button only
// - Resizable for comfortable viewing
// - No navigation toolbar or sidebar
// - Edit shortcut disabled (not applicable in standalone window)
//
// ## Usage
// Opened via `openWindow(value:)` with a GenerationWindowData payload.

import SwiftUI

#if os(macOS)

/// Data payload for opening generation preview windows.
///
/// This struct is used with `openWindow(value:)` to pass the generation
/// type and ID to the new window.
struct GenerationWindowData: Codable, Hashable {
    /// Whether this is a video generation (true) or image generation (false)
    let isVideo: Bool
    /// The ImageSet UUID to display
    let setId: UUID
}

/// Environment key to indicate if we're in a standalone preview window.
private struct IsPreviewWindowKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isPreviewWindow: Bool {
        get { self[IsPreviewWindowKey.self] }
        set { self[IsPreviewWindowKey.self] = newValue }
    }
}

/// Standalone window view for generation preview.
///
/// Displays either GenerationImageView or GenerationVideoView based on the
/// provided data, without navigation wrappers for a clean preview experience.
struct GenerationWindowView: View {
    let data: GenerationWindowData

    var body: some View {
        Group {
            if data.isVideo {
                GenerationVideoWindowContent(setId: data.setId)
            } else {
                GenerationImageWindowContent(setId: data.setId)
            }
        }
        .environment(\.isPreviewWindow, true)
        .withGlobalToast()
    }
}

/// Image generation content adapted for standalone window display.
struct GenerationImageWindowContent: View {
    let setId: UUID

    var body: some View {
        GenerationImageView(setId: setId)
            .frame(minWidth: 600, minHeight: 500)
    }
}

/// Video generation content adapted for standalone window display.
struct GenerationVideoWindowContent: View {
    let setId: UUID

    var body: some View {
        GenerationVideoView(setId: setId)
            .frame(minWidth: 700, minHeight: 550)
    }
}

#endif
