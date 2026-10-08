// MARK: - TestFixtureValidationTests.swift

// Validates that all TestFixtures factory methods produce valid, self-consistent objects.
//
// Tests cover:
// - Each factory method produces valid instances with expected defaults
// - Factory methods produce unique IDs on repeated calls
// - Date fields are reasonable (within last minute)
// - Fixtures with projectId use Project.defaultProjectId by default
// - Custom parameter overrides work correctly

import CoreGraphics
import Foundation
import XCTest
@testable import Illustrate

final class TestFixtureValidationTests: XCTestCase {
    // MARK: - Factory Method Validation

    func testFixture_makeProject_hasValidId() {
        let project = TestFixtures.makeProject()
        XCTAssertNotNil(project.id)
    }

    func testFixture_makeProject_hasNonEmptyName() {
        let project = TestFixtures.makeProject()
        XCTAssertFalse(project.name.isEmpty)
    }

    func testFixture_makeProject_createdAtIsSet() {
        let project = TestFixtures.makeProject()
        XCTAssertNotNil(project.createdAt)
    }

    func testFixture_makeGeneration_hasValidId() {
        let gen = TestFixtures.makeGeneration()
        XCTAssertNotNil(gen.id)
    }

    func testFixture_makeGeneration_hasNonEmptyPrompt() {
        let gen = TestFixtures.makeGeneration()
        XCTAssertFalse(gen.prompt.isEmpty)
    }

    func testFixture_makeGeneration_hasValidSetId() {
        let gen = TestFixtures.makeGeneration()
        XCTAssertNotNil(gen.setId)
    }

    func testFixture_makeImageSet_hasValidId() {
        let set = TestFixtures.makeImageSet()
        XCTAssertNotNil(set.id)
    }

    func testFixture_makeImageSet_hasNonEmptyPrompt() {
        let set = TestFixtures.makeImageSet()
        XCTAssertFalse(set.prompt.isEmpty)
    }

    func testFixture_makeProviderKey_hasValidProviderId() {
        let key = TestFixtures.makeProviderKey()
        XCTAssertNotNil(key.providerId)
    }

    func testFixture_makeProviderKey_projectIdMatchesDefault() {
        let key = TestFixtures.makeProviderKey()
        XCTAssertEqual(key.projectId, Project.defaultProjectId)
    }

    func testFixture_makeAgent_hasValidId() {
        let agent = TestFixtures.makeAgent()
        XCTAssertNotNil(agent.id)
    }

    func testFixture_makeAgent_hasNonEmptyName() {
        let agent = TestFixtures.makeAgent()
        XCTAssertFalse(agent.name.isEmpty)
    }

    func testFixture_makeAgent_hasValidProjectId() {
        let agent = TestFixtures.makeAgent()
        XCTAssertEqual(agent.projectId, Project.defaultProjectId)
    }

    func testFixture_makeAgentCard_hasValidId() {
        let card = TestFixtures.makeAgentCard(agentId: UUID())
        XCTAssertNotNil(card.id)
    }

    func testFixture_makeAgentCard_hasValidAgentId() {
        let agentId = UUID()
        let card = TestFixtures.makeAgentCard(agentId: agentId)
        XCTAssertEqual(card.agentId, agentId)
    }

    func testFixture_makeAgentCard_createdAtIsSet() {
        let card = TestFixtures.makeAgentCard(agentId: UUID())
        XCTAssertNotNil(card.createdAt)
    }

    func testFixture_makeStartCard_cardTypeIsStart() {
        let card = TestFixtures.makeStartCard(agentId: UUID())
        XCTAssertEqual(card.cardType, .start)
    }

    func testFixture_makeStartCard_isDefaultIsTrue() {
        let card = TestFixtures.makeStartCard(agentId: UUID())
        XCTAssertTrue(card.isDefault)
    }

    func testFixture_makeOutputCard_cardTypeIsOutput() {
        let card = TestFixtures.makeOutputCard(agentId: UUID())
        XCTAssertEqual(card.cardType, .output)
    }

    func testFixture_makeOutputCard_isDefaultIsFalse() {
        let card = TestFixtures.makeOutputCard(agentId: UUID())
        XCTAssertFalse(card.isDefault)
    }

    func testFixture_makeCardLink_hasValidAgentId() {
        let agentId = UUID()
        let link = TestFixtures.makeCardLink(agentId: agentId, sourceCardId: UUID(), targetCardId: UUID())
        XCTAssertEqual(link.agentId, agentId)
    }

