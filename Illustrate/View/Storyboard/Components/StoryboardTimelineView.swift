// MARK: - StoryboardTimelineView.swift

// Timeline component for the storyboard editor.
//
// StoryboardTimelineView displays scenes as blocks in a horizontal
// scrolling timeline with the following features:
//
// ## Scene Blocks
// - Thumbnail preview (from generated video)
// - Duration badge
// - Status indicator (generating, completed, failed)
// - Progress ring during generation
//
// ## Interactions
// - Click to select and play
// - Drag to reorder
// - Right-click context menu (Regenerate, Delete)
// - "+" button to add new scenes

import SwiftData
import SwiftUI
#if !os(macOS)
import UIKit
#endif

/// Timeline view showing scene blocks in horizontal layout.
struct StoryboardTimelineView: View {
    @ObservedObject var viewModel: StoryboardViewModel
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var queueManager: QueueManager
    let isCompactLayout: Bool

    @State private var draggedScene: StoryboardScene?

    var body: some View {
        VStack(spacing: 0) {
            if !isCompactLayout {
                HStack(spacing: 0) {
                    Text("Storyboard Timeline")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    if !viewModel.scenes.isEmpty {
                        Text("\(viewModel.scenes.count) scene\(viewModel.scenes.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 16)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(viewModel.scenes.enumerated()), id: \.element.id) { index, scene in
                        let block = SceneBlock(
                            scene: scene,
                            index: index,
                            isSelected: viewModel.selectedSceneIndex == index,
                            isLastScene: index == viewModel.scenes.count - 1,
                            sceneDuration: viewModel.storyboard.sceneDuration,
                            onSelect: {
                                viewModel.selectScene(at: index, autoPlay: true)
                            },
                            onRegenerate: {
                                Task {
                                    await viewModel.regenerateScene(
                                        scene,
                                        projectId: projectManager.currentProjectId,
                                        queueManager: queueManager,
                                        modelContext: modelContext
                                    )
                                }
                            },
                            onExport: {
                                #if os(macOS)
                                if let generationId = scene.generationId,
                                   let videoURL = loadVideoFromiCloud(generationId.uuidString)
                                {
                                    saveVideoToDownloads(url: videoURL, fileName: "scene_\(index + 1)")
                                }
                                #endif
                            },
                            onDelete: {
                                viewModel.deleteScene(at: index, modelContext: modelContext)
                            },
                            onDuplicate: {
                                viewModel.duplicateScene(at: index, modelContext: modelContext)
                            },
                            onCopyPrompt: {
                                if !scene.prompt.isEmpty {
                                    #if os(macOS)
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(scene.prompt, forType: .string)
                                    #else
                                    UIPasteboard.general.string = scene.prompt
                                    #endif
                                    showToast(.success("Prompt copied to clipboard"))
                                }
                            }
                        )

                        if isCompactLayout {
                            block
                        } else {
                            block
                                .onDrag {
                                    draggedScene = scene
                                    return NSItemProvider(object: scene.id.uuidString as NSString)
                                }
                                .onDrop(of: [.text], delegate: SceneDropDelegate(
                                    scene: scene,
                                    scenes: viewModel.scenes,
                                    draggedScene: $draggedScene,
                                    onReorder: { from, to in
                                        viewModel.reorderScene(from: from, to: to, modelContext: modelContext)
                                    }
                                ))
                        }
                    }

                    addSceneButton
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .padding(.top, isCompactLayout ? 0 : 8)
        .background(isCompactLayout ? systemBackground : secondarySystemFill)
    }

    // MARK: - Add Scene Button

    @State private var isAddButtonHovering = false

    private var addSceneButton: some View {
        Button {
            viewModel.showAddSceneSheet = true
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                        )
                        .foregroundStyle(Color.secondary.opacity(isAddButtonHovering ? 0.8 : 0.5))

                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(isAddButtonHovering ? 0.1 : 0))

                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(Color.secondary.opacity(isAddButtonHovering ? 1.0 : 0.6))
                }
                .frame(width: 120, height: 68)

                Text("Add Scene")
                    .font(.caption2)
                    .foregroundStyle(Color.secondary.opacity(isAddButtonHovering ? 1.0 : 0.6))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .onHover { hovering in
            isAddButtonHovering = hovering
        }
        #endif
        .disabled(!viewModel.canAddScene)
        .opacity(viewModel.canAddScene ? 1.0 : 0.5)
        .animation(.easeInOut(duration: 0.15), value: isAddButtonHovering)
    }
}

// MARK: - Scene Block

/// Individual scene block in the timeline.
private struct SceneBlock: View {
    let scene: StoryboardScene
    let index: Int
    let isSelected: Bool
    let isLastScene: Bool
    let sceneDuration: Double
    let onSelect: () -> Void
    let onRegenerate: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void
    var onDuplicate: (() -> Void)?
    var onCopyPrompt: (() -> Void)?

    @State private var isHovering = false
    @State private var showRegenerateConfirmation = false

    var body: some View {
        VStack(spacing: 6) {
            // Scene thumbnail
            ZStack {
                thumbnailView
                    .frame(width: 120, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Status overlay
                statusOverlay

                // Selection indicator
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.accentColor, lineWidth: 3)
                }
            }
            .frame(width: 120, height: 68)

            // Scene info
            HStack(spacing: 4) {
                Text("Scene \(index + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("/")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)

                Text("+\(Int(sceneDuration))s")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .onTapGesture {
            onSelect()
        }
        #if os(macOS)
        .onHover { hovering in
            isHovering = hovering
        }
        #endif
        .contextMenu {
            if let onDuplicate {
                Button {
                    onDuplicate()
                } label: {
                    Label("Duplicate Scene", systemImage: "doc.on.doc")
                }
            }

            if let onCopyPrompt {
                Button {
                    onCopyPrompt()
                } label: {
                    Label("Copy Prompt", systemImage: "text.quote")
                }
            }

            if onDuplicate != nil || onCopyPrompt != nil {
                Divider()
            }

            Button {
                showRegenerateConfirmation = true
            } label: {
                Label("Regenerate", systemImage: "arrow.clockwise")
            }
            .disabled(!isLastScene || scene.status == .GENERATING)

            #if os(macOS)
            Button {
                onExport()
            } label: {
                Label("Export Scene", systemImage: "square.and.arrow.up")
            }
            .disabled(scene.status != .COMPLETED || scene.generationId == nil)
            #endif

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Regenerate Scene?",
            isPresented: $showRegenerateConfirmation,
            titleVisibility: .visible
        ) {
            Button("Regenerate", role: .destructive) {
                onRegenerate()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will replace the current scene with a newly generated video.")
        }
    }

    // MARK: - Thumbnail View

    @ViewBuilder
    private var thumbnailView: some View {
        if scene.status == .COMPLETED, let generationId = scene.generationId {
            AsyncThumbnailView(generationId: generationId)
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.1),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "film")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Status Overlay

    @ViewBuilder
    private var statusOverlay: some View {
        switch scene.status {
        case .GENERATING:
            ShimmerView()
        case .FAILED:
            ZStack {
                Color.black.opacity(0.5)
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.title2)
            }
        default:
            EmptyView()
        }
    }
}

// MARK: - Async Thumbnail View

/// Loads and displays a video thumbnail asynchronously.
private struct AsyncThumbnailView: View {
    let generationId: UUID

    @State private var thumbnail: PlatformImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(platformImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ShimmerView()
            }
        }
        .task {
            thumbnail = await loadThumbnail()
        }
    }

    private func loadThumbnail() async -> PlatformImage? {
        // Use loadVideoFromiCloud which checks both local and iCloud storage
        guard let videoURL = loadVideoFromiCloud(generationId.uuidString) else {
            return nil
        }

        // Extract thumbnail from video using modern async API
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 240, height: 136)

        do {
            let (cgImage, _) = try await generator.image(at: .zero)
            #if os(macOS)
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            #else
            return UIImage(cgImage: cgImage)
            #endif
        } catch {
            return nil
        }
    }
}

// MARK: - Scene Drop Delegate

/// Handles drag-and-drop reordering of scenes.
private struct SceneDropDelegate: DropDelegate {
    let scene: StoryboardScene
    let scenes: [StoryboardScene]
    @Binding var draggedScene: StoryboardScene?
    let onReorder: (Int, Int) -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggedScene = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedScene,
              draggedScene.id != scene.id,
              let fromIndex = scenes.firstIndex(where: { $0.id == draggedScene.id }),
              let toIndex = scenes.firstIndex(where: { $0.id == scene.id })
        else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            onReorder(fromIndex, toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Platform Image Extension

#if os(macOS)
import AVFoundation

extension Image {
    init(platformImage: NSImage) {
        self.init(nsImage: platformImage)
    }
}
#else
import AVFoundation

extension Image {
    init(platformImage: UIImage) {
        self.init(uiImage: platformImage)
    }
}
#endif
