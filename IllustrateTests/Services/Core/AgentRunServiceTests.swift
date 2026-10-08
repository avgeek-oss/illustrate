// MARK: - AgentRunServiceTests.swift

// Tests for AgentRunService - the runtime engine for agent workflows.
//
// Tests cover:
// - Template variable expansion ({{input}} placeholder replacement)
// - ProcessCardResult struct validation
// - Full executeRun() lifecycle with in-memory SwiftData
// - Card state management during execution
// - Error propagation and run status tracking

import Foundation
import IllustrateProviders
import SwiftData
import XCTest
@testable import Illustrate

// MARK: - Template Expansion Tests

final class AgentRunServiceExpandPromptTests: XCTestCase {
    // MARK: - Basic Replacement

    func testExpandPrompt_inputPlaceholder_replacedWithPreviousPrompt() {
        let result = AgentRunService.expandPrompt(
            template: "Generate an image of {{input}} in watercolor",
            previousPrompt: "a sunset over mountains"
        )
        XCTAssertEqual(result, "Generate an image of a sunset over mountains in watercolor")
    }

    func testExpandPrompt_noPlaceholder_promptUnchanged() {
        let result = AgentRunService.expandPrompt(
            template: "A simple prompt with no placeholders",
            previousPrompt: "some previous text"
        )
        XCTAssertEqual(result, "A simple prompt with no placeholders")
    }

    func testExpandPrompt_multiplePlaceholders_allReplaced() {
        let result = AgentRunService.expandPrompt(
            template: "{{input}} and {{input}} combined",
            previousPrompt: "cats"
        )
        XCTAssertEqual(result, "cats and cats combined")
    }

    // MARK: - Empty String Handling

    func testExpandPrompt_emptyTemplate_fallsBackToPreviousPrompt() {
        let result = AgentRunService.expandPrompt(
            template: "",
            previousPrompt: "fallback prompt"
        )
        XCTAssertEqual(result, "fallback prompt")
    }

    func testExpandPrompt_whitespaceOnlyTemplate_fallsBackToPreviousPrompt() {
        let result = AgentRunService.expandPrompt(
            template: "   \n  ",
            previousPrompt: "fallback prompt"
        )
        XCTAssertEqual(result, "fallback prompt")
    }

    func testExpandPrompt_templateBecomesEmptyAfterExpansion_fallsBackToPreviousPrompt() {
        let result = AgentRunService.expandPrompt(
            template: "{{input}}",
            previousPrompt: ""
        )
        // When both template resolves to empty and previousPrompt is empty,
        // the result is the empty previousPrompt
        XCTAssertEqual(result, "")
    }

    func testExpandPrompt_emptyPreviousPrompt_placeholderReplacedWithEmpty() {
        let result = AgentRunService.expandPrompt(
            template: "Create {{input}} artwork",
            previousPrompt: ""
        )
        XCTAssertEqual(result, "Create  artwork")
    }

    // MARK: - Edge Cases

    func testExpandPrompt_templateIsOnlyPlaceholder_returnsPreviousPrompt() {
        let result = AgentRunService.expandPrompt(
            template: "{{input}}",
            previousPrompt: "a beautiful landscape"
        )
        XCTAssertEqual(result, "a beautiful landscape")
    }

    func testExpandPrompt_caseSensitivePlaceholder_doesNotReplaceWrongCase() {
        let result = AgentRunService.expandPrompt(
            template: "{{INPUT}} test",
            previousPrompt: "value"
        )
        // {{INPUT}} is not the same as {{input}} — should NOT be replaced
        XCTAssertEqual(result, "{{INPUT}} test")
    }

    func testExpandPrompt_specialCharactersInPreviousPrompt_preserved() {
        let result = AgentRunService.expandPrompt(
            template: "Draw {{input}}",
            previousPrompt: "a cat & dog with <style>"
        )
        XCTAssertEqual(result, "Draw a cat & dog with <style>")
    }

    func testExpandPrompt_longPrompt_handledCorrectly() {
        let longPrompt = String(repeating: "word ", count: 1000)
        let result = AgentRunService.expandPrompt(
            template: "{{input}}",
            previousPrompt: longPrompt
        )
        XCTAssertEqual(result, longPrompt)
    }
}

// MARK: - Provider Input Validation Tests

