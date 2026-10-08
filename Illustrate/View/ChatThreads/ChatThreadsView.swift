// MARK: - ChatThreadsView.swift

// Main view for chat-based iterative image generation.
//
// ChatThreadsView provides a conversational interface for generating images.
// Users create threads, submit prompts, and see generated images in a
// scrolling conversation view.
//
// ## Layout
// - Sidebar: Thread list with create/rename/delete
// - Chat Area: Scrolling messages with prompt bar at bottom
//
// ## Features
// - Create, rename, delete threads
// - Submit prompts to generate images
// - Automatic iteration using previous outputs as references
// - Configurable images per iteration
//
// ## Performance
// Messages are fetched on-demand when a thread is selected rather than using
// @Query for all messages. This prevents memory issues when rapidly navigating
// between threads. The fetch task is tracked and cancelled when switching
// threads to avoid stale updates and resource leaks.

import AvgeekDesignSystem
import IllustrateProviders
import KeychainSwift
import OSLog
import SwiftData
import SwiftUI

/// Main container view for chat-based image generation.
struct ChatThreadsView: View {
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

    @Query(sort: \ChatThread.createdAt, order: .reverse) private var allThreads: [ChatThread]
    @ObservedObject private var providerKeysCache = ProviderKeysCache.shared

    @State private var messagesForThread: [ChatMessage] = []
    @State private var messageFetchTask: Task<Void, Never>?
    @State private var selectedThread: ChatThread?
    @State private var showCreateSheet = false
    @State private var newThreadName = ""
    @State private var showRenameSheet = false
    @State private var renameThreadName = ""
    @State private var threadToRename: ChatThread?
    @State private var showDuplicateSheet = false
    @State private var duplicateThreadName = ""
    @State private var threadToDuplicate: ChatThread?
    @State private var showBranchSheet = false
    @State private var branchThreadName = ""
    @State private var branchSourceThread: ChatThread?
    @State private var branchMessagesToCopy: [ChatMessage] = []
    @State private var showGuide = false
    @State private var showFailedAlert = false
    @State private var failedAlertMessage = ""
    @State private var generatingThreadId: UUID?
    @State private var attachedImages: [PlatformImage] = []

    /// Whether the currently selected thread is generating
    private var isGenerating: Bool {
        guard let threadId = selectedThread?.id else { return false }
        return generatingThreadId == threadId
    }

    @State private var isChatDropTargeted = false

    @State private var threads: [ChatThread] = []
    @State private var threadToDelete: ChatThread?
    @State private var showDeleteConfirmation = false
    @State private var compactPresentedThreadId: UUID?

    private func updateThreads() {
        threads = filteredAndSorted(allThreads, for: projectManager.currentProjectId)
    }

    private var lastSelectedThreadKey: String {
        "lastSelectedThread_\(projectManager.currentProjectId.uuidString)"
    }

    private var messagesForSelectedThread: [ChatMessage] {
        messagesForThread.filter { !$0.isDelinked }
    }

    /// Check if we can branch (at least 1 successful message and not generating)
    private var canBranchThread: Bool {
        let hasSuccessfulMessage = messagesForSelectedThread.contains { $0.status == .GENERATED }
        return hasSuccessfulMessage && !isGenerating
    }

