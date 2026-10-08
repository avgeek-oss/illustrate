// MARK: - ProjectSelectorView.swift

// Dropdown menu for switching between projects.
//
// Displays in the sidebar and allows users to:
// - View all projects
// - Switch to a different project
// - Create new projects
//
// ## Project Switching
// When a project is selected, ProjectManager.switchProject() is called,
// which updates currentProjectId and triggers data reloads.
//
// ## Create Project Sheet
// Presents a simple form for entering a new project name.
// Creates project and switches to it on success.

import SwiftData
import SwiftUI

/// Dropdown menu for project selection and creation.
struct ProjectSelectorView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var projectManager: ProjectManager
    @Query(sort: \Project.createdAt, order: .forward) private var projects: [Project]

    @State private var showCreateSheet = false
    @State private var newProjectName = ""

    /// Deduplicated projects by id, keeping the first occurrence (oldest by createdAt due to .forward sort order)
    private var uniqueProjects: [Project] {
        var seenIds = Set<UUID>()
        return projects.filter { project in
            if seenIds.contains(project.id) {
                return false
            }
            seenIds.insert(project.id)
            return true
        }
    }

    var body: some View {
        Menu {
            ForEach(uniqueProjects) { project in
                Button {
                    projectManager.switchProject(to: project)
                } label: {
                    HStack {
                        Text(project.name)
                        if project.id == projectManager.currentProjectId {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            Button {
                newProjectName = ""
                showCreateSheet = true
            } label: {
                Label("New Project", systemImage: "plus")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(projectManager.currentProject?.name ?? "Select Project")
                    .font(.subheadline)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showCreateSheet) {
            CreateProjectSheet(
                projectName: $newProjectName,
                onCancel: { showCreateSheet = false },
                onCreate: {
                    if !newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if let newProject = projectManager.createProject(
                            name: newProjectName,
                            modelContext: modelContext
                        ) {
                            projectManager.switchProject(to: newProject)
                        }
                    }
                    showCreateSheet = false
                }
            )
        }
    }
}

// MARK: - Create Project Sheet

struct CreateProjectSheet: View {
    @Binding var projectName: String
    let onCancel: () -> Void
    let onCreate: () -> Void

    private var isValidName: Bool {
        !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Project Name", text: $projectName)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Create New Project")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: onCreate)
                        .disabled(!isValidName)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 240, minHeight: 120)
        #endif
    }
}

// MARK: - Rename Project Sheet

struct RenameProjectSheet: View {
    @Binding var projectName: String
    let onCancel: () -> Void
    let onRename: () -> Void

    private var isValidName: Bool {
        !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Project Name", text: $projectName)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Rename Project")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Rename", action: onRename)
                        .disabled(!isValidName)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 240, minHeight: 120)
        #endif
    }
}
