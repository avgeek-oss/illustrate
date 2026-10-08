// MARK: - PhotoshootGalleryView.swift

// Gallery view for displaying generated product photographs.
//
// PhotoshootGalleryView shows a grid of generated photos:
// - Processing items show ShimmerView loading state
// - Generated items show thumbnail with expand icon
// - Failed items show error state
//
// ## Layout
// Responsive grid with columns based on available width,
// using the same pattern as BulkSessionsView gallery.

import AvgeekDesignSystem
import SwiftData
import SwiftUI

#if !os(macOS)
import Photos
import UIKit
#endif

/// Gallery grid displaying generated product photographs.
struct PhotoshootGalleryView: View {
    @Environment(\.modelContext) private var modelContext

    let photoshoot: ProductPhotoshoot
    var isActive = true

    @State private var items: [ProductPhotoshootItem] = []
    @State private var itemToRemove: ProductPhotoshootItem?
    @State private var showRemoveConfirmation = false
    @State private var selectedNavigationItem: EnumNavigationItem?

    private var aspectRatio: CGFloat {
        photoshoot.dimensionsEnum.aspectRatio
    }

    var body: some View {
        GeometryReader { geometry in
            if items.isEmpty {
                emptyState
            } else {
                galleryGrid(width: geometry.size.width)
            }
        }
        .onAppear {
            loadItems()
        }
        .onChange(of: photoshoot.id) { _, _ in
            loadItems()
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                loadItems()
            }
        }
        .alert("Remove Generation", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let itemToRemove {
                    removeItem(itemToRemove)
                }
                itemToRemove = nil
            }
        } message: {
            Text("This removes the generation from this photoshoot gallery.")
        }
        .navigationDestination(item: $selectedNavigationItem) { item in
            viewForItem(item)
        }
    }

    // MARK: - Data Loading

    /// Loads items for the current photoshoot using a predicate-based query.
    /// This is more efficient than fetching all items and filtering in memory.
    private func loadItems() {
        let photoshootId = photoshoot.id
        var descriptor = FetchDescriptor<ProductPhotoshootItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.predicate = #Predicate<ProductPhotoshootItem> { item in
            item.photoshootId == photoshootId
        }

        items = (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Empty State

    private var emptyState: some View {
        AvgeekEmptyStateView(
            icon: "photo.on.rectangle",
            title: "No photographs yet",
            message: "Go to the Studio tab to configure your backdrop and product objects, then generate your first photograph."
        )
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Gallery Grid

    private func galleryGrid(width: CGFloat) -> some View {
        ScrollView {
            LazyVGrid(columns: galleryColumns(for: width), spacing: 2) {
                ForEach(items) { item in
                    galleryCell(item: item)
                }
            }
        }
    }

    private func galleryColumns(for width: CGFloat) -> [GridItem] {
        #if os(macOS)
        var columnCount = 6
        if width < 600 {
            columnCount = 3
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

    @ViewBuilder
    private func galleryCell(item: ProductPhotoshootItem) -> some View {
        switch item.status {
        case .PROCESSING:
            ShimmerView(cornerRadius: 4)
                .aspectRatio(aspectRatio, contentMode: .fit)
                .contextMenu {
                    contextMenu(for: item)
                }

        case .GENERATED:
            if let genId = item.generationId {
                generationNavigationButton(for: genId) {
                    ICloudImageLoader(
                        imageName: genId.uuidString,
                        aspectRatio: aspectRatio
                    ) { image in
                        if let image {
                            GalleryImageCell(
                                image: image,
                                aspectRatio: aspectRatio,
                                onExpand: {
                                    navigateToGeneration(generationId: genId)
                                }
                            )
                        } else {
                            GalleryImagePlaceholder(aspectRatio: aspectRatio)
                        }
                    }
                }
                .contextMenu {
                    contextMenu(for: item)
                }
            } else {
                GalleryImagePlaceholder(aspectRatio: aspectRatio)
                    .contextMenu {
                        contextMenu(for: item)
                    }
            }

        case .FAILED:
            failedCell
                .contextMenu {
                    contextMenu(for: item)
                }
        }
    }

    private var failedCell: some View {
        Color.red.opacity(0.1)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay(
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.red)
                    Text("Failed")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenu(for item: ProductPhotoshootItem) -> some View {
        Button {
            if let generationId = item.generationId {
                navigateToGeneration(generationId: generationId)
            }
        } label: {
            Label("View image", systemImage: "eye")
        }
        .disabled(item.generationId == nil)

        Button {
            if let generationId = item.generationId {
                copyGeneration(generationId: generationId)
            }
        } label: {
            Label("Copy image", systemImage: "doc.on.doc")
        }
        .disabled(item.generationId == nil)

        Button {
            if let generationId = item.generationId {
                downloadGeneration(generationId: generationId)
            }
        } label: {
            Label("Download image", systemImage: "arrow.down")
        }
        .disabled(item.generationId == nil)

        Button {
            if let generationId = item.generationId {
                shareGeneration(generationId: generationId)
            }
        } label: {
            Label("Share image", systemImage: "square.and.arrow.up")
        }
        .disabled(item.generationId == nil)

        Button {
            copyPrompt(for: item)
        } label: {
            Label("Copy Prompt", systemImage: "text.quote")
        }

        Divider()

        Button(role: .destructive) {
            itemToRemove = item
            showRemoveConfirmation = true
        } label: {
            Label("Remove Generation", systemImage: "trash")
        }
    }

    private func copyGeneration(generationId: UUID) {
        guard let image = loadImageFromiCloud(generationId.uuidString) else {
            showToast(.error("Unable to copy generation"))
            return
        }

        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        #else
        UIPasteboard.general.image = image
        #endif

        showToast(.success("Copied to clipboard"))
    }

    private func downloadGeneration(generationId: UUID) {
        guard let image = loadImageFromiCloud(generationId.uuidString) else {
            showToast(.error("Unable to download image"))
            return
        }
        #if os(macOS)
        image.saveImageToDownloads(fileName: generationId.uuidString)
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

    private func shareGeneration(generationId: UUID) {
        guard let image = loadImageFromiCloud(generationId.uuidString) else {
            showToast(.error("Unable to share image"))
            return
        }
        #if os(macOS)
        image.shareImage()
        #else
        UIPasteboard.general.image = image
        showToast(.success("Copied to clipboard for sharing"))
        #endif
    }

    private func copyPrompt(for item: ProductPhotoshootItem) {
        let prompt = promptText(for: item)

        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        #else
        UIPasteboard.general.string = prompt
        #endif

        showToast(.success("Copied to clipboard"))
    }

    private func promptText(for item: ProductPhotoshootItem) -> String {
        if let generationId = item.generationId {
            let descriptor = FetchDescriptor<Generation>(
                predicate: #Predicate { $0.id == generationId }
            )

            if let generation = try? modelContext.fetch(descriptor).first, !generation.prompt.isEmpty {
                return generation.prompt
            }
        }

        return item.imageGenerationConfiguration.prompt
    }

    private func removeItem(_ item: ProductPhotoshootItem) {
        let itemId = item.id
        items.removeAll { $0.id == itemId }
        modelContext.delete(item)

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to remove photoshoot item: \(error.localizedDescription, privacy: .public)")
            showToast(.error("Failed to remove generation"))
            loadItems()
        }
    }

    // MARK: - Navigation

    @ViewBuilder
    private func generationNavigationButton(
        for generationId: UUID,
        @ViewBuilder content: () -> some View
    ) -> some View {
        if let destination = generationDestination(for: generationId) {
            NavigationLink(value: destination) {
                content()
            }
            .buttonStyle(.plain)
        } else {
            Button {
                navigateToGeneration(generationId: generationId)
            } label: {
                content()
            }
            .buttonStyle(.plain)
        }
    }

    private func generationDestination(for generationId: UUID) -> EnumNavigationItem? {
        let descriptor = FetchDescriptor<Generation>(
            predicate: #Predicate { $0.id == generationId }
        )

        guard let generation = try? modelContext.fetch(descriptor).first else {
            return nil
        }

        return .generationImage(setId: generation.setId)
    }

    private func navigateToGeneration(generationId: UUID) {
        if let destination = generationDestination(for: generationId) {
            selectedNavigationItem = destination
        } else {
            showToast(.error("Unable to open image"))
        }
    }
}
