// MARK: - PlaygroundCard.swift

// Defines the card system for interactive playground canvas.
//
// PlaygroundCards represent individual generations on the playground canvas.
// Unlike AgentCards which are workflow nodes, PlaygroundCards focus on
// displaying generation results with simple visual connections.
//
// ## Flow Canvas Card vs Agent Card
// - **AgentCard**: Workflow configuration node (what to generate)
// - **PlaygroundCard**: Result display card (what was generated)
//
// ## Card Lifecycle
// 1. Card created with status `.processing`
// 2. Generation request sent to API
// 3. On success: status → `.generated`, generationId set
// 4. On failure: status → `.failed`, errorMessage set
//
// ## Parent-Child Relationships
// Cards can have a parent card (`parentCardId`), indicating:
// - The child was generated as a follow-up to the parent
// - Visual links are drawn between parent and child
// - Useful for iteration chains

import SwiftData
import SwiftUI

// MARK: - Flow Canvas Card Status

/// Tracks the generation state of a Flow Canvas card.
///
/// Used to display appropriate UI:
/// - `.PROCESSING`: Show loading indicator
/// - `.GENERATED`: Show the generated content
/// - `.FAILED`: Show error message
enum PlaygroundCardStatus: String, Codable {
    case PROCESSING
    case GENERATED
    case FAILED

    // MARK: - Backward Compatible Decoding

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "processing", "PROCESSING": self = .PROCESSING
        case "generated", "GENERATED": self = .GENERATED
        case "failed", "FAILED": self = .FAILED
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown PlaygroundCardStatus: \(rawValue)"
                )
            )
        }
    }
}

// MARK: - Flow Canvas Card Type

/// Specifies whether the card contains an image or video.
///
/// Determines:
/// - How content is displayed (image view vs video player)
/// - Which configuration type is used
/// - Icon and label in UI
enum PlaygroundCardType: String, Codable, CaseIterable, Identifiable {
    var id: String {
        rawValue
    }

    /// Card displays a generated image
    case IMAGE
    /// Card displays a generated video
    case VIDEO

    /// Human-readable name for UI display
    var displayName: String {
        switch self {
        case .IMAGE: "Image"
        case .VIDEO: "Video"
        }
    }

    /// SF Symbol icon name
    var icon: String {
        switch self {
        case .IMAGE: "photo.fill"
        case .VIDEO: "video.fill"
        }
    }

    // MARK: - Backward Compatible Decoding

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "image", "IMAGE": self = .IMAGE
        case "video", "VIDEO": self = .VIDEO
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown PlaygroundCardType: \(rawValue)"
                )
            )
        }
    }
}

// MARK: - Flow Canvas Card Model

/// SwiftData model representing a generation result on the playground canvas.
///
/// PlaygroundCards are the visual elements on a playground, each showing
/// a generated image or video. They support parent-child relationships
/// for tracking iteration chains.
///
/// ## Queue Integration
/// The `queueItemId` links to the generation queue system, allowing
/// the UI to track progress and update status when generation completes.
///
/// ## Configuration Reuse
/// PlaygroundCards reuse the ImageGenerationConfiguration and
/// VideoGenerationConfiguration structs from AgentCard, accessed
/// via the same computed property pattern.
@Model
class PlaygroundCard: Identifiable, Codable {
    #Index<PlaygroundCard>([\.flowCanvasId])

    enum CodingKeys: CodingKey {
        case id
        case flowCanvasId
        case cardType
        case status
        case positionX
        case positionY
        case createdAt
        case parentCardId
        case generationId
        case errorMessage
        case configurationData
        case queueItemId
    }

    var id = UUID()

    var flowCanvasId = UUID()

    var playground: Playground?

    /// Whether this is an image or video card
    var cardType = PlaygroundCardType.IMAGE

    var status = PlaygroundCardStatus.PROCESSING

    /// X position on the canvas
    var positionX: CGFloat = 0

    /// Y position on the canvas
    var positionY: CGFloat = 0

    var createdAt = Date()

    /// Parent card this was derived from (for iteration chains)
    var parentCardId: UUID?

    var generationId: UUID?

    var errorMessage: String?

