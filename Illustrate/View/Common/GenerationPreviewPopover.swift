// MARK: - GenerationPreviewPopover.swift

// Popover preview for generated images and videos.
//
// A compact preview popover that shows the generated media
// with a "More details" button to navigate to the full detail view.
// Designed for macOS to reduce unnecessary navigation.
//
// ## Features
// - Full-resolution image preview (with thumbnail fallback)
// - Media-specific button labels for full navigation
// - "Open in New Window" for separate window view
// - Compact design optimized for popovers
//
// ## Usage
// ```swift
// Button("Preview") { showPopover = true }
//     .popover(isPresented: $showPopover) {
//         GenerationPreviewPopover(
//             setId: generation.setId,
//             generationId: generation.id,
//             isVideo: generation.contentType == .VIDEO,
//             isPresented: $showPopover,
//             onNavigateToDetails: { /* navigate */ }
//         )
//     }
// ```

import SwiftData
import SwiftUI

/// Compact popover preview for generated images and videos.
/// Uses synchronous image loading to avoid race conditions in popovers.
struct GenerationPreviewPopover: View {
    let setId: UUID
    let generationId: UUID?
    let isVideo: Bool
    @Binding var isPresented: Bool
    var onNavigateToDetails: (() -> Void)?

    /// Image loaded on appear (synchronously)
    @State private var loadedImage: PlatformImage?
    @State private var hasAttemptedLoad = false

    /// Original image name for clear preview display.
    private var originalImageName: String? {
        generationId?.uuidString
    }

    /// Optimized thumbnail image name (fallback when original is unavailable)
    private var thumbnailImageName: String? {
        guard let id = generationId?.uuidString else { return nil }
        return ".\(id)_o50"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Preview content
            previewContent
                .frame(width: 320)

            Divider()

            // Actions
            HStack(spacing: 12) {
                Button {
                    copyOutputToClipboard()
                } label: {
                    Text(isVideo ? "Copy video" : "Copy image")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    navigateToDetails()
                } label: {
                    Text(isVideo ? "View video" : "View image")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(12)
        }
        .frame(width: 320)
        .onAppear {
            loadImageSynchronously()
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        if let image = loadedImage {
            if isVideo {
                videoPreview(image: image)
            } else {
                imagePreview(image: image)
            }
        } else if hasAttemptedLoad {
            previewPlaceholder
        } else {
            // Loading state
            VStack(spacing: 8) {
                GradientSpinner()
                Text("Loading...")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 320, height: 200)
        }
    }

    /// Load image synchronously on main thread - safe for popovers
    private func loadImageSynchronously() {
        // Prefer the original for previews. The thumbnail is only a fallback.
        let imageNames = [originalImageName, thumbnailImageName].compactMap { $0 }

        guard !imageNames.isEmpty else {
            hasAttemptedLoad = true
            return
        }

        for imageName in imageNames {
            // Check cache first
            if let cached = ImageCache.shared.get(forKey: imageName) {
                loadedImage = cached
                hasAttemptedLoad = true
                return
            }

            // Load from disk synchronously (safe, no race conditions)
            if let image = loadImageFromiCloud(imageName) {
                loadedImage = image
                // Cache it for next time
                ImageCache.shared.set(image, forKey: imageName)
                hasAttemptedLoad = true
                return
            }
        }

        hasAttemptedLoad = true
    }

    @ViewBuilder
    private func imagePreview(image: PlatformImage) -> some View {
        #if os(macOS)
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
        #else
        Image(uiImage: image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
        #endif
    }

    private func videoPreview(image: PlatformImage) -> some View {
        ZStack {
            #if os(macOS)
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
            #else
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
            #endif

            // Play icon overlay
            Circle()
                .fill(.black.opacity(0.5))
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .offset(x: 2)
                }
        }
    }

    private var previewPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: isVideo ? "play.rectangle" : "photo")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Preview not available")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(width: 320, height: 200)
    }

    private func navigateToDetails() {
        isPresented = false
        onNavigateToDetails?()
    }

    private func copyOutputToClipboard() {
        guard let image = loadedImage else { return }

        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        #else
        UIPasteboard.general.image = image
        #endif

        isPresented = false
        showToast(.success("Copied to clipboard"))
    }
}

// MARK: - Helper Initializer

