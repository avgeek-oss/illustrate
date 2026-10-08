// MARK: - Agent.swift

// Defines the Agent model for visual workflow automation on the infinite canvas.
//
// Agents are the core concept of Illustrate's workflow system. An Agent represents
// a reusable image/video generation pipeline that users build visually by connecting
// cards on an infinite canvas.
//
// ## Agent Workflow System
// The agent system enables:
// - Visual workflow building with drag-and-drop cards
// - Connecting generation steps in sequences or branches
// - Reusing workflows with different inputs
// - Batch processing through agent runs
//
// ## Architecture
// An Agent contains:
// - AgentCards: Individual processing nodes (start, generate, output)
// - CardLinks: Connections between cards defining data flow
// - AgentRuns: Execution instances tracking workflow progress
//
// ## Canvas State
// The Agent model stores the user's canvas viewport state (zoom, pan position)
// so users return to their previous view when reopening an agent.

import SwiftData
import SwiftUI

// MARK: - Agent Model

/// SwiftData model representing a visual generation workflow.
///
/// An Agent is a container for a directed graph of AgentCards connected by CardLinks.
/// Users build agents visually on an infinite canvas, then execute them to generate
/// content based on the defined workflow.
///
/// ## Workflow Structure
/// Each agent has at minimum:
/// - A Start card (input node accepting text/image)
/// - One or more Process cards (image/video generation)
/// - Optional Output cards (workflow endpoints)
///
/// ## Canvas Viewport State
/// The model persists canvas state so users return to their previous view:
/// - `canvasScale`: Zoom level (1.0 = 100%)
/// - `canvasOffsetX/Y`: Pan offset from origin
/// - `isLocked`: Prevents accidental modifications
@Model
class Agent: Identifiable, Codable, Pinnable {
    #Index<Agent>([\.projectId])

    enum CodingKeys: CodingKey {
        case id
        case projectId
        case createdAt
        case name
        case canvasScale
        case canvasOffsetX
        case canvasOffsetY
        case isLocked
        case isPinned
    }

    var id = UUID()

    var projectId: UUID = Project.defaultProjectId

    var project: Project?

    var createdAt = Date()

    var name = "Untitled Agent"

    // MARK: Canvas State

    var canvasScale = 1.0

    var canvasOffsetX = 0.0

    var canvasOffsetY = 0.0

    var isLocked = false

    var isPinned = false

    // MARK: Relationships

    @Relationship(deleteRule: .cascade, inverse: \AgentCard.agent)
    var cards: [AgentCard]? = nil

    @Relationship(deleteRule: .cascade, inverse: \CardLink.agent)
    var links: [CardLink]? = nil

    @Relationship(deleteRule: .cascade, inverse: \AgentRun.agent)
    var runs: [AgentRun]? = nil

    /// Creates a new agent with default canvas settings.
    ///
    /// - Parameters:
    ///   - name: Display name for the agent
    ///   - projectId: Project to associate with
    init(name: String = "Untitled Agent", projectId: UUID = Project.defaultProjectId) {
        id = UUID()
        self.name = name
        self.projectId = projectId
        createdAt = Date()
        canvasScale = 1.0
        canvasOffsetX = 0.0
        canvasOffsetY = 0.0
        isLocked = false
        isPinned = false
    }

    // MARK: - Codable Implementation

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId) ?? Project.defaultProjectId
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        name = try container.decode(String.self, forKey: .name)
        canvasScale = try container.decodeIfPresent(Double.self, forKey: .canvasScale) ?? 1.0
        canvasOffsetX = try container.decodeIfPresent(Double.self, forKey: .canvasOffsetX) ?? 0.0
        canvasOffsetY = try container.decodeIfPresent(Double.self, forKey: .canvasOffsetY) ?? 0.0
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(name, forKey: .name)
        try container.encode(canvasScale, forKey: .canvasScale)
        try container.encode(canvasOffsetX, forKey: .canvasOffsetX)
        try container.encode(canvasOffsetY, forKey: .canvasOffsetY)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encode(isPinned, forKey: .isPinned)
    }
}

// MARK: - Agent Factory Methods

extension Agent {
    /// Creates a new agent with a default Start card and input generation.
    ///
    /// This is the primary factory method for creating agents. It sets up:
    /// 1. The Agent entity
    /// 2. A Start card at the canvas origin
    /// 3. A placeholder Generation for the start card's input
    ///
    /// The Start card and its associated Generation allow the agent to accept
    /// input (text or image) which flows through the workflow.
    ///
    /// - Parameters:
    ///   - name: Display name for the agent
    ///   - projectId: Project to associate with
    ///   - modelContext: SwiftData context for persistence
    /// - Returns: The created Agent instance
    @discardableResult
    static func createWithDefaultCard(
        name: String,
        projectId: UUID,
        modelContext: ModelContext
    ) -> Agent {
        // Create the agent entity
        let agent = Agent(name: name, projectId: projectId)
        modelContext.insert(agent)

        // Create the default Start card at origin
        let startCard = AgentCard.createDefault(agentId: agent.id, position: .zero)
        modelContext.insert(startCard)

        // Create a placeholder generation for the start card's input
        // This will be populated when the user provides input
        let inputGeneration = Generation(
            id: UUID(),
            setId: UUID(),
            projectId: projectId,
            modelId: "",
            prompt: "",
            promptEnhanceOpted: false,
            promptAfterEnhance: "",
            style: "",
            variant: "",
            quality: "",
            dimensions: "",
            size: 0,
            creditUsed: 0,
            status: .GENERATED,
            colorPalette: [],
            contentType: .IMAGE_2D
        )
        inputGeneration.isHidden = true
        inputGeneration.agentId = agent.id
        modelContext.insert(inputGeneration)

        // Link the start card to its input generation
        startCard.generationId = inputGeneration.id

        return agent
    }
}