    private var providerKeysForProject: [ProviderKey] {
        providerKeysCache.providerKeys
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
            threadsSidebar
                .frame(width: 240)

            Divider()

            chatArea
                .frame(minWidth: 0, maxWidth: .infinity)
        }
        .navigationTitle("Chat Threads")
        .sheet(isPresented: $showCreateSheet) {
            createThreadSheet
        }
        .sheet(isPresented: $showRenameSheet) {
            renameThreadSheet
        }
        .sheet(isPresented: $showDuplicateSheet) {
            duplicateThreadSheet
        }
        .sheet(isPresented: $showBranchSheet) {
            branchThreadSheet
        }
        .alert("Generation Failed", isPresented: $showFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failedAlertMessage)
        }
        .onChange(of: selectedThread) { _, newThread in
            if let newThread {
                UserDefaults.standard.set(newThread.id.uuidString, forKey: lastSelectedThreadKey)
            }
            fetchMessagesForThread(newThread)
            attachedImages = []
        }
        .onChange(of: threads) { _, _ in
            restoreLastSelectedThread()
        }
        .onAppear {
            providerKeysCache.loadIfNeeded(projectId: projectManager.currentProjectId, modelContext: modelContext)
            updateThreads()
            restoreLastSelectedThread()
        }
        .onChange(of: allThreads) { _, _ in updateThreads() }
        .onChange(of: projectManager.currentProjectId) { _, _ in
            compactPresentedThreadId = nil
            updateThreads()
        }
        .onDisappear {
            messageFetchTask?.cancel()
            messageFetchTask = nil
        }
        #else
        Group {
            if shouldUseCompactMobileLayout {
                compactMobileContent
            } else {
                NavigationSplitView {
                    threadsSidebar
                } detail: {
                    chatArea
                }
            }
        }
        .navigationTitle(shouldUseCompactMobileLayout ? compactMobileTitle : "Chat Threads")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if shouldUseCompactMobileLayout {
                compactMobileToolbar
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            createThreadSheet
        }
        .sheet(isPresented: $showRenameSheet) {
            renameThreadSheet
        }
        .sheet(isPresented: $showDuplicateSheet) {
            duplicateThreadSheet
        }
        .sheet(isPresented: $showBranchSheet) {
            branchThreadSheet
        }
        .sheet(
            isPresented: Binding(
                get: { shouldUseCompactMobileLayout && showGuide },
                set: { if !$0 { showGuide = false } }
            )
        ) {
            chatGuideSheet
        }
        .alert("Generation Failed", isPresented: $showFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failedAlertMessage)
        }
        .onChange(of: selectedThread) { _, newThread in
            if let newThread {
                UserDefaults.standard.set(newThread.id.uuidString, forKey: lastSelectedThreadKey)
            }
            fetchMessagesForThread(newThread)
            attachedImages = []
        }
        .onChange(of: compactPresentedThreadId) { _, newThreadId in
            if newThreadId == nil, shouldUseCompactMobileLayout {
                returnToThreadList()
            }
        }
        .onChange(of: threads) { _, _ in
            restoreLastSelectedThread()
        }
        .onAppear {
            providerKeysCache.loadIfNeeded(projectId: projectManager.currentProjectId, modelContext: modelContext)
            updateThreads()
            restoreLastSelectedThread()
        }
        .onChange(of: allThreads) { _, _ in updateThreads() }
        .onChange(of: projectManager.currentProjectId) { _, _ in updateThreads() }
        .onDisappear {
            messageFetchTask?.cancel()
            messageFetchTask = nil
        }
        #endif
    }

    private var compactMobileTitle: String {
        "Chat Threads"
    }

    #if os(iOS)
    @ToolbarContentBuilder
    private var compactMobileToolbar: some ToolbarContent {
        if compactPresentedThreadId == nil {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newThreadName = ""
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private var compactMobileContent: some View {
        compactThreadsList
            .navigationDestination(
                item: Binding(
                    get: { compactPresentedThreadId.map(CompactThreadRoute.detail) },
                    set: { route in
                        compactPresentedThreadId = route?.threadId
                    }
                )
            ) { route in
                compactThreadDetailView(threadId: route.threadId)
            }
    }

    private func returnToThreadList() {
        selectedThread = nil
        messagesForThread = []
        attachedImages = []
    }
    #endif

    // MARK: - Sidebar

    private var threadsSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Threads")
                    .font(.headline)
                Spacer()
                Button {
                    newThreadName = ""
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Create new thread")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if threads.isEmpty {
                emptyThreadsList
            } else {
                threadsList
            }
        }
        .background(tertiarySystemFill)
    }

    private var emptyThreadsList: some View {
        AvgeekEmptyStateView(
            icon: "bubble.left.and.text.bubble.right",
            title: "No threads yet",
            message: "Create a thread to start generating images through conversation.",
            buttonTitle: "Create Thread"
        ) {
            newThreadName = ""
            showCreateSheet = true
        }
    }

    private var threadsList: some View {
        List(selection: $selectedThread) {
            ForEach(threads) { thread in
                PinnableRowView(
                    item: thread,
                    onRename: {
                        threadToRename = thread
                        renameThreadName = thread.name
                        showRenameSheet = true
                    },
                    onTogglePin: {
                        togglePin(thread)
                    },
                    onDuplicate: {
                        threadToDuplicate = thread
                        duplicateThreadName = "\(thread.name) (Copy)"
                        showDuplicateSheet = true
                    },
                    onDelete: {
                        threadToDelete = thread
                        showDeleteConfirmation = true
                    }
                )
                .tag(thread)
            }
        }
        .listStyle(.sidebar)
        .alert("Delete Thread?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { threadToDelete = nil }
            Button("Delete", role: .destructive) {
                if let thread = threadToDelete { deleteThread(thread); threadToDelete = nil }
            }
        } message: {
            Text("This thread and all its messages will be permanently deleted. This action cannot be undone.")
        }
    }

    private var compactThreadsList: some View {
        Group {
            if threads.isEmpty {
                emptyThreadsList
            } else {
                List {
                    ForEach(threads) { thread in
                        Button {
                            selectedThread = thread
                            compactPresentedThreadId = thread.id
                        } label: {
                            CompactChatThreadRow(thread: thread)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            threadContextMenu(for: thread)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                threadToDelete = thread
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                togglePin(thread)
                            } label: {
                                Label(
                                    thread.isPinned ? "Unpin" : "Pin",
                                    systemImage: thread.isPinned ? "pin.slash" : "pin"
                                )
                            }
                            .tint(.accentColor)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .alert("Delete Thread?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { threadToDelete = nil }
            Button("Delete", role: .destructive) {
                if let thread = threadToDelete { deleteThread(thread); threadToDelete = nil }
            }
        } message: {
            Text("This thread and all its messages will be permanently deleted. This action cannot be undone.")
        }
    }

    @ViewBuilder
    private func compactThreadDetailView(threadId: UUID) -> some View {
        if let thread = threads.first(where: { $0.id == threadId }) {
            chatArea
                .navigationTitle(thread.name)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                prepareBranchThread(fromMessage: nil)
                            } label: {
                                Label("Branch", systemImage: "arrow.triangle.branch")
                            }
                            .disabled(!canBranchThread)

                            Button {
                                showGuide = true
                            } label: {
                                Label("Guide", systemImage: "questionmark.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .onAppear {
                    if selectedThread?.id != thread.id {
                        selectedThread = thread
                    }
                }
        } else {
            emptyChatState
                .navigationTitle("Chat Threads")
        }
    }

    @ViewBuilder
    private func threadContextMenu(for thread: ChatThread) -> some View {
        Button {
            togglePin(thread)
        } label: {
            Label(
                thread.isPinned ? "Unpin" : "Pin",
                systemImage: thread.isPinned ? "pin.slash" : "pin"
            )
        }

        Button {
            threadToRename = thread
            renameThreadName = thread.name
            showRenameSheet = true
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        Button {
            threadToDuplicate = thread
            duplicateThreadName = "\(thread.name) (Copy)"
            showDuplicateSheet = true
        } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
        }

        Divider()

        Button(role: .destructive) {
            threadToDelete = thread
            showDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Chat Area

    private var chatArea: some View {
        GeometryReader { geometry in
            if shouldShowExpandWindowPrompt(width: geometry.size.width) {
                ExpandWindowView()
            } else {
                Group {
                    if let thread = selectedThread {
                        VStack(spacing: 0) {
                            if !shouldUseCompactMobileLayout {
                                // Header
                                HStack {
                                    Text(thread.name)
                                        .font(.headline)
                                        .lineLimit(1)
                                    Spacer()

                                    // Branch button
                                    Button {
                                        prepareBranchThread(fromMessage: nil)
                                    } label: {
                                        Label("Branch", systemImage: "arrow.triangle.branch")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(!canBranchThread)
                                    .help("Create a new thread from this conversation")

                                    guideButton
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(tertiarySystemFill)

                                Divider()
                            }

                            // Messages + Prompt Bar
                            VStack(spacing: 0) {
                                // Messages scroll area
                                ScrollViewReader { scrollProxy in
                                    ScrollView {
                                        HStack {
                                            Spacer(minLength: 0)
                                            LazyVStack(spacing: 16) {
                                                ForEach(
                                                    Array(messagesForSelectedThread.enumerated()),
                                                    id: \.element.id
                                                ) { index, message in
                                                    let isLatest = index == messagesForSelectedThread.count - 1
                                                    let canDisassociate = isLatest && message
                                                        .status == .GENERATED && message
                                                        .generationIds.count > 1

                                                    ChatMessageView(
                                                        message: message,
                                                        expectedImageCount: thread.imagesPerIteration,
                                                        isLatestMessage: isLatest,
                                                        canDisassociate: canDisassociate,
                                                        canBranch: message.status == .GENERATED && !isGenerating,
                                                        canDelete: !isGenerating,
                                                        onDisassociate: { genId in
                                                            disassociateImage(genId: genId, from: message)
                                                        },
                                                        onBranch: {
                                                            prepareBranchThread(fromMessage: message)
                                                        },
                                                        onDelete: {
                                                            delinkMessage(message)
                                                        }
                                                    )
                                                    .id(message.id)
                                                }
                                            }
                                            .frame(maxWidth: 560)
                                            .padding(16)
                                            Spacer(minLength: 0)
                                        }
                                    }

                                    .onChange(of: messagesForSelectedThread.count) { _, _ in
                                        if let lastMessage = messagesForSelectedThread.last {
                                            scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                                        }
                                    }
                                }

                                Divider()

                                // Prompt bar at bottom
                                ChatPromptBar(
                                    thread: thread,
                                    providerKeys: providerKeysForProject,
                                    hasMessages: !messagesForSelectedThread.isEmpty,
                                    onSend: { prompt, config, attachments in
                                        submitPrompt(prompt: prompt, config: config, attachments: attachments)
                                    },
                                    attachedImages: $attachedImages
                                )
                            }
                            .overlay {
                                if isChatDropTargeted {
                                    chatDropOverlay
                                }
                            }
                            .imageDropTarget(isTargeted: $isChatDropTargeted) { image in
                                attachedImages.append(image)
                            } onMultipleImagesDropped: { images in
                                attachedImages.append(contentsOf: images)
                            }
                        }
                    } else {
                        emptyChatState
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

    private var emptyChatState: some View {
        AvgeekEmptyStateView(
            icon: "bubble.left.and.text.bubble.right",
            title: "Select a thread",
            message: "Choose a thread from the sidebar or create a new one to start chatting."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var chatDropOverlay: some View {
        ZStack {
            systemBackground.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
                Text("Drop to attach")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                Text("Image will be added to reference images")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.accentColor.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentColor, lineWidth: 2)
            )
        }
        .allowsHitTesting(false)
    }

    // MARK: - Guide Button

    private var guideButton: some View {
        GuidePopover(
            title: "Chat Threads Guide",
            sections: chatGuideSections,
            isPresented: $showGuide,
            height: 380
        )
    }

    private var chatGuideSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(chatGuideSections.enumerated()), id: \.offset) { index, section in
                        if index > 0 {
                            Divider()
                        }
                        chatGuideSection(section)
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

    private var chatGuideSections: [GuideSection] {
        [
            GuideSection(
                title: "What are Chat Threads?",
                content: "Chat Threads provide a chat-like interface for iterative image generation. Each message generates images, and subsequent prompts automatically use previous outputs as references."
            ),
            GuideSection(
                title: "Quick Reference",
                items: [
                    GuideItem(icon: "text.bubble", text: "Type a prompt and press Send to generate images."),
                    GuideItem(
                        icon: "arrow.triangle.2.circlepath",
                        text: "Each new prompt uses the previous generation as a reference for visual continuity."
                    ),
                    GuideItem(
                        icon: "slider.horizontal.3",
                        text: "Use the settings button to adjust model parameters."
                    ),
                    GuideItem(
                        icon: "photo",
                        text: "Set the number of images per prompt before your first message. It locks after."
                    ),
                ]
            ),
        ]
    }

    private func chatGuideSection(_ section: GuideSection) -> some View {
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

    private var createThreadSheet: some View {
        NameInputSheet(
            title: "Create New Thread",
            placeholder: "Thread Name",
            actionTitle: "Create",
            name: $newThreadName,
            isPresented: $showCreateSheet,
            onAction: createThread,
            usesRoundedBorder: false
        )
    }

    private var renameThreadSheet: some View {
        NameInputSheet(
            title: "Rename Thread",
            placeholder: "Thread Name",
            actionTitle: "Rename",
            name: $renameThreadName,
            isPresented: $showRenameSheet,
            onAction: renameThread,
            onCancel: { threadToRename = nil }
        )
    }

    private var duplicateThreadSheet: some View {
        NameInputSheet(
            title: "Duplicate Thread",
            placeholder: "Thread Name",
            actionTitle: "Duplicate",
            name: $duplicateThreadName,
            isPresented: $showDuplicateSheet,
            onAction: {
                if let thread = threadToDuplicate {
                    duplicateThread(thread, name: duplicateThreadName)
                }
            },
            onCancel: { threadToDuplicate = nil }
        )
    }

    private var branchThreadSheet: some View {
        NameInputSheet(
            title: "Create Branch",
            placeholder: "Branch Name",
            actionTitle: "Create",
            name: $branchThreadName,
            isPresented: $showBranchSheet,
            onAction: {
                if let sourceThread = branchSourceThread {
                    branchThread(
                        sourceThread: sourceThread,
                        messagesToCopy: branchMessagesToCopy,
                        name: branchThreadName
                    )
                }
            },
            onCancel: {
                branchSourceThread = nil
                branchMessagesToCopy = []
            },
            usesRoundedBorder: false
        )
    }

    // MARK: - Actions

    private func restoreLastSelectedThread() {
        guard selectedThread == nil else { return }

        if let savedId = UserDefaults.standard.string(forKey: lastSelectedThreadKey),
           let uuid = UUID(uuidString: savedId),
           let thread = threads.first(where: { $0.id == uuid })
        {
            selectedThread = thread
        }
    }

    private func fetchMessagesForThread(_ thread: ChatThread?) {
        messageFetchTask?.cancel()

        guard let thread else {
            messagesForThread = []
            return
        }

        let threadId = thread.id

        messageFetchTask = Task { @MainActor in
            guard !Task.isCancelled else { return }

            var descriptor = FetchDescriptor<ChatMessage>(
                predicate: #Predicate { $0.threadId == threadId },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            descriptor.fetchLimit = 1000

            do {
                let messages = try modelContext.fetch(descriptor)
                guard !Task.isCancelled else { return }
                messagesForThread = messages
            } catch {
                AppLogger.ui
                    .error("Failed to fetch messages for thread: \(error.localizedDescription, privacy: .public)")
                messagesForThread = []
            }
        }
    }

    private func createThread() {
        let trimmedName = newThreadName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let thread = ChatThread(
            name: trimmedName,
            projectId: projectManager.currentProjectId
        )
        modelContext.insert(thread)

        do {
            try modelContext.save()
            selectedThread = thread
            compactPresentedThreadId = thread.id
        } catch {
            AppLogger.ui.error("Failed to save thread: \(error.localizedDescription, privacy: .public)")
        }

        showCreateSheet = false
    }

    private func renameThread() {
        guard let thread = threadToRename else { return }
        let trimmedName = renameThreadName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        thread.name = trimmedName

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to rename thread: \(error.localizedDescription, privacy: .public)")
        }

        showRenameSheet = false
        threadToRename = nil
    }

    private func duplicateThread(_ thread: ChatThread, name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let newThread = ChatThread(name: trimmedName, projectId: thread.projectId)
        newThread.isPinned = false
        modelContext.insert(newThread)

        do {
            try modelContext.save()
            updateThreads()
            selectedThread = newThread
            compactPresentedThreadId = newThread.id
            threadToDuplicate = nil
        } catch {
            AppLogger.data.error("Failed to duplicate thread: \(error.localizedDescription)")
        }
    }

    private func togglePin(_ thread: ChatThread) {
        thread.isPinned.toggle()

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to toggle pin for thread: \(error.localizedDescription, privacy: .public)")
        }

        updateThreads()
    }

    private func deleteThread(_ thread: ChatThread) {
        if selectedThread?.id == thread.id {
            selectedThread = nil
            messagesForThread = []
            compactPresentedThreadId = nil
        }

        let threadId = thread.id
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.threadId == threadId }
        )

        do {
            let messagesToDelete = try modelContext.fetch(descriptor)

            let otherThreadsDescriptor = FetchDescriptor<ChatMessage>(
                predicate: #Predicate { $0.threadId != threadId }
            )
            let otherMessages = try modelContext.fetch(otherThreadsDescriptor)

            for message in messagesToDelete {
                let generationIds = message.generationIds
                guard !generationIds.isEmpty else {
                    modelContext.delete(message)
                    continue
                }

                let isShared = otherMessages.contains { otherMessage in
                    let otherGenIds = Set(otherMessage.generationIds)
                    return !otherGenIds.isDisjoint(with: generationIds)
                }

                if !isShared {
                    modelContext.delete(message)
                }
            }

            modelContext.delete(thread)
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to delete thread: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func submitPrompt(prompt: String, config: ImageGenerationConfiguration, attachments: [PlatformImage]) {
        guard let thread = selectedThread else { return }

        // Create message
        let message = ChatMessage(threadId: thread.id, prompt: prompt)
        message.imageGenerationConfiguration = config
        modelContext.insert(message)

        do {
            try modelContext.save()
            // Append the new message to our local array
            messagesForThread.append(message)
        } catch {
            AppLogger.ui.error("Failed to save message: \(error.localizedDescription, privacy: .public)")
            return
        }

        // Get previous message's generation IDs for reference
        let previousGenerationIds = getPreviousGenerationIds()

        // Set generating state for this specific thread
        generatingThreadId = thread.id

        // Submit generation requests
        Task {
            await submitGenerationRequests(
                message: message,
                config: config,
                thread: thread,
                previousGenerationIds: previousGenerationIds,
                additionalAttachments: attachments
            )
        }
    }

    /// Delinks a message from the thread (soft delete)
    private func delinkMessage(_ message: ChatMessage) {
        message.isDelinked = true

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to delink message: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func prepareBranchThread(fromMessage message: ChatMessage?) {
        guard let sourceThread = selectedThread else { return }
        let messagesToCopy: [ChatMessage]
        if let message {
            let allMessagesInOrder = messagesForSelectedThread
            if let index = allMessagesInOrder.firstIndex(where: { $0.id == message.id }) {
                messagesToCopy = Array(allMessagesInOrder.prefix(through: index))
            } else {
                messagesToCopy = []
            }
        } else {
            messagesToCopy = messagesForSelectedThread.filter { $0.status == .GENERATED }
        }

        guard !messagesToCopy.isEmpty else { return }

        branchSourceThread = sourceThread
        branchMessagesToCopy = messagesToCopy
        branchThreadName = "\(sourceThread.name) (Branch)"
        showBranchSheet = true
    }

    /// Branches the thread from a specific message or from the latest state
    private func branchThread(sourceThread: ChatThread, messagesToCopy: [ChatMessage], name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard !messagesToCopy.isEmpty else { return }

        let newThread = ChatThread(
            name: trimmedName,
            projectId: projectManager.currentProjectId,
            imagesPerIteration: sourceThread.imagesPerIteration
        )

        // Copy provider/model settings from source thread
        newThread.selectedProviderId = sourceThread.selectedProviderId
        newThread.selectedModelId = sourceThread.selectedModelId
        newThread.configurationData = sourceThread.configurationData

        modelContext.insert(newThread)

        // Copy messages to new thread
        for sourceMessage in messagesToCopy {
            let newMessage = ChatMessage(threadId: newThread.id, prompt: sourceMessage.prompt)
            newMessage.status = sourceMessage.status
            newMessage.generationIds = sourceMessage.generationIds
            newMessage.errorMessage = sourceMessage.errorMessage
            newMessage.configurationData = sourceMessage.configurationData
            modelContext.insert(newMessage)
        }

        do {
            try modelContext.save()
            // Switch to the new thread
            selectedThread = newThread
            compactPresentedThreadId = newThread.id
            branchSourceThread = nil
            branchMessagesToCopy = []
        } catch {
            AppLogger.ui.error("Failed to branch thread: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Gets generation IDs from the most recently generated message to use as references.
    ///
    /// This finds the latest successfully generated message in the thread.
    /// Since newly added messages have status `.processing`, we simply find the
    /// most recent `.generated` message without needing to exclude the new one.
    ///
    /// - Returns: Array of generation UUIDs from the most recent generated message,
    ///            or empty array if no successful generations exist.
    private func getPreviousGenerationIds() -> [UUID] {
        let messages = messagesForSelectedThread

        // Find the most recent successfully generated message
        guard let latestGeneratedMessage = messages.last(where: { $0.status == .GENERATED }),
              !latestGeneratedMessage.generationIds.isEmpty
        else {
            AppLogger.ui.debug("ChatThreads: No previous generated images found for reference")
            return []
        }

        // Log for validation
        let generatedMessages = messages.filter { $0.status == .GENERATED }
        let isLatest = generatedMessages.last?.id == latestGeneratedMessage.id

        AppLogger.ui
            .debug(
                "ChatThreads: Using \(latestGeneratedMessage.generationIds.count, privacy: .public) reference image(s) from message (id: \(latestGeneratedMessage.id, privacy: .public), isLatestGenerated: \(isLatest, privacy: .public))"
            )

        return latestGeneratedMessage.generationIds
    }

    private func disassociateImage(genId: UUID, from message: ChatMessage) {
        guard let thread = selectedThread else { return }

        // Remove the generation ID from the message
        var currentIds = message.generationIds
        currentIds.removeAll { $0 == genId }
        message.generationIds = currentIds

        // Update the thread's imagesPerIteration to match the new count
        // This ensures future generations use the reduced count
        thread.imagesPerIteration = currentIds.count

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui.error("Failed to disassociate image: \(error.localizedDescription, privacy: .public)")
        }
    }

    @MainActor
    private func submitGenerationRequests(
        message: ChatMessage,
        config: ImageGenerationConfiguration,
        thread: ChatThread,
        previousGenerationIds: [UUID],
        additionalAttachments: [PlatformImage] = []
    ) async {
        guard let providerKey = providerKeysForProject.first(where: {
            $0.providerId.uuidString == config.selectedProviderId
        }) else {
            message.status = .FAILED
            message.errorMessage = "Provider not found"
            try? modelContext.save()
            return
        }

        guard let providerKeyInfo = try? providerKey.toProviderKeyInfo() else {
            message.status = .FAILED
            message.errorMessage = "Provider not found"
            try? modelContext.save()
            return
        }

        // Get provider secret from keychain
        let keychainKey = ProjectManager.keychainKey(
            projectId: projectManager.currentProjectId,
            providerId: providerKey.providerId
        )
        guard let providerSecret = keychain.get(keychainKey) else {
            message.status = .FAILED
            message.errorMessage = "Provider secret not found"
            try? modelContext.save()
            return
        }

        // Get the model to check what it supports
        let model = ProviderService.shared.models(for: .IMAGE_GENERATE)
            .first { $0.modelId.uuidString == config.selectedModelId }
        let supportsReferenceImages = model?.modelParams.supportsReferenceImages ?? false
        let supportsSourceImage = model?.modelParams.supportsSourceImage ?? false
        let defaultRefType = model?.modelParams.supportedReferenceTypes.first ?? "style"

        // Convert additional attachments to base64 (shared across all generations)
        var additionalRefs: [ReferenceImageData] = []
        if supportsReferenceImages {
            for attachment in additionalAttachments {
                if let base64 = attachment.toBase64PNG() {
                    additionalRefs.append(ReferenceImageData(base64Image: base64, referenceType: defaultRefType))
                }
            }
        }

        // Submit generation requests - each previous image maps to one new generation
        // If we have previous images A and B, new generations will be:
        // - C (using A as reference)
        // - D (using B as reference)
        var queueItemIds: [UUID] = []

        // Determine how many generations to submit
        let generationCount: Int = if previousGenerationIds.isEmpty {
            // First message: use the thread's initial imagesPerIteration
            thread.imagesPerIteration
        } else {
            // Subsequent messages: match the number of previous images
            previousGenerationIds.count
        }

        for index in 0 ..< generationCount {
            // Build reference images for this specific generation
            var clientReferenceImages: [ReferenceImageData] = []
            var clientImage: String? = nil

            // Add the corresponding previous image as source or reference
            if index < previousGenerationIds.count {
                let previousGenId = previousGenerationIds[index]
                if let refImage = loadImageFromDocumentsDirectory(withName: previousGenId.uuidString),
                   let base64 = refImage.toBase64PNG()
                {
                    // Prefer source image if supported, otherwise use as reference
                    if supportsSourceImage {
                        clientImage = base64
                    } else if supportsReferenceImages {
                        clientReferenceImages.append(ReferenceImageData(
                            base64Image: base64,
                            referenceType: defaultRefType
                        ))
                    }
                }
            }

            // Add additional attachments to all generations
            clientReferenceImages.append(contentsOf: additionalRefs)

            let request = ImageGenerationRequest(
                modelId: config.selectedModelId,
                prompt: config.prompt,
                searchPrompt: config.searchPrompt.isEmpty ? nil : config.searchPrompt,
                negativePrompt: config.negativePrompt.isEmpty ? nil : config.negativePrompt,
                variant: config.selectedVariant,
                quality: config.selectedQuality,
                style: config.selectedStyle,
                dimensions: config.selectedDimensions,
                clientImage: clientImage,
                clientReferenceImages: clientReferenceImages.isEmpty ? nil : clientReferenceImages,
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
                selectedTools: config.selectedTools.isEmpty ? nil : Array(config.selectedTools),
                personGeneration: config.personGeneration.isEmpty ? nil : config.personGeneration
            )

            let queueItem = queueManager.submitImageGeneration(
                request: request,
                modelContext: modelContext,
                source: .CHAT_THREADS
            )
            queueItemIds.append(queueItem.id)
        }

        message.queueItemIds = queueItemIds
        message.pendingCount = queueItemIds.count
        try? modelContext.save()

        // Monitor all queue items for completion (in parallel)
        await monitorQueueItems(queueItemIds, for: message)
    }

    @MainActor
    private func monitorQueueItems(_ queueItemIds: [UUID], for message: ChatMessage) async {
        // Monitor all queue items in parallel using a task group
        await withTaskGroup(of: (UUID?, String?).self) { group in
            for queueItemId in queueItemIds {
                group.addTask { @MainActor in
                    guard let queueItem = queueManager.items.first(where: { $0.id == queueItemId }) else {
                        return (nil, "Queue item not found")
                    }

                    // Poll for status changes
                    while queueItem.status == .IN_PROGRESS {
                        try? await Task.sleep(for: .milliseconds(300))
                    }

                    if queueItem.status == .SUCCESSFUL, let resultSetId = queueItem.resultSetId {
                        let genDescriptor =
                            FetchDescriptor<Generation>(predicate: #Predicate { $0.setId == resultSetId })
                        if let generation = try? modelContext.fetch(genDescriptor).first {
                            return (generation.id, nil)
                        }
                    }

                    return (nil, queueItem.errorMessage ?? "Generation failed")
                }
            }

            // Process results as they complete
            var failedCount = 0
            var lastError: String?

            for await (generationId, error) in group {
                message.pendingCount -= 1

                if let genId = generationId {
                    // Success - add to message immediately
                    var currentIds = message.generationIds
                    currentIds.append(genId)
                    message.generationIds = currentIds
                } else {
                    // Failed - just decrement pending (shimmer disappears)
                    failedCount += 1
                    lastError = error
                }

                try? modelContext.save()
            }

            // Final status update
            if message.generationIds.isEmpty {
                // All generations failed - remove the message and show alert
                modelContext.delete(message)
                // Remove from our local array
                messagesForThread.removeAll { $0.id == message.id }
                failedAlertMessage = lastError ?? "All generations failed. Please try again."
                showFailedAlert = true
            } else {
                message.status = .GENERATED

                // If some generations failed, update thread's imagesPerIteration
                if failedCount > 0, let thread = selectedThread {
                    thread.imagesPerIteration = message.generationIds.count
                }
            }

            try? modelContext.save()

            // Reset generating state only if this thread is still the one generating
            if generatingThreadId == message.threadId {
                generatingThreadId = nil
            }
        }
    }
}

private enum CompactThreadRoute: Hashable, Identifiable {
    case detail(UUID)

    var id: UUID {
        threadId
    }

    var threadId: UUID {
        switch self {
        case let .detail(id):
            id
        }
    }
}

private struct CompactChatThreadRow: View {
    let thread: ChatThread

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if thread.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }

                    Text(thread.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Text(thread.createdAt.formatted(date: .abbreviated, time: .shortened))
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
