// MARK: - SessionItemsTable.swift

// Table/Gallery view for bulk session items.
//
// Displays prompts and their generation status with toggle between:
// - Table View: List with prompt, status, and actions
// - Gallery View: Grid of completed generations
//
// ## Table View Features
// - Row number, prompt (truncated), status badge, action buttons
// - Edit prompt
// - Delete item (when not running)
// - Click completed item to view generation
//
// ## Gallery View Features
// - Grid of generated images
// - Shows only completed items
// - Click to view full generation detail
//
// ## Status Badges
// - Pending: Gray
// - In Progress: Blue
// - Completed: Green
// - Failed: Red
// - Cancelled: Orange

import AvgeekDesignSystem
import SwiftData
import SwiftUI

/// Table/Gallery view for bulk session items.
struct SessionItemsTable: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigationManager: NavigationManager

    let items: [BulkSessionItem]
    @Binding var showGalleryView: Bool
    let isGenerating: Bool
    let sessionHasStarted: Bool
    let onEditItem: (BulkSessionItem, String) -> Void
    let onDeleteItem: (BulkSessionItem) -> Void
    let onRegenerateItem: (BulkSessionItem) -> Void
    let onAddItem: (String, String?) -> Void
    let onImportCSV: () -> Void
    let onDownloadTemplate: () -> Void
    let isCompactLayout: Bool
    let showCompactViewToggle: Bool
    let externalShowAddPromptSheet: Binding<Bool>?

    @State private var editingItem: BulkSessionItem?
    @State private var editingPrompt = ""
    @State private var viewingPromptItem: BulkSessionItem?
    @State private var showAddPromptSheet = false
    @State private var newPrompt = ""
    @State private var newFilename = ""
    @State private var itemToDelete: BulkSessionItem?
    @State private var showDeleteConfirmation = false
    @State private var previewPopoverItem: BulkSessionItem?
    @State private var selectedNavigationItem: EnumNavigationItem?
    @AppStorage("bulkGalleryDisplayMode") private var displayMode: GalleryDisplayMode = .fill

    private var completedCount: Int {
        items.filter { $0.status == .COMPLETED }.count
    }

    private var totalCount: Int {
        items.count
    }

    /// Items that have completed generation with a valid generationId
    /// Filter safely to avoid crashes from accessing detached SwiftData objects
    private var completedItems: [BulkSessionItem] {
        items.compactMap { item -> BulkSessionItem? in
            // Safely check status and generationId
            guard item.status == .COMPLETED, item.generationId != nil else {
                return nil
            }
            return item
        }
    }

    private var hasAnyFilename: Bool {
        items.contains { $0.filename != nil }
    }

    private var addPromptSheetBinding: Binding<Bool> {
        externalShowAddPromptSheet ?? $showAddPromptSheet
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isCompactLayout {
                viewHeader
                Divider()
            }

            contentView
        }
        .sheet(item: $editingItem) { item in
            editItemSheet(item: item)
        }
        .sheet(item: $viewingPromptItem) { item in
            viewPromptSheet(item: item)
        }
        .sheet(isPresented: addPromptSheetBinding) {
            addPromptSheet
        }
        .alert("Delete Prompt", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    onDeleteItem(item)
                    itemToDelete = nil
                }
            }
        } message: {
            Text("Are you sure you want to delete this prompt? This action cannot be undone.")
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
                Label("Prompt List", systemImage: "list.bullet")
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
                presentAddPromptSheet()
            } label: {
                Label("Add Prompt", systemImage: "plus")
                    .font(.callout)
            }
            .buttonStyle(.bordered)
            .disabled(isGenerating)
            .help("Add a prompt manually")

            if !sessionHasStarted, !items.isEmpty {
                Button {
                    onImportCSV()
                } label: {
                    Label("Re-upload", systemImage: "arrow.triangle.2.circlepath")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .help("Replace prompts with a new CSV file")
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
                compactPromptList
            } else {
                tableView
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "doc.text")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No prompts yet")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Import a CSV file with a 'prompt' column to get started.")
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
            onDownloadTemplate()
        } label: {
            Label("Download Template", systemImage: "arrow.down.doc")
        }
        .buttonStyle(.bordered)
        .help("Download a CSV template file")

        Button {
            onImportCSV()
        } label: {
            Label("Import CSV", systemImage: "doc.badge.plus")
        }
        .buttonStyle(.borderedProminent)
        .disabled(isGenerating)
        .help("Import a CSV file with prompts")

        Button {
            presentAddPromptSheet()
        } label: {
            Label("Add Prompt", systemImage: "plus")
        }
        .buttonStyle(.bordered)
        .disabled(isGenerating)
        .help("Add a prompt manually")
    }

    // MARK: - Compact List

    private var compactPromptList: some View {
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

    private func compactRow(item: BulkSessionItem, index: Int) -> some View {
        let itemStatus = item.status
        let itemGenerationId = item.generationId

        return Button {
            if let generationId = itemGenerationId, itemStatus == .COMPLETED {
                navigateToGeneration(generationId: generationId)
            } else {
                viewingPromptItem = item
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

                VStack(alignment: .leading, spacing: 8) {
                    if let filename = item.filename, !filename.isEmpty {
                        Text(filename)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text(item.prompt)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                    Label("Re-generate", systemImage: "arrow.triangle.2.circlepath")
                }
                .tint(.orange)
                .disabled(isGenerating)
            }
        }
    }

    @ViewBuilder
    private func itemContextMenu(item: BulkSessionItem) -> some View {
        Button {
            copyPrompt(item.prompt)
        } label: {
            Label("Copy Prompt", systemImage: "doc.on.doc")
        }

        Button {
            viewingPromptItem = item
        } label: {
            Label("View Prompt", systemImage: "text.alignleft")
        }

        Button {
            editingItem = item
            editingPrompt = item.prompt
        } label: {
            Label("Edit Prompt", systemImage: "pencil")
        }

        if canDeleteItem(item) {
            Divider()

            Button(role: .destructive) {
                itemToDelete = item
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }

        if item.status == .COMPLETED, let generationId = item.generationId {
            Button {
                navigateToGeneration(generationId: generationId)
            } label: {
                Label("View image", systemImage: "eye")
            }

            Divider()
        }

        if canRegenerateItem(item) {
            Button {
                onRegenerateItem(item)
            } label: {
                Label("Re-generate", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(isGenerating)
        }
    }

    // MARK: - Table View

    private var tableView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Table header
                HStack(spacing: 0) {
                    Text("#")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .center)

                    Text("Prompt")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if hasAnyFilename {
                        Text("Filename")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .frame(width: 140, alignment: .leading)
                    }

                    Text("Status")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 90, alignment: .leading)

                    Text("Actions")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 90, alignment: .center)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(tertiarySystemFill)

                Divider()

                // Table rows
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    tableRow(item: item, index: index + 1)
                    Divider()
                }
            }
        }
    }

    private func tableRow(item: BulkSessionItem, index: Int) -> some View {
        let itemPrompt = item.prompt
        let itemFilename = item.filename
        let itemStatus = item.status
        let itemGenerationId = item.generationId
        let canDelete = canDeleteItem(item)

        return HStack(spacing: 0) {
            Text("\(index)")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .center)

            Text(itemPrompt)
                .font(.callout)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 16)
                .help(itemPrompt)

            if hasAnyFilename {
                Text(itemFilename ?? "")
                    .font(.callout)
                    .foregroundStyle(itemFilename != nil ? .primary : .secondary)
                    .lineLimit(1)
                    .frame(width: 140, alignment: .leading)
                    .padding(.trailing, 16)
            }

            statusBadge(for: itemStatus)
                .frame(width: 90, alignment: .leading)

            // Actions
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
                    .help("Re-generate this item")
                    .accessibilityLabel("Re-generate")
                } else if itemStatus == .FAILED {
                    Button {
                        onRegenerateItem(item)
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isGenerating)
                    .help("Re-generate this item")
                    .accessibilityLabel("Retry")
                } else if canDelete {
                    Button(role: .destructive) {
                        itemToDelete = item
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .help("Delete item")
                }
            }
            .frame(width: 90, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(itemStatus == .IN_PROGRESS ? Color.accentColor.opacity(0.1) : Color.clear)
        .contextMenu {
            itemContextMenu(item: item)
        }
    }

    private func statusBadge(for status: BulkSessionItemStatus) -> some View {
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

    private func statusColor(for status: BulkSessionItemStatus) -> Color {
        switch status {
        case .PENDING:
            Color.gray
        case .IN_PROGRESS:
            Color.accentColor
        case .COMPLETED:
            Color.green
        case .FAILED:
            Color.red
        case .CANCELLED:
            Color.orange
        }
    }

    private func statusText(for status: BulkSessionItemStatus) -> String {
        switch status {
        case .PENDING:
            "Pending"
        case .IN_PROGRESS:
            "Generating"
        case .COMPLETED:
            "Done"
        case .FAILED:
            "Failed"
        case .CANCELLED:
            "Cancelled"
        }
    }

    @ViewBuilder
    private func compactStatusIndicator(for status: BulkSessionItemStatus) -> some View {
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

    private func canDeleteItem(_ item: BulkSessionItem) -> Bool {
        !isGenerating && (item.status == .PENDING || item.status == .FAILED || item.status == .CANCELLED)
    }

    private func canRegenerateItem(_ item: BulkSessionItem) -> Bool {
        item.status == .FAILED || (item.status == .COMPLETED && item.generationId != nil)
    }

    // MARK: - Edit Sheet

    private func editItemSheet(item: BulkSessionItem) -> some View {
        NavigationStack {
            Form {
                TextField("Enter your prompt", text: $editingPrompt, axis: .vertical)
                    .lineLimit(3 ... 8)

                if item.status == .FAILED, let errorMessage = item.errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text("Previous error: \(errorMessage)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Prompt")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        editingItem = nil
                        editingPrompt = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !editingPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onEditItem(item, editingPrompt)
                            editingItem = nil
                            editingPrompt = ""
                        }
                    }
                    .disabled(editingPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(width: 480)
        #endif
    }

    // MARK: - Gallery View

    private var galleryView: some View {
        GeometryReader { geometry in
            if completedItems.isEmpty {
                AvgeekEmptyStateView(
                    icon: "photo",
                    title: "No completed generations yet",
                    message: "Generated images will appear here once completed."
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

    private func galleryCell(item: BulkSessionItem) -> some View {
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
            Button {
                copyPrompt(item.prompt)
            } label: {
                Label("Copy Prompt", systemImage: "doc.on.doc")
            }

            Button {
                viewingPromptItem = item
            } label: {
                Label("View Prompt", systemImage: "text.alignleft")
            }

            Button {
                editingItem = item
                editingPrompt = item.prompt
            } label: {
                Label("Edit Prompt", systemImage: "pencil")
            }

            if let genId = generationId {
                Divider()

                Button {
                    navigateToGeneration(generationId: genId)
                } label: {
                    Label("View image", systemImage: "eye")
                }
            }

            Button {
                onRegenerateItem(item)
            } label: {
                Label("Re-generate", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(isGenerating)
        }
    }

    // MARK: - Navigation

    private var addPromptSheet: some View {
        NavigationStack {
            Form {
                TextField("Prompt", text: $newPrompt, axis: .vertical)
                    .lineLimit(3 ... 8)

                TextField("Filename (optional)", text: $newFilename)
            }
            .formStyle(.grouped)
            .navigationTitle("Add Prompt")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetAddPromptSheet()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmedFilename = newFilename.trimmingCharacters(in: .whitespacesAndNewlines)
                        onAddItem(newPrompt, trimmedFilename.isEmpty ? nil : trimmedFilename)
                        resetAddPromptSheet()
                    }
                    .disabled(newPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(width: 480)
        #endif
    }

    private func resetAddPromptSheet() {
        addPromptSheetBinding.wrappedValue = false
        newPrompt = ""
        newFilename = ""
    }

    private func presentAddPromptSheet() {
        addPromptSheetBinding.wrappedValue = true
    }

    private func viewPromptSheet(item: BulkSessionItem) -> some View {
        NavigationStack {
            ScrollView {
                Text(item.prompt)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("Prompt")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewingPromptItem = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        copyPrompt(item.prompt)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 520, minHeight: 260, idealHeight: 360)
        #endif
    }

    private func copyPrompt(_ prompt: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        #else
        UIPasteboard.general.string = prompt
        #endif
    }

    private func navigateToGeneration(generationId: UUID) {
        // Fetch the generation to get its setId
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
}