    func testFixture_makeCardLink_sourceAndTargetSet() {
        let sourceId = UUID()
        let targetId = UUID()
        let link = TestFixtures.makeCardLink(agentId: UUID(), sourceCardId: sourceId, targetCardId: targetId)
        XCTAssertEqual(link.sourceCardId, sourceId)
        XCTAssertEqual(link.targetCardId, targetId)
    }

    func testFixture_makeAgentRun_hasValidAgentId() {
        let agentId = UUID()
        let run = TestFixtures.makeAgentRun(agentId: agentId)
        XCTAssertEqual(run.agentId, agentId)
    }

    func testFixture_makeFailedRequest_hasNonEmptyPrompt() {
        let request = TestFixtures.makeFailedRequest()
        XCTAssertFalse(request.prompt.isEmpty)
    }

    func testFixture_makeFailedRequest_hasNonEmptyModelId() {
        let request = TestFixtures.makeFailedRequest()
        XCTAssertFalse(request.modelId.isEmpty)
    }

    func testFixture_makeFailedRequest_hasNonEmptyErrorMessage() {
        let request = TestFixtures.makeFailedRequest()
        XCTAssertFalse(request.errorMessage.isEmpty)
    }

    func testFixture_makeBulkSession_hasValidId() {
        let session = TestFixtures.makeBulkSession()
        XCTAssertNotNil(session.id)
    }

    func testFixture_makeBulkSession_statusIsIdle() {
        let session = TestFixtures.makeBulkSession()
        XCTAssertEqual(session.status, .IDLE)
    }

    func testFixture_makeBrandKit_hasValidId() {
        let kit = TestFixtures.makeBrandKit()
        XCTAssertNotNil(kit.id)
    }

    func testFixture_makeBrandKit_hasValidProjectId() {
        let kit = TestFixtures.makeBrandKit()
        XCTAssertEqual(kit.projectId, Project.defaultProjectId)
    }

    // MARK: - Consistency Tests

    func testFixture_allFactories_produceUniqueIds() {
        let agent1 = TestFixtures.makeAgent()
        let agent2 = TestFixtures.makeAgent()
        XCTAssertNotEqual(agent1.id, agent2.id)

        let project1 = TestFixtures.makeProject()
        let project2 = TestFixtures.makeProject()
        XCTAssertNotEqual(project1.id, project2.id)

        let session1 = TestFixtures.makeBulkSession()
        let session2 = TestFixtures.makeBulkSession()
        XCTAssertNotEqual(session1.id, session2.id)
    }

    func testFixture_dateFields_areWithinLastMinute() {
        let oneMinuteAgo = Date().addingTimeInterval(-60)

        let agent = TestFixtures.makeAgent()
        XCTAssertGreaterThan(agent.createdAt, oneMinuteAgo)

        let project = TestFixtures.makeProject()
        XCTAssertGreaterThan(project.createdAt, oneMinuteAgo)

        let session = TestFixtures.makeBulkSession()
        XCTAssertGreaterThan(session.createdAt, oneMinuteAgo)
    }

    func testFixture_projectIdDefaults_matchDefaultProjectId() {
        XCTAssertEqual(TestFixtures.makeAgent().projectId, Project.defaultProjectId)
        XCTAssertEqual(TestFixtures.makeProviderKey().projectId, Project.defaultProjectId)
        XCTAssertEqual(TestFixtures.makeBulkSession().projectId, Project.defaultProjectId)
        XCTAssertEqual(TestFixtures.makeBrandKit().projectId, Project.defaultProjectId)
        XCTAssertEqual(TestFixtures.makeFailedRequest().projectId, Project.defaultProjectId)
    }

    // MARK: - Custom Parameter Tests

    func testFixture_makeProject_customName_preservesIt() {
        let project = TestFixtures.makeProject(name: "Custom Name")
        XCTAssertEqual(project.name, "Custom Name")
    }

    func testFixture_makeAgent_customProjectId_preservesIt() {
        let projectId = UUID()
        let agent = TestFixtures.makeAgent(projectId: projectId)
        XCTAssertEqual(agent.projectId, projectId)
    }

    func testFixture_makeGeneration_customPrompt_preservesIt() {
        let gen = TestFixtures.makeGeneration(prompt: "Custom prompt")
        XCTAssertEqual(gen.prompt, "Custom prompt")
    }

    func testFixture_makeDefaultProject_idIsDefaultProjectId() {
        let project = TestFixtures.makeDefaultProject()
        XCTAssertEqual(project.id, Project.defaultProjectId)
    }

    func testFixture_makeDefaultProject_isDefaultTrue() {
        let project = TestFixtures.makeDefaultProject()
        XCTAssertTrue(project.isDefault)
    }
}
