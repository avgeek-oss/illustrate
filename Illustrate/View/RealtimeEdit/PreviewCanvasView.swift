// MARK: - PreviewCanvasView.swift

// Middle preview panel showing flattened composition.
//
// Displays a flattened, read-only preview of all visible layers
// composited in z-order. Updates when layers change but not during
// active drawing to maintain performance.
//
// ## Rendering
// - Layers sorted by zIndex
// - Only visible layers included
// - Rendered as static preview (not realtime mirror)
//
// ## Image Loading
// Uses ICloudImageLoader which gets a cache hit since the adapter
// caches the image in ImageCache immediately after generation.

import AvgeekDesignSystem
import SwiftUI

#if !os(macOS)
import Photos
#endif

/// Preview canvas displaying flattened layer composition or realtime generation.
struct PreviewCanvasView: View {
    let layers: [RealtimeEditLayer]
    let refreshTrigger: UUID
    let canvasSize: CGSize

    /// Optional generation ID for image lookup
    var generationId: UUID?

    /// Whether a generation is currently in progress
    var isGenerating = false

    /// Callback to save the current generation to the Image Gallery
    var onSaveToGallery: ((UUID) -> Void)?

    var body: some View {
        ZStack {
            // Background
            #if os(macOS)
            Color(nsColor: .controlBackgroundColor)
            #else
            Color(uiColor: .systemBackground)
            #endif

            // Bounding box border
            Rectangle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)

            // Show realtime generation if available, otherwise show waiting state
            if let id = generationId {
                generationImageView(id)
            } else if layers.isEmpty {
                // Empty state - no layers added yet
                AvgeekEmptyStateView(
                    icon: "square.stack.3d.up",
                    title: "No Layers",
                    message: "Use the tools below to add layers to your canvas."
                )
            } else {
                // Waiting for generation - layers exist but no generation yet
                AvgeekEmptyStateView(
                    icon: "wand.and.sparkles",
                    title: "Waiting for Generation",
                    message: "Draw on the canvas to trigger AI generation."
                )
            }

            // Floating generation indicator
            if isGenerating {
                generatingIndicator
            }
        }
        // Note: Removed .id(refreshTrigger) - SwiftUI naturally updates when generationId changes
        // The .id() modifier was causing the entire view to be destroyed and recreated,
        // leading to flickering as ICloudImageLoader had to re-render on each change.
    }

    /// Floating card showing generation in progress.
    private var generatingIndicator: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Image(systemName: "progress.indicator")
                    .symbolEffect(.rotate.byLayer, options: .repeat(.periodic(delay: 0.0)))
                    .padding(.all, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .padding(12)
            }
        }
    }

    /// View for displaying the generation image loaded from cache.
    private func generationImageView(_ id: UUID) -> some View {
        ICloudImageLoader(imageName: id.uuidString, showLoading: false) { image in
            if let image {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .contextMenu {
                        previewContextMenu(id: id, image: image)
                    }
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .contextMenu {
                        previewContextMenu(id: id, image: image)
                    }
                #endif
            } else {
                AvgeekEmptyStateView(
                    icon: "photo",
                    title: "Loading...",
                    message: ""
                )
            }
        }
    }

    @ViewBuilder
    private func previewContextMenu(id: UUID, image: PlatformImage) -> some View {
        if let onSave = onSaveToGallery {
            Button {
                onSave(id)
            } label: {
                Label("Save to Image Gallery", systemImage: "photo.badge.plus")
            }
        }

        Button {
            #if os(macOS)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
            #else
            UIPasteboard.general.image = image
            #endif
            showToast(.success("Copied to clipboard"))
        } label: {
            Label("Copy image", systemImage: "doc.on.doc")
        }

        Button {
            #if os(macOS)
            image.saveImageToDownloads(fileName: id.uuidString)
            #else
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                DispatchQueue.main.async {
                    if status == .authorized || status == .limited {
                        PHPhotoLibrary.shared().performChanges {
                            PHAssetChangeRequest.creationRequestForAsset(from: image)
                        }
                    }
                }
            }
            #endif
        } label: {
            Label("Download image", systemImage: "arrow.down")
        }

        Button {
            #if os(macOS)
            image.shareImage()
            #else
            UIPasteboard.general.image = image
            showToast(.success("Copied to clipboard for sharing"))
            #endif
        } label: {
            Label("Share image", systemImage: "square.and.arrow.up")
        }
    }
}
