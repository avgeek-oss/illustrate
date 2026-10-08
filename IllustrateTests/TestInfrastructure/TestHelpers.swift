// MARK: - TestHelpers.swift

// Shared test infrastructure for Illustrate tests.
//
// Provides:
// - In-memory SwiftData ModelContainer for isolated DB testing
// - Factory methods for creating test model instances
// - MockURLProtocol for deterministic network testing
//
// ## Usage
// All test files should use these helpers rather than creating
// their own model instances to ensure consistency and reduce
// boilerplate.

import CoreGraphics
import Foundation
import IllustrateProviders
import SwiftData
@testable import Illustrate

// MARK: - In-Memory SwiftData Container

/// Creates an in-memory SwiftData ModelContainer for testing.
///
/// Uses the same schema as the production app but stores data
/// only in memory, ensuring test isolation and fast execution.
@MainActor
func makeTestModelContainer() throws -> ModelContainer {
    let schema = Schema([
        Provider.self,
        ProviderKey.self,
        ProviderModel.self,
        Generation.self,
        ImageSet.self,
        Project.self,
        BrandKit.self,
        Agent.self,
        AgentCard.self,
        CardLink.self,
        AgentRun.self,
        FailedRequest.self,
        Playground.self,
        PlaygroundCard.self,
        PlaygroundLink.self,
        ChatThread.self,
        ChatMessage.self,
        RealtimeEditSession.self,
        RealtimeEditLayer.self,
        CreativeStudio.self,
        CreativeStudioItem.self,
        Storyboard.self,
        StoryboardScene.self,
        StoryboardAsset.self,
        BulkSession.self,
        BulkSessionItem.self,
        BulkEditSession.self,
        BulkEditItem.self,
        ProductPhotoshoot.self,
        ProductPhotoshootItem.self,
        PromptGalleryItem.self,
        ProductGalleryItem.self,
    ])

    let config = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: true,
        allowsSave: true,
        cloudKitDatabase: .none
    )

    return try ModelContainer(for: schema, configurations: [config])
}

// MARK: - Test Fixtures

/// Factory methods for creating test model instances with sensible defaults.
///
/// Each method creates a minimal valid instance. Override specific
/// properties after creation when testing edge cases.
enum TestFixtures {
    // MARK: - Project

    static func makeProject(
        name: String = "Test Project",
        isDefault: Bool = false
    ) -> Project {
        Project(name: name, isDefault: isDefault)
    }

    static func makeDefaultProject() -> Project {
        Project.createDefault()
    }

    // MARK: - Generation

    static func makeGeneration(
        id: UUID = UUID(),
        setId: UUID = UUID(),
        projectId: UUID = Project.defaultProjectId,
        modelId: String = "test-model-id",
        prompt: String = "A test prompt",
        contentType: EnumGenerationContentType = .IMAGE_2D,
        status: IllustrateProviders.EnumGenerationStatus = .GENERATED,
        isHidden: Bool = false
    ) -> Generation {
        let gen = Generation(
            id: id,
            setId: setId,
            projectId: projectId,
            modelId: modelId,
            prompt: prompt,
            promptEnhanceOpted: false,
            promptAfterEnhance: "",
            dimensions: "1024x1024",
            size: 1024,
            creditUsed: 0.0,
            status: status,
            colorPalette: [],
            contentType: contentType
        )
        gen.isHidden = isHidden
        return gen
    }

    // MARK: - ImageSet

    static func makeImageSet(
        projectId: UUID = Project.defaultProjectId,
        prompt: String = "A test prompt",
        modelId: String = "test-model-id"
    ) -> ImageSet {
        ImageSet(
            prompt: prompt,
            projectId: projectId,
            modelId: modelId,
            dimensions: "1024x1024",
            setType: .IMAGE_GENERATE
        )
    }

    // MARK: - ProviderKey

    static func makeProviderKey(
        providerId: UUID = UUID(),
        projectId: UUID = Project.defaultProjectId
    ) -> ProviderKey {
        ProviderKey(providerId: providerId, projectId: projectId)
    }

    // MARK: - Agent

    static func makeAgent(
        name: String = "Test Agent",
        projectId: UUID = Project.defaultProjectId
    ) -> Agent {
        Agent(name: name, projectId: projectId)
    }

    // MARK: - AgentCard

