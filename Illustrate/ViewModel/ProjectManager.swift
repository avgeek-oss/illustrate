// MARK: - ProjectManager.swift

// Central manager for project selection, creation, and lifecycle.
//
// ProjectManager is a singleton ObservableObject that coordinates all project-related
// operations throughout the app. It handles:
// - Project selection and switching
// - Project creation, renaming, and deletion
// - Ensuring the default project exists
// - Managing project-scoped API keys in Keychain
//
// ## Architecture
// ProjectManager follows a singleton pattern with shared state:
// - `currentProjectId`: Persisted in UserDefaults for session continuity
// - `currentProject`: The active Project entity loaded from SwiftData
//
// ## Project Scoping
// All content in Illustrate is scoped to projects:
// - Generations belong to a project
// - API keys are stored per-project in Keychain
// - Agents and Flow Canvas belong to projects
//
// ## Keychain Integration
// API keys are stored in Keychain using a combined key format:
// `{projectId}_{providerId}` - This allows different API keys per project.

import Foundation
import KeychainSwift
import OSLog
import SwiftData
import SwiftUI

// MARK: - Project Manager

/// Singleton manager for project selection and lifecycle operations.
///
/// This class is the central authority for:
/// - Which project is currently active
/// - Creating, renaming, and deleting projects
/// - Managing project-scoped resources (API keys, content)
///
/// ## State Persistence
/// The current project ID is persisted in UserDefaults so users
/// return to the same project across app launches.
///
/// ## SwiftData Integration
/// Project entities are stored in SwiftData. This manager provides
/// helper methods that interact with the model context.
class ProjectManager: ObservableObject {
    /// Shared singleton instance
    static let shared = ProjectManager()

    /// UserDefaults key for persisting current project selection
    private let currentProjectIdKey = "currentProjectId"

    /// The currently selected project's UUID.
    /// Changes are automatically persisted to UserDefaults.
    @Published var currentProjectId: UUID {
        didSet {
            UserDefaults.standard.set(currentProjectId.uuidString, forKey: currentProjectIdKey)
        }
    }

    /// The currently active Project entity.
    /// Loaded from SwiftData when project changes or app launches.
    @Published var currentProject: Project?

    /// Private initializer enforces singleton pattern.
    /// Restores the last selected project from UserDefaults or defaults.
    private init() {
        if let savedIdString = UserDefaults.standard.string(forKey: currentProjectIdKey),
           let savedId = UUID(uuidString: savedIdString)
        {
            currentProjectId = savedId
        } else {
            currentProjectId = Project.defaultProjectId
        }
    }

