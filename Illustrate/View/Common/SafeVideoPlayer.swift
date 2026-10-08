// MARK: - SafeVideoPlayer.swift

// A safe video player component that avoids the _AVKit_SwiftUI metadata crash.
//
// ## Problem
// The SwiftUI `VideoPlayer` view from AVKit uses the `_AVKit_SwiftUI` framework
// internally, which can crash during Swift metadata initialization on certain
// macOS versions due to a runtime bug in `getSuperclassMetadata`.
//
// ## Solution
// This component uses `NSViewRepresentable` (macOS) or `UIViewRepresentable` (iOS)
// to wrap the native `AVPlayerView` / `AVPlayerViewController` directly, bypassing
// the problematic `_AVKit_SwiftUI` framework entirely.
//
// ## Usage
// For direct player management, use `SafeVideoPlayer(player:)` with a `@State` player.
// For convenience with automatic lifecycle management, use `SafeVideoPlayerView(url:)`.

import AVFoundation
import AVKit
import SwiftUI

#if os(macOS)

/// A safe video player for macOS that wraps AVPlayerView directly.
/// This avoids the _AVKit_SwiftUI metadata crash by using NSViewRepresentable.
struct SafeVideoPlayer: NSViewRepresentable {
    let player: AVPlayer?

    /// Controls style for the player view.
    var controlsStyle: AVPlayerViewControlsStyle = .inline

    /// Whether to show the full screen toggle button.
    var showsFullScreenToggleButton = true

    func makeNSView(context _: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.player = player
        playerView.controlsStyle = controlsStyle
        playerView.showsFullScreenToggleButton = showsFullScreenToggleButton
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context _: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
        nsView.controlsStyle = controlsStyle
        nsView.showsFullScreenToggleButton = showsFullScreenToggleButton
    }
}

#else

/// A safe video player for iOS that wraps AVPlayerViewController directly.
/// This avoids the _AVKit_SwiftUI metadata crash by using UIViewControllerRepresentable.
struct SafeVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer?

    /// Whether to show playback controls.
    var showsPlaybackControls = true

    func makeUIViewController(context _: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = showsPlaybackControls
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context _: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
        uiViewController.showsPlaybackControls = showsPlaybackControls
    }
}

#endif

// MARK: - SafeVideoPlayerView

/// A managed video player view with automatic lifecycle handling.
/// This provides the same functionality as the old VideoPlayer wrappers
/// but uses SafeVideoPlayer internally to avoid crashes.
struct SafeVideoPlayerView: View {
    let url: URL
    var autoPlay = false
    var onVideoEnded: (() -> Void)?

    @State private var player: AVPlayer?

    var body: some View {
        SafeVideoPlayer(player: player)
            .onAppear {
                setupPlayer()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
            .onChange(of: url) { _, newURL in
                player?.pause()
                setupPlayer(url: newURL)
            }
            .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
                guard let playerItem = notification.object as? AVPlayerItem,
                      playerItem == player?.currentItem else { return }
                onVideoEnded?()
            }
    }

    private func setupPlayer(url: URL? = nil) {
        let videoURL = url ?? self.url
        player = AVPlayer(url: videoURL)
        if autoPlay {
            player?.play()
        }
    }
}
