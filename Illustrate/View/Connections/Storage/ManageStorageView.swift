// MARK: - ManageStorageView.swift

// Storage management view for resetting the current project to a fresh state.
//
// Displays counts for the active project and provides a destructive reset action.
// Reset removes project-scoped data — generations, provider keys, agents, brand
// kits, chat threads, playgrounds, storyboards, bulk sessions, failed requests,
// and generated media files for that project.
//
// ## Warning
// Reset is irreversible. Project media files are permanently deleted with no backup.
//
// ## Data Cleared
// - All Generation, ImageSet entities
// - All ProviderKey entities + Keychain entries
// - All Agent, AgentCard, AgentRun, CardLink entities
// - All BrandKit, CreativeStudio, CreativeStudioItem entities
// - All ProductPhotoshoot, ProductPhotoshootItem entities
// - All ChatThread, ChatMessage entities
// - All Playground, PlaygroundCard, PlaygroundLink entities
// - All RealtimeEditSession, RealtimeEditLayer entities
// - All Storyboard, StoryboardScene, StoryboardAsset entities
// - All BulkSession, BulkSessionItem entities
// - All FailedRequest entities
// - Project entity is preserved

import SwiftData
import SwiftUI

struct ManageStorageView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var projectManager: ProjectManager
    @State private var showResetSheet = false
    @State private var resetConfirmationText = ""

    @State private var dataCounts = ProjectStorageCounts.empty

    private var projectName: String {
        projectManager.currentProject?.name ?? ""
    }

    func loadDataCounts() {
        dataCounts = ProjectStorageResetService.loadDataCounts(
            projectId: projectManager.currentProjectId,
            modelContext: modelContext
        )
    }

    func resetProject() {
        do {
            try ProjectStorageResetService.resetProjectData(
                projectId: projectManager.currentProjectId,
                modelContext: modelContext
            )

            GalleryCache.shared.invalidate()
            ProviderKeysCache.shared.invalidate()
            NotificationCenter.default.post(name: .providerKeysChanged, object: nil)

            projectManager.loadCurrentProject(modelContext: modelContext)

            loadDataCounts()
        } catch {
            AppLogger.storage.error("Failed to reset project: \(error.localizedDescription, privacy: .public)")
        }
    }

    var body: some View {
        Form {
            Section("Reset Project") {
                Text(
                    "Resetting will permanently delete data in \(projectName.isEmpty ? "this project" : projectName) — generations, provider keys, agents, brand kits, chat threads, playgrounds, storyboards, bulk sessions, failed requests, and generated media files. Other projects are not affected. This cannot be undone."
                )
                .fixedSize(horizontal: false, vertical: true)

                Group {
                    DataCountRow(label: "Generations", count: dataCounts.generations, icon: "photo.on.rectangle.angled")
                    DataCountRow(label: "Image Sets", count: dataCounts.imageSets, icon: "square.stack.3d.up")
                    DataCountRow(label: "Provider Keys", count: dataCounts.providerKeys, icon: "link")
                    DataCountRow(label: "Agents", count: dataCounts.agents, icon: "square.and.pencil")
                    DataCountRow(label: "Brand Kits", count: dataCounts.brandKits, icon: "briefcase")
                    DataCountRow(
                        label: "Chat Threads",
                        count: dataCounts.chatThreads,
                        icon: "bubble.left.and.text.bubble.right"
                    )
                    DataCountRow(
                        label: "Playgrounds",
                        count: dataCounts.playgrounds,
                        icon: "point.topleft.down.to.point.bottomright.curvepath"
                    )
                    DataCountRow(label: "Storyboards", count: dataCounts.storyboards, icon: "movieclapper")
                    DataCountRow(label: "Bulk Sessions", count: dataCounts.bulkSessions, icon: "square.grid.2x2")
                    DataCountRow(
                        label: "Failed Requests",
                        count: dataCounts.failedRequests,
                        icon: "exclamationmark.triangle"
                    )
                }

                Button(role: .destructive, action: {
                    resetConfirmationText = ""
                    showResetSheet = true
                }) {
                    Label("Clear Project Data", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .formStyle(.grouped)
        .task(id: projectManager.currentProjectId) { loadDataCounts() }
        .sheet(isPresented: $showResetSheet) {
            ResetProjectSheet(
                projectName: projectName,
                confirmationText: $resetConfirmationText,
                onCancel: { showResetSheet = false },
                onReset: {
                    resetProject()
                    showResetSheet = false
                }
            )
        }
        .navigationTitle(labelForItem(.settingsStorage))
    }
}

private struct DataCountRow: View {
    let label: String
    let count: Int
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 16)
                .foregroundStyle(secondaryLabel)
                .font(.body)
            Text(label)
            Spacer()
            Text("\(count)")
                .monospacedDigit()
                .foregroundStyle(secondaryLabel)
        }
    }
}

private struct ResetProjectSheet: View {
    let projectName: String
    @Binding var confirmationText: String
    let onCancel: () -> Void
    let onReset: () -> Void

    private var trimmedProjectName: String {
        projectName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isConfirmed: Bool {
        !trimmedProjectName.isEmpty &&
            confirmationText.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedProjectName
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(
                    "This will permanently delete data and asset files in this project. Other projects are not affected."
                )
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Project name")
                        .font(.caption)
                        .foregroundStyle(secondaryLabel)

                    Text(trimmedProjectName.isEmpty ? "Current project name unavailable" : trimmedProjectName)
                        .font(.body.weight(.semibold))
                        .lineLimit(3)
                        .textSelection(.enabled)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(secondarySystemFill, in: RoundedRectangle(cornerRadius: 8))
                }

                Text("Type the project name exactly to confirm.")
                    .fixedSize(horizontal: false, vertical: true)

                TextField("Project name", text: $confirmationText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(trimmedProjectName.isEmpty)
                    #if os(macOS)
                    .font(.system(.body, design: .monospaced))
                    #endif
            }
            .padding(.all, 24)
            .frame(minWidth: 320, idealWidth: 440, maxWidth: 480, alignment: .leading)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Reset", role: .destructive, action: onReset)
                        .disabled(!isConfirmed)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 360, idealWidth: 440)
        #endif
    }
}
