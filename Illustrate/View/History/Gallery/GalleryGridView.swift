// MARK: - GalleryGridView.swift

// Grid view for displaying generated images and videos.
//
// GalleryGridView renders a responsive grid of generation thumbnails.
// It supports both images and videos with different visual treatments.
//
// ## Display Modes
// - Fit: Maintain aspect ratio, show full image
// - Fill: Crop to fill square cells
//
// ## Thumbnail Loading
// Uses ICloudImageLoader to asynchronously load thumbnails from
// iCloud. Thumbnails are pre-cached by GalleryCache.
//
// ## Multi-Selection (macOS)
// - Cmd+click: Toggle individual selection
// - Shift+click: Range selection from last selected to clicked item
// - Right-click context menu: Delete selected items
//
// ## Navigation
// Tapping a cell navigates to GenerationImageView or GenerationVideoView
// for full details and actions.

import IllustrateProviders
import SwiftData
import SwiftUI

#if !os(macOS)
import Photos
import UIKit
#endif

struct GalleryGridView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigationManager: NavigationManager

    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    let sets: [ImageSet]
    let generations: [Generation]
    let contentType: EnumGenerationContentType
    let availableWidth: CGFloat
    let displayMode: GalleryDisplayMode
    private let providerService = ProviderService.shared

    // MARK: - Multi-Selection State

    @State private var selectedGenerationIds: Set<UUID> = []
    @State private var lastSelectedIndex: Int? = nil
    @State private var showDeleteConfirmation = false

    // MARK: - Quick Preview State

    @State private var expandedGenerationId: UUID? = nil

    /// Filtered generations for this content type
    private var filteredGenerations: [Generation] {
        generations
    }

    private func aspectRatio(for generation: Generation) -> CGFloat {
        let dims = generation.dimensions

        if dims.contains(":") {
            let parts = dims.split(separator: ":")
            guard parts.count == 2,
                  let width = Double(parts[0]),
                  let height = Double(parts[1]),
                  height > 0
            else {
                return 1.0
            }
            return CGFloat(width / height)
        }

        let parts = dims.split(separator: "x")
        guard parts.count == 2,
              let width = Double(parts[0]),
              let height = Double(parts[1]),
              height > 0
        else {
            return 1.0
        }
        return CGFloat(width / height)
    }

    private func columns(for width: CGFloat) -> [GridItem] {
        #if os(macOS)
        var columnCount = 6
        if width < 600 {
            columnCount = 2
        } else if width < 900 {
            columnCount = 4
        }
        return Array(repeating: GridItem(.flexible(), spacing: 2), count: columnCount)
        #else
        return Array(
            repeating: GridItem(.flexible(), spacing: 2),
            count: UIDevice.current.userInterfaceIdiom == .pad ? 4 : 2
        )
        #endif
    }

    // MARK: - Selection Handling

    #if os(macOS)
    private func handleSelection(for generation: Generation, at index: Int, with event: NSEvent) {
        let isCommandPressed = event.modifierFlags.contains(.command)
        let isShiftPressed = event.modifierFlags.contains(.shift)

        if isShiftPressed, let lastIndex = lastSelectedIndex {
            // Shift+click: Range selection
            let range = min(lastIndex, index) ... max(lastIndex, index)
            for i in range {
                selectedGenerationIds.insert(filteredGenerations[i].id)
            }
        } else if isCommandPressed {
            // Cmd+click: Toggle selection
            if selectedGenerationIds.contains(generation.id) {
                selectedGenerationIds.remove(generation.id)
            } else {
                selectedGenerationIds.insert(generation.id)
            }
            lastSelectedIndex = index
        } else {
            // Regular click: Clear selection and select this one (or navigate)
            // If clicking on a selected item with multiple selections, keep selection for context menu
            if selectedGenerationIds.count > 1, selectedGenerationIds.contains(generation.id) {
                // Keep current selection
            } else {
                selectedGenerationIds.removeAll()
                lastSelectedIndex = index
            }
        }
    }
    #endif

    private func clearSelection() {
        selectedGenerationIds.removeAll()
        lastSelectedIndex = nil
    }

    // MARK: - Deletion

    private func deleteSelectedGenerations() async {
        let idsToDelete = selectedGenerationIds
        var setIdsToCheck: Set<UUID> = []
        var setIdsToDelete: Set<UUID> = []

        // Collect setIds and delete generations
        for generation in filteredGenerations where idsToDelete.contains(generation.id) {
            setIdsToCheck.insert(generation.setId)
            modelContext.delete(generation)
            deleteICloudDocuments(containingSubstring: generation.id.uuidString)
        }

        // Check if any ImageSets are now empty and delete them
        for setId in setIdsToCheck {
            let remainingGenerations = generations.filter { $0.setId == setId && !idsToDelete.contains($0.id) }
            if remainingGenerations.isEmpty {
                if let imageSet = sets.first(where: { $0.id == setId }) {
                    modelContext.delete(imageSet)
                    setIdsToDelete.insert(setId)
                }
            }
        }

        try? modelContext.save()

        // Update the gallery cache directly instead of invalidating
        GalleryCache.shared.removeGenerations(ids: idsToDelete)
        if !setIdsToDelete.isEmpty {
            GalleryCache.shared.removeImageSets(ids: setIdsToDelete)
        }

        await MainActor.run {
            selectedGenerationIds.removeAll()
            lastSelectedIndex = nil
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenu(for generation: Generation) -> some View {
        let selectedCount = selectedGenerationIds.count
        let isInSelection = selectedGenerationIds.contains(generation.id)
        let mediaKind = generation.contentType == .VIDEO ? "video" : "image"

        if selectedCount > 1, isInSelection {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete \(selectedCount) Items", systemImage: "trash")
            }

            Divider()

            Button {
                clearSelection()
            } label: {
                Label("Clear Selection", systemImage: "xmark.circle")
            }
        } else {
            Button {
                let destination: EnumNavigationItem = generation.contentType == .IMAGE_2D
                    ? .generationImage(setId: generation.setId)
                    : .generationVideo(setId: generation.setId)
                navigationManager.pushDetail(destination)
            } label: {
                Label("View \(mediaKind)", systemImage: "eye")
            }

            if generation.contentType == .IMAGE_2D {
                Button {
                    if let image = loadImageFromiCloud(generation.id.uuidString) {
                        #if os(macOS)
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.writeObjects([image])
                        #else
                        UIPasteboard.general.image = image
                        #endif
                        showToast(.success("Copied to clipboard"))
                    }
                } label: {
                    Label("Copy image", systemImage: "doc.on.doc")
                }

                Button {
                    if let image = loadImageFromiCloud(generation.id.uuidString) {
                        #if os(macOS)
                        image.saveImageToDownloads(fileName: generation.id.uuidString)
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
                    }
                } label: {
                    Label("Download image", systemImage: "arrow.down")
                }
            }

            Button {
                if generation.contentType == .IMAGE_2D {
                    if let image = loadImageFromiCloud(generation.id.uuidString) {
                        #if os(macOS)
                        image.shareImage()
                        #else
                        navigationManager.detailNavigationItem = .generationImage(setId: generation.setId)
                        #endif
                    }
                } else {
                    if let videoURL = loadVideoFromiCloud(generation.id.uuidString) {
                        #if os(macOS)
                        shareVideo(url: videoURL)
                        #endif
                    }
                }
            } label: {
                Label("Share \(mediaKind)", systemImage: "square.and.arrow.up")
            }

            if generation.contentType == .VIDEO,
               hasCompatibleVideoExtendModel(for: generation)
            {
                Button {
                    navigateToVideoExtend(generation: generation)
                } label: {
                    Label(videoExtendActionTitle(for: generation), systemImage: "wand.and.sparkles")
                }
            }

            #if os(macOS)
            Button {
                let windowData = GenerationWindowData(
                    isVideo: generation.contentType == .VIDEO,
                    setId: generation.setId
                )
                openWindow(value: windowData)
            } label: {
                Label("Open in New Window", systemImage: "macwindow")
            }
            #endif

            Divider()

            Button(role: .destructive) {
                selectedGenerationIds = [generation.id]
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func navigateToVideoExtend(generation: Generation) {
        let preload = ExtendVideoPreload(
            videoId: generation.id.uuidString,
            colorPalette: generation.colorPalette,
            dimensions: generation.dimensions,
            prompt: nil,
            negativePrompt: nil,
            generation: generation
        )
        navigationManager.navigateToExtendVideo(with: preload)
    }

    private func hasCompatibleVideoExtendModel(for generation: Generation) -> Bool {
        providerService.models(for: .VIDEO_EXTEND).contains { model in
            let requiredKeys = model.modelParams.requiredMetadata
            guard !requiredKeys.isEmpty else { return false }
            return requiredKeys.allSatisfy { key in
                generation.metadata[key]?.isEmpty == false
            }
        }
    }

    private func videoExtendActionTitle(for generation: Generation) -> String {
        if generation.metadata[GeminiInteractionMetadataKey.interactionId]?.isEmpty == false {
            return "Edit Video"
        }
        return "Extend Video"
    }

    var body: some View {
        #if os(macOS)
        gridContent
            .background(
                // Invisible background to capture clicks outside grid items
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !selectedGenerationIds.isEmpty {
                            clearSelection()
                        }
                    }
            )
            .onKeyPress(.escape) {
                if !selectedGenerationIds.isEmpty {
                    clearSelection()
                    return .handled
                }
                return .ignored
            }
            .alert("Confirm Deletion", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteSelectedGenerations()
                    }
                }
            } message: {
                let count = selectedGenerationIds.count
                if count == 1 {
                    Text("Are you sure you want to delete this item? This action cannot be undone.")
                } else {
                    Text("Are you sure you want to delete \(count) items? This action cannot be undone.")
                }
            }
            .sheet(item: $expandedGenerationId) { genId in
                ExpandedImageView(
                    imageName: genId.uuidString,
                    isPresented: Binding(
                        get: { expandedGenerationId != nil },
                        set: { if !$0 { expandedGenerationId = nil } }
                    )
                )
            }
        #else
        gridContent
        #endif
    }

    private var gridContent: some View {
        LazyVGrid(columns: columns(for: availableWidth), spacing: 2) {
            ForEach(Array(filteredGenerations.enumerated()), id: \.element.id) { index, generation in
                let ratio = displayMode == .fill ? 1.0 : aspectRatio(for: generation)
                let isSelected = selectedGenerationIds.contains(generation.id)

                ICloudImageLoader(imageName: ".\(generation.id.uuidString)_o50", aspectRatio: ratio) { image in
                    if let image {
                        let isVideo = generation.contentType == .VIDEO
                        #if os(macOS)
                        GalleryImageCell(
                            image: image,
                            isSelected: isSelected,
                            isVideo: isVideo,
                            displayMode: displayMode,
                            aspectRatio: ratio,
                            onExpand: {
                                expandedGenerationId = generation.id
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let event = NSApp.currentEvent {
                                let isModifierPressed = event.modifierFlags
                                    .contains(.command) || event.modifierFlags.contains(.shift)
                                if isModifierPressed {
                                    handleSelection(for: generation, at: index, with: event)
                                } else if selectedGenerationIds.isEmpty || (
                                    selectedGenerationIds
                                        .count == 1 && selectedGenerationIds.contains(generation.id)
                                ) {
                                    // Navigate only if no selection or single-selecting the same item
                                    clearSelection()
                                    // Trigger navigation programmatically via NavigationManager
                                    let destination: EnumNavigationItem = generation.contentType == .IMAGE_2D
                                        ? .generationImage(setId: generation.setId)
                                        : .generationVideo(setId: generation.setId)
                                    navigationManager.pushDetail(destination)
                                } else {
                                    // Clear selection on regular click when items are selected
                                    clearSelection()
                                }
                            }
                        }
                        .contextMenu {
                            contextMenu(for: generation)
                        }
                        #else
                        NavigationLink(
                            value: generation.contentType == .IMAGE_2D ? EnumNavigationItem
                                .generationImage(setId: generation.setId) : EnumNavigationItem
                                .generationVideo(setId: generation.setId)
                        ) {
                            GalleryImageCell(
                                image: image,
                                isSelected: false,
                                isVideo: isVideo,
                                displayMode: displayMode,
                                aspectRatio: ratio
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            contextMenu(for: generation)
                        }
                        #endif
                    } else {
                        GalleryImagePlaceholder(aspectRatio: ratio)
                    }
                }
                .id("grid_\(generation.id.uuidString)")
            }
        }
        .frame(maxWidth: .infinity)
    }
}
