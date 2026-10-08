// MARK: - ProjectModelTests.swift

// Tests for the Project model - project organization entity.
//
// Tests cover:
// - Static defaultProjectId deterministic UUID
// - Project initialization with default and custom values
// - createDefault() factory method
// - Codable round-trip serialization
// - Identifiable conformance

import Foundation
import XCTest
@testable import Illustrate

final class ProjectModelTests: XCTestCase {
    // MARK: - Default Project ID

    func testProject_defaultProjectId_isNotNil() {
        XCTAssertNotNil(Project.defaultProjectId)
    }

    func testProject_defaultProjectId_stableAcrossAccesses() {
        let first = Project.defaultProjectId
        let second = Project.defaultProjectId
        XCTAssertEqual(first, second)
    }

    func testProject_defaultProjectId_isDeterministic() throws {
        // defaultProjectId is a hardcoded UUID constant
        let expected = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        XCTAssertEqual(Project.defaultProjectId, expected)
    }

    func testProject_defaultProjectId_isKnownUUIDString() {
        // Verify the exact UUID string for the default project
        XCTAssertEqual(Project.defaultProjectId.uuidString, "00000000-0000-0000-0000-000000000001")
    }

    // MARK: - Initialization

    func testProject_init_setsName() {
        let project = Project(name: "My Project")
        XCTAssertEqual(project.name, "My Project")
    }

    func testProject_init_defaultIsDefaultFalse() {
        let project = Project(name: "Test")
        XCTAssertFalse(project.isDefault)
    }

    func testProject_init_customId() {
        let customId = UUID()
        let project = Project(id: customId, name: "Test")
        XCTAssertEqual(project.id, customId)
    }

    func testProject_init_customIsDefault() {
        let project = Project(name: "Test", isDefault: true)
        XCTAssertTrue(project.isDefault)
    }

    func testProject_init_createdAtIsSet() {
        let before = Date()
        let project = Project(name: "Test")
        let after = Date()
        XCTAssertGreaterThanOrEqual(project.createdAt, before)
        XCTAssertLessThanOrEqual(project.createdAt, after)
    }

    // MARK: - createDefault Factory

    func testProject_createDefault_idIsDefaultProjectId() {
        let project = Project.createDefault()
        XCTAssertEqual(project.id, Project.defaultProjectId)
    }

    func testProject_createDefault_nameIsDefaultProject() {
        let project = Project.createDefault()
        XCTAssertEqual(project.name, "Default Project")
    }

    func testProject_createDefault_isDefaultIsTrue() {
        let project = Project.createDefault()
        XCTAssertTrue(project.isDefault)
    }

    func testProject_createDefault_createdAtIsSet() {
        let project = Project.createDefault()
        XCTAssertNotNil(project.createdAt)
    }

    func testProject_createDefault_calledTwice_sameId() {
        let p1 = Project.createDefault()
        let p2 = Project.createDefault()
        XCTAssertEqual(p1.id, p2.id, "createDefault should always use the same deterministic ID")
    }

    // MARK: - Codable Round-Trip

    func testProject_codableRoundTrip_preservesAllFields() throws {
        let project = Project(name: "Test Project", isDefault: false)

        let data = try JSONEncoder().encode(project)
        let restored = try JSONDecoder().decode(Project.self, from: data)

        XCTAssertEqual(restored.id, project.id)
        XCTAssertEqual(restored.name, project.name)
        XCTAssertEqual(restored.isDefault, project.isDefault)
    }

    func testProject_codableRoundTrip_defaultProject() throws {
        let project = Project.createDefault()

        let data = try JSONEncoder().encode(project)
        let restored = try JSONDecoder().decode(Project.self, from: data)

        XCTAssertEqual(restored.id, Project.defaultProjectId)
        XCTAssertEqual(restored.name, "Default Project")
        XCTAssertTrue(restored.isDefault)
    }

    func testProject_codableRoundTrip_preservesIsDefault() throws {
        let project = Project(name: "Regular", isDefault: false)
        XCTAssertFalse(project.isDefault)

        let data = try JSONEncoder().encode(project)
        let restored = try JSONDecoder().decode(Project.self, from: data)
        XCTAssertFalse(restored.isDefault)
    }

    func testProject_codableRoundTrip_isDefaultTrue() throws {
        let project = Project(name: "Primary", isDefault: true)

        let data = try JSONEncoder().encode(project)
        let restored = try JSONDecoder().decode(Project.self, from: data)
        XCTAssertTrue(restored.isDefault)
    }

    // MARK: - Edge Cases

    func testProject_emptyName_isAllowed() {
        let project = Project(name: "")
        XCTAssertEqual(project.name, "")
    }

    func testProject_longName_isPreserved() throws {
        let longName = String(repeating: "A", count: 1000)
        let project = Project(name: longName)

        let data = try JSONEncoder().encode(project)
        let restored = try JSONDecoder().decode(Project.self, from: data)

        XCTAssertEqual(restored.name, longName)
    }

    func testProject_identifiable_conformance() {
        let project = Project(name: "Identifiable Test")
        let _: UUID = project.id
        XCTAssertNotNil(project.id)
    }

    func testProject_twoInstances_haveDifferentIds() {
        let p1 = Project(name: "First")
        let p2 = Project(name: "Second")
        XCTAssertNotEqual(p1.id, p2.id)
    }
}