    /// Ensures the default project exists in the database
    func ensureDefaultProjectExists(modelContext: ModelContext) {
        let defaultId = Project.defaultProjectId
        let descriptor = FetchDescriptor<Project>(predicate: #Predicate { $0.id == defaultId })

        do {
            let existingProjects = try modelContext.fetch(descriptor)
            if existingProjects.isEmpty {
                let defaultProject = Project.createDefault()
                modelContext.insert(defaultProject)
                try modelContext.save()
            }
        } catch {
            AppLogger.data
                .error("Error ensuring default project exists: \(error.localizedDescription, privacy: .public)")
        }

        loadCurrentProject(modelContext: modelContext)
    }

    /// Loads the current project from the database
    func loadCurrentProject(modelContext: ModelContext) {
        let projectId = currentProjectId
        let descriptor = FetchDescriptor<Project>(predicate: #Predicate { $0.id == projectId })

        do {
            let projects = try modelContext.fetch(descriptor)
            if let project = projects.first {
                DispatchQueue.main.async {
                    self.currentProject = project
                }
            } else {
                switchToDefaultProject(modelContext: modelContext)
            }
        } catch {
            AppLogger.data.error("Error loading current project: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Switches to the default project
    func switchToDefaultProject(modelContext: ModelContext) {
        currentProjectId = Project.defaultProjectId
        loadCurrentProject(modelContext: modelContext)
    }

    /// Switches to a different project
    func switchProject(to project: Project) {
        currentProjectId = project.id
        currentProject = project
    }

    /// Creates a new project
    func createProject(name: String, modelContext: ModelContext) -> Project? {
        let newProject = Project(name: name)
        modelContext.insert(newProject)

        do {
            try modelContext.save()
            return newProject
        } catch {
            AppLogger.data.error("Error creating project: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Renames a project
    func renameProject(_ project: Project, to newName: String, modelContext: ModelContext) -> Bool {
        project.name = newName

        do {
            try modelContext.save()
            if project.id == currentProjectId {
                currentProject = project
            }
            return true
        } catch {
            AppLogger.data.error("Error renaming project: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Deletes a project and all associated data
    func deleteProject(_ project: Project, modelContext: ModelContext) -> Bool {
        guard !project.isDefault else {
            AppLogger.data.error("Cannot delete default project")
            return false
        }

        let projectId = project.id

        if projectId == currentProjectId {
            switchToDefaultProject(modelContext: modelContext)
        }

        deleteProviderKeys(for: projectId, modelContext: modelContext)
        deleteChatMessagesAndGenerations(for: projectId, modelContext: modelContext)

        modelContext.delete(project)

        do {
            try modelContext.save()
            return true
        } catch {
            AppLogger.data.error("Error deleting project: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Deletes all provider keys for a project and removes their keychain entries
    private func deleteProviderKeys(for projectId: UUID, modelContext: ModelContext) {
        let descriptor = FetchDescriptor<ProviderKey>(
            predicate: #Predicate { $0.projectId == projectId }
        )

        do {
            let providerKeys = try modelContext.fetch(descriptor)
            let keychain = KeychainSwift()
            keychain.accessGroup = TEAM_KEYCHAIN_AG
            keychain.synchronizable = true

            for providerKey in providerKeys {
                let keychainKey = Self.keychainKey(projectId: projectId, providerId: providerKey.providerId)
                keychain.delete(keychainKey)
                modelContext.delete(providerKey)
            }

            // Notify that provider keys changed
            NotificationCenter.default.post(name: .providerKeysChanged, object: nil)
        } catch {
            AppLogger.data.error("Error deleting provider keys: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Deletes ChatMessages and orphaned Generations, cleans up iCloud files.
    /// ChatMessages are not cascaded from ChatThread (branched-generation safety).
    /// Orphaned Generations (no ImageSet parent) are not covered by Project→ImageSet→Generation cascade.
    /// Generation iCloud files must be cleaned up before cascade deletes them.
    private func deleteChatMessagesAndGenerations(for projectId: UUID, modelContext: ModelContext) {
        do {
            let threadDescriptor = FetchDescriptor<ChatThread>(
                predicate: #Predicate { $0.projectId == projectId }
            )
            let threads = try modelContext.fetch(threadDescriptor)
            let threadIds = Set(threads.map(\.id))

            if !threadIds.isEmpty {
                let messageDescriptor = FetchDescriptor<ChatMessage>(
                    predicate: #Predicate { threadIds.contains($0.threadId) }
                )
                let messages = try modelContext.fetch(messageDescriptor)
                for message in messages {
                    modelContext.delete(message)
                }
            }

            let genDescriptor = FetchDescriptor<Generation>(
                predicate: #Predicate { $0.projectId == projectId }
            )
            let generations = try modelContext.fetch(genDescriptor)
            for generation in generations {
                deleteICloudDocuments(containingSubstring: generation.id.uuidString)
                modelContext.delete(generation)
            }
        } catch {
            AppLogger.data
                .error(
                    "Error cleaning up chat messages and generation files: \(error.localizedDescription, privacy: .public)"
                )
        }
    }

    /// Fetches all projects
    func fetchAllProjects(modelContext: ModelContext) -> [Project] {
        let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            AppLogger.data.error("Error fetching projects: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Generates keychain key for a provider within current project
    func keychainKey(for providerId: UUID) -> String {
        "\(currentProjectId.uuidString)_\(providerId.uuidString)"
    }

    /// Generates keychain key for a provider within a specific project
    static func keychainKey(projectId: UUID, providerId: UUID) -> String {
        "\(projectId.uuidString)_\(providerId.uuidString)"
    }
}

// MARK: - Environment Key

struct ProjectManagerKey: EnvironmentKey {
    static let defaultValue = ProjectManager.shared
}

extension EnvironmentValues {
    var projectManager: ProjectManager {
        get { self[ProjectManagerKey.self] }
        set { self[ProjectManagerKey.self] = newValue }
    }
}
