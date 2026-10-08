// MARK: - RealtimeEditListView.swift

// Session list view for Realtime Edit.
//
// Displays all realtime edit sessions in a scrollable list with:
// - Session name and creation date
// - Pin/unpin functionality
// - Rename action
// - Delete action
// - Create new session button
//
// ## Pinned Sessions
// Pinned sessions appear at the top of the list with a pin icon indicator.
//
// ## Interaction
// - Click session → Opens canvas editor
// - Right-click → Context menu for rename/delete/pin
// - Plus button → Creates new session

import SwiftUI

/// List view displaying all realtime edit sessions.
///
/// Provides session management UI with sorting (pinned first),
/// context menus, and creation button.
struct RealtimeEditListView: View {
    let sessions: [RealtimeEditSession]
    let onSelectSession: (RealtimeEditSession) -> Void
    let onCreateSession: () -> Void
    let onDeleteSession: (RealtimeEditSession) -> Void
    let onRenameSession: (RealtimeEditSession, String) -> Void
    let onTogglePin: (RealtimeEditSession) -> Void

    @State private var sessionToRename: RealtimeEditSession?
    @State private var renameText = ""
    @State private var showRenameSheet = false
    @State private var sessionToDelete: RealtimeEditSession?
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Realtime Edit Sessions")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    onCreateSession()
                } label: {
                    Label("New Session", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Session List
            if sessions.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sessions) { session in
                            sessionCard(session)
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            renameSheet
        }
        .alert("Delete Session?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete { onDeleteSession(session); sessionToDelete = nil }
            }
        } message: {
            Text("This session and all its layers will be permanently deleted. This action cannot be undone.")
        }
    }

    // MARK: - Session Card

    private func sessionCard(_ session: RealtimeEditSession) -> some View {
        Button {
            onSelectSession(session)
        } label: {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: "timer")
                    .font(.system(size: 32))
                    .foregroundStyle(.blue)
                    .frame(width: 50, height: 50)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(session.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if session.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.quaternary.opacity(0.3))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                sessionToRename = session
                renameText = session.name
                showRenameSheet = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button {
                onTogglePin(session)
            } label: {
                Label(
                    session.isPinned ? "Unpin" : "Pin",
                    systemImage: session.isPinned ? "pin.slash" : "pin"
                )
            }

            Divider()

            Button(role: .destructive) {
                sessionToDelete = session
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "timer")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No Sessions Yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Create your first realtime edit session to start editing")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                onCreateSession()
            } label: {
                Label("Create Session", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }

    // MARK: - Rename Sheet

    private var renameSheet: some View {
        NavigationStack {
            Form {
                TextField("Session Name", text: $renameText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        saveRename()
                    }
            }
            .navigationTitle("Rename Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showRenameSheet = false
                        sessionToRename = nil
                        renameText = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRename()
                    }
                    .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 200)
    }

    private func saveRename() {
        if let session = sessionToRename,
           !renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            onRenameSession(session, renameText)
            showRenameSheet = false
            sessionToRename = nil
            renameText = ""
        }
    }
}
