import AvgeekDesignSystem
import IllustrateProviders
import KeychainSwift
import OSLog
import SwiftData
import SwiftUI

struct BulkEditsView: View {
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

    @Query(sort: \BulkEditSession.createdAt, order: .reverse) private var allSessions: [BulkEditSession]
    @ObservedObject private var providerKeysCache = ProviderKeysCache.shared

    @State private var itemsForSession: [BulkEditItem] = []
    @State private var itemsFetchTask: Task<Void, Never>?
    @State private var selectedSessionId: UUID?
    @State private var showCreateSheet = false
    @State private var newSessionName = ""
    @State private var showRenameSheet = false
    @State private var renameSessionName = ""
    @State private var sessionToRename: BulkEditSession?
    @State private var showGuide = false
    @State private var showCostInfo = false
    @State private var generationTask: Task<Void, Never>?
    @State private var isGenerating = false
    @State private var showGalleryView = false
    @State private var showStartConfirmation = false
    @State private var showGenerationError = false
    @State private var generationErrorMessage = ""
    @State private var showImportSuccess = false
    @State private var showDuplicateSheet = false
    @State private var duplicateSessionName = ""
    @State private var sessionToDuplicate: BulkEditSession?
    @State private var sessions: [BulkEditSession] = []
    @State private var sessionToDelete: BulkEditSession?
    @State private var showDeleteConfirmation = false
    @State private var showZipImporter = false
    @State private var isAddImageOpen = false
    @State private var compactPresentedSessionId: UUID?
    @State private var showCompactConfigSheet = false
    @State private var showCompactDetailsSheet = false
    private func updateSessions() {
        sessions = filteredAndSorted(allSessions, for: projectManager.currentProjectId)
    }

    private var selectedSession: BulkEditSession? {
        guard let id = selectedSessionId else { return nil }
        return sessions.first { $0.id == id }
    }

    private var lastSelectedSessionKey: String {
        "lastSelectedBulkEditSession_\(projectManager.currentProjectId.uuidString)"
    }

    private var providerKeysForProject: [ProviderKey] {
        providerKeysCache.providerKeys
    }

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

    private var processableCount: Int {
        let c = statusCounts
        return c.pending + c.inProgress + c.failed + c.cancelled
    }

    private var hasCompletedItems: Bool {
        completedCount > 0
    }

    private var isResumable: Bool {
        hasCompletedItems || itemsForSession.contains { $0.status == .FAILED || $0.status == .CANCELLED }
    }

    private var sessionHasStarted: Bool {
        if isGenerating { return true }
        guard let session = selectedSession else { return false }
        if session.status == .COMPLETED { return true }
        guard !itemsForSession.isEmpty else { return false }
        return itemsForSession.contains { $0.status != .PENDING }
    }

    private var canStart: Bool {
        guard let session = selectedSession else { return false }
        return !isGenerating && processableCount > 0 && !session.selectedProviderId.isEmpty && !session.selectedModelId
            .isEmpty
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
            numberOfImages: 1,
            hasSourceImage: true
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
        if costCurrency == .USD { return formatEstimatedCost(estimatedCost) }
        return estimatedCost == floor(estimatedCost) ? String(format: "%.0f credits", estimatedCost) : String(
            format: "%.2f credits",
            estimatedCost
        )
    }

    private var formattedCostPerImage: String {
        if costCurrency == .USD { return formatEstimatedCost(costPerImage) }
        return costPerImage == floor(costPerImage) ? String(format: "%.0f credits", costPerImage) : String(
            format: "%.2f credits",
            costPerImage
        )
    }

