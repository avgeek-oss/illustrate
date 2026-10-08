// MARK: - StoryboardListView.swift

// Main view for managing storyboards with sidebar + detail layout.
//
// StoryboardListView provides a master-detail interface:
// - Left sidebar: List of storyboards with pin, rename, delete
// - Right detail: Selected storyboard editor
//
// ## Layout Pattern
// Follows the same pattern as Agent Builder and Flow Canvas:
// - NavigationSplitView with sidebar and detail
// - PinnableRowView for list items

import AvgeekDesignSystem
import OSLog
import SwiftData
import SwiftUI

/// Main container view for storyboard management.
struct StoryboardListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var projectManager: ProjectManager

    @Query(sort: \Storyboard.createdAt, order: .reverse) private var allStoryboards: [Storyboard]

    @State private var selectedStoryboard: Storyboard?
    @State private var showCreateSheet = false
    @State private var showRenameSheet = false
    @State private var renameStoryboardName = ""
    @State private var storyboardToRename: Storyboard?
    @State private var showDuplicateSheet = false
    @State private var duplicateStoryboardName = ""
    @State private var storyboardToDuplicate: Storyboard?
    @State private var storyboardToDelete: Storyboard?
    @State private var showDeleteConfirmation = false

    @State private var storyboards: [Storyboard] = []
    @State private var compactPresentedStoryboardId: UUID?
    @State private var showCompactDetailsSheet = false

    private func updateStoryboards() {
        storyboards = filteredAndSorted(allStoryboards, for: projectManager.currentProjectId)
    }

    private var lastSelectedStoryboardKey: String {
        "lastSelectedStoryboard_\(projectManager.currentProjectId.uuidString)"
    }

    private var shouldUseCompactMobileLayout: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    private var compactStoryboardRouteBinding: Binding<CompactStoryboardRoute?> {
        Binding(
            get: { compactPresentedStoryboardId.map(CompactStoryboardRoute.detail) },
            set: { route in
                compactPresentedStoryboardId = route?.storyboardId
            }
        )
    }

    private var compactDetailsSheetBinding: Binding<Bool> {
        Binding(
            get: { shouldUseCompactMobileLayout && showCompactDetailsSheet },
            set: { showCompactDetailsSheet = $0 }
        )
    }

    private var compactMobileContent: some View {
        compactStoryboardsList
            .navigationDestination(item: compactStoryboardRouteBinding) { route in
                compactStoryboardDetailView(storyboardId: route.storyboardId)
            }
    }

    private var baseContent: some View {
        Group {
            if shouldUseCompactMobileLayout {
                compactMobileContent
            } else {
                platformLayout
            }
        }
        .navigationTitle("Storyboards")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var presentationContent: some View {
        baseContent
            .toolbar {
                if shouldUseCompactMobileLayout, compactPresentedStoryboardId == nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showCreateSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                StoryboardCreateSheet(isPresented: $showCreateSheet) { storyboard in
                    selectedStoryboard = storyboard
                    compactPresentedStoryboardId = storyboard.id
                }
            }
            .sheet(isPresented: $showRenameSheet) {
                renameSheet
            }
            .sheet(isPresented: $showDuplicateSheet) {
                duplicateSheet
            }
            .sheet(isPresented: compactDetailsSheetBinding) {
                compactDetailsSheet
            }
    }

    var body: some View {
        presentationContent
            .onChange(of: selectedStoryboard) { _, newStoryboard in
                if let newStoryboard {
                    UserDefaults.standard.set(newStoryboard.id.uuidString, forKey: lastSelectedStoryboardKey)
                }
            }
            .onChange(of: compactPresentedStoryboardId) { _, newId in
                if newId == nil, shouldUseCompactMobileLayout {
                    selectedStoryboard = nil
                }
            }
            .onAppear {
                updateStoryboards()
                restoreLastSelectedStoryboard()
            }
            .onChange(of: allStoryboards) { _, _ in updateStoryboards() }
            .onChange(of: projectManager.currentProjectId) { _, _ in
                compactPresentedStoryboardId = nil
                selectedStoryboard = nil
                showCompactDetailsSheet = false
                updateStoryboards()
            }
            .onChange(of: storyboards) { _, newStoryboards in
                if selectedStoryboard == nil, !newStoryboards.isEmpty {
                    restoreLastSelectedStoryboard()
                }
            }
    }

    @ViewBuilder
    private var platformLayout: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            storyboardsSidebar
                .frame(width: 240)

            Divider()

            detailArea
                .frame(minWidth: 0, maxWidth: .infinity)
        }
        #else
        NavigationSplitView {
            storyboardsSidebar
        } detail: {
            detailArea
        }
        #endif
    }

    // MARK: - Sidebar

    private var storyboardsSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Storyboards")
                    .font(.headline)
                Spacer()
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                #if os(macOS)
                .help("Create new storyboard")
                #endif
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if storyboards.isEmpty {
                emptyStoryboardsList
            } else {
                storyboardsList
            }
        }
        .background(tertiarySystemFill)
    }

    private var emptyStoryboardsList: some View {
        AvgeekEmptyStateView(
            icon: "movieclapper",
            title: "No storyboards yet",
            message: "Create a storyboard to start building multi-scene movies.",
            buttonTitle: "Create Storyboard"
        ) {
            showCreateSheet = true
        }
    }

    private var storyboardsList: some View {
        List(selection: $selectedStoryboard) {
            ForEach(storyboards) { storyboard in
                PinnableRowView(
                    item: storyboard,
                    onRename: {
                        storyboardToRename = storyboard
                        renameStoryboardName = storyboard.name
                        showRenameSheet = true
                    },
                    onTogglePin: {
                        togglePin(storyboard)
                    },
                    onDuplicate: {
                        storyboardToDuplicate = storyboard
                        duplicateStoryboardName = "\(storyboard.name) (Copy)"
                        showDuplicateSheet = true
                    },
                    onDelete: {
                        storyboardToDelete = storyboard
                        showDeleteConfirmation = true
                    }
                )
                .tag(storyboard)
            }
        }
        .listStyle(.sidebar)
        .alert("Delete Storyboard?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { storyboardToDelete = nil }
            Button("Delete", role: .destructive) {
                if let storyboard = storyboardToDelete { deleteStoryboard(storyboard); storyboardToDelete = nil }
            }
        } message: {
            Text("This storyboard and all its scenes will be permanently deleted. This action cannot be undone.")
        }
    }

    private var compactStoryboardsList: some View {
        Group {
            if storyboards.isEmpty {
                emptyStoryboardsList
            } else {
                List {
                    ForEach(storyboards) { storyboard in
                        Button {
                            selectedStoryboard = storyboard
                            compactPresentedStoryboardId = storyboard.id
                        } label: {
                            CompactStoryboardRow(storyboard: storyboard)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            storyboardContextMenu(for: storyboard)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                storyboardToDelete = storyboard
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                togglePin(storyboard)
                            } label: {
                                Label(
                                    storyboard.isPinned ? "Unpin" : "Pin",
                                    systemImage: storyboard.isPinned ? "pin.slash" : "pin"
                                )
                            }
                            .tint(.accentColor)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .alert("Delete Storyboard?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { storyboardToDelete = nil }
            Button("Delete", role: .destructive) {
                if let storyboard = storyboardToDelete { deleteStoryboard(storyboard); storyboardToDelete = nil }
            }
        } message: {
            Text("This storyboard and all its scenes will be permanently deleted. This action cannot be undone.")
        }
    }

    // MARK: - Detail Area

    private var detailArea: some View {
        Group {
            if let storyboard = selectedStoryboard {
                StoryboardEditorView(storyboard: storyboard)
                    .id(storyboard.id)
            } else {
                emptyDetailState
            }
        }
    }

    private var emptyDetailState: some View {
        AvgeekEmptyStateView(
            icon: "movieclapper",
            title: "Select a Storyboard",
            message: "Choose a storyboard from the sidebar or create a new one to start building multi-scene movies.",
            buttonTitle: "Create Storyboard",
            buttonIcon: "plus",
            onButtonTap: { showCreateSheet = true }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func compactStoryboardDetailView(storyboardId: UUID) -> some View {
        if let storyboard = storyboards.first(where: { $0.id == storyboardId }) {
            StoryboardEditorView(storyboard: storyboard)
                .id(storyboard.id)
                .navigationTitle(storyboard.name)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                showCompactDetailsSheet = true
                            } label: {
                                Label("View Details", systemImage: "info.circle")
                            }

                            Divider()

                            Button {
                                togglePin(storyboard)
                            } label: {
                                Label(
                                    storyboard.isPinned ? "Unpin" : "Pin",
                                    systemImage: storyboard.isPinned ? "pin.slash" : "pin"
                                )
                            }

                            Button {
                                storyboardToRename = storyboard
                                renameStoryboardName = storyboard.name
                                showRenameSheet = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }

                            Button {
                                storyboardToDuplicate = storyboard
                                duplicateStoryboardName = "\(storyboard.name) (Copy)"
                                showDuplicateSheet = true
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }

                            Divider()

                            Button(role: .destructive) {
                                storyboardToDelete = storyboard
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
        } else {
            emptyDetailState
                .navigationTitle("Storyboards")
        }
    }

    // MARK: - Rename Sheet

    private var renameSheet: some View {
        NameInputSheet(
            title: "Rename Storyboard",
            placeholder: "Storyboard Name",
            actionTitle: "Rename",
            name: $renameStoryboardName,
            isPresented: $showRenameSheet,
            onAction: renameStoryboard,
            onCancel: { storyboardToRename = nil },
            usesRoundedBorder: false
        )
    }

    private var duplicateSheet: some View {
        NameInputSheet(
            title: "Duplicate Storyboard",
            placeholder: "Storyboard Name",
            actionTitle: "Duplicate",
            name: $duplicateStoryboardName,
            isPresented: $showDuplicateSheet,
            onAction: {
                if let storyboard = storyboardToDuplicate {
                    duplicateStoryboard(storyboard, name: duplicateStoryboardName)
                }
            },
            onCancel: { storyboardToDuplicate = nil },
            usesRoundedBorder: false
        )
    }

    @ViewBuilder
    private var compactDetailsSheet: some View {
        if let storyboard = selectedStoryboard {
            NavigationStack {
                Form {
                    Section {
                        LabeledContent("Mode", value: storyboard.mode.displayName)
                        LabeledContent("Provider", value: compactProviderName(for: storyboard))
                        LabeledContent("Model", value: compactModelName(for: storyboard))
                        LabeledContent("Dimensions", value: storyboard.dimensions)
                        LabeledContent("Scene Duration", value: "\(Int(storyboard.sceneDuration)) seconds")

                        if !storyboard.resolution.isEmpty {
                            LabeledContent("Resolution", value: storyboard.resolution)
                        }

                        LabeledContent(
                            "Created",
                            value: storyboard.createdAt.formatted(date: .abbreviated, time: .shortened)
                        )
                    }
                }
                .formStyle(.grouped)
                .navigationTitle("Storyboard Details")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showCompactDetailsSheet = false
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func storyboardContextMenu(for storyboard: Storyboard) -> some View {
        Button {
            togglePin(storyboard)
        } label: {
            Label(
                storyboard.isPinned ? "Unpin" : "Pin",
                systemImage: storyboard.isPinned ? "pin.slash" : "pin"
            )
        }

        Button {
            storyboardToRename = storyboard
            renameStoryboardName = storyboard.name
            showRenameSheet = true
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        Button {
            storyboardToDuplicate = storyboard
            duplicateStoryboardName = "\(storyboard.name) (Copy)"
            showDuplicateSheet = true
        } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
        }

        Divider()

        Button(role: .destructive) {
            storyboardToDelete = storyboard
            showDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Actions

    private func restoreLastSelectedStoryboard() {
        guard selectedStoryboard == nil,
              let savedId = UserDefaults.standard.string(forKey: lastSelectedStoryboardKey),
              let uuid = UUID(uuidString: savedId),
              let storyboard = storyboards.first(where: { $0.id == uuid })
        else { return }

        selectedStoryboard = storyboard
    }

    private func compactProviderName(for storyboard: Storyboard) -> String {
        guard let providerId = UUID(uuidString: storyboard.providerId),
              let provider = providersById[providerId]
        else {
            return "Not selected"
        }

        return provider.providerName
    }

    private func compactModelName(for storyboard: Storyboard) -> String {
        ProviderService.shared.model(by: storyboard.modelId)?.modelName ?? "Not selected"
    }

    private func duplicateStoryboard(_ storyboard: Storyboard, name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let newStoryboard = Storyboard(
            name: trimmedName,
            projectId: storyboard.projectId,
            mode: storyboard.mode,
            modelId: storyboard.modelId,
            providerId: storyboard.providerId,
            dimensions: storyboard.dimensions,
            sceneDuration: storyboard.sceneDuration,
            resolution: storyboard.resolution
        )
        newStoryboard.isPinned = false
        modelContext.insert(newStoryboard)

        do {
            try modelContext.save()
            updateStoryboards()
            storyboardToDuplicate = nil
        } catch {
            AppLogger.data.error("Failed to duplicate storyboard: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func togglePin(_ storyboard: Storyboard) {
        storyboard.isPinned.toggle()

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to toggle pin for storyboard: \(error.localizedDescription, privacy: .public)")
        }

        updateStoryboards()
    }

    private func renameStoryboard() {
        guard let storyboard = storyboardToRename else { return }
        let trimmedName = renameStoryboardName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        storyboard.name = trimmedName

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to rename storyboard: \(error.localizedDescription, privacy: .public)")
        }

        showRenameSheet = false
        storyboardToRename = nil
    }

    private func deleteStoryboard(_ storyboard: Storyboard) {
        if selectedStoryboard?.id == storyboard.id {
            selectedStoryboard = nil
            if compactPresentedStoryboardId == storyboard.id {
                compactPresentedStoryboardId = nil
            }
        }

        modelContext.delete(storyboard)

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to delete storyboard: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private enum CompactStoryboardRoute: Hashable, Identifiable {
    case detail(UUID)

    var id: UUID {
        storyboardId
    }

    var storyboardId: UUID {
        switch self {
        case let .detail(storyboardId):
            storyboardId
        }
    }
}

private struct CompactStoryboardRow: View {
    let storyboard: Storyboard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if storyboard.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.accent)
                }

                Text(storyboard.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Spacer(minLength: 8)
            }

            Text(storyboard.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