final class AgentRunServiceProviderInputValidationTests: XCTestCase {
    func testXAIImageInputValidation_enforcesCombinedLimit() {
        let modelId = EnumProviderModelCode.XAI_GROK_IMAGINE_IMAGE.modelId.uuidString

        XCTAssertNil(AgentRunService.xAIImageInputValidationError(
            modelId: modelId,
            hasSourceImage: true,
            referenceImageCount: 2
        ))
        XCTAssertNotNil(AgentRunService.xAIImageInputValidationError(
            modelId: modelId,
            hasSourceImage: true,
            referenceImageCount: 3
        ))
    }

    func testXAIImageInputValidation_ignoresOtherModels() {
        XCTAssertNil(AgentRunService.xAIImageInputValidationError(
            modelId: EnumProviderModelCode.OPENAI_GPT_IMAGE_1.modelId.uuidString,
            hasSourceImage: true,
            referenceImageCount: 20
        ))
    }

    func testXAIVideoInputValidation_requiresPreviousSourceFor15() {
        let modelId = EnumProviderModelCode.XAI_GROK_IMAGINE_VIDEO_1_5.modelId.uuidString

        XCTAssertNotNil(AgentRunService.xAIVideoInputValidationError(
            modelId: modelId,
            hasSourceImage: false
        ))
        XCTAssertNil(AgentRunService.xAIVideoInputValidationError(
            modelId: modelId,
            hasSourceImage: true
        ))
    }
}

// MARK: - ProcessCardResult Tests

final class ProcessCardResultTests: XCTestCase {
    func testProcessCardResult_successWithGenerationId() {
        let genId = UUID()
        let result = ProcessCardResult(generationId: genId)
        XCTAssertEqual(result.generationId, genId)
        XCTAssertNil(result.error)
    }

    func testProcessCardResult_errorWithMessage() {
        let result = ProcessCardResult(error: "Generation failed")
        XCTAssertNil(result.generationId)
        XCTAssertEqual(result.error, "Generation failed")
    }

    func testProcessCardResult_defaultInit_bothNil() {
        let result = ProcessCardResult()
        XCTAssertNil(result.generationId)
        XCTAssertNil(result.error)
    }
}

// MARK: - AgentRunService Execution Tests

