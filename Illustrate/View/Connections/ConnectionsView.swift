// MARK: - ConnectionsView.swift

// Navigation hub for settings-related views.
//
// Lists available settings options (Providers, Storage, etc.)
// with platform-specific additions on mobile:
// - Project switching
// - Brand kit access

import AvgeekLocalizationCore
import AvgeekLocalizationUI
import SwiftData
import SwiftUI

/// Navigation list for settings section items.
struct ConnectionsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var appLanguageSettings = IllustrateLanguageSettings.shared
    @StateObject private var projectManager = ProjectManager.shared
    @Query(sort: \Project.createdAt, order: .forward) private var projects: [Project]
    @State private var showCreateProjectSheet = false
    @State private var newProjectName = ""

    var body: some View {
        Form {
            Section("Language") {
                Picker("Application Language", selection: $appLanguageSettings.appLanguage) {
                    ForEach(SupportedLanguage.allCases) { language in
                        Text(language.displayName)
                            .tag(language)
                    }
                }
            }

            #if !os(macOS)
            Section("Project") {
                Picker("Current Project", selection: Binding(
                    get: { projectManager.currentProjectId },
                    set: { newId in
                        if let project = projects.first(where: { $0.id == newId }) {
                            projectManager.switchProject(to: project)
                        }
                    }
                )) {
                    ForEach(projects) { project in
                        Text(project.name).tag(project.id)
                    }
                }

                Button {
                    newProjectName = ""
                    showCreateProjectSheet = true
                } label: {
                    Label("New Project", systemImage: "plus")
                }
            }

            #endif

            Section(EnumNavigationSection.Project.title) {
                List(sectionItems(section: EnumNavigationSection.Project), id: \.self) { item in
                    NavigationLink(value: item) {
                        Label(labelForItem(item), systemImage: iconForItem(item))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(EnumNavigationSection.Project.title)
        .sheet(isPresented: $showCreateProjectSheet) {
            CreateProjectSheet(
                projectName: $newProjectName,
                onCancel: { showCreateProjectSheet = false },
                onCreate: {
                    if !newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       let newProject = projectManager.createProject(
                           name: newProjectName,
                           modelContext: modelContext
                       )
                    {
                        projectManager.switchProject(to: newProject)
                    }
                    showCreateProjectSheet = false
                }
            )
        }
    }
}
