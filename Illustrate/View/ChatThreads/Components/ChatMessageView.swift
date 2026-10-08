// MARK: - ChatMessageView.swift

// Component for displaying a single chat message with generated images.
//
// ChatMessageView renders a message in the conversation, showing:
// - The user's prompt text
// - Generated images in a grid layout
// - Loading state while generating
// - Error state if generation failed
//
// ## Image Loading
// Uses async image loading from documents directory,
// similar to PlaygroundCardView pattern.
//
// ## Disassociate Feature
// Users can disassociate images from the latest message to reduce
// the number of reference images for future generations.
//
// ## Performance
// Image loading tasks are tracked and cancelled when the view disappears.
// This prevents memory leaks and stale updates when rapidly scrolling or
// navigating between threads.

import SwiftUI

/// Component displaying a single chat message with generated images.
struct ChatMessageView: View {
    let message: ChatMessage
    let expectedImageCount: Int
    let isLatestMessage: Bool
    let canDisassociate: Bool
    let canBranch: Bool
    let canDelete: Bool
    let onDisassociate: ((UUID) -> Void)?
    let onBranch: (() -> Void)?
    let onDelete: (() -> Void)?

    @State private var loadedImages: [UUID: PlatformImage] = [:]
    @State private var isLoadingImages = false
    @State private var hoveredImageId: UUID?
    @State private var showImages = false
    @State private var selectedImageId: UUID?
    @State private var compareImageId: UUID?
    @State private var hasClientImage: [UUID: Bool] = [:]
    @State private var isHovered = false
    @State private var imageLoadTask: Task<Void, Never>?

    private var modelName: String? {
        let modelId = message.imageGenerationConfiguration.selectedModelId
        guard !modelId.isEmpty else { return nil }
        return ProviderService.shared.model(by: modelId)?.modelName
    }

    private var providerCode: String? {
        let providerId = message.imageGenerationConfiguration.selectedProviderId
        guard !providerId.isEmpty,
              let uuid = UUID(uuidString: providerId),
              let provider = providersById[uuid]
        else { return nil }
        return provider.providerCode.rawValue
    }

