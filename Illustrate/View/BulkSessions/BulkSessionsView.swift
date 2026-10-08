// MARK: - BulkSessionsView.swift

// Main view for bulk image generation from CSV files.
//
// BulkSessionsView provides an interface for batch image generation:
// - Sidebar: Session list with create/rename/delete
// - Content: Configuration panel + items table/gallery
//
// ## Layout
// Uses HStack layout similar to ChatThreadsView and AgentCanvasView:
// - Sidebar (240px): Session management
// - Content: Session configuration and prompt list
//
// ## Features
// - Create, rename, delete, pin sessions
// - Import prompts from CSV (max 250)
// - Configure model and generation parameters
// - Start/cancel bulk generation
// - Toggle between table and gallery view
// - Download all generated images

import AvgeekDesignSystem
import IllustrateProviders
import KeychainSwift
import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

#if !os(macOS)
import UIKit

private struct FileShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
#endif

/// Main container view for bulk image generation sessions.
struct BulkSessionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var queueManager: QueueManager

    private let keychain: KeychainSwift = {
        let kc = KeychainSwift()
        kc.accessGroup = TEAM_KEYCHAIN_AG
        kc.synchronizable = true
        return kc
    }()

    @Query(sort: \BulkSession.createdAt, order: .reverse) private var allSessions: [BulkSession]
    @ObservedObject private var providerKeysCache = ProviderKeysCache.shared

    @State private var itemsForSession: [BulkSessionItem] = []
    @State private var itemsFetchTask: Task<Void, Never>?
    @State private var selectedSessionId: UUID?
    @State private var showCreateSheet = false
    @State private var newSessionName = ""
    @State private var showRenameSheet = false
    @State private var renameSessionName = ""
    @State private var sessionToRename: BulkSession?
    @State private var showGuide = false
    @State private var showCostInfo = false
    @State private var generationTask: Task<Void, Never>?

    /// Whether generation is currently running
    @State private var isGenerating = false

    @State private var showGalleryView = false
    @State private var showFileImporter = false
    @State private var showStartConfirmation = false
    @State private var showGenerationError = false
    @State private var generationErrorMessage = ""
    @State private var showImportSuccess = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var showDuplicateSheet = false
    @State private var duplicateSessionName = ""
    @State private var sessionToDuplicate: BulkSession?

    @State private var sessions: [BulkSession] = []
    @State private var sessionToDelete: BulkSession?
    @State private var showDeleteConfirmation = false
    @State private var compactPresentedSessionId: UUID?
    @State private var templateShareFile: IdentifiableFileURL?
    @State private var showCompactConfigSheet = false
    @State private var showCompactDetailsSheet = false
    @State private var showCompactAddPromptSheet = false

    private func updateSessions() {
        sessions = filteredAndSorted(allSessions, for: projectManager.currentProjectId)
    }

    private var selectedSession: BulkSession? {
        guard let id = selectedSessionId else { return nil }
        return sessions.first { $0.id == id }
    }

    private var lastSelectedSessionKey: String {
        "lastSelectedBulkSession_\(projectManager.currentProjectId.uuidString)"
    }

    private var providerKeysForProject: [ProviderKey] {
        providerKeysCache.providerKeys
    }

    // MARK: - Computed Properties for Progress

    /// Single-pass computation of all status counts for efficiency
    private var statusCounts: (completed: Int, pending: Int, inProgress: Int, failed: Int, cancelled: Int) {
        var completed = 0, pending = 0, inProgress = 0, failed = 0, cancelled = 0
        for item in itemsForSession {
            switch item.status {
            case .COMPLETED: completed += 1
            case .PENDING: pending += 1
            case .IN_PROGRESS: inProgress += 1
            case .FAILED: failed += 1
            case .CANCELLED: cancelled += 1
            }
        }
        return (completed, pending, inProgress, failed, cancelled)
    }

    private var completedCount: Int {
        statusCounts.completed
    }

    private var totalCount: Int {
        itemsForSession.count
    }

    private var pendingCount: Int {
        statusCounts.pending
    }

    private var inProgressCount: Int {
        statusCounts.inProgress
    }

    private var failedCount: Int {
        statusCounts.failed
    }

    private var cancelledCount: Int {
        statusCounts.cancelled
    }

    /// Count of items that can be processed (pending + aborted in-progress + failed + cancelled for retry)
    private var processableCount: Int {
        let counts = statusCounts
        return counts.pending + counts.inProgress + counts.failed + counts.cancelled
    }

    private var hasCompletedItems: Bool {
        completedCount > 0
    }

    /// True if we should show "Resume" instead of "Start" (has prior progress)
    private var isResumable: Bool {
        hasCompletedItems || itemsForSession.contains { $0.status == .FAILED || $0.status == .CANCELLED }
    }

    /// True if generation has ever started for this session
    private var sessionHasStarted: Bool {
        if isGenerating {
            return true
        }
        guard let session = selectedSession else { return false }
        if session.status == .COMPLETED {
            return true
        }
        guard !itemsForSession.isEmpty else { return false }
        return itemsForSession.contains { $0.status != .PENDING }
    }

    private var costPerImage: Double {
        guard let session = selectedSession,
              !session.selectedModelId.isEmpty,
              let model = ProviderService.shared.model(by: session.selectedModelId)
        else { return 0 }

        let config = session.savedConfiguration
        return model.modelCode.rawImageCost(
            quality: config.selectedQuality,
            dimensions: config.selectedDimensions,
            resolution: config.selectedResolution.isEmpty ? nil : config.selectedResolution,
            numberOfImages: 1
        )
    }

    private var costCurrency: EnumProviderCreditCurrency {
        guard let session = selectedSession,
              !session.selectedProviderId.isEmpty,
              let providerId = UUID(uuidString: session.selectedProviderId),
              let provider = getProvider(providerId: providerId)
        else { return .USD }
        return provider.creditCurrency
    }

    private var estimatedCost: Double {
        costPerImage * Double(totalCount)
    }

    private var formattedCost: String {
        if costCurrency == .USD {
            return formatEstimatedCost(estimatedCost)
        }
        return estimatedCost == floor(estimatedCost)
            ? String(format: "%.0f credits", estimatedCost)
            : String(format: "%.2f credits", estimatedCost)
    }

    private var formattedCostPerImage: String {
        if costCurrency == .USD {
            return formatEstimatedCost(costPerImage)
        }
        return costPerImage == floor(costPerImage)
            ? String(format: "%.0f credits", costPerImage)
            : String(format: "%.2f credits", costPerImage)
    }

    private var canStart: Bool {
        guard let session = selectedSession else { return false }
        return !isGenerating &&
            processableCount > 0 &&
            !session.selectedProviderId.isEmpty &&
            !session.selectedModelId.isEmpty
    }

    private var shouldUseCompactMobileLayout: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    private var compactSessionRouteBinding: Binding<CompactBulkSessionRoute?> {
        Binding(
            get: { compactPresentedSessionId.map(CompactBulkSessionRoute.detail) },
            set: { route in
                compactPresentedSessionId = route?.sessionId
            }
        )
    }

    private var compactMobileContent: some View {
        compactSessionsList
            .navigationDestination(item: compactSessionRouteBinding) { route in
                compactSessionDetailView(sessionId: route.sessionId)
            }
    }

    private var guideSheetBinding: Binding<Bool> {
        Binding(
            get: { shouldUseCompactMobileLayout && showGuide },
            set: { if !$0 { showGuide = false } }
        )
    }

    private var compactConfigSheetBinding: Binding<Bool> {
        Binding(
            get: { shouldUseCompactMobileLayout && showCompactConfigSheet },
            set: { showCompactConfigSheet = $0 }
        )
    }

    private var compactDetailsSheetBinding: Binding<Bool> {
        Binding(
            get: { shouldUseCompactMobileLayout && showCompactDetailsSheet },
            set: { showCompactDetailsSheet = $0 }
        )
    }

    private var baseContent: some View {
        Group {
            if shouldUseCompactMobileLayout {
                compactMobileContent
            } else {
                platformLayout
            }
        }
        .navigationTitle(shouldUseCompactMobileLayout ? compactMobileTitle : "Bulk Generate")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var presentationContent: some View {
        baseContent
            .toolbar {
                if shouldUseCompactMobileLayout, compactPresentedSessionId == nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            newSessionName = ""
                            showCreateSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                createSessionSheet
            }
            .sheet(isPresented: $showRenameSheet) {
                renameSessionSheet
            }
            .sheet(isPresented: $showDuplicateSheet) {
                duplicateSessionSheet
            }
            .sheet(isPresented: guideSheetBinding) {
                bulkGuideSheet
            }
            .sheet(item: $templateShareFile) { shareFile in
                #if os(macOS)
                EmptyView()
                #else
                FileShareSheet(activityItems: [shareFile.url])
                #endif
            }
            .sheet(isPresented: compactConfigSheetBinding) {
                compactConfigSheet
            }
            .sheet(isPresented: compactDetailsSheetBinding) {
                compactDetailsSheet
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [UTType.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Bulk Generation", isPresented: $showStartConfirmation) {
                Button("Okay") {
                    startGeneration()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "Stay on this page to ensure the bulk generation process continues. Navigating elsewhere will pause the process."
                )
            }
            .alert("Generation Error", isPresented: $showGenerationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(generationErrorMessage)
            }
            .alert("Import Error", isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importErrorMessage)
            }
            .alert("Prompts Imported", isPresented: $showImportSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your prompts are ready. Click Start to begin bulk generation.")
            }
    }

    private var lifecycleContent: some View {
        presentationContent
            .onChange(of: selectedSessionId) { _, newId in
                handleSelectedSessionChange(newId)
            }
            .onChange(of: compactPresentedSessionId) { _, newId in
                handleCompactPresentedSessionChange(newId)
            }
            .onChange(of: sessions) { _, newSessions in
                handleSessionsChange(newSessions)
            }
            .onAppear {
                providerKeysCache.loadIfNeeded(projectId: projectManager.currentProjectId, modelContext: modelContext)
                updateSessions()
                restoreLastSelectedSession()
                syncIsGeneratingState()
            }
            .onChange(of: allSessions) { _, _ in updateSessions() }
            .onChange(of: projectManager.currentProjectId) { _, _ in
                handleProjectChange()
            }
            .onDisappear {
                itemsFetchTask?.cancel()
                itemsFetchTask = nil
                generationTask?.cancel()
                generationTask = nil
                resetGenerationStateOnDisappear()
            }
    }

    var body: some View {
        lifecycleContent
    }

    private var compactMobileTitle: String {
        "Bulk Generate"
    }

    private func resetGenerationStateOnDisappear() {
        guard isGenerating, let session = selectedSession else {
            isGenerating = false
            return
        }

        for item in itemsForSession {
            if item.status == .IN_PROGRESS {
                item.status = .PENDING
            }
        }

        session.status = .IDLE
        try? modelContext.save()
        isGenerating = false
    }

    @MainActor
    private func regenerateSingleItem(_ item: BulkSessionItem) {
        guard let session = selectedSession else { return }

        let keychainKey = ProjectManager.keychainKey(
            projectId: projectManager.currentProjectId,
            providerId: UUID(uuidString: session.savedConfiguration.selectedProviderId)!
        )
        guard let providerSecret = keychain.get(keychainKey) else { return }

        guard let providerKey = providerKeysCache.providerKeys.first(where: {
            $0.providerId.uuidString == session.savedConfiguration.selectedProviderId
        }) else { return }

        guard let providerKeyInfo = try? providerKey.toProviderKeyInfo() else { return }

        let config = session.savedConfiguration
        let commonPrompt = session.commonPrompt

        item.status = .PENDING
        item.generationId = nil
        item.errorMessage = nil
        try? modelContext.save()

        Task {
            await generateSingleItem(
                item: item,
                config: config,
                commonPrompt: commonPrompt,
                providerKeyInfo: providerKeyInfo,
                providerSecret: providerSecret
            )
        }
    }

    @ViewBuilder
    private var platformLayout: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            sessionsSidebar
                .frame(width: 240)

            Divider()

            contentArea
                .frame(minWidth: 0, maxWidth: .infinity)
        }
        #else
        NavigationSplitView {
            sessionsSidebar
        } detail: {
            contentArea
        }
        #endif
    }

    // MARK: - Sidebar

    private var sessionsSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Sessions")
                    .font(.headline)
                Spacer()
                Button {
                    newSessionName = ""
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Create new session")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if sessions.isEmpty {
                emptySessionsList
            } else {
                sessionsList
            }
        }
        .background(tertiarySystemFill)
    }

    private var emptySessionsList: some View {
        AvgeekEmptyStateView(
            icon: "square.stack.3d.up",
            title: "No sessions yet",
            message: "Create a session to start generating images in bulk from CSV files.",
            buttonTitle: "Create Session"
        ) {
            newSessionName = ""
            showCreateSheet = true
        }
    }

    private var sessionSelectionBinding: Binding<BulkSession?> {
        Binding(
            get: { selectedSession },
            set: { newSession in
                // Only update selection if user is selecting a new session.
                // Ignore nil assignments during navigation transitions to preserve selection.
                if let newSession {
                    selectedSessionId = newSession.id
                }
            }
        )
    }

    private var sessionsList: some View {
        List(selection: sessionSelectionBinding) {
            ForEach(sessions) { session in
                PinnableRowView(
                    item: session,
                    onRename: {
                        sessionToRename = session
                        renameSessionName = session.name
                        showRenameSheet = true
                    },
                    onTogglePin: {
                        togglePin(session)
                    },
                    onDuplicate: {
                        sessionToDuplicate = session
                        duplicateSessionName = "\(session.name) (Copy)"
                        showDuplicateSheet = true
                    },
                    onDelete: {
                        sessionToDelete = session
                        showDeleteConfirmation = true
                    }
                )
                .tag(session)
            }
        }
        .listStyle(.sidebar)
        .alert("Delete Session?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete { deleteSession(session); sessionToDelete = nil }
            }
        } message: {
            Text("This session and all its prompts will be permanently deleted. This action cannot be undone.")
        }
    }

    private var compactSessionsList: some View {
        Group {
            if sessions.isEmpty {
                emptySessionsList
            } else {
                List {
                    ForEach(sessions) { session in
                        Button {
                            selectedSessionId = session.id
                            compactPresentedSessionId = session.id
                        } label: {
                            CompactBulkSessionRow(session: session)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            sessionContextMenu(for: session)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                sessionToDelete = session
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                togglePin(session)
                            } label: {
                                Label(
                                    session.isPinned ? "Unpin" : "Pin",
                                    systemImage: session.isPinned ? "pin.slash" : "pin"
                                )
                            }
                            .tint(.accentColor)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .alert("Delete Session?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete { deleteSession(session); sessionToDelete = nil }
            }
        } message: {
            Text("This session and all its prompts will be permanently deleted. This action cannot be undone.")
        }
    }

    // MARK: - Content Area

    private var contentArea: some View {
        GeometryReader { geometry in
            if geometry.size.width < canvasMinWidth {
                ExpandWindowView()
            } else {
                Group {
                    if let session = selectedSession {
                        sessionDetailContent(session: session, isCompactLayout: false)
                    } else {
                        emptyContentState
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func compactSessionDetailView(sessionId: UUID) -> some View {
        if let session = sessions.first(where: { $0.id == sessionId }) {
            sessionDetailContent(session: session, isCompactLayout: true)
                .navigationTitle(session.name)
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
                                showGuide = true
                            } label: {
                                Label("Guide", systemImage: "questionmark.circle")
                            }

                            Divider()

                            Button {
                                togglePin(session)
                            } label: {
                                Label(
                                    session.isPinned ? "Unpin" : "Pin",
                                    systemImage: session.isPinned ? "pin.slash" : "pin"
                                )
                            }

                            Button {
                                sessionToRename = session
                                renameSessionName = session.name
                                showRenameSheet = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }

                            Button {
                                sessionToDuplicate = session
                                duplicateSessionName = "\(session.name) (Copy)"
                                showDuplicateSheet = true
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }

                            Divider()

                            Button(role: .destructive) {
                                sessionToDelete = session
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
                    if selectedSessionId != session.id {
                        selectedSessionId = session.id
                    }
                }
        } else {
            emptyContentState
                .navigationTitle("Bulk Generate")
        }
    }

    @ViewBuilder
    private func sessionContextMenu(for session: BulkSession) -> some View {
        Button {
            togglePin(session)
        } label: {
            Label(
                session.isPinned ? "Unpin" : "Pin",
                systemImage: session.isPinned ? "pin.slash" : "pin"
            )
        }

        Button {
            sessionToRename = session
            renameSessionName = session.name
            showRenameSheet = true
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        Button {
            sessionToDuplicate = session
            duplicateSessionName = "\(session.name) (Copy)"
            showDuplicateSheet = true
        } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
        }

        Divider()

        Button(role: .destructive) {
            sessionToDelete = session
            showDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func sessionDetailContent(session: BulkSession, isCompactLayout: Bool) -> some View {
        VStack(spacing: 0) {
            if isCompactLayout {
                compactSessionControls
                Divider()
            } else {
                sessionHeader(session: session)
                Divider()

                SessionConfigPanel(
                    session: session,
                    providerKeys: providerKeysForProject,
                    items: itemsForSession,
                    isGenerating: isGenerating,
                    sessionHasStarted: sessionHasStarted,
                    onItemsImported: { newItems in
                        importItems(newItems)
                        showImportSuccess = true
                    },
                    showFileImporter: $showFileImporter,
                    isCompactLayout: isCompactLayout
                )

                Divider()
            }

            SessionItemsTable(
                items: itemsForSession,
                showGalleryView: $showGalleryView,
                isGenerating: isGenerating,
                sessionHasStarted: sessionHasStarted,
                onEditItem: { item, newPrompt in
                    editItem(item, newPrompt: newPrompt)
                },
                onDeleteItem: { item in
                    deleteItem(item)
                },
                onRegenerateItem: { item in
                    regenerateSingleItem(item)
                },
                onAddItem: { prompt, filename in
                    addItem(prompt: prompt, filename: filename)
                },
                onImportCSV: {
                    showFileImporter = true
                },
                onDownloadTemplate: {
                    downloadTemplateCSV()
                },
                isCompactLayout: isCompactLayout,
                showCompactViewToggle: !isCompactLayout,
                externalShowAddPromptSheet: isCompactLayout ? $showCompactAddPromptSheet : nil
            )
        }
    }

    private func sessionHeader(session: BulkSession) -> some View {
        HStack {
            Text(session.name)
                .font(.headline)

            Spacer()

            #if os(macOS)
            Button {
                downloadAllAssets()
            } label: {
                Label("Download All", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.bordered)
            .disabled(!hasCompletedItems || isGenerating)
            .help("Download all generated images")
            #endif

            // Cost Info button
            if totalCount > 0 {
                costInfoButton
            }

            // Guide button
            guideButton

            // Start/Resume/Pause button
            if isGenerating {
                Button {
                    pauseGeneration()
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .help("Pause generation")
            } else if processableCount > 0 {
                Button {
                    showStartConfirmation = true
                } label: {
                    Label(isResumable ? "Resume" : "Start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canStart)
                .help(isResumable ? "Resume generation" : "Start generation")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(tertiarySystemFill)
    }

    private var compactSessionControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $showGalleryView) {
                Label("Prompts", systemImage: "list.bullet")
                    .tag(false)
                Label("Gallery", systemImage: "square.grid.2x2")
                    .tag(true)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Button {
                    showCompactConfigSheet = true
                } label: {
                    Label("Set Up", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .font(.callout)
                .buttonStyle(.bordered)

                Button {
                    showCompactAddPromptSheet = true
                } label: {
                    Label("Add Prompt", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .font(.callout)
                .buttonStyle(.bordered)
                .disabled(isGenerating)
            }

            if isGenerating {
                Button {
                    pauseGeneration()
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .font(.callout)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            } else if processableCount > 0 {
                Button {
                    startGeneration()
                } label: {
                    Label(isResumable ? "Resume" : "Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .font(.callout)
                .buttonStyle(.borderedProminent)
                .disabled(!canStart)
            }
        }
        .padding(16)
        .background(systemBackground)
    }

    private var emptyContentState: some View {
        AvgeekEmptyStateView(
            icon: "square.stack.3d.up",
            title: "Select a session",
            message: "Choose a session from the sidebar or create a new one to start bulk generation."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Cost Info Button

    private var costInfoButton: some View {
        Button {
            showCostInfo.toggle()
        } label: {
            Label("Cost Estimate", systemImage: "dollarsign.circle")
        }
        .buttonStyle(.bordered)
        .help("View cost breakdown")
        .popover(isPresented: $showCostInfo) {
            costInfoPopover
        }
    }

    private var costInfoPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cost Estimate")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow {
                    Text("Cost per image")
                        .foregroundStyle(.secondary)
                    Text(formattedCostPerImage)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                GridRow {
                    Text("Total images")
                        .foregroundStyle(.secondary)
                    Text("\(totalCount)")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Divider()
                    .gridCellUnsizedAxes(.horizontal)

                GridRow {
                    Text("Estimated total")
                        .fontWeight(.semibold)
                    Text(formattedCost)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            Text("Actual cost may vary based on provider pricing.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(minWidth: 280)
    }

    // MARK: - Guide Button

    private var guideButton: some View {
        GuidePopover(
            title: "Bulk Generate Guide",
            sections: bulkGuideSections,
            isPresented: $showGuide,
            height: 380
        )
    }

    private var bulkGuideSections: [GuideSection] {
        [
            GuideSection(
                title: "What is Bulk Generate?",
                content: "Bulk Generate allows you to create multiple images from a list of prompts imported from a CSV file. Configure your model settings once, and generate all images with controlled concurrency."
            ),
            GuideSection(
                title: "Quick Reference",
                items: [
                    GuideItem(icon: "doc.text", text: "Import a CSV file with a 'prompt' column header."),
                    GuideItem(icon: "slider.horizontal.3", text: "Set concurrency (1-10) to control rate limits."),
                    GuideItem(icon: "text.append", text: "Add a common prompt suffix applied to all prompts."),
                    GuideItem(icon: "play.fill", text: "Tap Start to begin generation. Pause stops pending items."),
                    GuideItem(icon: "plus", text: "You can also add prompts manually one by one."),
                ]
            ),
        ]
    }

    private var bulkGuideSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(bulkGuideSections.enumerated()), id: \.offset) { index, section in
                        if index > 0 {
                            Divider()
                        }
                        bulkGuideSection(section)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showGuide = false
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }

    @ViewBuilder
    private var compactConfigSheet: some View {
        if let session = selectedSession {
            NavigationStack {
                SessionConfigPanel(
                    session: session,
                    providerKeys: providerKeysForProject,
                    items: itemsForSession,
                    isGenerating: isGenerating,
                    sessionHasStarted: sessionHasStarted,
                    onItemsImported: { newItems in
                        importItems(newItems)
                        showImportSuccess = true
                    },
                    showFileImporter: $showFileImporter,
                    isCompactLayout: true
                )
                .navigationTitle("Configure Session")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            showCompactConfigSheet = false
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var compactDetailsSheet: some View {
        if let session = selectedSession {
            NavigationStack {
                Form {
                    Section {
                        LabeledContent("Provider", value: compactProviderName(for: session))
                        LabeledContent("Model", value: compactModelName(for: session))

                        if !session.savedConfiguration.selectedDimensions.isEmpty {
                            LabeledContent("Dimensions", value: session.savedConfiguration.selectedDimensions)
                        }

                        LabeledContent(
                            "Concurrency",
                            value: "\(session.concurrencyLimit) \(session.concurrencyLimit == 1 ? "request" : "requests")"
                        )

                        LabeledContent(
                            "Created",
                            value: session.createdAt.formatted(date: .abbreviated, time: .shortened)
                        )
                    }

                    if !session.commonPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Section("Common Prompt") {
                            Text(session.commonPrompt)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .formStyle(.grouped)
                .navigationTitle("Session Details")
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

    private func compactProviderName(for session: BulkSession) -> String {
        guard let providerId = UUID(uuidString: session.selectedProviderId),
              let provider = providersById[providerId]
        else {
            return "Not set"
        }

        return provider.providerName
    }

    private func compactModelName(for session: BulkSession) -> String {
        ProviderService.shared.model(by: session.selectedModelId)?.modelName ?? "Not set"
    }

    private func bulkGuideSection(_ section: GuideSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let sectionTitle = section.title {
                Text(sectionTitle)
                    .font(.headline)
            }

            if let content = section.content {
                Text(content)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(section.items, id: \.icon) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.icon)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 20)
                    Text(item.text)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Sheets

    private var createSessionSheet: some View {
        NameInputSheet(
            title: "Create New Session",
            placeholder: "Session Name",
            actionTitle: "Create",
            name: $newSessionName,
            isPresented: $showCreateSheet,
            onAction: createSession,
            usesRoundedBorder: false
        )
    }

    private var renameSessionSheet: some View {
        NameInputSheet(
            title: "Rename Session",
            placeholder: "Session Name",
            actionTitle: "Rename",
            name: $renameSessionName,
            isPresented: $showRenameSheet,
            onAction: renameSession,
            onCancel: { sessionToRename = nil },
            usesRoundedBorder: false
        )
    }

    private var duplicateSessionSheet: some View {
        NameInputSheet(
            title: "Duplicate Session",
            placeholder: "Session Name",
            actionTitle: "Duplicate",
            name: $duplicateSessionName,
            isPresented: $showDuplicateSheet,
            onAction: {
                if let session = sessionToDuplicate {
                    duplicateSession(session, name: duplicateSessionName)
                }
            },
            onCancel: { sessionToDuplicate = nil },
            usesRoundedBorder: false
        )
    }

    // MARK: - Session Actions

    private func syncIsGeneratingState() {
        isGenerating = selectedSession?.status == .RUNNING
    }

    private func handleSelectedSessionChange(_ newId: UUID?) {
        if let newId {
            UserDefaults.standard.set(newId.uuidString, forKey: lastSelectedSessionKey)
        }
        fetchItemsForSession(newId)
        syncIsGeneratingState()
    }

    private func handleCompactPresentedSessionChange(_ newId: UUID?) {
        guard newId == nil, shouldUseCompactMobileLayout else { return }
        showStartConfirmation = false
        selectedSessionId = nil
        itemsForSession = []
        showGalleryView = false
        showCompactAddPromptSheet = false
    }

    private func handleSessionsChange(_ newSessions: [BulkSession]) {
        guard selectedSessionId == nil, !newSessions.isEmpty else { return }
        restoreLastSelectedSession()
    }

    private func handleProjectChange() {
        showStartConfirmation = false
        compactPresentedSessionId = nil
        selectedSessionId = nil
        showCompactConfigSheet = false
        showCompactDetailsSheet = false
        showCompactAddPromptSheet = false
        updateSessions()
        restoreLastSelectedSession()
    }

    private func restoreLastSelectedSession() {
        guard selectedSessionId == nil else { return }

        if let savedId = UserDefaults.standard.string(forKey: lastSelectedSessionKey),
           let uuid = UUID(uuidString: savedId),
           sessions.contains(where: { $0.id == uuid })
        {
            selectedSessionId = uuid
            if let session = sessions.first(where: { $0.id == uuid }) {
                fetchItemsForSession(session)
            }
        }
    }

    private func fetchItemsForSession(_ sessionId: UUID?) {
        itemsFetchTask?.cancel()

        guard let sessionId else {
            itemsForSession = []
            return
        }

        itemsFetchTask = Task { @MainActor in
            guard !Task.isCancelled else { return }

            var descriptor = FetchDescriptor<BulkSessionItem>(
                predicate: #Predicate { $0.sessionId == sessionId },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            descriptor.fetchLimit = 300

            do {
                let items = try modelContext.fetch(descriptor)
                guard !Task.isCancelled else { return }
                itemsForSession = items
            } catch {
                AppLogger.ui.error("Failed to fetch items for session: \(error.localizedDescription, privacy: .public)")
                itemsForSession = []
            }
        }
    }

    private func fetchItemsForSession(_ session: BulkSession?) {
        fetchItemsForSession(session?.id)
    }

    private func createSession() {
        let trimmedName = newSessionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let session = BulkSession(
            name: trimmedName,
            projectId: projectManager.currentProjectId
        )
        modelContext.insert(session)

        do {
            try modelContext.save()
            selectedSessionId = session.id
            compactPresentedSessionId = session.id
            if shouldUseCompactMobileLayout {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    guard selectedSessionId == session.id, compactPresentedSessionId == session.id else { return }
                    showCompactConfigSheet = true
                }
            }
        } catch {
            AppLogger.ui.error("Failed to save session: \(error.localizedDescription, privacy: .public)")
        }

        showCreateSheet = false
    }

    private func renameSession() {
        guard let session = sessionToRename else { return }
        let trimmedName = renameSessionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        session.name = trimmedName

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to rename session: \(error.localizedDescription, privacy: .public)")
        }

        showRenameSheet = false
        sessionToRename = nil
    }

    private func togglePin(_ session: BulkSession) {
        session.isPinned.toggle()

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to toggle pin for session: \(error.localizedDescription, privacy: .public)")
        }

        updateSessions()
    }

    private func deleteSession(_ session: BulkSession) {
        if selectedSessionId == session.id {
            selectedSessionId = nil
            itemsForSession = []
            compactPresentedSessionId = nil
        }

        modelContext.delete(session)

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to delete session: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func duplicateSession(_ session: BulkSession, name: String) {
        let newSession = BulkSession(
            name: name,
            projectId: session.projectId
        )
        newSession.concurrencyLimit = session.concurrencyLimit
        newSession.commonPrompt = session.commonPrompt
        newSession.selectedProviderId = session.selectedProviderId
        newSession.selectedModelId = session.selectedModelId
        newSession.configurationData = session.configurationData
        newSession.status = .IDLE

        modelContext.insert(newSession)

        let originalSessionId = session.id
        let descriptor = FetchDescriptor<BulkSessionItem>(
            predicate: #Predicate { $0.sessionId == originalSessionId },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        do {
            let originalItems = try modelContext.fetch(descriptor)

            var copiedItems: [BulkSessionItem] = []
            for originalItem in originalItems {
                let newItem = BulkSessionItem(
                    sessionId: newSession.id,
                    prompt: originalItem.prompt,
                    filename: originalItem.filename
                )
                newItem.status = .PENDING
                modelContext.insert(newItem)
                copiedItems.append(newItem)
            }

            try modelContext.save()

            updateSessions()
            selectedSessionId = newSession.id
            compactPresentedSessionId = newSession.id
            itemsForSession = copiedItems
        } catch {
            AppLogger.ui.error("Failed to duplicate session: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else {
                importErrorMessage = "Could not access the file"
                showImportError = true
                return
            }

            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let parsed = CSVParser.parse(content)

                if parsed.isEmpty {
                    importErrorMessage = "No prompts found. Make sure your CSV has a 'prompt' column header."
                    showImportError = true
                    return
                }

                if parsed.count > bulkSessionMaxItems {
                    importErrorMessage =
                        "CSV contains \(parsed.count) prompts. Maximum allowed is \(bulkSessionMaxItems)."
                    showImportError = true
                    return
                }

                importItems(parsed.map { (prompt: $0.prompt, filename: $0.filename) })
                showImportSuccess = true
            } catch {
                importErrorMessage = "Failed to read file: \(error.localizedDescription)"
                showImportError = true
            }

        case let .failure(error):
            importErrorMessage = "Failed to import: \(error.localizedDescription)"
            showImportError = true
        }
    }

    // MARK: - Item Actions

    private func importItems(_ items: [(prompt: String, filename: String?)]) {
        guard let session = selectedSession else { return }

        itemsForSession = []

        let sessionId = session.id
        let descriptor = FetchDescriptor<BulkSessionItem>(
            predicate: #Predicate { $0.sessionId == sessionId }
        )

        do {
            let existingItems = try modelContext.fetch(descriptor)
            for item in existingItems {
                modelContext.delete(item)
            }

            for item in items {
                let bulkItem = BulkSessionItem(
                    sessionId: session.id,
                    prompt: item.prompt,
                    filename: item.filename
                )
                modelContext.insert(bulkItem)
            }

            try modelContext.save()
            fetchItemsForSession(session)
        } catch {
            AppLogger.ui.error("Failed to import items: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func addItem(prompt: String, filename: String?) {
        guard let session = selectedSession else { return }
        guard !isGenerating else { return }
        guard itemsForSession.count < bulkSessionMaxItems else { return }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        let trimmedFilename = filename?.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = BulkSessionItem(
            sessionId: session.id,
            prompt: trimmedPrompt,
            filename: trimmedFilename?.isEmpty == false ? trimmedFilename : nil
        )
        modelContext.insert(item)

        do {
            try modelContext.save()
            itemsForSession.append(item)
        } catch {
            AppLogger.ui.error("Failed to add item: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func editItem(_ item: BulkSessionItem, newPrompt: String) {
        let trimmedPrompt = newPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        item.prompt = trimmedPrompt
        // Reset status if it was failed/cancelled so it can be retried
        if item.status == .FAILED || item.status == .CANCELLED {
            item.status = .PENDING
            item.errorMessage = nil
        }

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to edit item: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func deleteItem(_ item: BulkSessionItem) {
        guard !isGenerating else { return }

        // Remove from local array first to prevent accessing deleted object
        let itemId = item.id
        itemsForSession.removeAll { $0.id == itemId }

        modelContext.delete(item)

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to delete item: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Generation Actions

    private func startGeneration() {
        guard let session = selectedSession, canStart else { return }

        // Reset items that can be retried (in-progress, failed, cancelled) back to pending
        for item in itemsForSession {
            switch item.status {
            case .IN_PROGRESS, .FAILED, .CANCELLED:
                item.status = .PENDING
                item.errorMessage = nil
            default:
                break
            }
        }

        session.status = .RUNNING
        isGenerating = true
        try? modelContext.save()

        generationTask = Task {
            await performBulkGeneration(session: session)
        }
    }

    private func pauseGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false

        for item in itemsForSession where item.status == .IN_PROGRESS {
            item.status = .PENDING
        }

        if let session = selectedSession {
            session.status = .IDLE
        }

        try? modelContext.save()
    }

    @MainActor
    private func performBulkGeneration(session: BulkSession) async {
        defer { isGenerating = false }

        let pendingItems = itemsForSession.filter { $0.status == .PENDING }
        guard !pendingItems.isEmpty else {
            session.status = .IDLE
            try? modelContext.save()
            generationErrorMessage = "No pending items to generate. All items may already be completed."
            showGenerationError = true
            return
        }

        // Get provider key and secret
        guard let providerKey = providerKeysForProject.first(where: {
            $0.providerId.uuidString == session.selectedProviderId
        }) else {
            session.status = .IDLE
            try? modelContext.save()
            generationErrorMessage = "Provider not found. Please select a valid provider in the configuration."
            showGenerationError = true
            return
        }

        guard let providerKeyInfo = try? providerKey.toProviderKeyInfo() else {
            session.status = .IDLE
            try? modelContext.save()
            generationErrorMessage = "Provider not found. Please select a valid provider in the configuration."
            showGenerationError = true
            return
        }

        let keychainKey = ProjectManager.keychainKey(
            projectId: projectManager.currentProjectId,
            providerId: providerKey.providerId
        )
        guard let providerSecret = keychain.get(keychainKey) else {
            session.status = .IDLE
            try? modelContext.save()
            generationErrorMessage = "API key not found. Please connect the provider to proceed."
            showGenerationError = true
            return
        }

        let config = session.savedConfiguration
        let concurrencyLimit = session.concurrencyLimit
        let commonPrompt = session.commonPrompt

        // Use a semaphore pattern for concurrency control
        await withTaskGroup(of: Void.self) { group in
            var runningCount = 0

            for item in pendingItems {
                // Check for cancellation
                if Task.isCancelled { break }

                // Wait if we're at concurrency limit
                if runningCount >= concurrencyLimit {
                    await group.next()
                    runningCount -= 1
                }

                // Check again after waiting
                if Task.isCancelled { break }

                runningCount += 1

                group.addTask { @MainActor in
                    await generateSingleItem(
                        item: item,
                        config: config,
                        commonPrompt: commonPrompt,
                        providerKeyInfo: providerKeyInfo,
                        providerSecret: providerSecret
                    )
                }
            }

            // Wait for remaining tasks
            await group.waitForAll()
        }

        session.status = .COMPLETED
        try? modelContext.save()

        #if os(macOS)
        if !NSApplication.shared.isActive {
            let completed = pendingItems.filter { $0.status == .COMPLETED }.count
            let failed = pendingItems.filter { $0.status == .FAILED }.count
            GenerationNotificationService.shared.sendBulkCompletionNotification(
                sessionName: session.name,
                completed: completed,
                failed: failed
            )
        }
        #endif
    }

    @MainActor
    private func generateSingleItem(
        item: BulkSessionItem,
        config: ImageGenerationConfiguration,
        commonPrompt: String,
        providerKeyInfo: ProviderKeyInfo,
        providerSecret: String
    ) async {
        // Check if item was cancelled
        guard item.status == .PENDING else { return }

        item.status = .IN_PROGRESS
        try? modelContext.save()

        // Combine prompt with common prompt suffix
        let finalPrompt = commonPrompt.isEmpty
            ? item.prompt
            : "\(item.prompt)\(commonPrompt)"

        let request = ImageGenerationRequest(
            modelId: config.selectedModelId,
            prompt: finalPrompt,
            negativePrompt: config.negativePrompt.isEmpty ? nil : config.negativePrompt,
            variant: config.selectedVariant,
            quality: config.selectedQuality,
            style: config.selectedStyle,
            dimensions: config.selectedDimensions,
            providerKey: providerKeyInfo,
            providerSecret: providerSecret,
            resolution: config.selectedResolution.isEmpty ? nil : config.selectedResolution,
            guidance: config.guidanceValue,
            seed: config.seedValue.isEmpty ? nil : Int(config.seedValue),
            safetyTolerance: Int(config.safetyValue),
            promptEnhance: config.modelPromptEnhance,
            inputFidelity: config.selectedInputFidelity.isEmpty ? nil : config.selectedInputFidelity,
            moderation: config.selectedModeration.isEmpty ? nil : config.selectedModeration,
            growMask: Int(config.growMaskValue),
            selectedTools: config.selectedTools.isEmpty ? nil : config.selectedTools,
            personGeneration: config.personGeneration.isEmpty ? nil : config.personGeneration
        )

        let queueItem = queueManager.submitImageGeneration(
            request: request,
            modelContext: modelContext,
            source: .BULK_GENERATE
        )
        item.queueItemId = queueItem.id

        // Wait for completion
        while queueItem.status == .IN_PROGRESS {
            try? await Task.sleep(for: .milliseconds(300))
        }

        if queueItem.status == .SUCCESSFUL, let resultSetId = queueItem.resultSetId {
            // Find the generation ID from the set
            let genDescriptor = FetchDescriptor<Generation>(
                predicate: #Predicate { $0.setId == resultSetId }
            )
            if let generation = try? modelContext.fetch(genDescriptor).first {
                item.generationId = generation.id
                item.status = .COMPLETED
            } else {
                item.status = .FAILED
                item.errorMessage = "Could not find generated image"
            }
        } else {
            item.status = .FAILED
            item.errorMessage = queueItem.errorMessage ?? "Generation failed"
        }

        try? modelContext.save()
    }

    // MARK: - Download Template

    private func downloadTemplateCSV() {
        let templateContent = """
        prompt,filename
        A serene mountain landscape at sunset with golden light,mountain_sunset
        A futuristic city skyline with flying cars,futuristic_city
        A cozy coffee shop interior with warm lighting,coffee_shop
        An underwater scene with colorful coral reef,coral_reef
        A magical forest with glowing mushrooms at night,
        """

        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "bulk_generate_template.csv"
        panel.prompt = "Save"
        panel.message = "Save the template CSV file"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try templateContent.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            AppLogger.ui.error("Failed to save template CSV: \(error.localizedDescription, privacy: .public)")
        }
        #else
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("bulk_generate_template.csv")
        do {
            try templateContent.write(to: tempURL, atomically: true, encoding: .utf8)
            templateShareFile = IdentifiableFileURL(url: tempURL)
        } catch {
            AppLogger.ui.error("Failed to create template CSV: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    // MARK: - Download All

    private func downloadAllAssets() {
        let exportItems: [(index: Int, id: UUID, filename: String?)] = itemsForSession
            .filter { $0.status == .COMPLETED && $0.generationId != nil }
            .enumerated()
            .compactMap { index, item in
                guard let genId = item.generationId else { return nil }
                return (index: index, id: genId, filename: item.filename)
            }
        guard !exportItems.isEmpty else { return }

        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        panel.message = "Select a folder to save all generated images"

        guard panel.runModal() == .OK, let folderURL = panel.url else { return }

        let sessionName = selectedSession?.name ?? "BulkSession"
        let sanitizedName = sessionName.replacingOccurrences(of: "/", with: "-")
        let exportFolder = folderURL.appendingPathComponent(sanitizedName)

        Task.detached(priority: .userInitiated) {
            do {
                try FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)

                for (index, generationId, customFilename) in exportItems {
                    if let image = loadImageFromDocumentsDirectory(withName: generationId.uuidString) {
                        let fileStem = customFilename ?? generationId.uuidString.prefix(8).lowercased()
                        let filename = "image_\(index + 1)_\(fileStem).png"
                        let fileURL = exportFolder.appendingPathComponent(filename)

                        if let tiffData = image.tiffRepresentation,
                           let bitmap = NSBitmapImageRep(data: tiffData),
                           let pngData = bitmap.representation(using: .png, properties: [:])
                        {
                            try pngData.write(to: fileURL)
                        }
                    }
                }

                // Open the folder in Finder on main thread
                _ = await MainActor.run {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: exportFolder.path)
                }
            } catch {
                AppLogger.ui.error("Failed to export images: \(error.localizedDescription, privacy: .public)")
            }
        }
        #endif
    }
}

private enum CompactBulkSessionRoute: Hashable, Identifiable {
    case detail(UUID)

    var id: UUID {
        sessionId
    }

    var sessionId: UUID {
        switch self {
        case let .detail(id):
            id
        }
    }
}

private struct IdentifiableFileURL: Identifiable {
    let id = UUID()
    let url: URL
}

private struct CompactBulkSessionRow: View {
    let session: BulkSession

    private var modelName: String {
        ProviderService.shared.model(by: session.selectedModelId)?.modelName ?? "Model not set"
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if session.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }

                    Text(session.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Text(modelName)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
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
