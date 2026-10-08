// MARK: - CardLink.swift

// Defines connections between cards in agent workflows.
//
// CardLinks represent the directed edges in an agent's workflow graph.
// Each link connects a source card (output) to a target card (input),
// defining how data flows through the workflow during execution.
//
// ## Graph Structure
// - Agents form directed acyclic graphs (DAGs)
// - Links always flow from source to target
// - A card can have multiple incoming and outgoing links
// - The graph must not contain cycles
//
// ## Visual Representation
// On the canvas, links are rendered as curved lines with arrows,
// drawn by ConnectionComponents.swift. Users create links by dragging
// from a card's output handle to another card's input handle.
//
// ## Execution Flow
// During agent runs (AgentRunService/AgentGraphService):
// 1. The graph is traversed starting from Start cards
// 2. Links determine which cards receive which outputs
// 3. Multiple links from one source means the output goes to all targets

import SwiftData
import SwiftUI

// MARK: - Card Link Model

/// SwiftData model representing a connection between two agent cards.
///
/// CardLinks are the edges in the agent workflow graph. Each link connects
/// a source card's output to a target card's input, enabling data to flow
/// from one processing step to the next.
///
/// ## Direction
/// Links are directional: data flows from `sourceCardId` to `targetCardId`.
/// The source card's output (typically a generated image or text) becomes
/// available as input to the target card.
///
/// ## Visualization
/// Links are rendered on the canvas as curved Bézier paths with direction
/// indicators. The visual connection helps users understand data flow.
@Model
class CardLink: Identifiable, Codable {
    #Index<CardLink>([\.agentId])

    enum CodingKeys: CodingKey {
        case id
        case agentId
        case sourceCardId
        case targetCardId
        case createdAt
    }

    var id = UUID()

    var agentId = UUID()

    var agent: Agent?

    /// Card that provides data (link origin)
    var sourceCardId = UUID()

    /// Card that receives data (link destination)
    var targetCardId = UUID()

    var createdAt = Date()

    /// Creates a new connection between two cards.
    ///
    /// - Parameters:
    ///   - agentId: Parent agent UUID
    ///   - sourceCardId: Output card UUID (data source)
    ///   - targetCardId: Input card UUID (data destination)
    init(
        agentId: UUID,
        sourceCardId: UUID,
        targetCardId: UUID
    ) {
        id = UUID()
        self.agentId = agentId
        self.sourceCardId = sourceCardId
        self.targetCardId = targetCardId
        createdAt = Date()
    }

    // MARK: - Codable Implementation

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        agentId = try container.decode(UUID.self, forKey: .agentId)
        sourceCardId = try container.decode(UUID.self, forKey: .sourceCardId)
        targetCardId = try container.decode(UUID.self, forKey: .targetCardId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(agentId, forKey: .agentId)
        try container.encode(sourceCardId, forKey: .sourceCardId)
        try container.encode(targetCardId, forKey: .targetCardId)
        try container.encode(createdAt, forKey: .createdAt)
    }
}