    static func makeAgentCard(
        agentId: UUID,
        cardType: CardType = .process,
        processCardType: ProcessCardType? = .imageGeneration,
        position: CGPoint = .zero,
        title: String = "Test Card"
    ) -> AgentCard {
        AgentCard(
            agentId: agentId,
            cardType: cardType,
            processCardType: processCardType,
            position: position,
            title: title
        )
    }

    static func makeStartCard(agentId: UUID) -> AgentCard {
        AgentCard.createDefault(agentId: agentId)
    }

    static func makeOutputCard(agentId: UUID) -> AgentCard {
        AgentCard.createOutputCard(agentId: agentId)
    }

    // MARK: - CardLink

    static func makeCardLink(
        agentId: UUID,
        sourceCardId: UUID,
        targetCardId: UUID
    ) -> CardLink {
        CardLink(
            agentId: agentId,
            sourceCardId: sourceCardId,
            targetCardId: targetCardId
        )
    }

    // MARK: - AgentRun

    static func makeAgentRun(
        agentId: UUID,
        projectId: UUID = Project.defaultProjectId
    ) -> AgentRun {
        AgentRun(agentId: agentId, projectId: projectId)
    }

    // MARK: - FailedRequest

    static func makeFailedRequest(
        projectId: UUID = Project.defaultProjectId,
        prompt: String = "Failed prompt",
        modelId: String = "test-model",
        errorMessage: String = "Test error"
    ) -> FailedRequest {
        FailedRequest(
            projectId: projectId,
            prompt: prompt,
            modelId: modelId,
            errorMessage: errorMessage
        )
    }

    // MARK: - BulkSession

    static func makeBulkSession(
        name: String = "Test Session",
        projectId: UUID = Project.defaultProjectId
    ) -> BulkSession {
        BulkSession(name: name, projectId: projectId)
    }

    // MARK: - BrandKit

    static func makeBrandKit(
        projectId: UUID = Project.defaultProjectId
    ) -> BrandKit {
        BrandKit(projectId: projectId)
    }

    // MARK: - ChatThread

    static func makeChatThread(
        name: String = "Test Thread",
        projectId: UUID = Project.defaultProjectId
    ) -> ChatThread {
        ChatThread(name: name, projectId: projectId)
    }

    // MARK: - Playground

    static func makePlayground(
        name: String = "Test Playground",
        projectId: UUID = Project.defaultProjectId
    ) -> Playground {
        Playground(name: name, projectId: projectId)
    }

    // MARK: - Storyboard

    static func makeStoryboard(
        name: String = "Test Storyboard",
        projectId: UUID = Project.defaultProjectId
    ) -> Storyboard {
        Storyboard(name: name, projectId: projectId)
    }

    // MARK: - RealtimeEditSession

    static func makeRealtimeEditSession(
        name: String = "Test Edit",
        projectId: UUID = Project.defaultProjectId
    ) -> RealtimeEditSession {
        RealtimeEditSession(name: name, projectId: projectId)
    }

    // MARK: - CreativeStudio

    static func makeCreativeStudio(
        projectId: UUID = Project.defaultProjectId
    ) -> CreativeStudio {
        CreativeStudio(projectId: projectId)
    }

    // MARK: - ProductPhotoshoot

    static func makeProductPhotoshoot(
        name: String = "Test Photoshoot",
        projectId: UUID = Project.defaultProjectId
    ) -> ProductPhotoshoot {
        ProductPhotoshoot(name: name, projectId: projectId)
    }
}

// MARK: - MockURLProtocol

/// URLProtocol subclass for intercepting network requests in tests.
///
/// Usage:
/// ```swift
/// MockURLProtocol.requestHandler = { request in
///     let response = HTTPURLResponse(
///         url: request.url!, statusCode: 200,
///         httpVersion: nil, headerFields: nil
///     )!
///     return (response, someData)
/// }
/// ```
///
/// Register with a URLSession configuration:
/// ```swift
/// let config = URLSessionConfiguration.ephemeral
/// config.protocolClasses = [MockURLProtocol.self]
/// let session = URLSession(configuration: config)
/// ```
class MockURLProtocol: URLProtocol {
    /// Handler that returns (response, data) for each intercepted request.
    /// Set this before making requests in your test.
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    /// Tracks all requests made during the test for assertion purposes.
    static var requestLog: [URLRequest] = []

    /// Resets the protocol state between tests.
    static func reset() {
        requestHandler = nil
        requestLog = []
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        MockURLProtocol.requestLog.append(request)

        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
