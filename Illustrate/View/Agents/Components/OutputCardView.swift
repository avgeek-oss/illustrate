// MARK: - OutputCardView.swift

// Card view for workflow output/endpoint.
//
// Displays the final result of a workflow execution:
// - Text output (prompt results)
// - Image output with preview
// - Video output with player
//
// ## Actions
// Generation actions are exposed from the card context menu.
//
// ## Content Loading
// Loads output from the linked Generation entity,
// using ICloudImageLoader/ICloudVideoLoader for media.

import AVFoundation
import AvgeekDesignSystem
import SwiftData
import SwiftUI

/// Content type for output card display.
enum OutputContent {
    case text(String)
    case image(PlatformImage)
    case video(URL)
    case empty

    var hasContent: Bool {
        switch self {
        case let .text(text): !text.isEmpty
        case .image, .video: true
        case .empty: false
        }
    }
}

struct OutputCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var card: AgentCard
    var isHovered = false
    var isRunning = false
    var isErrored = false
    var errorMessage: String?
    var isLocked = false

    @State private var loadedContent: OutputContent = .empty
    @State private var isLoading = false
    @State private var outputGeneration: Generation?

    private func fetchOutputGeneration() {
        guard let genId = card.generationId else {
            outputGeneration = nil
            return
        }
        let descriptor = FetchDescriptor<Generation>(predicate: #Predicate { $0.id == genId })
        outputGeneration = try? modelContext.fetch(descriptor).first
    }

    var body: some View {
        CardContainerView(
            isHovered: isHovered,
            isRunning: isRunning,
            isErrored: isErrored,
            errorMessage: errorMessage
        ) {
            headerView
        } content: {
            contentView
        }
        .task(id: card.generationId) {
            fetchOutputGeneration()
            await loadOutputContent()
        }
    }

    private func loadOutputContent() async {
        guard let gen = outputGeneration else {
            loadedContent = .empty
            return
        }

        if gen.contentType == .VIDEO {
            let fileManager = FileManager.default
            if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let videoURL = documentsURL.appendingPathComponent("\(gen.id.uuidString).mp4")
                if fileManager.fileExists(atPath: videoURL.path) {
                    loadedContent = .video(videoURL)
                    return
                }
            }
        }

        if gen.contentType == .IMAGE_2D {
            isLoading = true
            let genId = gen.id.uuidString

            let image: PlatformImage? = await Task.detached(priority: .background) {
                loadImageFromDocumentsDirectory(withName: genId)
            }.value

            await MainActor.run {
                if let image {
                    loadedContent = .image(image)
                } else if !gen.prompt.isEmpty {
                    loadedContent = .text(gen.prompt)
                } else {
                    loadedContent = .empty
                }
                isLoading = false
            }
            return
        }

        if !gen.prompt.isEmpty {
            loadedContent = .text(gen.prompt)
        } else {
            loadedContent = .empty
        }
    }

    private var headerView: some View {
        CardHeaderView(
            title: "Output",
            icon: "square.and.arrow.up.fill",
            iconColor: .accentColor,
            hasGenerationId: card.generationId != nil
        )
    }

    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            loadingContentView
        } else {
            switch loadedContent {
            case let .text(text):
                textContentView(text)
            case let .image(image):
                imageContentView(image)
            case let .video(url):
                videoContentView(url)
            case .empty:
                emptyContentView
            }
        }
    }

    private var loadingContentView: some View {
        VStack(spacing: 12) {
            GradientSpinner()
            Text("Loading output...")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func textContentView(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 60, maxHeight: 200)
            .padding(12)
            .background(secondarySystemFill.opacity(0.5))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
    }

    private func imageContentView(_ image: PlatformImage) -> some View {
        VStack(spacing: 12) {
            ZStack {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
                #else
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
                #endif
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Generated image")
            .accessibilityHint("Double tap for actions")

            imageInfoRow(image)
        }
    }

    private func imageInfoRow(_ image: PlatformImage) -> some View {
        HStack(spacing: 12) {
            #if os(macOS)
            let size = image.size
            #else
            let size = image.size
            #endif

            HStack(spacing: 4) {
                Image(systemName: "aspectratio")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("\(Int(size.width)) × \(Int(size.height))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func videoContentView(_ url: URL) -> some View {
        VStack(spacing: 12) {
            VideoPlayerView(url: url)
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )

            HStack(spacing: 4) {
                Image(systemName: "film")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(url.lastPathComponent)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }

    private var emptyContentView: some View {
        AvgeekEmptyStateView(
            icon: "tray",
            title: "No output yet",
            message: "Run the agent to see results here."
        )
        .padding(.vertical, 8)
    }
}

private struct VideoPlayerView: View {
    let url: URL

    @State private var player: AVPlayer?
    @State private var isPlaying = false

    var body: some View {
        ZStack {
            if let player {
                SafeVideoPlayer(player: player)
                    .onDisappear {
                        player.pause()
                    }
            } else {
                Rectangle()
                    .fill(secondarySystemFill)
                    .overlay {
                        VStack(spacing: 8) {
                            GradientSpinner()
                            Text("Loading video...")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
            }

            if !isPlaying, player != nil {
                Button {
                    player?.play()
                    isPlaying = true
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white, .black.opacity(0.4))
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play video")
                .accessibilityHint("Plays the generated video")
            }
        }
        .onAppear {
            player = AVPlayer(url: url)

            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player?.currentItem,
                queue: .main
            ) { _ in
                isPlaying = false
                player?.seek(to: .zero)
            }
        }
    }
}
