// MARK: - StoryboardPlayerView.swift

// Video player component for the storyboard editor.
// Uses SafeVideoPlayer to avoid _AVKit_SwiftUI metadata crash.

import AVFoundation
import AvgeekDesignSystem
import IllustrateProviders
import SwiftUI

/// Video player for the storyboard editor.
struct StoryboardPlayerView: View {
    @ObservedObject var viewModel: StoryboardViewModel

    @State private var shouldAutoPlay = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.05)

            if let scene = viewModel.selectedScene {
                if scene.status == .COMPLETED, let generationId = scene.generationId {
                    playerContent(generationId: generationId)
                } else if scene.status == .FAILED {
                    failedState(scene: scene)
                } else {
                    generatingState
                }
            } else if viewModel.scenes.isEmpty {
                emptyState
            } else {
                noSelectionState
            }
        }
    }

    // MARK: - Player Content

    /// Whether auto-play to next scene should be disabled.
    /// Google models (Veo) in auto-extend mode produce videos by appending to the previous video,
    /// so playing them back-to-back looks like it restarts from scratch.
    private var shouldDisableAutoPlayNextScene: Bool {
        viewModel.storyboard.mode == .AUTO_EXTEND &&
            viewModel.storyboard.providerId == EnumProviderCode.GOOGLE_CLOUD.providerId.uuidString
    }

    private func playerContent(generationId: UUID) -> some View {
        let videoName = generationId.uuidString

        return ICloudVideoLoader(videoName: videoName) { url in
            if let url {
                NativeVideoPlayer(url: url, autoPlay: shouldAutoPlay, onVideoEnded: {
                    if viewModel.hasNextScene, !shouldDisableAutoPlayNextScene {
                        shouldAutoPlay = true
                        viewModel.nextScene()
                    }
                })
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.icloud")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Video not found")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .id(generationId)
        .onAppear {
            VideoCache.shared.clearFailedAttempt(forKey: videoName)
        }
    }

    // MARK: - State Views

    private var emptyState: some View {
        AvgeekEmptyStateView(
            icon: "film",
            title: "No scenes added yet",
            message: "Add your first scene to start building your storyboard.",
            buttonTitle: "Add First Scene",
            buttonIcon: "plus",
            onButtonTap: { viewModel.showAddSceneSheet = true }
        )
        .frame(maxWidth: 400)
    }

    private var noSelectionState: some View {
        AvgeekEmptyStateView(
            icon: "hand.tap",
            title: "Select a scene",
            message: "Click on a scene in the timeline to preview it."
        )
    }

    private var generatingState: some View {
        VStack(spacing: 8) {
            GradientSpinner()
            VStack(spacing: 4) {
                Text("Generating scene...")
                Text("This may take a few minutes to complete.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func failedState(scene: StoryboardScene) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.red)

            VStack(spacing: 4) {
                Text("Scene generation failed")
                Text(scene.errorMessage ?? "This scene failed to generate.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Native Video Player

/// Native video player with built-in controls.
/// Uses SafeVideoPlayerView to avoid _AVKit_SwiftUI metadata crash.
private struct NativeVideoPlayer: View {
    let url: URL
    let autoPlay: Bool
    var onVideoEnded: (() -> Void)?

    var body: some View {
        SafeVideoPlayerView(url: url, autoPlay: autoPlay, onVideoEnded: onVideoEnded)
    }
}