    private var shouldUseCompactMobileLayout: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    private var compactSessionRouteBinding: Binding<CompactBulkEditRoute?> {
        Binding(
            get: { compactPresentedSessionId.map(CompactBulkEditRoute.detail) },
            set: { route in
                compactPresentedSessionId = route?.sessionId
            }
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

    private var guideSheetBinding: Binding<Bool> {
        Binding(
            get: { shouldUseCompactMobileLayout && showGuide },
            set: { if !$0 { showGuide = false } }
        )
    }

    private var compactMobileContent: some View {
        compactSessionsList
            .navigationDestination(item: compactSessionRouteBinding) { route in
                compactSessionDetailView(sessionId: route.sessionId)
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
        .navigationTitle(shouldUseCompactMobileLayout ? "Bulk Edits" : "Bulk Edits")
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
            .sheet(isPresented: $showCreateSheet) { createSessionSheet }
            .sheet(isPresented: $showRenameSheet) { renameSessionSheet }
            .sheet(isPresented: $showDuplicateSheet) { duplicateSessionSheet }
            .sheet(isPresented: guideSheetBinding) { bulkGuideSheet }
            .sheet(isPresented: compactConfigSheetBinding) { compactConfigSheet }
            .sheet(isPresented: compactDetailsSheetBinding) { compactDetailsSheet }
            .alert("Bulk Edits", isPresented: $showStartConfirmation) {
                Button("Okay") { startGeneration() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "Stay on this page to ensure the bulk edit process continues. Navigating elsewhere will pause the process."
                )
            }
            .alert("Generation Error", isPresented: $showGenerationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(generationErrorMessage)
            }
            .alert("Images Imported", isPresented: $showImportSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your images are ready. Click Start to begin bulk editing.")
            }
            #if os(iOS)
            .fileImporter(
                isPresented: $showZipImporter,
                allowedContentTypes: [.zip],
                allowsMultipleSelection: false
            ) { result in
                handleZipImport(result)
            }
            #endif
            .imageSelection(
                id: "bulkEditAddImage",
                isPickerOpen: $isAddImageOpen,
                sources: .all,
                onImageSelected: { image in
                    addSingleImage(image)
                }
            )
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

    private func resetGenerationStateOnDisappear() {
        guard isGenerating, let session = selectedSession else {
            isGenerating = false
            return
        }

        for item in itemsForSession where item.status == .IN_PROGRESS {
            item.status = .PENDING
        }

        session.status = .IDLE
        try? modelContext.save()
        isGenerating = false
    }

    // MARK: - Layout

    @ViewBuilder
    private var platformLayout: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            sessionsSidebar.frame(width: 240)
            Divider()
            contentArea.frame(minWidth: 0, maxWidth: .infinity)
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
                Text("Sessions").font(.headline)
                Spacer()
                Button { newSessionName = ""; showCreateSheet = true } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Create new session")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if sessions.isEmpty {
                AvgeekEmptyStateView(
                    icon: "photo.on.rectangle.angled",
                    title: "No sessions yet",
                    message: "Create a session to start editing images in bulk.",
                    buttonTitle: "Create Session"
                ) { newSessionName = ""; showCreateSheet = true }
            } else {
                sessionsList
            }
        }
        .background(tertiarySystemFill)
    }

    private var sessionSelectionBinding: Binding<BulkEditSession?> {
        Binding(
            get: { selectedSession },
            set: { newSession in
                if let newSession { selectedSessionId = newSession.id }
            }
        )
    }

    private var sessionsList: some View {
        List(selection: sessionSelectionBinding) {
            ForEach(sessions) { session in
                PinnableRowView(
                    item: session,
                    onRename: { sessionToRename = session; renameSessionName = session.name; showRenameSheet = true },
                    onTogglePin: { togglePin(session) },
                    onDuplicate: {
                        sessionToDuplicate = session; duplicateSessionName =
                            "\(session.name) (Copy)"; showDuplicateSheet =
                            true
                    },
                    onDelete: { sessionToDelete = session; showDeleteConfirmation = true }
                )
                .tag(session)
            }
        }
        .listStyle(.sidebar)
        .alert("Delete Session?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
            Button("Delete", role: .destructive) {
                if let s = sessionToDelete { deleteSession(s); sessionToDelete = nil }
            }
        } message: {
            Text("This session and all its images will be permanently deleted.")
        }
    }

    private var compactSessionsList: some View {
        Group {
            if sessions.isEmpty {
                AvgeekEmptyStateView(
                    icon: "photo.on.rectangle.angled",
                    title: "No sessions yet",
                    message: "Create a session to start editing images in bulk.",
                    buttonTitle: "Create Session"
                ) {
                    newSessionName = ""
                    showCreateSheet = true
                }
            } else {
                List {
                    ForEach(sessions) { session in
                        Button {
                            selectedSessionId = session.id
                            compactPresentedSessionId = session.id
                        } label: {
                            CompactBulkEditSessionRow(session: session)
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
            Text("This session and all its images will be permanently deleted.")
        }
    }

    // MARK: - Content

    private var contentArea: some View {
        GeometryReader { geometry in
            if geometry.size.width < canvasMinWidth {
                ExpandWindowView()
            } else {
                Group {
                    if let session = selectedSession {
                        sessionDetailContent(session: session, isCompactLayout: false)
                    } else {
                        AvgeekEmptyStateView(
                            icon: "photo.on.rectangle.angled",
                            title: "Select a session",
                            message: "Choose a session from the sidebar or create a new one to start bulk editing."
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            AvgeekEmptyStateView(
                icon: "photo.on.rectangle.angled",
                title: "Select a session",
                message: "Choose a session from the list or create a new one to start bulk editing."
            )
            .navigationTitle("Bulk Edits")
        }
    }

    @ViewBuilder
    private func sessionContextMenu(for session: BulkEditSession) -> some View {
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

    private func sessionDetailContent(session: BulkEditSession, isCompactLayout: Bool) -> some View {
        VStack(spacing: 0) {
            if isCompactLayout {
                compactSessionControls
                Divider()
            } else {
                sessionHeader(session: session)
                Divider()

                BulkEditConfigPanel(
                    session: session,
                    providerKeys: providerKeysForProject,
                    isGenerating: isGenerating,
                    sessionHasStarted: sessionHasStarted,
                    isCompactLayout: false
                )

                Divider()
            }

            BulkEditItemsTable(
                items: itemsForSession,
                showGalleryView: $showGalleryView,
                isGenerating: isGenerating,
                sessionHasStarted: sessionHasStarted,
                onDeleteItem: { deleteItem($0) },
                onRegenerateItem: { regenerateSingleItem($0) },
                onAddImage: { isAddImageOpen = true },
                onImportZIP: { openZipPanel() },
                isCompactLayout: isCompactLayout
            )
        }
    }

    private func sessionHeader(session: BulkEditSession) -> some View {
        HStack {
            Text(session.name).font(.headline)
            Spacer()
            if hasCompletedItems {
                Button { downloadAllAssets() } label: {
                    Label("Download All", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)
                .disabled(isGenerating)
            }
            if totalCount > 0 { costInfoButton }
            guideButton
            if isGenerating {
                Button { pauseGeneration() } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            } else if processableCount > 0 {
                Button { showStartConfirmation = true } label: {
                    Label(isResumable ? "Resume" : "Start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canStart)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(tertiarySystemFill)
    }

    private var compactSessionControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $showGalleryView) {
                Label("Images", systemImage: "photo.on.rectangle")
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
                    isAddImageOpen = true
                } label: {
                    Label("Add Image", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .font(.callout)
                .buttonStyle(.bordered)
                .disabled(isGenerating || itemsForSession.count >= bulkEditMaxItems)
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

    private var costInfoButton: some View {
        Button { showCostInfo.toggle() } label: {
            Label("Cost Estimate", systemImage: "dollarsign.circle")
        }
        .buttonStyle(.bordered)
        .popover(isPresented: $showCostInfo) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Cost Estimate").font(.headline)
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                    GridRow {
                        Text("Cost per image").foregroundStyle(.secondary); Text(formattedCostPerImage)
                            .fontWeight(.medium).frame(
                                maxWidth: .infinity,
                                alignment: .trailing
                            )
                    }
                    GridRow {
                        Text("Total images").foregroundStyle(.secondary); Text("\(totalCount)").fontWeight(.medium)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .trailing
                            )
                    }
                    Divider().gridCellUnsizedAxes(.horizontal)
                    GridRow {
                        Text("Estimated total").fontWeight(.semibold); Text(formattedCost).fontWeight(.bold)
                            .foregroundStyle(Color.accentColor).frame(
                                maxWidth: .infinity,
                                alignment: .trailing
                            )
                    }
                }
                Text("Actual cost may vary based on provider pricing.").font(.caption).foregroundStyle(.secondary)
            }
            .padding(16).frame(minWidth: 280)
        }
    }

    private var guideButton: some View {
        GuidePopover(
            title: "Bulk Edits Guide",
            sections: [
                GuideSection(
                    title: "What is Bulk Edits?",
                    content: "Bulk Edits allows you to edit multiple images at once using a common prompt. Upload a ZIP of images or add them manually, configure your model, and generate."
                ),
                GuideSection(title: "Quick Reference", items: [
                    GuideItem(icon: "doc.zipper", text: "Import a ZIP file containing images."),
                    GuideItem(icon: "plus", text: "Add individual images manually."),
                    GuideItem(icon: "text.append", text: "Set a common prompt applied to all images."),
                    GuideItem(icon: "play.fill", text: "Click Start to begin. Pause stops pending items."),
                    GuideItem(icon: "arrow.down.circle", text: "Download All exports generated images."),
                ]),
            ],
            isPresented: $showGuide,
            height: 380
        )
    }

    private var bulkGuideSections: [GuideSection] {
        [
            GuideSection(
                title: "What is Bulk Edits?",
                content: "Bulk Edits allows you to edit multiple images at once using a common prompt. Import a ZIP of images or add them manually, configure your model once, and run the edits in bulk."
            ),
            GuideSection(title: "Quick Reference", items: [
                GuideItem(icon: "doc.zipper", text: "Import a ZIP file containing images."),
                GuideItem(icon: "plus", text: "Add individual images manually."),
                GuideItem(icon: "slider.horizontal.3", text: "Set provider, model, prompt, and edit settings."),
                GuideItem(icon: "play.fill", text: "Tap Start to begin. Pause stops pending edits."),
                GuideItem(icon: "arrow.down.circle", text: "Download All exports completed edited images."),
            ]),
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
                BulkEditConfigPanel(
                    session: session,
                    providerKeys: providerKeysForProject,
                    isGenerating: isGenerating,
                    sessionHasStarted: sessionHasStarted,
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

    private func compactProviderName(for session: BulkEditSession) -> String {
        guard let providerId = UUID(uuidString: session.selectedProviderId),
              let provider = getProvider(providerId: providerId)
        else {
            return "Not selected"
        }

        return provider.providerName
    }

    private func compactModelName(for session: BulkEditSession) -> String {
        guard !session.selectedModelId.isEmpty,
              let model = ProviderService.shared.model(by: session.selectedModelId)
        else {
            return "Not selected"
        }

        return model.modelName
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
            onAction: { if let s = sessionToDuplicate { duplicateSession(s, name: duplicateSessionName) } },
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
        showCompactConfigSheet = false
        showCompactDetailsSheet = false
    }

    private func handleSessionsChange(_ newSessions: [BulkEditSession]) {
        guard selectedSessionId == nil, !newSessions.isEmpty else { return }
        restoreLastSelectedSession()
    }

    private func handleProjectChange() {
        showStartConfirmation = false
        compactPresentedSessionId = nil
        selectedSessionId = nil
        showCompactConfigSheet = false
        showCompactDetailsSheet = false
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
            if sessions.first(where: { $0.id == uuid }) != nil { fetchItemsForSession(uuid) }
        }
    }

    private func fetchItemsForSession(_ sessionId: UUID?) {
        itemsFetchTask?.cancel()
        guard let sessionId else { itemsForSession = []; return }
        itemsFetchTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            var descriptor = FetchDescriptor<BulkEditItem>(
                predicate: #Predicate { $0.sessionId == sessionId },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            descriptor.fetchLimit = 300
            do {
                let items = try modelContext.fetch(descriptor)
                guard !Task.isCancelled else { return }
                itemsForSession = items
            } catch {
                AppLogger.ui.error("Failed to fetch items: \(error.localizedDescription, privacy: .public)")
                itemsForSession = []
            }
        }
    }

    private func createSession() {
        let trimmedName = newSessionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let session = BulkEditSession(name: trimmedName, projectId: projectManager.currentProjectId)
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
            AppLogger.ui.error("Failed to save session: \(error)")
        }
        showCreateSheet = false
    }

    private func renameSession() {
        guard let session = sessionToRename else { return }
        let trimmedName = renameSessionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        session.name = trimmedName
        try? modelContext.save()
        showRenameSheet = false
        sessionToRename = nil
    }

    private func togglePin(_ session: BulkEditSession) {
        session.isPinned.toggle()
        try? modelContext.save()
        updateSessions()
    }

    private func deleteSession(_ session: BulkEditSession) {
        if selectedSessionId == session.id { selectedSessionId = nil; itemsForSession = [] }
        modelContext.delete(session)
        try? modelContext.save()
    }

    private func duplicateSession(_ session: BulkEditSession, name: String) {
        let newSession = BulkEditSession(name: name, projectId: session.projectId)
        newSession.concurrencyLimit = session.concurrencyLimit
        newSession.commonPrompt = session.commonPrompt
        newSession.selectedProviderId = session.selectedProviderId
        newSession.selectedModelId = session.selectedModelId
        newSession.configurationData = session.configurationData
        modelContext.insert(newSession)

        let originalSessionId = session.id
        let descriptor = FetchDescriptor<BulkEditItem>(
            predicate: #Predicate { $0.sessionId == originalSessionId },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        do {
            let originalItems = try modelContext.fetch(descriptor)
            for original in originalItems {
                let newItem = BulkEditItem(
                    sessionId: newSession.id,
                    sourceImageFileName: original.sourceImageFileName,
                    sourceImageThumbFileName: original.sourceImageThumbFileName,
                    sourceImageName: original.sourceImageName
                )
                modelContext.insert(newItem)
            }
            try modelContext.save()
            updateSessions()
            selectedSessionId = newSession.id
            fetchItemsForSession(newSession.id)
        } catch {
            AppLogger.ui.error("Failed to duplicate session: \(error)")
        }
    }

    // MARK: - Item Actions

    private func openZipPanel() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Import ZIP with Images"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            handleZipURL(url)
        }
        #else
        showZipImporter = true
        #endif
    }

    private func handleZipImport(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else { return }
        handleZipURL(url)
    }

    private func handleZipURL(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        let extractedImages = ZipExtractor.extractImages(from: url)
        guard !extractedImages.isEmpty else { return }

        importExtractedImages(extractedImages)
        showImportSuccess = true
    }

    private func addSingleImage(_ image: PlatformImage) {
        guard let session = selectedSession, !isGenerating, itemsForSession.count < bulkEditMaxItems else { return }
        let itemId = UUID()
        let baseName = "bulk_edit_\(itemId.uuidString)"
        let fileName = baseName
        image.saveToiCloud(fileName: fileName)

        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        let maxDim: CGFloat = 320
        let thumbSize = if aspectRatio > 1 {
            CGSize(width: maxDim, height: maxDim / aspectRatio)
        } else {
            CGSize(width: maxDim * aspectRatio, height: maxDim)
        }
        var thumbFileName: String?
        if let thumb = image.resizeImage(targetSize: thumbSize) {
            thumbFileName = baseName + "_thumb"
            thumb.saveToiCloud(fileName: thumbFileName!)
        }

        let item = BulkEditItem(
            sessionId: session.id,
            sourceImageFileName: fileName,
            sourceImageThumbFileName: thumbFileName,
            sourceImageName: "Manual Image"
        )
        modelContext.insert(item)
        do { try modelContext.save(); itemsForSession.append(item) } catch {
            AppLogger.ui.error("Failed to add image: \(error)")
        }
    }

    private func importExtractedImages(_ images: [(name: String, image: PlatformImage)]) {
        guard let session = selectedSession else { return }

        // Delete existing items
        itemsForSession = []
        let sessionId = session.id
        let descriptor = FetchDescriptor<BulkEditItem>(predicate: #Predicate { $0.sessionId == sessionId })
        do {
            let existingItems = try modelContext.fetch(descriptor)
            for item in existingItems {
                modelContext.delete(item)
            }

            for (name, image) in images {
                let itemId = UUID()
                let baseName = "bulk_edit_\(itemId.uuidString)"
                image.saveToiCloud(fileName: baseName)

                let imageSize = image.size
                let aspectRatio = imageSize.width / imageSize.height
                let maxDim: CGFloat = 320
                let thumbSize = if aspectRatio > 1 {
                    CGSize(width: maxDim, height: maxDim / aspectRatio)
                } else {
                    CGSize(width: maxDim * aspectRatio, height: maxDim)
                }
                var thumbFileName: String?
                if let thumb = image.resizeImage(targetSize: thumbSize) {
                    thumbFileName = baseName + "_thumb"
                    thumb.saveToiCloud(fileName: thumbFileName!)
                }

                let item = BulkEditItem(
                    sessionId: session.id,
                    sourceImageFileName: baseName,
                    sourceImageThumbFileName: thumbFileName,
                    sourceImageName: name
                )
                modelContext.insert(item)
            }
            try modelContext.save()
            fetchItemsForSession(session.id)
        } catch {
            AppLogger.ui.error("Failed to import images: \(error)")
        }
    }

    private func deleteItem(_ item: BulkEditItem) {
        guard !isGenerating else { return }
        let itemId = item.id
        itemsForSession.removeAll { $0.id == itemId }
        modelContext.delete(item)
        try? modelContext.save()
    }

    // MARK: - Generation

    private func startGeneration() {
        guard let session = selectedSession, canStart else { return }
        for item in itemsForSession {
            switch item.status {
            case .IN_PROGRESS, .FAILED, .CANCELLED: item.status = .PENDING; item.errorMessage = nil
            default: break
            }
        }
        session.status = .RUNNING
        isGenerating = true
        try? modelContext.save()
        generationTask = Task { await performBulkEdit(session: session) }
    }

    private func pauseGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        for item in itemsForSession where item.status == .IN_PROGRESS {
            item.status = .PENDING
        }
        selectedSession?.status = .IDLE
        try? modelContext.save()
    }

    @MainActor
    private func performBulkEdit(session: BulkEditSession) async {
        defer { isGenerating = false }
        let pendingItems = itemsForSession.filter { $0.status == .PENDING }
        guard !pendingItems.isEmpty else {
            session.status = .IDLE; try? modelContext.save()
            generationErrorMessage = "No pending items."; showGenerationError = true; return
        }

        guard let providerKey = providerKeysForProject
            .first(where: { $0.providerId.uuidString == session.selectedProviderId })
        else {
            session.status = .IDLE; try? modelContext.save()
            generationErrorMessage = "Provider not found."; showGenerationError = true; return
        }
        guard let providerKeyInfo = try? providerKey.toProviderKeyInfo() else {
            session.status = .IDLE; try? modelContext.save()
            generationErrorMessage = "Provider not found."; showGenerationError = true; return
        }
        let keychainKey = ProjectManager.keychainKey(
            projectId: projectManager.currentProjectId,
            providerId: providerKey.providerId
        )
        guard let providerSecret = keychain.get(keychainKey) else {
            session.status = .IDLE; try? modelContext.save()
            generationErrorMessage = "API key not found."; showGenerationError = true; return
        }

        let config = session.savedConfiguration
        let concurrencyLimit = session.concurrencyLimit
        let commonPrompt = session.commonPrompt
        let model = ProviderService.shared.model(by: session.selectedModelId)

        await withTaskGroup(of: Void.self) { group in
            var runningCount = 0
            for item in pendingItems {
                if Task.isCancelled { break }
                if runningCount >= concurrencyLimit { await group.next(); runningCount -= 1 }
                if Task.isCancelled { break }
                runningCount += 1
                group.addTask { @MainActor in
                    await generateSingleItem(
                        item: item, config: config, commonPrompt: commonPrompt,
                        providerKeyInfo: providerKeyInfo, providerSecret: providerSecret, model: model
                    )
                }
            }
            await group.waitForAll()
        }

        session.status = .COMPLETED
        try? modelContext.save()

        #if os(macOS)
        if !NSApplication.shared.isActive {
            let completed = pendingItems.filter { $0.status == .COMPLETED }.count
            let failed = pendingItems.filter { $0.status == .FAILED }.count
            GenerationNotificationService.shared.sendBulkCompletionNotification(
                sessionName: session.name, completed: completed, failed: failed
            )
        }
        #endif
    }

    @MainActor
    private func generateSingleItem(
        item: BulkEditItem, config: ImageGenerationConfiguration, commonPrompt: String,
        providerKeyInfo: ProviderKeyInfo, providerSecret: String, model: ProviderModel?
    ) async {
        guard item.status == .PENDING else { return }
        item.status = .IN_PROGRESS
        try? modelContext.save()

        guard let fileName = item.sourceImageFileName,
              let sourceImage = loadImageFromiCloud(fileName)
        else {
            item.status = .FAILED
            item.errorMessage = "Could not load source image"
            try? modelContext.save()
            return
        }

        let maxPixels = model?.modelParams.maxImagePixels
        let maxSizeBytes = model?.modelParams.maxImageSizeBytes
        let clientImage = sourceImage.toBase64(maxPixels: maxPixels, maxSizeBytes: maxSizeBytes)

        let request = ImageGenerationRequest(
            modelId: config.selectedModelId,
            prompt: commonPrompt,
            negativePrompt: config.negativePrompt.isEmpty ? nil : config.negativePrompt,
            variant: config.selectedVariant,
            quality: config.selectedQuality,
            style: config.selectedStyle,
            dimensions: config.selectedDimensions,
            clientImage: clientImage,
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
            source: .BULK_EDIT
        )
        item.queueItemId = queueItem.id

        while queueItem.status == .IN_PROGRESS {
            try? await Task.sleep(for: .milliseconds(300))
        }

        if queueItem.status == .SUCCESSFUL, let resultSetId = queueItem.resultSetId {
            let genDescriptor = FetchDescriptor<Generation>(predicate: #Predicate { $0.setId == resultSetId })
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

    @MainActor
    private func regenerateSingleItem(_ item: BulkEditItem) {
        guard let session = selectedSession else { return }
        let keychainKey = ProjectManager.keychainKey(
            projectId: projectManager.currentProjectId,
            providerId: UUID(uuidString: session.savedConfiguration.selectedProviderId)!
        )
        guard let providerSecret = keychain.get(keychainKey) else { return }
        guard let providerKey = providerKeysCache.providerKeys
            .first(where: { $0.providerId.uuidString == session.savedConfiguration.selectedProviderId }) else { return }
        guard let providerKeyInfo = try? providerKey.toProviderKeyInfo() else { return }

        item.status = .PENDING
        item.generationId = nil
        item.errorMessage = nil
        try? modelContext.save()

        let config = session.savedConfiguration
        let model = ProviderService.shared.model(by: session.selectedModelId)
        Task {
            await generateSingleItem(
                item: item,
                config: config,
                commonPrompt: session.commonPrompt,
                providerKeyInfo: providerKeyInfo,
                providerSecret: providerSecret,
                model: model
            )
        }
    }

    // MARK: - Download

    private func downloadAllAssets() {
        let exportItems = itemsForSession
            .filter { $0.status == .COMPLETED && $0.generationId != nil }
            .enumerated()
            .compactMap { index, item -> (Int, UUID)? in
                guard let genId = item.generationId else { return nil }; return (
                    index,
                    genId
                )
            }
        guard !exportItems.isEmpty else { return }

        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        guard panel.runModal() == .OK, let folderURL = panel.url else { return }
        let sessionName = selectedSession?.name ?? "BulkEdit"
        let exportFolder = folderURL.appendingPathComponent(sessionName.replacingOccurrences(of: "/", with: "-"))

        Task.detached(priority: .userInitiated) {
            do {
                try FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
                for (index, generationId) in exportItems {
                    if let image = loadImageFromDocumentsDirectory(withName: generationId.uuidString) {
                        let fileURL = exportFolder
                            .appendingPathComponent("image_\(index + 1)_\(generationId.uuidString.prefix(8)).png")
                        if let tiffData = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffData),
                           let pngData = bitmap.representation(
                               using: .png,
                               properties: [:]
                           )
                        {
                            try pngData.write(to: fileURL)
                        }
                    }
                }
                _ = await MainActor
                    .run { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: exportFolder.path) }
            } catch {
                AppLogger.ui.error("Failed to export images: \(error)")
            }
        }
        #endif
    }
}

private enum CompactBulkEditRoute: Hashable, Identifiable {
    case detail(UUID)

    var id: UUID {
        sessionId
    }

    var sessionId: UUID {
        switch self {
        case let .detail(sessionId):
            sessionId
        }
    }
}

private struct CompactBulkEditSessionRow: View {
    let session: BulkEditSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if session.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.accent)
                }

                Text(session.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Spacer(minLength: 8)
            }

            Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
