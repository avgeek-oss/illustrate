// MARK: - PlaygroundCardView.swift

// Card rendering for playground canvas items.
//
// Displays a generated image or video with:
// - Thumbnail/preview loading
// - Selection highlight
// - Context menu actions
// - Drag to reposition
//
// ## Media Loading
// Uses ICloudImageLoader/VideoCache for async loading.
// Shows loading indicator while fetching from iCloud.
//
// ## Context Actions
// - Edit: Open generation form with this as source
// - Create Video: Generate video from this image
// - Combine: Multi-select combine operations
// - Delete: Remove from canvas
//
// ## Performance
// Media loading tasks are tracked and cancelled when the view disappears.
// This prevents memory leaks and stale updates when rapidly panning the
// canvas or navigating between playgrounds.

import AVFoundation
import OSLog
import SwiftData
import SwiftUI

/// Card component for playground canvas items.
struct PlaygroundCardView: View {
    let card: PlaygroundCard
    let scale: CGFloat
    let centerOffset: CGPoint
    var isSelected = false
    var externalDragOffset: CGSize = .zero
    var isLocked = false
    var selectedCardCount = 0
    var canRegenerate = false
    var onMove: ((CGPoint) -> Void)?
    var onSelect: ((EventModifiers) -> Void)?
    var onDelete: (() -> Void)?
    var onEdit: (() -> Void)?
    var onCreateVideo: (() -> Void)?
    var onEditWithMultipleImages: (() -> Void)?
    var onCombineToVideo: (() -> Void)?
    var onDragOffsetChange: ((CGSize) -> Void)?
    var onRegenerate: (() -> Void)?
    var onDuplicate: (() -> Void)?
    var onShowPreview: (() -> Void)?

    @State private var isDragging = false
    @State private var localDragOffset: CGSize = .zero
    @State private var dragStartWorldPosition: CGPoint? = nil
    @State private var loadedImage: PlatformImage?
    @State private var loadedVideoURL: URL?
    @State private var isLoadingMedia = false
    @State private var showExpandedImage = false
    @State private var showCompareImages = false
    @State private var hasClientImage = false
    @State private var imageSize: CGSize = .zero
    @State private var videoSize: CGSize = .zero
    @State private var showCopiedFeedback = false
    @State private var mediaLoadTask: Task<Void, Never>?

    private var screenPosition: CGPoint {
        let baseX = isDragging && dragStartWorldPosition != nil ? dragStartWorldPosition!.x : card.positionX
        let baseY = isDragging && dragStartWorldPosition != nil ? dragStartWorldPosition!.y : card.positionY

        let effectiveDragOffset = externalDragOffset == .zero ? localDragOffset : externalDragOffset

        return CGPoint(
            x: baseX * scale + centerOffset.x + effectiveDragOffset.width,
            y: baseY * scale + centerOffset.y + effectiveDragOffset.height
        )
    }