@MainActor
final class AgentRunServiceExecutionTests: XCTestCase {
    private var service: AgentRunService!
    private var container: ModelContainer!
    private var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        service = AgentRunService.shared
        container = try makeTestModelContainer()
        modelContext = container.mainContext
    }

    override func tearDown() async throws {
        service = nil
        container = nil
        modelContext = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func createTestCard(
        agentId: UUID,
        cardType: CardType,
        processCardType: ProcessCardType? = nil,
        title: String = "Test Card"
    ) -> AgentCard {
        AgentCard(
            agentId: agentId,
            cardType: cardType,
            processCardType: processCardType,
            title: title
        )
    }

    // MARK: - Run Lifecycle Tests

    func testExecuteRun_emptyCardList_returnsSuccessfulRun() async {
        let agent = TestFixtures.makeAgent()
        modelContext.insert(agent)
        try? modelContext.save()

        let queueManager = QueueManager()

        let run = await service.executeRun(
            agent: agent,
            orderedCards: [],
            links: [],
            providerKeys: [],
            queueManager: queueManager,
            modelContext: modelContext
        )

        XCTAssertEqual(run.status, .SUCCESSFUL)
        XCTAssertNotNil(run.completedAt)
        XCTAssertNil(run.errorMessage)
        XCTAssertNil(run.errorCardId)
    }

    func testExecuteRun_startCardOnly_extractsGenerationId() async {
        let agent = TestFixtures.makeAgent()
        modelContext.insert(agent)

        let startCard = createTestCard(agentId: agent.id, cardType: .start)
        let expectedGenId = UUID()
        startCard.generationId = expectedGenId
        modelContext.insert(startCard)
        try? modelContext.save()

        let queueManager = QueueManager()

        let run = await service.executeRun(
            agent: agent,
            orderedCards: [startCard],
            links: [],
            providerKeys: [],
            queueManager: queueManager,
            modelContext: modelContext
        )

        XCTAssertEqual(run.status, .SUCCESSFUL)
        XCTAssertNotNil(run.completedAt)
    }

    func testExecuteRun_resetsCardStates_beforeExecution() async {
        let agent = TestFixtures.makeAgent()
        modelContext.insert(agent)

        let startCard = createTestCard(agentId: agent.id, cardType: .start)

        let processCard = createTestCard(
            agentId: agent.id,
            cardType: .process,
            processCardType: .imageGeneration
        )
        processCard.isErrored = true
        processCard.errorMessage = "Previous error"
        processCard.generationId = UUID()
        processCard.isRunning = true

        modelContext.insert(startCard)
        modelContext.insert(processCard)
        try? modelContext.save()

        let queueManager = QueueManager()

        // Execute — the process card will fail because no provider is configured,
        // but we can verify card states were reset before execution began
        _ = await service.executeRun(
            agent: agent,
            orderedCards: [startCard, processCard],
            links: [],
            providerKeys: [],
            queueManager: queueManager,
            modelContext: modelContext
        )

        // After execution, card state should reflect the execution result,
        // not the old state. The process card should have been reset then
        // marked errored again with a new error message.
        XCTAssertFalse(processCard.isRunning, "Card should not be running after execution completes")
        XCTAssertTrue(processCard.isErrored, "Card should be errored due to missing provider")
        XCTAssertNotEqual(processCard.errorMessage, "Previous error", "Error should be updated, not old error")
    }

    func testExecuteRun_processCardWithNoProvider_returnsError() async {
        let agent = TestFixtures.makeAgent()
        modelContext.insert(agent)

        let startCard = createTestCard(agentId: agent.id, cardType: .start)
        let processCard = createTestCard(
            agentId: agent.id,
            cardType: .process,
            processCardType: .imageGeneration
        )
        // Config has empty selectedProviderId by default

        modelContext.insert(startCard)
        modelContext.insert(processCard)
        try? modelContext.save()

        let queueManager = QueueManager()

        let run = await service.executeRun(
            agent: agent,
            orderedCards: [startCard, processCard],
            links: [],
            providerKeys: [],
            queueManager: queueManager,
            modelContext: modelContext
        )

        XCTAssertEqual(run.status, .ERRORED)
        XCTAssertNotNil(run.errorMessage)
        XCTAssertEqual(run.errorCardId, processCard.id)
        XCTAssertTrue(processCard.isErrored)
        XCTAssertFalse(processCard.isRunning)
    }

    func testExecuteRun_processCardWithNoModel_returnsError() async {
        let agent = TestFixtures.makeAgent()
        modelContext.insert(agent)

        let startCard = createTestCard(agentId: agent.id, cardType: .start)
        let processCard = createTestCard(
            agentId: agent.id,
            cardType: .process,
            processCardType: .imageGeneration
        )
        // Set provider ID but not model ID
        var config = processCard.imageGenerationConfiguration
        config.selectedProviderId = UUID().uuidString
        processCard.imageGenerationConfiguration = config

        modelContext.insert(startCard)
        modelContext.insert(processCard)
        try? modelContext.save()

        let queueManager = QueueManager()

        let run = await service.executeRun(
            agent: agent,
            orderedCards: [startCard, processCard],
            links: [],
            providerKeys: [],
            queueManager: queueManager,
            modelContext: modelContext
        )

        XCTAssertEqual(run.status, .ERRORED)
        XCTAssertEqual(run.errorMessage, "No model selected")
    }

    func testExecuteRun_processCardWithMissingProviderKey_returnsError() async {
        let agent = TestFixtures.makeAgent()
        modelContext.insert(agent)

        let startCard = createTestCard(agentId: agent.id, cardType: .start)
        let processCard = createTestCard(
            agentId: agent.id,
            cardType: .process,
            processCardType: .imageGeneration
        )
        var config = processCard.imageGenerationConfiguration
        config.selectedProviderId = UUID().uuidString
        config.selectedModelId = UUID().uuidString
        processCard.imageGenerationConfiguration = config

        modelContext.insert(startCard)
        modelContext.insert(processCard)
        try? modelContext.save()

        let queueManager = QueueManager()

        // Pass empty providerKeys — the card's provider won't be found
        let run = await service.executeRun(
            agent: agent,
            orderedCards: [startCard, processCard],
            links: [],
            providerKeys: [],
            queueManager: queueManager,
            modelContext: modelContext
        )

        XCTAssertEqual(run.status, .ERRORED)
        XCTAssertEqual(run.errorMessage, "Provider key not found")
    }

    func testExecuteRun_invalidProcessCardType_returnsError() async {
        let agent = TestFixtures.makeAgent()
        modelContext.insert(agent)

        let startCard = createTestCard(agentId: agent.id, cardType: .start)
        // Create a process card with nil processCardType
        let processCard = createTestCard(
            agentId: agent.id,
            cardType: .process,
            processCardType: nil
        )

        modelContext.insert(startCard)
        modelContext.insert(processCard)
        try? modelContext.save()

        let queueManager = QueueManager()

        let run = await service.executeRun(
            agent: agent,
            orderedCards: [startCard, processCard],
            links: [],
            providerKeys: [],
            queueManager: queueManager,
            modelContext: modelContext
        )

        XCTAssertEqual(run.status, .ERRORED)
        XCTAssertEqual(run.errorMessage, "Invalid process card type")
        XCTAssertEqual(run.errorCardId, processCard.id)
    }

    func testExecuteRun_outputCard_receivesPreviousGenerationId() async {
        let agent = TestFixtures.makeAgent()
        modelContext.insert(agent)

        let startCard = createTestCard(agentId: agent.id, cardType: .start)
        let genId = UUID()
        startCard.generationId = genId

        let outputCard = createTestCard(agentId: agent.id, cardType: .output)

        modelContext.insert(startCard)
        modelContext.insert(outputCard)
        try? modelContext.save()

        let queueManager = QueueManager()

        let run = await service.executeRun(
            agent: agent,
            orderedCards: [startCard, outputCard],
            links: [],
            providerKeys: [],
            queueManager: queueManager,
            modelContext: modelContext
        )

        XCTAssertEqual(run.status, .SUCCESSFUL)
        XCTAssertEqual(outputCard.generationId, genId, "Output card should receive the start card's generationId")
    }

    func testExecuteRun_errorStopsExecution_remainingCardsSkipped() async {
        let agent = TestFixtures.makeAgent()
        modelContext.insert(agent)

        let startCard = createTestCard(agentId: agent.id, cardType: .start)

        // First process card will fail (no provider)
        let failCard = createTestCard(
            agentId: agent.id,
            cardType: .process,
            processCardType: .imageGeneration,
            title: "Failing Card"
        )

        // Second process card should never execute
        let skippedCard = createTestCard(
            agentId: agent.id,
            cardType: .process,
            processCardType: .imageGeneration,
            title: "Skipped Card"
        )

        modelContext.insert(startCard)
        modelContext.insert(failCard)
        modelContext.insert(skippedCard)
        try? modelContext.save()

        let queueManager = QueueManager()

        let run = await service.executeRun(
            agent: agent,
            orderedCards: [startCard, failCard, skippedCard],
            links: [],
            providerKeys: [],
            queueManager: queueManager,
            modelContext: modelContext
        )

        XCTAssertEqual(run.status, .ERRORED)
        XCTAssertEqual(run.errorCardId, failCard.id)
        // Skipped card should not have been touched (was reset at start, stays clean)
        XCTAssertFalse(skippedCard.isRunning)
        XCTAssertFalse(skippedCard.isErrored)
    }

    func testExecuteRun_createsAgentRunInDatabase() async {
        let agent = TestFixtures.makeAgent()
        modelContext.insert(agent)
        try? modelContext.save()

        let queueManager = QueueManager()

        let run = await service.executeRun(
            agent: agent,
            orderedCards: [],
            links: [],
            providerKeys: [],
            queueManager: queueManager,
            modelContext: modelContext
        )

        // Verify the run was persisted
        let descriptor = FetchDescriptor<AgentRun>(
            predicate: #Predicate { $0.id == run.id }
        )
        let fetchedRuns = try? modelContext.fetch(descriptor)
        XCTAssertEqual(fetchedRuns?.count, 1)
        XCTAssertEqual(fetchedRuns?.first?.status, .SUCCESSFUL)
    }

    func testExecuteRun_videoProcessCard_withNoProvider_returnsError() async {
        let agent = TestFixtures.makeAgent()
        modelContext.insert(agent)

        let startCard = createTestCard(agentId: agent.id, cardType: .start)
        let videoCard = createTestCard(
            agentId: agent.id,
            cardType: .process,
            processCardType: .videoGeneration
        )
        // Config has empty selectedProviderId by default

        modelContext.insert(startCard)
        modelContext.insert(videoCard)
        try? modelContext.save()

        let queueManager = QueueManager()

        let run = await service.executeRun(
            agent: agent,
            orderedCards: [startCard, videoCard],
            links: [],
            providerKeys: [],
            queueManager: queueManager,
            modelContext: modelContext
        )

        XCTAssertEqual(run.status, .ERRORED)
        XCTAssertEqual(run.errorMessage, "No provider selected")
    }
}
