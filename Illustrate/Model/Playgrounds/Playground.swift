// MARK: - Playground.swift

// Defines the Flow Canvas model for interactive canvas-based generation.
//
// Flow Canvas are a simpler, more interactive alternative to Agents.
// While Agents are workflow-oriented (build once, run many times),
// Flow Canvas are exploration-oriented (quick iterations, visual results).
//
// ## Flow Canvas vs Agent Builder
// - **Agents**: Complex workflows with configurations, designed for reuse
// - **Flow Canvas**: Quick experimentation with immediate visual feedback
//
// ## Interactive Canvas
// Flow Canvas use the same infinite canvas system as Agents but with
// a simpler card model focused on rapid generation and iteration.
//
// ## Canvas State
// Like Agents, Flow Canvas persist canvas viewport state (zoom, pan)
// so users return to their previous view.

import SwiftData
import SwiftUI

// MARK: - Flow Canvas Model

/// SwiftData model representing an interactive generation canvas.
///
/// Flow Canvas provide a free-form canvas for quick experimentation.
/// Users can generate content, see results immediately, and iterate
/// by creating variations or follow-up generations.
///
/// ## Structure
/// Each Flow Canvas contains:
/// - PlaygroundCards: Generation outputs positioned on canvas
/// - PlaygroundLinks: Visual connections showing relationships
///
/// ## Canvas State
/// Viewport state is persisted for continuity:
/// - `canvasScale`: Zoom level
/// - `canvasOffsetX/Y`: Pan position
/// - `isLocked`: Prevents accidental changes
@Model
class Playground: Identifiable, Codable, Pinnable {
    #Index<Playground>([\.projectId])

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

    var name = "Untitled Canvas"

    // MARK: Canvas State

    /// Current zoom level (1.0 = 100%)
    var canvasScale = 1.0

    /// Horizontal pan offset from origin
    var canvasOffsetX = 0.0

    /// Vertical pan offset from origin
    var canvasOffsetY = 0.0

    /// When true, prevents modifications
    var isLocked = false

    /// When true, the Flow Canvas is pinned to the top of the list
    var isPinned = false

    // MARK: Relationships

    @Relationship(deleteRule: .cascade, inverse: \PlaygroundCard.playground)
    var cards: [PlaygroundCard]? = nil

    @Relationship(deleteRule: .cascade, inverse: \PlaygroundLink.playground)
    var links: [PlaygroundLink]? = nil

    /// Creates a new Flow Canvas.
    ///
    /// - Parameters:
    ///   - name: Display name for the Flow Canvas
    ///   - projectId: Parent project
    init(name: String = "Untitled Canvas", projectId: UUID = Project.defaultProjectId) {
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
