// MARK: - PlaygroundLink.swift

// Defines visual connections between cards on the playground canvas.
//
// PlaygroundLinks visualize relationships between cards, typically showing
// parent-child relationships where one generation led to another. Unlike
// CardLinks in the agent system which define data flow, PlaygroundLinks
// are primarily visual indicators of iteration history.
//
// ## Link Purpose
// Links help users understand:
// - Which card was the starting point
// - How iterations evolved
// - The creative progression of their work
//
// ## Automatic vs Manual
// Links can be created:
// - Automatically: When generating from an existing card (parentCardId)
// - Manually: By users to show conceptual relationships
//
// ## Visual Rendering
// Links are drawn as curved Bézier paths connecting source to target,
// similar to agent card links but with simpler styling.

import SwiftData
import SwiftUI

// MARK: - Flow Canvas Link Model

/// SwiftData model representing a visual connection between playground cards.
///
/// PlaygroundLinks show relationships between cards on the canvas,
/// helping users track their creative iteration history.
///
/// ## Direction
/// Links are directional: source → target, typically meaning
/// "target was derived from source" or "target is a follow-up to source".
///
/// ## Persistence
/// Links are stored in SwiftData and synced via iCloud, preserving
/// the visual structure of playgrounds across devices.
@Model
class PlaygroundLink: Identifiable, Codable {
    #Index<PlaygroundLink>([\.flowCanvasId])

    enum CodingKeys: CodingKey {
        case id
        case flowCanvasId
        case sourceCardId
        case targetCardId
        case createdAt
    }

    var id = UUID()

    var flowCanvasId = UUID()

    var playground: Playground?

    /// Origin card (link starts here)
    var sourceCardId = UUID()

    /// Destination card (link ends here)
    var targetCardId = UUID()

    var createdAt = Date()

    /// Creates a new link between two cards.
    ///
    /// - Parameters:
    ///   - flowCanvasId: Parent playground
    ///   - sourceCardId: Origin card UUID
    ///   - targetCardId: Destination card UUID
    init(
        flowCanvasId: UUID,
        sourceCardId: UUID,
        targetCardId: UUID
    ) {
        id = UUID()
        self.flowCanvasId = flowCanvasId
        self.sourceCardId = sourceCardId
        self.targetCardId = targetCardId
        createdAt = Date()
    }

    // MARK: - Codable Implementation

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        flowCanvasId = try container.decode(UUID.self, forKey: .flowCanvasId)
        sourceCardId = try container.decode(UUID.self, forKey: .sourceCardId)
        targetCardId = try container.decode(UUID.self, forKey: .targetCardId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(flowCanvasId, forKey: .flowCanvasId)
        try container.encode(sourceCardId, forKey: .sourceCardId)
        try container.encode(targetCardId, forKey: .targetCardId)
        try container.encode(createdAt, forKey: .createdAt)
    }
}
