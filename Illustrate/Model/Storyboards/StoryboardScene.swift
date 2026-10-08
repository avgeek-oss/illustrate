// MARK: - StoryboardScene.swift

// Defines individual scenes within a storyboard.
//
// Each StoryboardScene represents a single video segment in the storyboard
// timeline. Scenes are generated sequentially and can reference:
// - Previous scene (for auto-extend mode)
// - First/last frame assets (for frame-based mode)
//
// ## Scene Lifecycle
// 1. Created with status `.pending` when user adds a scene
// 2. Status → `.generating` when generation starts
// 3. Status → `.completed` on success, `generationId` set
// 4. Status → `.failed` on error, `errorMessage` set

import SwiftData
import SwiftUI

// MARK: - Scene Status

/// Tracks the generation state of a storyboard scene.
///
/// Used to display appropriate UI in the timeline:
/// - `.PENDING`: Waiting to be generated
/// - `.GENERATING`: Generation in progress (show progress ring)
/// - `.COMPLETED`: Ready to play (show thumbnail)
/// - `.FAILED`: Show error indicator
enum StoryboardSceneStatus: String, Codable, CaseIterable, Identifiable {
    var id: String {
        rawValue
    }

    /// Scene is waiting to be generated
    case PENDING

    case GENERATING

    case COMPLETED

    case FAILED

    /// SF Symbol for status indicator
    var icon: String {
        switch self {
        case .PENDING: "clock"
        case .GENERATING: "arrow.trianglehead.2.clockwise"
        case .COMPLETED: "checkmark.circle.fill"
        case .FAILED: "exclamationmark.triangle.fill"
        }
    }

    /// Color for status indicator
    var color: Color {
        switch self {
        case .PENDING: .secondary
        case .GENERATING: .blue
        case .COMPLETED: .green
        case .FAILED: .red
        }
    }

    // MARK: - Backward Compatible Decoding

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "pending", "PENDING": self = .PENDING
        case "generating", "GENERATING": self = .GENERATING
        case "completed", "COMPLETED": self = .COMPLETED
        case "failed", "FAILED": self = .FAILED
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown StoryboardSceneStatus: \(rawValue)"
                )
            )
        }
    }
}

// MARK: - Storyboard Scene Model

/// SwiftData model representing a single scene in a storyboard.
///
/// Scenes are ordered by `orderIndex` and form the timeline of a storyboard.
/// Each scene has its own prompt and can optionally reference frame images
/// for continuity in frame-based mode.
///
/// ## Generation Tracking
/// - `queueItemId`: Links to the generation queue for progress tracking
/// - `generationId`: Links to the completed Generation entity
/// - `status`: Current generation state
///
/// ## Frame-Based Mode
/// For frame-based storyboards, scenes can reference:
/// - `firstFrameAssetId`: Starting frame image
/// - `lastFrameAssetId`: Ending frame image (optional)
@Model
class StoryboardScene: Identifiable, Codable {
    #Index<StoryboardScene>([\.storyboardId])

    enum CodingKeys: CodingKey {
        case id
        case storyboardId
        case orderIndex
        case prompt
        case negativePrompt
        case status
        case generationId
        case queueItemId
        case errorMessage
        case firstFrameAssetId
        case lastFrameAssetId
        case createdAt
    }

    var id = UUID()

    var storyboardId = UUID()

    var storyboard: Storyboard?

    /// Position in the timeline (0-based)
    var orderIndex = 0

    /// Prompt describing what happens in this scene
    var prompt = ""

    /// Negative prompt (what to avoid)
    var negativePrompt: String?

    var status = StoryboardSceneStatus.PENDING

    /// UUID of the completed Generation entity
    var generationId: UUID?

    /// Queue item ID for tracking generation progress
    var queueItemId: UUID?

    /// Error message if generation failed
    var errorMessage: String?

    /// First frame reference image (for frame-based mode)
    var firstFrameAssetId: UUID?

    /// Last frame reference image (for frame-based mode)
    var lastFrameAssetId: UUID?

    var createdAt = Date()

    /// Creates a new scene for a storyboard.
    ///
    /// - Parameters:
    ///   - storyboardId: Parent storyboard
    ///   - orderIndex: Position in timeline
    ///   - prompt: Scene description
    ///   - negativePrompt: What to avoid
    ///   - firstFrameAssetId: Starting frame (frame-based mode)
    ///   - lastFrameAssetId: Ending frame (frame-based mode)
    init(
        storyboardId: UUID,
        orderIndex: Int,
        prompt: String = "",
        negativePrompt: String? = nil,
        firstFrameAssetId: UUID? = nil,
        lastFrameAssetId: UUID? = nil
    ) {
        id = UUID()
        self.storyboardId = storyboardId
        self.orderIndex = orderIndex
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        status = .PENDING
        self.firstFrameAssetId = firstFrameAssetId
        self.lastFrameAssetId = lastFrameAssetId
        createdAt = Date()
    }

    // MARK: - Codable Implementation

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        storyboardId = try container.decode(UUID.self, forKey: .storyboardId)
        orderIndex = try container.decode(Int.self, forKey: .orderIndex)
        prompt = try container.decode(String.self, forKey: .prompt)
        negativePrompt = try container.decodeIfPresent(String.self, forKey: .negativePrompt)
        status = try container.decodeIfPresent(StoryboardSceneStatus.self, forKey: .status) ?? .PENDING
        generationId = try container.decodeIfPresent(UUID.self, forKey: .generationId)
        queueItemId = try container.decodeIfPresent(UUID.self, forKey: .queueItemId)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        firstFrameAssetId = try container.decodeIfPresent(UUID.self, forKey: .firstFrameAssetId)
        lastFrameAssetId = try container.decodeIfPresent(UUID.self, forKey: .lastFrameAssetId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(storyboardId, forKey: .storyboardId)
        try container.encode(orderIndex, forKey: .orderIndex)
        try container.encode(prompt, forKey: .prompt)
        try container.encodeIfPresent(negativePrompt, forKey: .negativePrompt)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(generationId, forKey: .generationId)
        try container.encodeIfPresent(queueItemId, forKey: .queueItemId)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try container.encodeIfPresent(firstFrameAssetId, forKey: .firstFrameAssetId)
        try container.encodeIfPresent(lastFrameAssetId, forKey: .lastFrameAssetId)
        try container.encode(createdAt, forKey: .createdAt)
    }
}