    var configurationData: Data?

    var queueItemId: UUID?

    /// Convenient CGPoint access to card position.
    var position: CGPoint {
        get { CGPoint(x: positionX, y: positionY) }
        set {
            positionX = newValue.x
            positionY = newValue.y
        }
    }

    init(
        flowCanvasId: UUID,
        cardType: PlaygroundCardType,
        position: CGPoint = .zero,
        parentCardId: UUID? = nil
    ) {
        id = UUID()
        self.flowCanvasId = flowCanvasId
        self.cardType = cardType
        status = .PROCESSING
        positionX = position.x
        positionY = position.y
        createdAt = Date()
        self.parentCardId = parentCardId
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        flowCanvasId = try container.decode(UUID.self, forKey: .flowCanvasId)
        cardType = try container.decode(PlaygroundCardType.self, forKey: .cardType)
        status = try container.decode(PlaygroundCardStatus.self, forKey: .status)
        positionX = try container.decode(CGFloat.self, forKey: .positionX)
        positionY = try container.decode(CGFloat.self, forKey: .positionY)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        parentCardId = try container.decodeIfPresent(UUID.self, forKey: .parentCardId)
        generationId = try container.decodeIfPresent(UUID.self, forKey: .generationId)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        configurationData = try container.decodeIfPresent(Data.self, forKey: .configurationData)
        queueItemId = try container.decodeIfPresent(UUID.self, forKey: .queueItemId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(flowCanvasId, forKey: .flowCanvasId)
        try container.encode(cardType, forKey: .cardType)
        try container.encode(status, forKey: .status)
        try container.encode(positionX, forKey: .positionX)
        try container.encode(positionY, forKey: .positionY)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(parentCardId, forKey: .parentCardId)
        try container.encodeIfPresent(generationId, forKey: .generationId)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try container.encodeIfPresent(configurationData, forKey: .configurationData)
        try container.encodeIfPresent(queueItemId, forKey: .queueItemId)
    }

    // MARK: - Configuration Accessors

    /// Typed access to image generation configuration.
    ///
    /// Reuses the ImageGenerationConfiguration struct from AgentCard.
    /// Decodes from configurationData JSON, returns default if unavailable.
    var imageGenerationConfiguration: ImageGenerationConfiguration {
        get {
            guard let data = configurationData else { return ImageGenerationConfiguration() }
            do {
                return try JSONDecoder().decode(ImageGenerationConfiguration.self, from: data)
            } catch {
                AppLogger.data
                    .error("Failed to decode PlaygroundCard ImageGenerationConfiguration: \(error, privacy: .public)")
                return ImageGenerationConfiguration()
            }
        }
        set {
            do {
                configurationData = try JSONEncoder().encode(newValue)
            } catch {
                configurationData = nil
                AppLogger.data
                    .error("Failed to encode PlaygroundCard ImageGenerationConfiguration: \(error, privacy: .public)")
            }
        }
    }

    /// Typed access to video generation configuration.
    ///
    /// Reuses the VideoGenerationConfiguration struct from AgentCard.
    /// Decodes from configurationData JSON, returns default if unavailable.
    var videoGenerationConfiguration: VideoGenerationConfiguration {
        get {
            guard let data = configurationData else { return VideoGenerationConfiguration() }
            do {
                return try JSONDecoder().decode(VideoGenerationConfiguration.self, from: data)
            } catch {
                AppLogger.data
                    .error("Failed to decode PlaygroundCard VideoGenerationConfiguration: \(error, privacy: .public)")
                return VideoGenerationConfiguration()
            }
        }
        set {
            do {
                configurationData = try JSONEncoder().encode(newValue)
            } catch {
                configurationData = nil
                AppLogger.data
                    .error("Failed to encode PlaygroundCard VideoGenerationConfiguration: \(error, privacy: .public)")
            }
        }
    }
}

// MARK: - CanvasPositionable Conformance

/// Enables PlaygroundCard to work with generic canvas positioning code.
/// The CanvasPositionable protocol provides a standard interface for
/// elements that can be positioned and moved on an infinite canvas.
extension PlaygroundCard: CanvasPositionable {}
