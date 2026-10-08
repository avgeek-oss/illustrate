// MARK: - ProductPhotoshootsView.swift

// Main view for managing product photoshoots with sidebar + detail layout.
//
// ProductPhotoshootsView provides a master-detail interface:
// - Left sidebar: List of photoshoots with pin, rename, delete
// - Right detail: Selected photoshoot editor
//
// ## Layout Pattern
// Follows the same pattern as StoryboardListView:
// - NavigationSplitView with sidebar and detail
// - PinnableRowView for list items

import AvgeekDesignSystem
import OSLog
import SwiftData
import SwiftUI

/// Main container view for product photoshoot management.
struct ProductPhotoshootsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var projectManager: ProjectManager

    @State private var photoshoots: [ProductPhotoshoot] = []
    @State private var selectedPhotoshootId: UUID?
    @State private var showCreateSheet = false
    @State private var showRenameSheet = false
    @State private var renamePhotoshootName = ""
    @State private var photoshootToRename: ProductPhotoshoot?
    @State private var showDuplicateSheet = false
    @State private var duplicatePhotoshootName = ""
    @State private var photoshootToDuplicate: ProductPhotoshoot?
    @State private var photoshootToDelete: ProductPhotoshoot?
    @State private var showDeleteConfirmation = false
    @State private var showDetailsSheet = false
    @State private var compactPresentedPhotoshootId: UUID?

    private var selectedPhotoshoot: ProductPhotoshoot? {
        guard let id = selectedPhotoshootId else { return nil }
        return photoshoots.first { $0.id == id }
    }

    private var lastSelectedPhotoshootKey: String {
        "lastSelectedPhotoshoot_\(projectManager.currentProjectId.uuidString)"
    }

    private var shouldUseCompactMobileLayout: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    var body: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            photoshootsSidebar
                .frame(width: 240)
                .zIndex(1)

            Divider()

            detailArea
                .frame(minWidth: 0, maxWidth: .infinity)
                .contentShape(Rectangle())
                .clipped()
        }
        .navigationTitle("Product Photoshoots")
        .sheet(isPresented: $showCreateSheet) {
            PhotoshootCreateSheet(isPresented: $showCreateSheet) { photoshoot in
                loadPhotoshoots()
                selectedPhotoshootId = photoshoot.id
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            renameSheet
        }
        .sheet(isPresented: $showDuplicateSheet) {
            duplicateSheet
        }
        .sheet(
            isPresented: Binding(
                get: { showDetailsSheet && selectedPhotoshoot != nil },
                set: { if !$0 { showDetailsSheet = false } }
            )
        ) {
            if let selectedPhotoshoot {
                PhotoshootDetailsSheet(
                    photoshoot: selectedPhotoshoot,
                    isPresented: $showDetailsSheet
                )
            }
        }
        .onChange(of: selectedPhotoshootId) { _, newId in
            if let newId {
                UserDefaults.standard.set(newId.uuidString, forKey: lastSelectedPhotoshootKey)
            }
        }
        .onAppear {
            loadPhotoshoots()
            restoreLastSelectedPhotoshoot()
        }
        .onChange(of: projectManager.currentProjectId) { _, _ in
            compactPresentedPhotoshootId = nil
            loadPhotoshoots()
            selectedPhotoshootId = nil
            restoreLastSelectedPhotoshoot()
        }
        .onChange(of: photoshoots) { _, newPhotoshoots in
            if let selectedPhotoshootId,
               !newPhotoshoots.contains(where: { $0.id == selectedPhotoshootId })
            {
                self.selectedPhotoshootId = nil
            }

            if selectedPhotoshootId == nil, !newPhotoshoots.isEmpty {
                restoreLastSelectedPhotoshoot()
            }
        }
        #else
        Group {
            if shouldUseCompactMobileLayout {
                compactMobileContent
            } else {
                NavigationSplitView {
                    photoshootsSidebar
                } detail: {
                    detailArea
                }
            }
        }
        .navigationTitle(shouldUseCompactMobileLayout ? compactMobileTitle : "Product Photoshoots")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if shouldUseCompactMobileLayout {
                compactMobileToolbar
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            PhotoshootCreateSheet(isPresented: $showCreateSheet) { photoshoot in
                loadPhotoshoots()
                selectedPhotoshootId = photoshoot.id
                compactPresentedPhotoshootId = photoshoot.id
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            renameSheet
        }
        .sheet(isPresented: $showDuplicateSheet) {
            duplicateSheet
        }
        .sheet(
            isPresented: Binding(
                get: { showDetailsSheet && selectedPhotoshoot != nil },
                set: { if !$0 { showDetailsSheet = false } }
            )
        ) {
            if let selectedPhotoshoot {
                PhotoshootDetailsSheet(
                    photoshoot: selectedPhotoshoot,
                    isPresented: $showDetailsSheet
                )
            }
        }
        .onChange(of: selectedPhotoshootId) { _, newId in
            if let newId {
                UserDefaults.standard.set(newId.uuidString, forKey: lastSelectedPhotoshootKey)
            }
        }
        .onChange(of: compactPresentedPhotoshootId) { _, newId in
            if newId == nil, shouldUseCompactMobileLayout {
                returnToPhotoshootsList()
            }
        }
        .onAppear {
            loadPhotoshoots()
            restoreLastSelectedPhotoshoot()
        }
        .onChange(of: projectManager.currentProjectId) { _, _ in
            loadPhotoshoots()
            selectedPhotoshootId = nil
            restoreLastSelectedPhotoshoot()
        }
        .onChange(of: photoshoots) { _, newPhotoshoots in
            if let selectedPhotoshootId,
               !newPhotoshoots.contains(where: { $0.id == selectedPhotoshootId })
            {
                self.selectedPhotoshootId = nil
            }

            if selectedPhotoshootId == nil, !newPhotoshoots.isEmpty {
                restoreLastSelectedPhotoshoot()
            }
        }
        #endif
    }

    private var compactMobileTitle: String {
        "Product Photoshoots"
    }

    #if os(iOS)
    @ToolbarContentBuilder
    private var compactMobileToolbar: some ToolbarContent {
        if compactPresentedPhotoshootId == nil {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private var compactMobileContent: some View {
        compactPhotoshootsList
            .navigationDestination(
                item: Binding(
                    get: { compactPresentedPhotoshootId.map(CompactPhotoshootRoute.detail) },
                    set: { route in
                        compactPresentedPhotoshootId = route?.photoshootId
                    }
                )
            ) { route in
                compactPhotoshootDetailView(photoshootId: route.photoshootId)
            }
    }

    private func returnToPhotoshootsList() {
        selectedPhotoshootId = nil
    }
    #endif

    // MARK: - Sidebar

    private var photoshootsSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Photoshoots")
                    .font(.headline)
                Spacer()
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                #if os(macOS)
                .help("Create new photoshoot")
                #endif
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if photoshoots.isEmpty {
                emptyPhotoshootsList
            } else {
                photoshootsList
            }
        }
        .background(tertiarySystemFill)
    }

    private var emptyPhotoshootsList: some View {
        AvgeekEmptyStateView(
            icon: "camera.aperture",
            title: "No photoshoots yet",
            message: "Create a photoshoot to start generating professional product photographs.",
            buttonTitle: "Create Photoshoot"
        ) {
            showCreateSheet = true
        }
    }

    private var photoshootSelectionBinding: Binding<ProductPhotoshoot?> {
        Binding(
            get: { selectedPhotoshoot },
            set: { newPhotoshoot in
                if let newPhotoshoot {
                    selectedPhotoshootId = newPhotoshoot.id
                }
            }
        )
    }

    private var photoshootsList: some View {
        List(selection: photoshootSelectionBinding) {
            ForEach(photoshoots) { photoshoot in
                PinnableRowView(
                    item: photoshoot,
                    onRename: {
                        photoshootToRename = photoshoot
                        renamePhotoshootName = photoshoot.name
                        showRenameSheet = true
                    },
                    onTogglePin: {
                        togglePin(photoshoot)
                    },
                    onDuplicate: {
                        photoshootToDuplicate = photoshoot
                        duplicatePhotoshootName = "\(photoshoot.name) (Copy)"
                        showDuplicateSheet = true
                    },
                    onDelete: {
                        photoshootToDelete = photoshoot
                        showDeleteConfirmation = true
                    }
                )
                .tag(photoshoot)
            }
        }
        .listStyle(.sidebar)
        .alert("Delete Photoshoot?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { photoshootToDelete = nil }
            Button("Delete", role: .destructive) {
                if let photoshoot = photoshootToDelete { deletePhotoshoot(photoshoot); photoshootToDelete = nil }
            }
        } message: {
            Text("This photoshoot and all its items will be permanently deleted. This action cannot be undone.")
        }
    }

    private var compactPhotoshootsList: some View {
        Group {
            if photoshoots.isEmpty {
                emptyPhotoshootsList
            } else {
                List {
                    ForEach(photoshoots) { photoshoot in
                        Button {
                            selectedPhotoshootId = photoshoot.id
                            compactPresentedPhotoshootId = photoshoot.id
                        } label: {
                            CompactPhotoshootRow(photoshoot: photoshoot)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            photoshootContextMenu(for: photoshoot)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                photoshootToDelete = photoshoot
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                togglePin(photoshoot)
                            } label: {
                                Label(
                                    photoshoot.isPinned ? "Unpin" : "Pin",
                                    systemImage: photoshoot.isPinned ? "pin.slash" : "pin"
                                )
                            }
                            .tint(.accentColor)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .alert("Delete Photoshoot?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { photoshootToDelete = nil }
            Button("Delete", role: .destructive) {
                if let photoshoot = photoshootToDelete { deletePhotoshoot(photoshoot); photoshootToDelete = nil }
            }
        } message: {
            Text("This photoshoot and all its items will be permanently deleted. This action cannot be undone.")
        }
    }

    @ViewBuilder
    private func compactPhotoshootDetailView(photoshootId: UUID) -> some View {
        if let photoshoot = photoshoots.first(where: { $0.id == photoshootId }) {
            PhotoshootEditorView(photoshoot: photoshoot)
                .id(photoshoot.id)
                .navigationTitle(photoshoot.name)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                showDetailsSheet = true
                            } label: {
                                Label("View Details", systemImage: "info.circle")
                            }

                            Divider()

                            Button {
                                togglePin(photoshoot)
                            } label: {
                                Label(
                                    photoshoot.isPinned ? "Unpin" : "Pin",
                                    systemImage: photoshoot.isPinned ? "pin.slash" : "pin"
                                )
                            }

                            Button {
                                photoshootToRename = photoshoot
                                renamePhotoshootName = photoshoot.name
                                showRenameSheet = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }

                            Button {
                                photoshootToDuplicate = photoshoot
                                duplicatePhotoshootName = "\(photoshoot.name) (Copy)"
                                showDuplicateSheet = true
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }

                            Divider()

                            Button(role: .destructive) {
                                photoshootToDelete = photoshoot
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .onAppear {
                    if selectedPhotoshootId != photoshoot.id {
                        selectedPhotoshootId = photoshoot.id
                    }
                }
        } else {
            emptyDetailState
                .navigationTitle("Product Photoshoots")
        }
    }

    @ViewBuilder
    private func photoshootContextMenu(for photoshoot: ProductPhotoshoot) -> some View {
        Button {
            togglePin(photoshoot)
        } label: {
            Label(
                photoshoot.isPinned ? "Unpin" : "Pin",
                systemImage: photoshoot.isPinned ? "pin.slash" : "pin"
            )
        }

        Button {
            photoshootToRename = photoshoot
            renamePhotoshootName = photoshoot.name
            showRenameSheet = true
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        Button {
            photoshootToDuplicate = photoshoot
            duplicatePhotoshootName = "\(photoshoot.name) (Copy)"
            showDuplicateSheet = true
        } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
        }

        Divider()

        Button(role: .destructive) {
            photoshootToDelete = photoshoot
            showDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Detail Area

    private var detailArea: some View {
        GeometryReader { geometry in
            if shouldShowExpandWindowPrompt(width: geometry.size.width) {
                ExpandWindowView()
            } else {
                Group {
                    if let photoshoot = selectedPhotoshoot {
                        PhotoshootEditorView(photoshoot: photoshoot)
                            .id(photoshoot.id)
                    } else {
                        emptyDetailState
                    }
                }
            }
        }
    }

    private func shouldShowExpandWindowPrompt(width: CGFloat) -> Bool {
        #if os(macOS)
        width < canvasMinWidth
        #else
        false
        #endif
    }

    private var emptyDetailState: some View {
        AvgeekEmptyStateView(
            icon: "camera.aperture",
            title: "Select a Photoshoot",
            message: "Choose a photoshoot from the sidebar or create a new one to start generating professional product photographs.",
            buttonTitle: "Create Photoshoot",
            buttonIcon: "plus",
            onButtonTap: { showCreateSheet = true }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Rename Sheet

    private var renameSheet: some View {
        NameInputSheet(
            title: "Rename Photoshoot",
            placeholder: "Photoshoot Name",
            actionTitle: "Rename",
            name: $renamePhotoshootName,
            isPresented: $showRenameSheet,
            onAction: renamePhotoshoot,
            onCancel: { photoshootToRename = nil },
            usesRoundedBorder: false
        )
    }

    private var duplicateSheet: some View {
        NameInputSheet(
            title: "Duplicate Photoshoot",
            placeholder: "Photoshoot Name",
            actionTitle: "Duplicate",
            name: $duplicatePhotoshootName,
            isPresented: $showDuplicateSheet,
            onAction: {
                if let photoshoot = photoshootToDuplicate {
                    duplicatePhotoshoot(photoshoot, name: duplicatePhotoshootName)
                }
            },
            onCancel: { photoshootToDuplicate = nil },
            usesRoundedBorder: false
        )
    }

    // MARK: - Actions

    private func restoreLastSelectedPhotoshoot() {
        guard selectedPhotoshootId == nil else { return }

        if let savedId = UserDefaults.standard.string(forKey: lastSelectedPhotoshootKey),
           let uuid = UUID(uuidString: savedId),
           photoshoots.contains(where: { $0.id == uuid })
        {
            selectedPhotoshootId = uuid
        }
    }

    private func duplicatePhotoshoot(_ photoshoot: ProductPhotoshoot, name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let newPhotoshoot = ProductPhotoshoot(
            name: trimmedName,
            projectId: photoshoot.projectId,
            modelId: photoshoot.modelId,
            providerId: photoshoot.providerId,
            dimensions: photoshoot.dimensionsEnum,
            productDescription: photoshoot.productDescription
        )
        newPhotoshoot.isPinned = false
        newPhotoshoot.selectedBackdropIndex = photoshoot.selectedBackdropIndex
        newPhotoshoot.customBackdropData = photoshoot.customBackdropData
        newPhotoshoot.productObjectsData = photoshoot.productObjectsData
        newPhotoshoot.cameraAngle = photoshoot.cameraAngle
        newPhotoshoot.productPosition = photoshoot.productPosition
        modelContext.insert(newPhotoshoot)

        do {
            try modelContext.save()
            loadPhotoshoots()
            selectedPhotoshootId = newPhotoshoot.id
            compactPresentedPhotoshootId = newPhotoshoot.id
            photoshootToDuplicate = nil
        } catch {
            AppLogger.data.error("Failed to duplicate photoshoot: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func togglePin(_ photoshoot: ProductPhotoshoot) {
        photoshoot.isPinned.toggle()

        do {
            try modelContext.save()
            loadPhotoshoots() // Refresh to update sort order
        } catch {
            AppLogger.ui.error("Failed to toggle pin for photoshoot: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func renamePhotoshoot() {
        guard let photoshoot = photoshootToRename else { return }
        let trimmedName = renamePhotoshootName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        photoshoot.name = trimmedName

        do {
            try modelContext.save()
            loadPhotoshoots() // Refresh to update the list
        } catch {
            AppLogger.ui.error("Failed to rename photoshoot: \(error.localizedDescription, privacy: .public)")
        }

        showRenameSheet = false
        photoshootToRename = nil
    }

    private func deletePhotoshoot(_ photoshoot: ProductPhotoshoot) {
        if selectedPhotoshootId == photoshoot.id {
            selectedPhotoshootId = nil
            compactPresentedPhotoshootId = nil
        }

        modelContext.delete(photoshoot)

        do {
            try modelContext.save()
            loadPhotoshoots()
        } catch {
            AppLogger.ui.error("Failed to delete photoshoot: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Data Loading

    /// Loads photoshoots for the current project using a predicate-based query.
    /// This is more efficient than fetching all photoshoots and filtering in memory.
    private func loadPhotoshoots() {
        let projectId = projectManager.currentProjectId
        var descriptor = FetchDescriptor<ProductPhotoshoot>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.predicate = #Predicate<ProductPhotoshoot> { photoshoot in
            photoshoot.projectId == projectId
        }

        let fetched = (try? modelContext.fetch(descriptor)) ?? []

        // Sort with pinned items first, then by date (newest first)
        photoshoots = fetched.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            return lhs.createdAt > rhs.createdAt
        }
    }
}

private enum CompactPhotoshootRoute: Hashable, Identifiable {
    case detail(UUID)

    var id: UUID {
        photoshootId
    }

    var photoshootId: UUID {
        switch self {
        case let .detail(id):
            id
        }
    }
}

private struct CompactPhotoshootRow: View {
    let photoshoot: ProductPhotoshoot

    private var modelName: String {
        ProviderService.shared.model(by: photoshoot.modelId)?.modelName ?? "Unknown Model"
    }

    private var providerCode: String? {
        guard let uuid = UUID(uuidString: photoshoot.providerId),
              let provider = providersById[uuid]
        else {
            return nil
        }
        return "\(provider.providerCode)".lowercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if photoshoot.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }

                    Text(photoshoot.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                HStack(alignment: .center, spacing: 4) {
                    if let providerCode {
                        Image(providerArtworkName(code: providerCode, variant: .square))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                    }

                    Text(modelName)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(photoshoot.dimensionsEnum.displayName)
                    .font(.body)
                    .foregroundStyle(.secondary)

                Text(photoshoot.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 6)
    }
}

private struct PhotoshootDetailsSheet: View {
    let photoshoot: ProductPhotoshoot
    @Binding var isPresented: Bool

    private var providerName: String {
        guard let uuid = UUID(uuidString: photoshoot.providerId),
              let provider = providersById[uuid]
        else {
            return "Unknown Provider"
        }
        return provider.providerName
    }

    private var modelName: String {
        ProviderService.shared.model(by: photoshoot.modelId)?.modelName ?? "Unknown Model"
    }

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("Aspect Ratio", value: photoshoot.dimensionsEnum.displayName)
                LabeledContent("Provider", value: providerName)
                LabeledContent("Model", value: modelName)
            }
            .navigationTitle("Photoshoot Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
