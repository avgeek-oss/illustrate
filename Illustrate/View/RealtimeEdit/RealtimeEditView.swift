// MARK: - RealtimeEditView.swift

// Main view for Realtime Edit feature with multi-session support.
//
// Provides a canvas-based image editing interface with realtime feedback.
//
// ## Layout
// - Sidebar: Session list with create/rename/delete
// - Main Area: Canvas editor with tools and preview
//
// ## Features
// - Create, rename, delete sessions
// - Pin sessions to top of list
// - Automatic last session restoration
// - Canvas state persisted per session

import AvgeekDesignSystem
import OSLog
import SwiftData
import SwiftUI

/// Main container view for Realtime Edit with multi-session support.
struct RealtimeEditView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var projectManager: ProjectManager

    @Query(sort: \RealtimeEditSession.createdAt, order: .reverse) private var allSessions: [RealtimeEditSession]

    @State private var selectedSession: RealtimeEditSession?
    @State private var showCreateSheet = false
    @State private var newSessionName = ""
    @State private var showRenameSheet = false
    @State private var renameSessionName = ""
    @State private var sessionToRename: RealtimeEditSession?
    @State private var showDuplicateSheet = false
    @State private var duplicateSessionName = ""
    @State private var sessionToDuplicate: RealtimeEditSession?
    @State private var sessionToDelete: RealtimeEditSession?
    @State private var showDeleteConfirmation = false

    @State private var sessions: [RealtimeEditSession] = []

    private func updateSessions() {
        sessions = filteredAndSorted(allSessions, for: projectManager.currentProjectId)
    }

    private var lastSelectedSessionKey: String {
        "lastSelectedRealtimeEditSession_\(projectManager.currentProjectId.uuidString)"
    }

    var body: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            sessionsSidebar
                .frame(width: 240)

            Divider()

            mainArea
                .frame(minWidth: 0, maxWidth: .infinity)
        }
        .navigationTitle("Realtime Edit")
        .sheet(isPresented: $showCreateSheet) {
            createSessionSheet
        }
        .sheet(isPresented: $showRenameSheet) {
            renameSessionSheet
        }
        .sheet(isPresented: $showDuplicateSheet) {
            duplicateSessionSheet
        }
        .onChange(of: selectedSession) { _, newSession in
            if let newSession {
                UserDefaults.standard.set(newSession.id.uuidString, forKey: lastSelectedSessionKey)
            }
        }
        .onAppear {
            updateSessions()
            restoreLastSelectedSession()
        }
        .onChange(of: allSessions) { _, _ in updateSessions() }
        .onChange(of: projectManager.currentProjectId) { _, _ in updateSessions() }
        .onChange(of: sessions) { _, _ in
            restoreLastSelectedSession()
        }
        #else
        NavigationSplitView {
            sessionsSidebar
        } detail: {
            mainArea
        }
        .navigationTitle("Realtime Edit")
        .sheet(isPresented: $showCreateSheet) {
            createSessionSheet
        }
        .sheet(isPresented: $showRenameSheet) {
            renameSessionSheet
        }
        .sheet(isPresented: $showDuplicateSheet) {
            duplicateSessionSheet
        }
        .onChange(of: selectedSession) { _, newSession in
            if let newSession {
                UserDefaults.standard.set(newSession.id.uuidString, forKey: lastSelectedSessionKey)
            }
        }
        .onAppear {
            updateSessions()
            restoreLastSelectedSession()
        }
        .onChange(of: allSessions) { _, _ in updateSessions() }
        .onChange(of: projectManager.currentProjectId) { _, _ in updateSessions() }
        .onChange(of: sessions) { _, _ in
            restoreLastSelectedSession()
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
            icon: "timer",
            title: "No sessions yet",
            message: "Create a session to start editing images in realtime.",
            buttonTitle: "Create Session"
        ) {
            newSessionName = ""
            showCreateSheet = true
        }
    }

    private var sessionsList: some View {
        List(selection: $selectedSession) {
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
            Text("This session and all its layers will be permanently deleted. This action cannot be undone.")
        }
    }

    // MARK: - Main Area

    private var mainArea: some View {
        GeometryReader { geometry in
            if geometry.size.width < canvasMinWidth {
                ExpandWindowView()
            } else {
                Group {
                    if let session = selectedSession {
                        RealtimeEditCanvasView(session: session)
                            .id(session.id)
                    } else {
                        emptyMainState
                    }
                }
            }
        }
    }

    private var emptyMainState: some View {
        AvgeekEmptyStateView(
            icon: "timer",
            title: "Select a session",
            message: "Choose a session from the sidebar or create a new one to start editing."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sheets

    private var createSessionSheet: some View {
        NameInputSheet(
            title: "Create New Session",
            placeholder: "Session Name",
            actionTitle: "Create",
            name: $newSessionName,
            isPresented: $showCreateSheet,
            onAction: createSession
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
            onCancel: { sessionToRename = nil }
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
            onCancel: { sessionToDuplicate = nil }
        )
    }

    // MARK: - Actions

    private func restoreLastSelectedSession() {
        guard selectedSession == nil else { return }

        if let savedId = UserDefaults.standard.string(forKey: lastSelectedSessionKey),
           let uuid = UUID(uuidString: savedId),
           let session = sessions.first(where: { $0.id == uuid })
        {
            selectedSession = session
        }
    }

    private func createSession() {
        let trimmedName = newSessionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let session = RealtimeEditSession(
            name: trimmedName,
            projectId: projectManager.currentProjectId
        )
        modelContext.insert(session)

        do {
            try modelContext.save()
            selectedSession = session
        } catch {
            AppLogger.ui
                .error("Failed to create realtime edit session: \(error.localizedDescription, privacy: .public)")
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
            AppLogger.ui
                .error("Failed to rename realtime edit session: \(error.localizedDescription, privacy: .public)")
        }

        showRenameSheet = false
        sessionToRename = nil
    }

    private func duplicateSession(_ session: RealtimeEditSession, name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let newSession = RealtimeEditSession(
            name: trimmedName,
            projectId: session.projectId
        )
        newSession.isPinned = false
        modelContext.insert(newSession)

        do {
            try modelContext.save()
            updateSessions()
            sessionToDuplicate = nil
        } catch {
            AppLogger.data.error("Failed to duplicate session: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func togglePin(_ session: RealtimeEditSession) {
        session.isPinned.toggle()

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui
                .error(
                    "Failed to toggle pin for realtime edit session: \(error.localizedDescription, privacy: .public)"
                )
        }

        updateSessions()
    }

    private func deleteSession(_ session: RealtimeEditSession) {
        if selectedSession?.id == session.id {
            selectedSession = nil
        }

        modelContext.delete(session)

        do {
            try modelContext.save()
        } catch {
            AppLogger.ui
                .error("Failed to delete realtime edit session: \(error.localizedDescription, privacy: .public)")
        }
    }
}
