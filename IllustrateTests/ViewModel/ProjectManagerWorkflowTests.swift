// MARK: - ProjectManagerWorkflowTests.swift

// Tests for ProjectManager lifecycle operations.
//
// Tests cover:
// - Default project creation and idempotency
// - Project CRUD (create, rename, delete)
// - Default project protection (cannot be deleted)
// - Cascade deletion (provider keys + generations)
// - Project switching
// - Keychain key format generation
//
// ## Testing Strategy
// ProjectManager is a singleton with private init. Tests use the shared
// instance with an in-memory ModelContext. The default project must be
// created in setUp to prevent infinite recursion in loadCurrentProject
// when the project is not found in the in-memory DB.

import Foundation
import SwiftData
import XCTest
@testable import Illustrate

@MainActor
final class ProjectManagerWorkflowTests: XCTestCase {
    private var container: ModelContainer!
    private var modelContext: ModelContext!
    private var manager: ProjectManager!

    override func setUp() async throws {
        try await super.setUp()
        container = try makeTestModelContainer()
        modelContext = container.mainContext
        manager = ProjectManager.shared

        // Always create the default project in the in-memory container.
        // This prevents infinite recursion when loadCurrentProject calls
        // switchToDefaultProject which calls loadCurrentProject again.
        let defaultProject = Project.createDefault()
        modelContext.insert(defaultProject)
        try modelContext.save()

        manager.currentProjectId = Project.defaultProjectId
    }

    override func tearDown() async throws {
        // Restore default state
        manager.currentProjectId = Project.defaultProjectId
        manager.currentProject = nil
        container = nil
        modelContext = nil
        manager = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func fetchDefaultProject() -> Project? {
        let defaultId = Project.defaultProjectId
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.id == defaultId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Default Project

    func testEnsureDefaultProjectExists_findsExistingDefault() {
        // Default project already inserted in setUp
        manager.ensureDefaultProjectExists(modelContext: modelContext)

        let project = fetchDefaultProject()
        XCTAssertNotNil(project)
        XCTAssertEqual(project?.name, "Default Project")
        XCTAssertTrue(project?.isDefault ?? false)
    }

    func testEnsureDefaultProjectExists_idempotent_noDuplicate() {
        // Default already exists from setUp, calling again should not create duplicate
        manager.ensureDefaultProjectExists(modelContext: modelContext)
        manager.ensureDefaultProjectExists(modelContext: modelContext)

        let defaultId = Project.defaultProjectId
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.id == defaultId }
        )
        let projects = try? modelContext.fetch(descriptor)
        XCTAssertEqual(projects?.count, 1, "Should not create duplicate default projects")
    }