    var body: some View {
        cardContent
            .scaleEffect(scale)
            .position(screenPosition)
            #if os(macOS)
            .simultaneousGesture(
                TapGesture()
                    .modifiers(.shift)
                    .onEnded { _ in
                        guard !isLocked else { return }
                        onSelect?(.shift)
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .modifiers(.command)
                    .onEnded { _ in
                        guard !isLocked else { return }
                        onSelect?(.command)
                    }
            )
            #endif
            .onTapGesture {
                guard !isLocked else { return }
                onSelect?([])
            }
            .gesture(cardDragGesture)
            .onAppear {
                loadMediaIfNeeded()
            }
            .onDisappear {
                mediaLoadTask?.cancel()
                mediaLoadTask = nil
            }
            .onChange(of: card.generationId) { _, _ in
                loadMediaIfNeeded()
            }
            #if os(macOS)
            .sheet(isPresented: $showExpandedImage) {
                if let genId = card.generationId {
                    ExpandedImageView(
                        imageName: genId.uuidString,
                        isPresented: $showExpandedImage
                    )
                }
            }
            .sheet(isPresented: $showCompareImages) {
                if let genId = card.generationId {
                    CompareImagesView(
                        leftImageName: ".\(genId.uuidString)_client",
                        rightImageName: genId.uuidString,
                        leftLabel: "Source Image",
                        rightLabel: "Generated Image",
                        maskImageName: nil,
                        isPresented: $showCompareImages
                    )
                }
            }
            #else
            .fullScreenCover(isPresented: $showExpandedImage) {
                if let genId = card.generationId {
                    ExpandedImageView(
                        imageName: genId.uuidString,
                        isPresented: $showExpandedImage
                    )
                }
            }
            #endif
            .overlay {
                if showCopiedFeedback {
                    copiedFeedbackOverlay
                }
            }
    }

    // MARK: - Card Content

    @ViewBuilder
    private var cardContent: some View {
        // Use edge-to-edge layout for generated media, standard container for others
        if card.status == .GENERATED, card.cardType == .IMAGE, loadedImage != nil {
            edgeToEdgeImageCard
                .contentShape(Rectangle())
                .contextMenu {
                    contextMenuContent
                }
        } else if card.status == .GENERATED, card.cardType == .VIDEO, loadedVideoURL != nil {
            edgeToEdgeVideoCard
                .contentShape(Rectangle())
                .contextMenu {
                    contextMenuContent
                }
        } else {
            CardContainerView(
                isHovered: isSelected,
                isRunning: card.status == .PROCESSING,
                isErrored: card.status == .FAILED,
                errorMessage: card.errorMessage
            ) {
                CardHeaderView(
                    title: card.cardType == .IMAGE ? "Image" : "Video",
                    icon: card.cardType.icon,
                    iconColor: label,
                    hasGenerationId: card.generationId != nil
                )
            } content: {
                contentView
            } footer: {
                footerView
            }
            .contentShape(Rectangle())
            .contextMenu {
                contextMenuContent
            }
        }
    }

    // MARK: - Edge-to-Edge Image Card

    private var edgeToEdgeImageCard: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "photo")
                    .foregroundStyle(label)
                    .font(.system(size: 13, weight: .semibold))