    init(
        message: ChatMessage,
        expectedImageCount: Int = 4,
        isLatestMessage: Bool = false,
        canDisassociate: Bool = false,
        canBranch: Bool = false,
        canDelete: Bool = false,
        onDisassociate: ((UUID) -> Void)? = nil,
        onBranch: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.message = message
        self.expectedImageCount = expectedImageCount
        self.isLatestMessage = isLatestMessage
        self.canDisassociate = canDisassociate
        self.canBranch = canBranch
        self.canDelete = canDelete
        self.onDisassociate = onDisassociate
        self.onBranch = onBranch
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Prompt bubble
            promptBubble

            // Content based on status
            switch message.status {
            case .PROCESSING:
                processingView
            case .GENERATED:
                generatedImagesView
            case .FAILED:
                failedView
            }

            // Reference media section (shown below generated images)
            if message.status == .GENERATED, !message.generationIds.isEmpty {
                ChatReferenceMediaSection(generationIdsData: message.generationIdsData)
            }

            // Provider, model name and timestamp
            HStack(spacing: 6) {
                if let providerCode {
                    Image(providerArtworkName(code: providerCode, variant: .square))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .opacity(0.6)
                }
                if let modelName {
                    Text(modelName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(formatDate(message.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(isHovered ? tertiarySystemFill : secondarySystemFill)
        .cornerRadius(12)
        .onAppear {
            loadImagesIfNeeded()
        }
        .onDisappear {
            cancelImageLoading()
        }
        .onChange(of: message.generationIdsData) { _, _ in
            loadImagesIfNeeded()
        }
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            messageContextMenu
        }
        .sheet(item: $selectedImageId) { imageId in
            ExpandedImageView(
                imageName: imageId.uuidString,
                isPresented: Binding(
                    get: { selectedImageId != nil },
                    set: { if !$0 { selectedImageId = nil } }
                )
            )
        }
        .sheet(item: $compareImageId) { imageId in
            CompareImagesView(
                leftImageName: ".\(imageId.uuidString)_client",
                rightImageName: imageId.uuidString,
                leftLabel: "Source Image",
                rightLabel: "Generated Image",
                maskImageName: nil,
                isPresented: Binding(
                    get: { compareImageId != nil },
                    set: { if !$0 { compareImageId = nil } }
                )
            )
        }
        #else
        .contextMenu {
            messageContextMenu
        }
        .fullScreenCover(item: $selectedImageId) { imageId in
            ExpandedImageView(
                imageName: imageId.uuidString,
                isPresented: Binding(
                    get: { selectedImageId != nil },
                    set: { if !$0 { selectedImageId = nil } }
                )
            )
        }
        #endif
    }

    // MARK: - Message Context Menu

    @ViewBuilder
    private var messageContextMenu: some View {
        Button {
            let text = message.prompt
            #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            #else
            UIPasteboard.general.string = text
            #endif
            showToast(.success("Copied to clipboard"))
        } label: {
            Label("Copy Message", systemImage: "doc.on.doc")
        }

        if canBranch {
            Divider()

            Button {
                onBranch?()
            } label: {
                Label("Branch from here", systemImage: "arrow.triangle.branch")
            }
        }

        if canDelete {
            if canBranch {
                Divider()
            }

            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Remove Message", systemImage: "trash")
            }
        }
    }

    // MARK: - Prompt Bubble

    private var promptBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            Text(message.prompt)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }

    // MARK: - Processing View (Shows images + shimmers for pending)

    private var processingView: some View {
        progressiveImagesGrid
    }

    private var progressiveImagesGrid: some View {
        let totalCount = message.generationIds.count + message.pendingCount
        let columns = totalCount == 1
            ? [GridItem(.flexible(), spacing: 12)]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return LazyVGrid(columns: columns, spacing: 12) {
            // Show completed images first
            ForEach(message.generationIds, id: \.self) { genId in
                if let image = loadedImages[genId] {
                    imageCell(image: image, genId: genId)
                        .transition(.opacity)
                } else {
                    // Image still loading from disk
                    ShimmerView(delay: 0)
                        .aspectRatio(1, contentMode: .fit)
                        .cornerRadius(8)
                }
            }

            // Show shimmers for pending generations
            ForEach(0 ..< message.pendingCount, id: \.self) { index in
                ShimmerView(delay: Double(index) * 0.1)
                    .aspectRatio(1, contentMode: .fit)
                    .cornerRadius(8)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: message.generationIds.count)
        .animation(.easeInOut(duration: 0.3), value: message.pendingCount)
    }

    // MARK: - Generated Images View

    @ViewBuilder
    private var generatedImagesView: some View {
        // Don't show shimmer for already-generated images loading from disk.
        // Shimmer is reserved for active generation (processing state).
        // Instead, just fade in the images when ready.
        if loadedImages.isEmpty, !isLoadingImages {
            emptyImagesPlaceholder
        } else if !loadedImages.isEmpty {
            imagesGrid
                .opacity(showImages ? 1 : 0)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.3)) {
                        showImages = true
                    }
                }
        }
    }