    func testEnsureDefaultProjectExists_loadsCurrentProject() {
        manager.ensureDefaultProjectExists(modelContext: modelContext)

        // loadCurrentProject dispatches to main queue
        let expectation = XCTestExpectation(description: "Current project set")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertNotNil(self.manager.currentProject)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Create Project

    func testCreateProject_returnsNewProject() {
        let project = manager.createProject(name: "My Project", modelContext: modelContext)

        XCTAssertNotNil(project)
        XCTAssertEqual(project?.name, "My Project")
        XCTAssertFalse(project?.isDefault ?? true)
    }

    func testCreateProject_persistsToDatabase() {
        guard let project = manager.createProject(name: "Persisted Project", modelContext: modelContext) else {
            XCTFail("Project should have been created")
            return
        }

        let projectId = project.id
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.id == projectId }
        )
        let fetched = try? modelContext.fetch(descriptor)
        XCTAssertEqual(fetched?.count, 1)
        XCTAssertEqual(fetched?.first?.name, "Persisted Project")
    }

    // MARK: - Rename Project

    func testRenameProject_updatesName() {
        guard let project = manager.createProject(name: "Old Name", modelContext: modelContext) else {
            XCTFail("Project creation failed")
            return
        }

        let result = manager.renameProject(project, to: "New Name", modelContext: modelContext)

        XCTAssertTrue(result)
        XCTAssertEqual(project.name, "New Name")
    }

    func testRenameProject_updatesCurrentProjectIfActive() {
        guard let project = manager.createProject(name: "Active Project", modelContext: modelContext) else {
            XCTFail("Project creation failed")
            return
        }
        manager.switchProject(to: project)

        _ = manager.renameProject(project, to: "Renamed Active", modelContext: modelContext)

        XCTAssertEqual(manager.currentProject?.name, "Renamed Active")
    }

    // MARK: - Delete Project

    func testDeleteProject_removesFromDatabase() {
        guard let project = manager.createProject(name: "To Delete", modelContext: modelContext) else {
            XCTFail("Project creation failed")
            return
        }
        let projectId = project.id

        let result = manager.deleteProject(project, modelContext: modelContext)

        XCTAssertTrue(result)
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.id == projectId }
        )
        let remaining = try? modelContext.fetch(descriptor)
        XCTAssertEqual(remaining?.count, 0)
    }

    func testDeleteProject_defaultProject_returnsFalse() {
        guard let defaultProject = fetchDefaultProject() else {
            XCTFail("Default project should exist")
            return
        }

        let result = manager.deleteProject(defaultProject, modelContext: modelContext)
        XCTAssertFalse(result, "Should not be able to delete default project")
    }

    func testDeleteProject_defaultProject_projectSurvives() {
        guard let defaultProject = fetchDefaultProject() else {
            XCTFail("Default project should exist")
            return
        }

        _ = manager.deleteProject(defaultProject, modelContext: modelContext)

        let remaining = fetchDefaultProject()
        XCTAssertNotNil(remaining, "Default project should still exist after delete attempt")
    }

    func testDeleteProject_currentProject_switchesToDefault() {
        guard let project = manager.createProject(name: "Current", modelContext: modelContext) else {
            XCTFail("Project creation failed")
            return
        }
        manager.switchProject(to: project)

        _ = manager.deleteProject(project, modelContext: modelContext)

        XCTAssertEqual(manager.currentProjectId, Project.defaultProjectId)
    }

    func testDeleteProject_cascadesProviderKeyDeletion() {
        guard let project = manager.createProject(name: "With Keys", modelContext: modelContext) else {
            XCTFail("Project creation failed")
            return
        }
        let projectId = project.id

        let key1 = TestFixtures.makeProviderKey(projectId: projectId)
        let key2 = TestFixtures.makeProviderKey(projectId: projectId)
        modelContext.insert(key1)
        modelContext.insert(key2)
        try? modelContext.save()

        _ = manager.deleteProject(project, modelContext: modelContext)

        let descriptor = FetchDescriptor<ProviderKey>(
            predicate: #Predicate { $0.projectId == projectId }
        )
        let remainingKeys = try? modelContext.fetch(descriptor)
        XCTAssertEqual(remainingKeys?.count, 0, "Provider keys should be deleted with project")
    }

    func testDeleteProject_cascadesGenerationDeletion() {
        guard let project = manager.createProject(name: "With Gens", modelContext: modelContext) else {
            XCTFail("Project creation failed")
            return
        }
        let projectId = project.id

        let gen1 = TestFixtures.makeGeneration(projectId: projectId)
        let gen2 = TestFixtures.makeGeneration(projectId: projectId)
        modelContext.insert(gen1)
        modelContext.insert(gen2)
        try? modelContext.save()

        _ = manager.deleteProject(project, modelContext: modelContext)

        let descriptor = FetchDescriptor<Generation>(
            predicate: #Predicate { $0.projectId == projectId }
        )
        let remainingGens = try? modelContext.fetch(descriptor)
        XCTAssertEqual(remainingGens?.count, 0, "Generations should be deleted with project")
    }

    func testDeleteProject_doesNotAffectOtherProjects() {
        guard let keepProject = manager.createProject(name: "Keep", modelContext: modelContext),
              let deleteProject = manager.createProject(name: "Delete", modelContext: modelContext)
        else {
            XCTFail("Project creation failed")
            return
        }

        let keepProjectId = keepProject.id
        let keepGen = TestFixtures.makeGeneration(projectId: keepProjectId)
        let deleteGen = TestFixtures.makeGeneration(projectId: deleteProject.id)
        modelContext.insert(keepGen)
        modelContext.insert(deleteGen)
        try? modelContext.save()

        _ = manager.deleteProject(deleteProject, modelContext: modelContext)

        let descriptor = FetchDescriptor<Generation>(
            predicate: #Predicate { $0.projectId == keepProjectId }
        )
        let remaining = try? modelContext.fetch(descriptor)
        XCTAssertEqual(remaining?.count, 1, "Other project's generations should be untouched")
    }

    // MARK: - Switch Project

    func testSwitchProject_updatesCurrentProjectId() {
        guard let project = manager.createProject(name: "Switch Target", modelContext: modelContext) else {
            XCTFail("Project creation failed")
            return
        }
        manager.switchProject(to: project)
        XCTAssertEqual(manager.currentProjectId, project.id)
    }

    func testSwitchProject_updatesCurrentProject() {
        guard let project = manager.createProject(name: "Switch Target", modelContext: modelContext) else {
            XCTFail("Project creation failed")
            return
        }
        manager.switchProject(to: project)
        XCTAssertEqual(manager.currentProject?.id, project.id)
    }

    // MARK: - Fetch All Projects

    func testFetchAllProjects_returnsAllProjects() {
        // Default project already exists from setUp
        _ = manager.createProject(name: "Project A", modelContext: modelContext)
        _ = manager.createProject(name: "Project B", modelContext: modelContext)

        let allProjects = manager.fetchAllProjects(modelContext: modelContext)
        XCTAssertEqual(allProjects.count, 3) // default + A + B
    }

    // MARK: - Keychain Key Generation

    func testKeychainKey_static_formatIsProjectIdUnderscoreProviderId() {
        let projectId = UUID()
        let providerId = UUID()
        let key = ProjectManager.keychainKey(projectId: projectId, providerId: providerId)
        XCTAssertEqual(key, "\(projectId.uuidString)_\(providerId.uuidString)")
    }

    func testKeychainKey_deterministicForSameInputs() {
        let projectId = UUID()
        let providerId = UUID()
        let key1 = ProjectManager.keychainKey(projectId: projectId, providerId: providerId)
        let key2 = ProjectManager.keychainKey(projectId: projectId, providerId: providerId)
        XCTAssertEqual(key1, key2)
    }

    func testKeychainKey_differentProjects_differentKeys() {
        let providerId = UUID()
        let key1 = ProjectManager.keychainKey(projectId: UUID(), providerId: providerId)
        let key2 = ProjectManager.keychainKey(projectId: UUID(), providerId: providerId)
        XCTAssertNotEqual(key1, key2)
    }

    func testKeychainKey_differentProviders_differentKeys() {
        let projectId = UUID()
        let key1 = ProjectManager.keychainKey(projectId: projectId, providerId: UUID())
        let key2 = ProjectManager.keychainKey(projectId: projectId, providerId: UUID())
        XCTAssertNotEqual(key1, key2)
    }

    func testKeychainKey_instanceMethod_usesCurrentProjectId() {
        let providerId = UUID()
        let instanceKey = manager.keychainKey(for: providerId)
        let staticKey = ProjectManager.keychainKey(
            projectId: manager.currentProjectId,
            providerId: providerId
        )
        XCTAssertEqual(instanceKey, staticKey)
    }
}