extension GenerationPreviewPopover {
    /// Initialize with setId only - generationId will be looked up
    init(setId: UUID, isVideo: Bool, isPresented: Binding<Bool>, onNavigateToDetails: (() -> Void)? = nil) {
        self.setId = setId
        generationId = nil
        self.isVideo = isVideo
        _isPresented = isPresented
        self.onNavigateToDetails = onNavigateToDetails
    }

    /// Initialize with explicit generationId for faster preview loading
    init(
        setId: UUID,
        generationId: UUID,
        isVideo: Bool,
        isPresented: Binding<Bool>,
        onNavigateToDetails: (() -> Void)? = nil
    ) {
        self.setId = setId
        self.generationId = generationId
        self.isVideo = isVideo
        _isPresented = isPresented
        self.onNavigateToDetails = onNavigateToDetails
    }
}

// MARK: - Fetching GenerationId Wrapper

/// A wrapper that fetches the generationId from the setId if not provided
struct GenerationPreviewPopoverWithFetch: View {
    @Environment(\.modelContext) private var modelContext

    let setId: UUID
    let isVideo: Bool
    @Binding var isPresented: Bool
    var onNavigateToDetails: (() -> Void)?

    @State private var generationId: UUID?

    var body: some View {
        GenerationPreviewPopover(
            setId: setId,
            generationId: generationId ?? setId,
            isVideo: isVideo,
            isPresented: $isPresented,
            onNavigateToDetails: onNavigateToDetails
        )
        .onAppear {
            loadGenerationId()
        }
    }

    private func loadGenerationId() {
        // First try cache (fast path)
        let cache = GalleryCache.shared
        if cache.isLoaded {
            let generations = isVideo ? cache.videoGenerations : cache.imageGenerations
            if let gen = generations.first(where: { $0.setId == setId }) {
                generationId = gen.id
                return
            }
        }

        // Fallback: Query SwiftData directly when cache doesn't have it
        let targetSetId = setId
        let descriptor = FetchDescriptor<Generation>(
            predicate: #Predicate { $0.setId == targetSetId }
        )

        if let generation = try? modelContext.fetch(descriptor).first {
            generationId = generation.id
        }
    }
}

// MARK: - Fetching SetId from GenerationId Wrapper

/// A wrapper that fetches the setId from the generationId
/// Used when we have a generationId but need to navigate to the detail view
struct GenerationPreviewPopoverFromGenerationId: View {
    @Environment(\.modelContext) private var modelContext

    let generationId: UUID
    @Binding var isPresented: Bool
    var onNavigateToDetails: ((UUID, Bool) -> Void)?

    @State private var setId: UUID?
    @State private var isVideo = false
    @State private var isLoaded = false

    var body: some View {
        Group {
            if let setId, isLoaded {
                GenerationPreviewPopover(
                    setId: setId,
                    generationId: generationId,
                    isVideo: isVideo,
                    isPresented: $isPresented,
                    onNavigateToDetails: {
                        onNavigateToDetails?(setId, isVideo)
                    }
                )
            } else if isLoaded {
                // Loaded but not found
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                    Text("Unable to load")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 320, height: 200)
            } else {
                // Still loading
                VStack(spacing: 8) {
                    GradientSpinner()
                    Text("Loading...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 320, height: 200)
            }
        }
        .onAppear {
            loadSetId()
        }
    }

    private func loadSetId() {
        // First try cache (fast path)
        let cache = GalleryCache.shared
        if cache.isLoaded {
            // Check image generations
            if let gen = cache.imageGenerations.first(where: { $0.id == generationId }) {
                setId = gen.setId
                isVideo = gen.contentType == .VIDEO
                isLoaded = true
                return
            }
            // Check video generations
            if let gen = cache.videoGenerations.first(where: { $0.id == generationId }) {
                setId = gen.setId
                isVideo = true
                isLoaded = true
                return
            }
        }

        // Fallback: Query SwiftData directly when cache isn't loaded
        let genId = generationId
        let descriptor = FetchDescriptor<Generation>(
            predicate: #Predicate { $0.id == genId }
        )

        if let generation = try? modelContext.fetch(descriptor).first {
            setId = generation.setId
            isVideo = generation.contentType == .VIDEO
        }

        isLoaded = true
    }
}