    private var emptyImagesPlaceholder: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title3)
                .foregroundStyle(.tertiary)
            Text("Images not found")
                .font(.callout)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.vertical, 12)
    }

    private var imagesGrid: some View {
        let columns = adaptiveColumns(for: loadedImages.count)

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(message.generationIds, id: \.self) { genId in
                if let image = loadedImages[genId] {
                    imageCell(image: image, genId: genId)
                }
            }
        }
    }

    private func adaptiveColumns(for count: Int) -> [GridItem] {
        switch count {
        case 1:
            [GridItem(.flexible(), spacing: 12)]
        case 2:
            [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        default:
            [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        }
    }

    @ViewBuilder
    private func imageCell(image: PlatformImage, genId: UUID) -> some View {
        let isHovered = hoveredImageId == genId
        let genHasClientImage = hasClientImage[genId] ?? false

        #if os(macOS)
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: isHovered ? 2 : 0)
            )
            .overlay(alignment: .topTrailing) {
                if isHovered {
                    imageOverlayButtons(genId: genId, hasSource: genHasClientImage)
                }
            }
            .onHover { hovering in
                hoveredImageId = hovering ? genId : nil
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedImageId = genId
            }
            .contextMenu {
                imageContextMenu(genId: genId, hasSource: genHasClientImage)
            }
        #else
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .cornerRadius(8)
            .overlay(alignment: .topTrailing) {
                expandButton(genId: genId)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedImageId = genId
            }
            .contextMenu {
                imageContextMenu(genId: genId, hasSource: genHasClientImage)
            }
        #endif
    }

    @ViewBuilder
    private func imageContextMenu(genId: UUID, hasSource: Bool) -> some View {
        Button {
            selectedImageId = genId
        } label: {
            Label("View image", systemImage: "eye")
        }

        #if os(macOS)
        if hasSource {
            Button {
                compareImageId = genId
            } label: {
                Label("Compare with Source", systemImage: "rectangle.split.2x1")
            }
        }
        #endif

        Divider()

        Button {
            copyImageToClipboard(genId: genId)
        } label: {
            Label("Copy image", systemImage: "doc.on.doc")
        }

        #if os(macOS)
        Button {
            saveImage(genId: genId)
        } label: {
            Label("Download image", systemImage: "arrow.down.circle")
        }

        Button {
            shareImage(genId: genId)
        } label: {
            Label("Share image", systemImage: "square.and.arrow.up")
        }
        #endif

        // Disassociate option - only for latest message with more than 1 image
        if isLatestMessage, canDisassociate, message.generationIds.count > 1 {
            Divider()

            Button(role: .destructive) {
                onDisassociate?(genId)
            } label: {
                Label("Disassociate from Thread", systemImage: "minus.circle")
            }
        }
    }

    #if os(macOS)
    private func imageOverlayButtons(genId: UUID, hasSource: Bool) -> some View {
        HStack(spacing: 6) {
            if hasSource {
                Button {
                    compareImageId = genId
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
                selectedImageId = genId
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

    private func expandButton(genId: UUID) -> some View {
        Button {
            selectedImageId = genId
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

    // MARK: - Failed View

    private var failedView: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 2) {
                Text("Generation Failed")
                    .font(.callout)
                    .fontWeight(.medium)
                if let errorMessage = message.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Image Loading

    private func loadImagesIfNeeded() {
        let genIds = message.generationIds
        guard !genIds.isEmpty else { return }

        let newIds = genIds.filter { loadedImages[$0] == nil }
        guard !newIds.isEmpty else {
            isLoadingImages = false
            return
        }

        imageLoadTask?.cancel()

        isLoadingImages = true
        if message.status == .GENERATED {
            showImages = false
        }

        imageLoadTask = Task.detached(priority: .userInitiated) {
            var newlyLoadedImages: [UUID: PlatformImage] = [:]
            var clientImageStatus: [UUID: Bool] = [:]

            for genId in newIds {
                guard !Task.isCancelled else { return }

                if let image = loadImageFromDocumentsDirectory(withName: genId.uuidString) {
                    newlyLoadedImages[genId] = image
                }

                let clientImageName = ".\(genId.uuidString)_client"
                let clientExists = loadImageFromDocumentsDirectory(withName: clientImageName) != nil
                    || loadImageFromiCloud(clientImageName) != nil
                clientImageStatus[genId] = clientExists
            }

            guard !Task.isCancelled else { return }

            let loadedImagesResult = newlyLoadedImages
            let clientImageStatusResult = clientImageStatus

            await MainActor.run {
                guard !Task.isCancelled else { return }

                for (id, image) in loadedImagesResult {
                    loadedImages[id] = image
                }
                for (id, exists) in clientImageStatusResult {
                    hasClientImage[id] = exists
                }
                isLoadingImages = false
            }
        }
    }

    private func cancelImageLoading() {
        imageLoadTask?.cancel()
        imageLoadTask = nil
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Just now"
        }
        return date.formatted(.relative(presentation: .named))
    }

    private func copyImageToClipboard(genId: UUID) {
        guard let image = loadedImages[genId] else { return }

        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        #else
        UIPasteboard.general.image = image
        #endif
        showToast(.success("Copied to clipboard"))
    }

    #if os(macOS)
    private func saveImage(genId: UUID) {
        guard let image = loadedImages[genId] else { return }
        image.saveImageToDownloads(fileName: genId.uuidString)
    }

    private func shareImage(genId: UUID) {
        guard let image = loadedImages[genId] else { return }
        image.shareImage()
    }
    #endif
}

// MARK: - Chat Reference Media Section

/// Displays reference media (source and reference images) used in chat generations.
/// Shows a collapsible horizontal scroll of thumbnails below the generated images.
struct ChatReferenceMediaSection: View {
    /// Raw data for generation IDs - using Data instead of [UUID] to avoid
    /// infinite re-renders from computed property creating new arrays
    let generationIdsData: Data?

    @State private var isExpanded = false
    @State private var referenceMedia: [ReferenceMediaEntry] = []
    @State private var hasLoaded = false

    /// Decode generation IDs from data
    private var generationIds: [UUID] {
        guard let data = generationIdsData,
              let ids = try? JSONDecoder().decode([UUID].self, from: data)
        else {
            return []
        }
        return ids
    }

    private var hasAnyMedia: Bool {
        !referenceMedia.isEmpty
    }

    var body: some View {
        Group {
            if hasAnyMedia {
                VStack(alignment: .leading, spacing: 8) {
                    // Header with toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("Reference Media")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)

                            Text("(\(referenceMedia.count))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)

                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)

                    // Expandable content
                    if isExpanded {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(referenceMedia) { entry in
                                    ChatReferenceMediaItem(entry: entry)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.top, 4)
            }
        }
        .task(id: generationIdsData) {
            await loadReferenceMedia()
        }
    }

    private func loadReferenceMedia() async {
        let genIds = generationIds
        let media = await Task.detached(priority: .userInitiated) {
            var entries: [ReferenceMediaEntry] = []

            for genId in genIds {
                let genIdString = genId.uuidString

                // Check for client/source image
                let clientImageName = ".\(genIdString)_client"
                if let clientImage = loadImageFromDocumentsDirectory(withName: clientImageName)
                    ?? loadImageFromiCloud(clientImageName)
                {
                    entries.append(ReferenceMediaEntry(
                        id: UUID(),
                        image: clientImage,
                        label: "Source",
                        generationId: genId
                    ))
                }

                // Check for reference images (up to 10)
                for i in 0 ..< 10 {
                    let refImageName = ".\(genIdString)_ref\(i)"
                    if let refImage = loadImageFromDocumentsDirectory(withName: refImageName)
                        ?? loadImageFromiCloud(refImageName)
                    {
                        entries.append(ReferenceMediaEntry(
                            id: UUID(),
                            image: refImage,
                            label: "Ref \(i + 1)",
                            generationId: genId
                        ))
                    } else {
                        break
                    }
                }
            }

            return entries
        }.value

        await MainActor.run {
            referenceMedia = media
            hasLoaded = true
        }
    }
}

/// Entry representing a single reference media item
struct ReferenceMediaEntry: Identifiable {
    let id: UUID
    let image: PlatformImage
    let label: String
    let generationId: UUID
}

/// Individual reference media thumbnail
struct ChatReferenceMediaItem: View {
    let entry: ReferenceMediaEntry

    var body: some View {
        VStack(spacing: 4) {
            #if os(macOS)
            Image(nsImage: entry.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.15), radius: 2)
            #else
            Image(uiImage: entry.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.15), radius: 2)
            #endif

            Text(entry.label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
