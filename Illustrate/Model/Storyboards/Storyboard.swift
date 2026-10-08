// MARK: - Storyboard.swift

// Defines the Storyboard model for multi-scene movie creation.
//
// Storyboards enable users to create longer-form video content by chaining
// multiple video generations together. Each storyboard has a fixed configuration
// (model, dimensions, duration) that applies to all scenes.
//
// ## Storyboard Modes
// - **Auto-extend**: Each scene extends from the previous video using extend models
// - **Frame-based**: Each scene uses first/last frame images for continuity
//
// ## Structure
// Each Storyboard contains:
// - StoryboardScenes: Individual video scenes in sequence
// - StoryboardAssets: Reference images for frame-based generation

import SwiftData
import SwiftUI

// MARK: - Storyboard Mode

/// Defines how scenes in a storyboard connect to each other.
///
/// The mode determines which models are available and how
/// scene continuity is achieved:
/// - `.AUTO_EXTEND`: Uses video extend APIs (Veo, Sora)
/// - `.FRAME_BASED`: Uses first/last frame images (Seedance, etc.)
enum StoryboardMode: String, Codable, CaseIterable, Identifiable {
    var id: String {
        rawValue
    }

    /// Extends each scene from the previous video using extend models
    case AUTO_EXTEND

    /// Uses first/last frame images for scene continuity
    case FRAME_BASED

    // MARK: - Backward Compatible Decoding

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "autoExtend", "AUTO_EXTEND": self = .AUTO_EXTEND
        case "frameBased", "FRAME_BASED": self = .FRAME_BASED
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown StoryboardMode: \(rawValue)"
                )
            )
        }
    }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .AUTO_EXTEND: "Auto Extend"
        case .FRAME_BASED: "Frame Based"
        }
    }

    /// Description for UI tooltips
    var description: String {
        switch self {
        case .AUTO_EXTEND:
            "Each scene automatically extends from the previous video"
        case .FRAME_BASED:
            "Use reference images as first/last frames for each scene"
        }
    }

    /// SF Symbol icon
    var icon: String {
        switch self {
        case .AUTO_EXTEND: "arrow.right.circle"
        case .FRAME_BASED: "photo.on.rectangle"
        }
    }
}

// MARK: - Storyboard Model

/// SwiftData model representing a multi-scene movie project.
///
/// A Storyboard is a container for sequential video scenes that together
/// form a longer video. The configuration (model, dimensions, etc.) is
/// set at creation and applies to all scenes.
///
/// ## Configuration
/// - `mode`: How scenes connect (auto-extend vs frame-based)
/// - `modelId`: The video generation model to use
/// - `dimensions`: Video dimensions (e.g., "1920x1080")
/// - `sceneDuration`: Duration of each scene in seconds
/// - `resolution`: Resolution tier (e.g., "1080p")
@Model
class Storyboard: Identifiable, Codable, Pinnable {
    #Index<Storyboard>([\.projectId])

    enum CodingKeys: CodingKey {
        case id
        case projectId
        case createdAt
        case name
        case isPinned
        case mode
        case modelId
        case providerId
        case dimensions
        case sceneDuration
        case resolution
    }

    var id = UUID()

    var projectId: UUID = Project.defaultProjectId

    var project: Project?

    var createdAt = Date()

    var name = "Untitled Storyboard"

    var isPinned = false

    // MARK: Configuration

    /// How scenes connect to each other
    var mode = StoryboardMode.AUTO_EXTEND

    /// The video generation model ID to use
    var modelId = ""

    /// The provider ID for the selected model
    var providerId = ""

    /// Video dimensions (e.g., "1920x1080")
    var dimensions = "1920x1080"

    /// Duration of each scene in seconds
    var sceneDuration = 8.0

    /// Resolution tier (e.g., "1080p", "720p")
    var resolution = "1080p"

    // MARK: Relationships

    @Relationship(deleteRule: .cascade, inverse: \StoryboardScene.storyboard)
    var scenes: [StoryboardScene]? = nil

    @Relationship(deleteRule: .cascade, inverse: \StoryboardAsset.storyboard)
    var assets: [StoryboardAsset]? = nil

    /// Creates a new storyboard with the specified configuration.
    ///
    /// - Parameters:
    ///   - name: Display name for the storyboard
    ///   - projectId: Parent project
    ///   - mode: How scenes connect
    ///   - modelId: Video generation model ID
    ///   - providerId: Provider ID for the model
    ///   - dimensions: Video dimensions
    ///   - sceneDuration: Duration per scene in seconds
    ///   - resolution: Resolution tier
    init(
        name: String = "Untitled Storyboard",
        projectId: UUID = Project.defaultProjectId,
        mode: StoryboardMode = .AUTO_EXTEND,
        modelId: String = "",
        providerId: String = "",
        dimensions: String = "1920x1080",
        sceneDuration: Double = 8.0,
        resolution: String = "1080p"
    ) {
        id = UUID()
        self.name = name
        self.projectId = projectId
        createdAt = Date()
        isPinned = false
        self.mode = mode
        self.modelId = modelId
        self.providerId = providerId
        self.dimensions = dimensions
        self.sceneDuration = sceneDuration
        self.resolution = resolution
    }

    // MARK: - Codable Implementation

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId) ?? Project.defaultProjectId
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        name = try container.decode(String.self, forKey: .name)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        mode = try container.decodeIfPresent(StoryboardMode.self, forKey: .mode) ?? .AUTO_EXTEND
        modelId = try container.decodeIfPresent(String.self, forKey: .modelId) ?? ""
        providerId = try container.decodeIfPresent(String.self, forKey: .providerId) ?? ""
        dimensions = try container.decodeIfPresent(String.self, forKey: .dimensions) ?? "1920x1080"
        sceneDuration = try container.decodeIfPresent(Double.self, forKey: .sceneDuration) ?? 8.0
        resolution = try container.decodeIfPresent(String.self, forKey: .resolution) ?? "1080p"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(name, forKey: .name)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(mode, forKey: .mode)
        try container.encode(modelId, forKey: .modelId)
        try container.encode(providerId, forKey: .providerId)
        try container.encode(dimensions, forKey: .dimensions)
        try container.encode(sceneDuration, forKey: .sceneDuration)
        try container.encode(resolution, forKey: .resolution)
    }
}
