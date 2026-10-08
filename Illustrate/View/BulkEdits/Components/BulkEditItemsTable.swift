import AvgeekDesignSystem
import SwiftData
import SwiftUI

#if !os(macOS)
import Photos
import UIKit
#endif

struct BulkEditItemsTable: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigationManager: NavigationManager

    let items: [BulkEditItem]
    @Binding var showGalleryView: Bool
    let isGenerating: Bool
    let sessionHasStarted: Bool
    let onDeleteItem: (BulkEditItem) -> Void
    let onRegenerateItem: (BulkEditItem) -> Void
    let onAddImage: () -> Void
    let onImportZIP: () -> Void
    let isCompactLayout: Bool

    @State private var itemToDelete: BulkEditItem?
    @State private var showDeleteConfirmation = false
    @State private var loadedThumbs: [UUID: PlatformImage] = [:]
    @State private var loadingIds: Set<UUID> = []
    @State private var previewPopoverItem: BulkEditItem?
    @State private var selectedNavigationItem: EnumNavigationItem?
    @AppStorage("bulkEditGalleryDisplayMode") private var displayMode: GalleryDisplayMode = .fill

    private var completedCount: Int {
        items.filter { $0.status == .COMPLETED }.count
    }

    private var totalCount: Int {
        items.count
    }

    private var completedItems: [BulkEditItem] {
        items.compactMap { item -> BulkEditItem? in
            guard item.status == .COMPLETED, item.generationId != nil else { return nil }
            return item
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isCompactLayout {
                viewHeader
                Divider()
            }

            contentView
        }
        .alert("Delete Image", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { itemToDelete = nil }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete { onDeleteItem(item); itemToDelete = nil }
            }
        } message: {
            Text("Are you sure you want to remove this image? This action cannot be undone.")
        }
        .navigationDestination(item: $selectedNavigationItem) { item in
            viewForItem(item)
        }
    }

    // MARK: - Header

    private var viewHeader: some View {
        Group {
            if isCompactLayout {
                EmptyView()
            } else {
                desktopViewHeader
            }
        }
    }

    private var desktopViewHeader: some View {
        HStack(spacing: 16) {
            Picker("", selection: $showGalleryView) {
                Label("Image List", systemImage: "list.bullet")
                    .tag(false)
                Label("Gallery", systemImage: "square.grid.2x2")
                    .tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 160)

            Spacer()

            if showGalleryView {
                Menu {
                    ForEach(GalleryDisplayMode.allCases, id: \.self) { mode in
                        Button {
                            displayMode = mode
                        } label: {
                            Label(mode.rawValue, systemImage: mode.icon)
                        }
                    }
                } label: {
                    Image(systemName: displayMode.icon)
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .help("Toggle fit/fill display mode")
                .accessibilityLabel("Display mode")
                .accessibilityValue(displayMode.rawValue)
            }

            if totalCount > 0, !showGalleryView {
                ProgressView(value: Double(completedCount), total: Double(totalCount))
                    .progressViewStyle(.linear)
                    .frame(width: 120)
            }

            Text("\(completedCount)/\(totalCount) processed")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button {
                onAddImage()
            } label: {
                Label("Add Image", systemImage: "plus")
                    .font(.callout)
            }
            .buttonStyle(.bordered)
            .disabled(isGenerating || items.count >= bulkEditMaxItems)
            .help("Add an image manually")

            if !sessionHasStarted, !items.isEmpty {
                Button {
                    onImportZIP()
                } label: {
                    Label("Re-upload", systemImage: "arrow.triangle.2.circlepath")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .help("Replace images with a new ZIP file")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(tertiarySystemFill)
    }

    private var contentView: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else if showGalleryView {
                galleryView
            } else if isCompactLayout {
                compactImageList
            } else {
                tableView
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No images yet")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Import a ZIP file containing images or add them manually to get started.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Group {
                if isCompactLayout {
                    VStack(spacing: 12) {
                        emptyStateButtons
                    }
                } else {
                    HStack(spacing: 12) {
                        emptyStateButtons
                    }
                }
            }
            .padding(.top, 12)

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var emptyStateButtons: some View {
        Button {
            onImportZIP()
        } label: {
            Label("Import ZIP", systemImage: "doc.zipper")
        }
        .buttonStyle(.borderedProminent)
        .disabled(isGenerating)
        .help("Import images from a ZIP file")

        Button {
            onAddImage()
        } label: {
            Label("Add Image", systemImage: "plus")
        }
        .buttonStyle(.bordered)
        .disabled(isGenerating)
        .help("Add an image manually")
    }

    private var compactImageList: some View {
        List {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                compactRow(item: item, index: index + 1)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowSeparator(.visible)
                    .listRowBackground(systemBackground)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(systemBackground)
    }

    private func compactRow(item: BulkEditItem, index: Int) -> some View {
        let itemStatus = item.status
        let itemGenerationId = item.generationId
        let itemName = item.sourceImageName ?? "Image"

        return Button {
            if let generationId = itemGenerationId, itemStatus == .COMPLETED {
                navigateToGeneration(generationId: generationId)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 6) {
                    Text("\(index)")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    compactStatusIndicator(for: itemStatus)
                }
                .frame(width: 24, alignment: .top)

                Group {
                    if let image = loadedThumbs[item.id] {
                        #if os(macOS)
                        Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                        #else
                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                        #endif
                    } else {
                        Color.secondary.opacity(0.1)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onAppear { loadThumbnail(for: item) }

                VStack(alignment: .leading, spacing: 6) {
                    Text(itemName)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let errorMessage = item.errorMessage, itemStatus == .FAILED, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if itemStatus == .COMPLETED, itemGenerationId != nil {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            itemContextMenu(item: item)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if canDeleteItem(item) {
                Button(role: .destructive) {
                    itemToDelete = item
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } else if canRegenerateItem(item) {
                Button {
                    onRegenerateItem(item)
                } label: {
                    Label("Re-edit", systemImage: "arrow.triangle.2.circlepath")
                }
                .tint(.orange)
                .disabled(isGenerating)
            }
        }
    }

    @ViewBuilder
    private func itemContextMenu(item: BulkEditItem) -> some View {
        if canDeleteItem(item) {
            Button(role: .destructive) {
                itemToDelete = item
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Divider()
        }

        if item.status == .COMPLETED, let generationId = item.generationId {
            Button {
                navigateToGeneration(generationId: generationId)
            } label: {
                Label("View image", systemImage: "eye")
            }

            Button {
                copyImage(generationId: generationId)
            } label: {
                Label("Copy image", systemImage: "doc.on.doc")
            }

            Button {
                downloadImage(generationId: generationId)
            } label: {
                Label("Download image", systemImage: "arrow.down")
            }

            Button {
                shareImage(generationId: generationId)
            } label: {
                Label("Share image", systemImage: "square.and.arrow.up")
            }

            Button {
                copyPromptForGeneration(generationId)
            } label: {
                Label("Copy Prompt", systemImage: "text.quote")
            }

            Divider()
        }

        if canRegenerateItem(item) {
            Button {
                onRegenerateItem(item)
            } label: {
                Label(item.status == .FAILED ? "Retry" : "Re-edit", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(isGenerating)
        }
    }

    // MARK: - Table View

    private var tableView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("#")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .center)

                    Text("Source")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .center)

                    Text("Name")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Status")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)

                    Text("Actions")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .center)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(tertiarySystemFill)

                Divider()

                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    tableRow(item: item, index: index + 1)
                    Divider()
                }
            }
        }
    }

    private func tableRow(item: BulkEditItem, index: Int) -> some View {
        let itemStatus = item.status
        let itemGenerationId = item.generationId
        let itemName = item.sourceImageName ?? "Image"
        let canDelete = canDeleteItem(item)

        return HStack(spacing: 0) {
            Text("\(index)")
                .font(.callout).foregroundStyle(.secondary)
                .frame(width: 40, alignment: .center)

            Group {
                if let image = loadedThumbs[item.id] {
                    #if os(macOS)
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                    #else
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
                    #endif
                } else {
                    Color.secondary.opacity(0.1)
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .frame(width: 50, alignment: .center)
            .onAppear { loadThumbnail(for: item) }

            Text(itemName)
                .font(.callout)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 16)
                .help(itemName)

            statusBadge(for: itemStatus)
                .frame(width: 100, alignment: .leading)

            HStack(spacing: 6) {
                if itemStatus == .COMPLETED, itemGenerationId != nil {
                    #if os(macOS)
                    Button {
                        previewPopoverItem = item
                    } label: {
                        Image(systemName: "eye")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isGenerating)
                    .help("Preview generation")
                    .accessibilityLabel("Preview")
                    .accessibilityHint("Preview this generation")
                    .popover(isPresented: Binding(
                        get: { previewPopoverItem?.id == item.id },
                        set: { if !$0 { previewPopoverItem = nil } }
                    )) {
                        if let genId = itemGenerationId {
                            GenerationPreviewPopoverFromGenerationId(
                                generationId: genId,
                                isPresented: Binding(
                                    get: { previewPopoverItem?.id == item.id },
                                    set: { if !$0 { previewPopoverItem = nil } }
                                ),
                                onNavigateToDetails: { setId, isVideo in
                                    navigationManager.detailNavigationItem = isVideo
                                        ? .generationVideo(setId: setId)
                                        : .generationImage(setId: setId)
                                }
                            )
                        }
                    }
                    #else
                    Button {
                        if let genId = itemGenerationId {
                            navigateToGeneration(generationId: genId)
                        }
                    } label: {
                        Image(systemName: "eye")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isGenerating)
                    .help("Preview generation")
                    .accessibilityLabel("Preview")
                    .accessibilityHint("Preview this generation")
                    #endif

                    Button {
                        onRegenerateItem(item)
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isGenerating)
                    .help("Re-edit this image")
                    .accessibilityLabel("Re-edit")
                } else if itemStatus == .FAILED {
                    Button {
                        onRegenerateItem(item)
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isGenerating)
                    .help("Re-edit this image")
                    .accessibilityLabel("Retry")
                } else if canDelete {
                    Button(role: .destructive) {
                        itemToDelete = item
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .help("Remove image")
                }
            }
            .frame(width: 100, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(itemStatus == .IN_PROGRESS ? Color.accentColor.opacity(0.1) : Color.clear)
        .contextMenu {
            itemContextMenu(item: item)
        }
    }

    // MARK: - Status Badge

    private func statusBadge(for status: BulkEditItemStatus) -> some View {
        HStack(spacing: 4) {
            if status == .IN_PROGRESS {
                GradientSpinner()
            } else {
                Circle()
                    .fill(statusColor(for: status))
                    .frame(width: 6, height: 6)
            }

            Text(statusText(for: status))
                .font(.body)
                .foregroundStyle(statusColor(for: status))
        }
    }

    private func statusColor(for status: BulkEditItemStatus) -> Color {
        switch status {
        case .PENDING: Color.gray
        case .IN_PROGRESS: Color.accentColor
        case .COMPLETED: Color.green
        case .FAILED: Color.red
        case .CANCELLED: Color.orange
        }
    }

    private func statusText(for status: BulkEditItemStatus) -> String {
        switch status {
        case .PENDING: "Pending"
        case .IN_PROGRESS: "Editing"
        case .COMPLETED: "Done"
        case .FAILED: "Failed"
        case .CANCELLED: "Cancelled"
        }
    }

    @ViewBuilder
    private func compactStatusIndicator(for status: BulkEditItemStatus) -> some View {
        switch status {
        case .COMPLETED:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .IN_PROGRESS:
            GradientSpinner()
                .frame(width: 10, height: 10)
        case .FAILED:
            Image(systemName: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        case .CANCELLED:
            Image(systemName: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        case .PENDING:
            Image(systemName: "circle.fill")
                .font(.system(size: 7))
                .foregroundStyle(.tertiary)
        }
    }

    private func canDeleteItem(_ item: BulkEditItem) -> Bool {
        !isGenerating && (item.status == .PENDING || item.status == .FAILED || item.status == .CANCELLED)
    }

    private func canRegenerateItem(_ item: BulkEditItem) -> Bool {
        item.status == .FAILED || (item.status == .COMPLETED && item.generationId != nil)
    }

    // MARK: - Gallery View

    private var galleryView: some View {
        GeometryReader { geometry in
            if completedItems.isEmpty {
                AvgeekEmptyStateView(
                    icon: "photo",
                    title: "No completed edits yet",
                    message: "Edited images will appear here once completed."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: galleryColumns(for: geometry.size.width), spacing: 2) {
                        ForEach(completedItems) { item in
                            galleryCell(item: item)
                        }
                    }
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

    private func galleryCell(item: BulkEditItem) -> some View {
        let generationId = item.generationId
        let effectiveDisplayMode: GalleryDisplayMode = isCompactLayout ? .fit : displayMode

        return Button {
            if let genId = generationId {
                navigateToGeneration(generationId: genId)
            }
        } label: {
            if let genId = generationId {
                ICloudImageLoader(
                    imageName: genId.uuidString,
                    aspectRatio: 1.0
                ) { image in
                    if let image {
                        GalleryImageCell(
                            image: image,
                            displayMode: effectiveDisplayMode,
                            onExpand: {
                                navigateToGeneration(generationId: genId)
                            }
                        )
                    } else {
                        GalleryImagePlaceholder()
                    }
                }
            } else {
                GalleryImagePlaceholder()
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let genId = generationId {
                Button {
                    navigateToGeneration(generationId: genId)
                } label: {
                    Label("View image", systemImage: "eye")
                }

                Button {
                    copyImage(generationId: genId)
                } label: {
                    Label("Copy image", systemImage: "doc.on.doc")
                }

                Button {
                    downloadImage(generationId: genId)
                } label: {
                    Label("Download image", systemImage: "arrow.down")
                }

                Button {
                    shareImage(generationId: genId)
                } label: {
                    Label("Share image", systemImage: "square.and.arrow.up")
                }

                Button {
                    copyPromptForGeneration(generationId)
                } label: {
                    Label("Copy Prompt", systemImage: "text.quote")
                }
            }

            Button {
                onRegenerateItem(item)
            } label: {
                Label("Re-edit", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(isGenerating)
        }
    }

    // MARK: - Context Menu Actions

    private func copyImage(generationId: UUID) {
        guard let image = loadImageFromiCloud(generationId.uuidString) else {
            showToast(.error("Unable to copy image"))
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

    private func downloadImage(generationId: UUID) {
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

    private func shareImage(generationId: UUID) {
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

    private func copyPromptForGeneration(_ generationId: UUID?) {
        guard let generationId else { return }
        let descriptor = FetchDescriptor<Generation>(
            predicate: #Predicate { $0.id == generationId }
        )
        if let generation = try? modelContext.fetch(descriptor).first, !generation.prompt.isEmpty {
            #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(generation.prompt, forType: .string)
            #else
            UIPasteboard.general.string = generation.prompt
            #endif
            showToast(.success("Prompt copied to clipboard"))
        }
    }

    // MARK: - Navigation

    private func navigateToGeneration(generationId: UUID) {
        let descriptor = FetchDescriptor<Generation>(
            predicate: #Predicate { $0.id == generationId }
        )
        if let generation = try? modelContext.fetch(descriptor).first {
            let destination = EnumNavigationItem.generationImage(setId: generation.setId)
            if isCompactLayout {
                selectedNavigationItem = destination
            } else {
                navigationManager.detailNavigationItem = destination
            }
        }
    }

    // MARK: - Thumbnail Loading

    private func loadThumbnail(for item: BulkEditItem) {
        let thumbName = item.sourceImageThumbFileName ?? item.sourceImageFileName
        guard let thumbName, loadedThumbs[item.id] == nil, !loadingIds.contains(item.id) else { return }

        if let cached = ImageCache.shared.get(forKey: thumbName) {
            loadedThumbs[item.id] = cached
            return
        }

        loadingIds.insert(item.id)
        DispatchQueue.global(qos: .userInitiated).async {
            let image = loadImageFromiCloud(thumbName)
            DispatchQueue.main.async {
                if let image {
                    ImageCache.shared.set(image, forKey: thumbName)
                    loadedThumbs[item.id] = image
                }
                loadingIds.remove(item.id)
            }
        }
    }
}