                Text("Image")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Image content - edge to edge
            if let image = loadedImage {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: calculatedCardWidth, height: calculatedImageHeight)
                    .clipped()
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            imageOverlayButtons
                        }
                    }
                #else
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: calculatedCardWidth, height: calculatedImageHeight)
                    .clipped()
                    .overlay(alignment: .topTrailing) {
                        expandButton
                    }
                #endif
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Text(formatDate(card.createdAt))
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: calculatedCardWidth)
        .background(systemBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ? Color.accentColor.opacity(0.8) : secondaryLabel.opacity(0.2),
                    lineWidth: isSelected ? 2.5 : 1
                )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
    }

    /// Calculate card width based on image aspect ratio (min 250, max 400)
    private var calculatedCardWidth: CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return cardFixedWidth
        }

        let aspectRatio = imageSize.width / imageSize.height

        // For landscape images, use wider cards
        // For portrait images, use narrower cards
        if aspectRatio >= 1.5 {
            return 380 // Wide landscape (16:9, etc.)
        } else if aspectRatio >= 1.2 {
            return 340 // Moderate landscape (4:3, etc.)
        } else if aspectRatio >= 0.9 {
            return 300 // Square-ish
        } else if aspectRatio >= 0.7 {
            return 280 // Moderate portrait (3:4, etc.)
        } else {
            return 250 // Tall portrait (9:16, etc.)
        }
    }

    /// Calculate image height based on aspect ratio
    private var calculatedImageHeight: CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return 200
        }

        let aspectRatio = imageSize.width / imageSize.height
        let height = calculatedCardWidth / aspectRatio

        // Clamp height between reasonable bounds
        return min(max(height, 150), 500)
    }

    // MARK: - Edge-to-Edge Video Card

    private var edgeToEdgeVideoCard: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "video.fill")
                    .foregroundStyle(label)
                    .font(.system(size: 13, weight: .semibold))

                Text("Video")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Video content - edge to edge
            if let videoURL = loadedVideoURL {
                PlaygroundVideoPlayer(url: videoURL)
                    .frame(width: calculatedVideoCardWidth, height: calculatedVideoHeight)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Text(formatDate(card.createdAt))
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: calculatedVideoCardWidth)
        .background(systemBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ? Color.accentColor.opacity(0.8) : secondaryLabel.opacity(0.2),
                    lineWidth: isSelected ? 2.5 : 1
                )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
    }

    /// Calculate video card width based on aspect ratio
    private var calculatedVideoCardWidth: CGFloat {
        guard videoSize.width > 0, videoSize.height > 0 else {
            return cardFixedWidth
        }

        let aspectRatio = videoSize.width / videoSize.height

        // Videos typically are landscape or portrait
        if aspectRatio >= 1.5 {
            return 380 // Wide landscape (16:9, etc.)
        } else if aspectRatio >= 1.2 {
            return 340 // Moderate landscape (4:3, etc.)
        } else if aspectRatio >= 0.9 {
            return 300 // Square-ish
        } else if aspectRatio >= 0.7 {
            return 280 // Moderate portrait (3:4, etc.)
        } else {
            return 250 // Tall portrait (9:16, etc.)
        }
    }

    /// Calculate video height based on aspect ratio
    private var calculatedVideoHeight: CGFloat {
        guard videoSize.width > 0, videoSize.height > 0 else {
            return 200
        }

        let aspectRatio = videoSize.width / videoSize.height
        let height = calculatedVideoCardWidth / aspectRatio

        // Clamp height between reasonable bounds
        return min(max(height, 150), 500)
    }

    @ViewBuilder
    private var contentView: some View {
        switch card.status {
        case .PROCESSING:
            processingView
        case .GENERATED:
            generatedView
        case .FAILED:
            failedView
        }
    }

    // MARK: - Processing View

    private var processingView: some View {
        ShimmerView(cornerRadius: 0)
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .padding(-16)
    }

    // MARK: - Generated View

    @ViewBuilder
    private var generatedView: some View {
        if isLoadingMedia {
            VStack(spacing: 8) {
                GradientSpinner()
                Text("Loading...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
        } else if card.cardType == .IMAGE {
            imageContentView
        } else {
            videoContentView
        }
    }

    @ViewBuilder
    private var imageContentView: some View {
        if let image = loadedImage {
            #if os(macOS)
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 200)
                .cornerRadius(8)
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        imageOverlayButtons
                    }
                }
            #else
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 200)
                .cornerRadius(8)
                .overlay(alignment: .topTrailing) {
                    expandButton
                }
            #endif
        } else {
            emptyMediaPlaceholder(icon: "photo", text: "Image not found")
        }
    }

    @ViewBuilder
    private var videoContentView: some View {
        if let videoURL = loadedVideoURL {
            PlaygroundVideoPlayer(url: videoURL)
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .cornerRadius(8)
        } else {
            emptyMediaPlaceholder(icon: "video.slash", text: "Video not found")
        }
    }

    private func emptyMediaPlaceholder(icon: String, text: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(secondarySystemFill)
        .cornerRadius(8)
    }

    // MARK: - Failed View

    private var failedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.red)
            Text("Generation Failed")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
    }

    // MARK: - Footer View

    private var footerView: some View {
        HStack {
            Spacer()
            Text(formatDate(card.createdAt))
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Just now"
        }
        return date.formatted(.relative(presentation: .named))
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        // Image card options (single or multi-selection)
        if card.cardType == .IMAGE, card.status == .GENERATED, !isLocked {
            // Expand image
            Button {
                showExpandedImage = true
            } label: {
                Label("View image", systemImage: "eye")
            }

            #if os(macOS)
            // Compare with source (if client image exists)
            if hasClientImage {
                Button {
                    showCompareImages = true
                } label: {
                    Label("Compare with Source", systemImage: "rectangle.split.2x1")
                }
            }
            #endif

            Divider()

            // Regenerate - only if no outgoing links
            if canRegenerate {
                Button {
                    onRegenerate?()
                } label: {
                    Label("Regenerate Image", systemImage: "arrow.clockwise")
                }
            }

            // Duplicate card
            Button {
                onDuplicate?()
            } label: {
                Label("Duplicate Card", systemImage: "plus.square.on.square")
            }

            Divider()

            // Edit/Fuse Image - works for single or multiple selected cards
            Button {
                if isSelected, selectedCardCount > 1 {
                    onEditWithMultipleImages?()
                } else {
                    onEdit?()
                }
            } label: {
                if isSelected, selectedCardCount > 1 {
                    Label("Fuse Images (\(selectedCardCount) references)", systemImage: "square.stack.3d.up")
                } else {
                    Label("Edit Image", systemImage: "pencil")
                }
            }

            // Create Video - single card only
            if !isSelected || selectedCardCount <= 1 {
                Button {
                    onCreateVideo?()
                } label: {
                    Label("Convert to Video", systemImage: "video.fill")
                }
            }

            // Combine to Video - exactly 2 cards selected
            if isSelected, selectedCardCount == 2 {
                Button {
                    onCombineToVideo?()
                } label: {
                    Label("Combine to Video", systemImage: "video.badge.plus")
                }
            }

            Divider()

            // Copy image to clipboard
            Button {
                copyImageToClipboard()
            } label: {
                Label("Copy image", systemImage: "doc.on.doc")
            }

            #if os(macOS)
            // Save image with file picker
            Button {
                saveImage()
            } label: {
                Label("Download image", systemImage: "arrow.down.circle")
            }

            // Share image
            Button {
                shareImage()
            } label: {
                Label("Share image", systemImage: "square.and.arrow.up")
            }
            #endif
        }

        // Video card options
        if card.cardType == .VIDEO, card.status == .GENERATED, !isLocked {
            // Regenerate - only if no outgoing links
            if canRegenerate {
                Button {
                    onRegenerate?()
                } label: {
                    Label("Regenerate Video", systemImage: "arrow.clockwise")
                }
            }

            // Duplicate card
            Button {
                onDuplicate?()
            } label: {
                Label("Duplicate Card", systemImage: "plus.square.on.square")
            }

            Divider()

            #if os(macOS)
            // Copy video to clipboard
            Button {
                copyVideoToClipboard()
            } label: {
                Label("Copy video", systemImage: "doc.on.doc")
            }

            // Save video with file picker
            Button {
                saveVideo()
            } label: {
                Label("Download video", systemImage: "arrow.down.circle")
            }

            // Share video
            Button {
                shareVideo()
            } label: {
                Label("Share video", systemImage: "square.and.arrow.up")
            }
            #endif
        }

        // Failed card options
        if card.status == .FAILED, !isLocked {
            // Regenerate failed card (always allowed for failed cards)
            Button {
                onRegenerate?()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }

            Divider()

            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Delete Card", systemImage: "trash")
            }
        }
    }

    // MARK: - Media Loading

    private func loadMediaIfNeeded() {
        guard let genId = card.generationId else {
            loadedImage = nil
            loadedVideoURL = nil
            imageSize = .zero
            videoSize = .zero
            return
        }

        mediaLoadTask?.cancel()
        isLoadingMedia = true

        let genIdString = genId.uuidString
        let cardType = card.cardType

        mediaLoadTask = Task.detached(priority: .userInitiated) {
            guard !Task.isCancelled else { return }

            if cardType == .IMAGE {
                let image = loadImageFromDocumentsDirectory(withName: genIdString)
                guard !Task.isCancelled else { return }

                let clientImageName = ".\(genIdString)_client"
                let clientExists = loadImageFromDocumentsDirectory(withName: clientImageName) != nil
                    || loadImageFromiCloud(clientImageName) != nil

                let size: CGSize = image?.size ?? .zero
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    loadedImage = image
                    imageSize = size
                    hasClientImage = clientExists
                    isLoadingMedia = false
                }
            } else {
                let fileManager = FileManager.default
                var foundVideoURL: URL? = nil
                var size: CGSize = .zero

                if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let url = documentsURL.appendingPathComponent("\(genIdString).mp4")
                    if fileManager.fileExists(atPath: url.path) {
                        foundVideoURL = url
                        guard !Task.isCancelled else { return }

                        let asset = AVURLAsset(url: url)
                        if let track = try? await asset.loadTracks(withMediaType: .video).first {
                            let naturalSize = try? await track.load(.naturalSize)
                            let transform = try? await track.load(.preferredTransform)
                            if let naturalSize {
                                if let transform {
                                    let isRotated = transform.a == 0 && transform.d == 0
                                    size = isRotated
                                        ? CGSize(width: naturalSize.height, height: naturalSize.width)
                                        : naturalSize
                                } else {
                                    size = naturalSize
                                }
                            }
                        }
                    }
                }

                guard !Task.isCancelled else { return }

                let finalVideoURL = foundVideoURL
                let finalSize = size
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    loadedVideoURL = finalVideoURL
                    videoSize = finalSize
                    isLoadingMedia = false
                }
            }
        }
    }

    // MARK: - Image Actions

    private func copyImageToClipboard() {
        guard let image = loadedImage else { return }

        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        #else
        UIPasteboard.general.image = image
        #endif

        showCopiedFeedbackBriefly()
    }

    private func showCopiedFeedbackBriefly() {
        withAnimation(.easeIn(duration: 0.2)) {
            showCopiedFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showCopiedFeedback = false
            }
        }
    }

    private var copiedFeedbackOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Copied!")
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.8))
            )
            .foregroundStyle(.white)
            Spacer()
        }
        .transition(.opacity)
    }

    #if os(macOS)
    private func saveImage() {
        guard let image = loadedImage, let genId = card.generationId else { return }
        image.saveImageToDownloads(fileName: genId.uuidString)
    }

    private func shareImage() {
        guard let image = loadedImage else { return }
        image.shareImage()
    }
    #endif

    // MARK: - Video Actions

    #if os(macOS)
    private func copyVideoToClipboard() {
        guard let videoURL = loadedVideoURL else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([videoURL as NSURL])

        showCopiedFeedbackBriefly()
    }

    private func saveVideo() {
        guard let videoURL = loadedVideoURL, let genId = card.generationId else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.mpeg4Movie]
        savePanel.nameFieldStringValue = "\(genId.uuidString).mp4"
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            if response == .OK, let destinationURL = savePanel.url {
                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(at: videoURL, to: destinationURL)
                } catch {
                    AppLogger.storage.error("Failed to save video: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func shareVideo() {
        guard let videoURL = loadedVideoURL else { return }

        let picker = NSSharingServicePicker(items: [videoURL])
        if let window = NSApp.keyWindow, let contentView = window.contentView {
            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
        }
    }
    #endif

    // MARK: - Image Overlay Buttons

    #if os(macOS)
    private var imageOverlayButtons: some View {
        HStack(spacing: 6) {
            if hasClientImage {
                Button {
                    showCompareImages = true
                } label: {
                    Image(systemName: "rectangle.split.2x1")
                        .font(.callout)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.5))
                        )
                }
                .buttonStyle(.plain)
            }

            Button {
                showExpandedImage = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.5))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(8)
    }
    #endif

    private var expandButton: some View {
        Button {
            showExpandedImage = true
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.callout)
                .foregroundStyle(.white)
                .padding(8)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.5))
                )
        }
        .buttonStyle(.plain)
        .padding(8)
    }

    // MARK: - Drag Gesture

    private var cardDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isLocked else { return }

                if !isDragging {
                    dragStartWorldPosition = CGPoint(x: card.positionX, y: card.positionY)
                }
                isDragging = true
                localDragOffset = value.translation
                onDragOffsetChange?(value.translation)
            }
            .onEnded { value in
                guard !isLocked else { return }
                isDragging = false
                localDragOffset = .zero

                let startX = dragStartWorldPosition?.x ?? card.positionX
                let startY = dragStartWorldPosition?.y ?? card.positionY
                let newWorldX = startX + value.translation.width / scale
                let newWorldY = startY + value.translation.height / scale

                onDragOffsetChange?(.zero)
                onMove?(CGPoint(x: newWorldX, y: newWorldY))

                dragStartWorldPosition = nil
            }
    }
}

// MARK: - Video Player

private struct PlaygroundVideoPlayer: View {
    let url: URL

    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                SafeVideoPlayer(player: player)
                    .onDisappear {
                        player.pause()
                    }
            } else {
                Rectangle()
                    .fill(secondarySystemFill)
                    .overlay {
                        GradientSpinner()
                    }
            }
        }
        .onAppear {
            player = AVPlayer(url: url)
        }
    }
}
