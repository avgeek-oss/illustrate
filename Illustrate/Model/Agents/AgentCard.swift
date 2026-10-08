// MARK: - AgentCard.swift

// Defines the card system for agent workflows on the infinite canvas.
//
// AgentCards are the building blocks of agent workflows. Each card represents
// a node in the generation pipeline: accepting input, performing generation,
// or marking outputs. Cards are connected via CardLinks to define data flow.
//
// ## Card Types
// - **Start**: Entry point accepting text or image input
// - **Process**: Generation nodes (image or video generation)
// - **Output**: Terminal nodes marking workflow endpoints
//
// ## Configuration System
// Each card type has a specific configuration struct stored as JSON in `configurationData`.
// This allows different card types to have different settings while sharing the same
// base model. The configuration is accessed via computed properties that handle
// JSON encoding/decoding transparently.
//
// ## Data Flow
// During agent execution (AgentRunService):
// 1. Start card provides initial input
// 2. Data flows through connected cards
// 3. Each process card generates content using its configuration
// 4. Output cards collect final results

import SwiftData
import SwiftUI

// MARK: - Card Type Enumeration

/// Classifies the role of a card in an agent workflow.
///
/// Each type has different behavior and configuration:
/// - `start`: Single entry point providing workflow input
/// - `process`: Processing nodes that generate content
/// - `output`: Optional terminal nodes for collecting results
enum CardType: String, Codable, CaseIterable, Identifiable {
    var id: String {
        rawValue
    }

    /// Entry point card accepting user input
    case start
    /// Processing card performing generation
    case process
    /// Terminal card marking workflow output
    case output
}

// MARK: - Card Configuration Structures

/// Configuration for Start cards defining workflow input.
///
/// Start cards can accept different input types:
/// - Text: A prompt string passed to downstream cards
/// - Image: An image file used as reference or source
/// - Video: A video file for video-based workflows
struct StartCardConfiguration: Codable {
    /// Input type: "Text", "Image", or "Video"
    var inputType = "Text"
    /// Text prompt when inputType is "Text"
    var textInput = ""
    /// File path when inputType is "Image"
    var imagePath: String?
    /// File path when inputType is "Video"
    var videoPath: String?
}

/// Configuration for a single reference image in generation.
///
/// Reference images guide generation style or content:
/// - imagePath: Location of the reference image
/// - referenceType: How to use it ("asset", "style", etc.)
struct ReferenceImageConfig: Codable, Identifiable {
    var id = UUID()
    /// Path to the reference image file
    var imagePath: String
    /// Type of reference ("asset", "style", etc.)
    var referenceType: String
}

/// Complete configuration for image generation process cards.
///
/// This struct captures all parameters needed for image generation,
/// mirroring the options available in ImageGenerateView. It's serialized
/// to JSON and stored in the card's configurationData.
///
/// ## Model Selection
/// - `selectedProviderId`: Which provider to use
/// - `selectedModelId`: Which model from that provider
///
/// ## Prompt Configuration
/// - `prompt`: Main generation prompt
/// - `negativePrompt`: What to avoid
/// - `searchPrompt`: For search-and-replace operations
///
/// ## Output Options
/// - `selectedDimensions`: Output size
/// - `selectedQuality`, `selectedStyle`, `selectedVariant`: Model options
///
/// ## Advanced Parameters
/// - `stepsValue`, `guidanceValue`: Generation quality
/// - `seedValue`: For reproducibility
/// - `safetyValue`: Content filtering level
///
/// ## Reference Images
/// - `referenceImages`: Array of reference images
/// - `usePreviousImageAsReference`: Use upstream card's output as reference
/// - `usePreviousImageAsSourceImage`: Use upstream card's output as source
struct ImageGenerationConfiguration: Codable {
    var selectedProviderId = ""
    var selectedModelId = ""
    var prompt = ""
    var negativePrompt = ""
    var searchPrompt = ""
    var selectedDimensions = "1024x1024"
    var selectedQuality = "standard"
    var selectedStyle = ""
    var selectedVariant = ""
    var selectedInputFidelity = ""
    var selectedModeration = ""
    var selectedResolution = ""
    var stepsValue: Double = 28
    var guidanceValue = 3.5
    var seedValue = ""
    var safetyValue: Double = 5
    var growMaskValue: Double = 3
    var modelPromptEnhance = true
    var personGeneration = ""
    var selectedTools: [String] = []
    var referenceImages: [ReferenceImageConfig] = []
    var usePreviousImageAsReference = false
    var usePreviousImageAsSourceImage = false
}

/// Complete configuration for video generation process cards.
///
/// Similar to ImageGenerationConfiguration but with video-specific options:
/// - `durationSeconds`: Video length
/// - `selectedFPS`: Frame rate
/// - `generateAudio`: Whether to generate audio track
/// - `selectedResolution`: Video resolution tier
struct VideoGenerationConfiguration: Codable {
    var selectedProviderId = ""
    var selectedModelId = ""
    var prompt = ""
    var negativePrompt = ""
    var selectedDimensions = "1280x720"
    var selectedResolution = ""
    var durationSeconds = 5
    var selectedFPS = 24
    var generateAudio = false
    var guidanceValue = 3.5
    var seedValue = ""
    var safetyValue: Double = 5
    var modelPromptEnhance = true
    var selectedTools: [String] = []
    var usePreviousImageAsSourceImage = false
}

/// Represents data available from an upstream (previous) card.
///
/// During agent execution, each card receives input from connected upstream cards.
/// This struct packages that input data for the current card to use.
///
/// ## Usage
/// - Process cards check what input is available
/// - Configuration options adapt based on available input
/// - Generation requests include appropriate input data
struct PreviousCardInput {
    /// Text from upstream (prompt or output text)
    var text: String?
    /// Image from upstream card's generation
    var image: PlatformImage?
    /// Video URL from upstream card's generation
    var video: URL?
    /// Whether image is a placeholder (card exists but no output yet)
    var isImagePlaceholder = false

    /// True if text input is available and non-empty
    var hasText: Bool {
        text != nil && !text!.isEmpty
    }

    /// True if an actual image is available
    var hasImage: Bool {
        image != nil
    }

    /// True if a video URL is available
    var hasVideo: Bool {
        video != nil
    }

    /// True if any input type is available
    var hasAnyInput: Bool {
        hasText || hasImage || hasVideo
    }

    /// True if image is available or will be (placeholder)
    var canProvideImage: Bool {
        image != nil || isImagePlaceholder
    }
}

// MARK: - Process Card Type Enumeration

/// Specifies the generation type for process cards.
///
/// Process cards can perform either image or video generation.
/// This determines which configuration struct is used and which
/// generation adapter handles the request.
enum ProcessCardType: String, Codable, CaseIterable, Identifiable {
    var id: String {
        rawValue
    }

    /// Image generation process
    case imageGeneration = "image_generation"
    /// Video generation process
    case videoGeneration = "video_generation"

    /// Human-readable name for UI display
    var displayName: String {
        switch self {
        case .imageGeneration: "Image Generation"
        case .videoGeneration: "Video Generation"
        }
    }

    /// SF Symbol icon name
    var icon: String {
        switch self {
        case .imageGeneration: "photo.fill"
        case .videoGeneration: "video.fill"
        }
    }

    /// Icon color (uses system label color)
    var iconColor: Color {
        label
    }
}

// MARK: - Agent Card Model

/// SwiftData model representing a single card in an agent workflow.
///
/// AgentCards are the visual nodes on the infinite canvas that make up a workflow.
/// Each card has:
/// - A type (start, process, output) defining its role
/// - A position on the canvas
/// - Configuration data specific to its type
/// - Execution state tracking (running, errored)
///
/// ## Configuration Storage
/// Card configurations are stored as JSON in `configurationData` rather than
/// as separate properties. This allows different card types to have different
/// configurations while sharing the same model. Access configurations via
/// the computed properties: `startConfiguration`, `imageGenerationConfiguration`,
/// `videoGenerationConfiguration`.
///
/// ## Execution State
/// During agent runs, cards track their execution state:
/// - `isRunning`: Currently processing
/// - `isErrored`: Failed during execution
/// - `errorMessage`: Details about the failure
/// - `generationId`: Links to the generated content
///
/// ## Canvas Positioning
/// The `positionX` and `positionY` properties store the card's location on the
/// infinite canvas. The `position` computed property provides convenient CGPoint access.
@Model
class AgentCard: Identifiable, Codable {
    #Index<AgentCard>([\.agentId])

    enum CodingKeys: CodingKey {
        case id
        case agentId
        case cardType
        case processCardType
        case positionX
        case positionY
        case isDefault
        case createdAt
        case title
        case configurationData
        case generationId
        case isRunning
        case isErrored
        case errorMessage
    }

    var id = UUID()

    var agentId = UUID()

    var agent: Agent?

    /// Role of this card (start, process, output)
    var cardType = CardType.process

    /// For process cards, specifies image or video generation
    var processCardType: ProcessCardType? = nil

    /// X position on the infinite canvas
    var positionX: CGFloat = 0

    /// Y position on the infinite canvas
    var positionY: CGFloat = 0

    /// Whether this is the default start card (cannot be deleted)
    var isDefault = false

    var createdAt = Date()

    /// Display title for the card
    var title = ""

    var configurationData: Data?

    /// UUID of the generation produced by this card (if any)
    var generationId: UUID?

    // MARK: Execution State

    /// Whether this card is currently being processed
    var isRunning = false

    /// Whether this card encountered an error during execution
    var isErrored = false

    /// Error message if execution failed
    var errorMessage: String?

    /// Convenient CGPoint access to card position.
    /// Reads from and writes to positionX/positionY properties.
    var position: CGPoint {
        get { CGPoint(x: positionX, y: positionY) }
        set {
            positionX = newValue.x
            positionY = newValue.y
        }
    }

    init(
        agentId: UUID,
        cardType: CardType = .process,
        processCardType: ProcessCardType? = nil,
        position: CGPoint = .zero,
        isDefault: Bool = false,
        title: String = ""
    ) {
        id = UUID()
        self.agentId = agentId
        self.cardType = cardType
        self.processCardType = processCardType
        positionX = position.x
        positionY = position.y
        self.isDefault = isDefault
        createdAt = Date()
        self.title = title
    }

    // MARK: - Factory Methods

    /// Creates the default Start card for a new agent.
    ///
    /// Start cards are the entry points for agent workflows. They accept
    /// user input (text or image) which flows to connected downstream cards.
    /// The default start card is marked as `isDefault = true` and cannot
    /// be deleted by users.
    ///
    /// - Parameters:
    ///   - agentId: Parent agent UUID
    ///   - position: Canvas position (defaults to origin)
    /// - Returns: Configured Start card
    static func createDefault(agentId: UUID, position: CGPoint = .zero) -> AgentCard {
        AgentCard(
            agentId: agentId,
            cardType: .start,
            position: position,
            isDefault: true,
            title: "Start"
        )
    }

    /// Creates a new Process card for image or video generation.
    ///
    /// Process cards are the workhorses of agent workflows. They take input
    /// from upstream cards and generate new content based on their configuration.
    ///
    /// - Parameters:
    ///   - agentId: Parent agent UUID
    ///   - processType: Whether this generates images or videos
    ///   - position: Canvas position
    /// - Returns: Configured Process card
    static func createProcessCard(
        agentId: UUID,
        processType: ProcessCardType,
        position: CGPoint = .zero
    ) -> AgentCard {
        AgentCard(
            agentId: agentId,
            cardType: .process,
            processCardType: processType,
            position: position,
            isDefault: false,
            title: processType.displayName
        )
    }

    /// Creates an Output card marking a workflow endpoint.
    ///
    /// Output cards are optional terminal nodes that can collect and
    /// organize workflow results. They're useful for multi-branch workflows
    /// where you want to explicitly mark endpoints.
    ///
    /// - Parameters:
    ///   - agentId: Parent agent UUID
    ///   - position: Canvas position
    /// - Returns: Configured Output card
    static func createOutputCard(
        agentId: UUID,
        position: CGPoint = .zero
    ) -> AgentCard {
        AgentCard(
            agentId: agentId,
            cardType: .output,
            position: position,
            isDefault: false,
            title: "Output"
        )
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        agentId = try container.decode(UUID.self, forKey: .agentId)
        cardType = try container.decode(CardType.self, forKey: .cardType)
        processCardType = try container.decodeIfPresent(ProcessCardType.self, forKey: .processCardType)
        positionX = try container.decode(CGFloat.self, forKey: .positionX)
        positionY = try container.decode(CGFloat.self, forKey: .positionY)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        title = try container.decode(String.self, forKey: .title)
        configurationData = try container.decodeIfPresent(Data.self, forKey: .configurationData)
        generationId = try container.decodeIfPresent(UUID.self, forKey: .generationId)
        isRunning = try container.decodeIfPresent(Bool.self, forKey: .isRunning) ?? false
        isErrored = try container.decodeIfPresent(Bool.self, forKey: .isErrored) ?? false
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(agentId, forKey: .agentId)
        try container.encode(cardType, forKey: .cardType)
        try container.encodeIfPresent(processCardType, forKey: .processCardType)
        try container.encode(positionX, forKey: .positionX)
        try container.encode(positionY, forKey: .positionY)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(configurationData, forKey: .configurationData)
        try container.encodeIfPresent(generationId, forKey: .generationId)
        try container.encode(isRunning, forKey: .isRunning)
        try container.encode(isErrored, forKey: .isErrored)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
    }

    // MARK: - Configuration Accessors

    /// Typed access to Start card configuration.
    ///
    /// Decodes the configurationData JSON to StartCardConfiguration.
    /// Returns a default configuration if decoding fails or data is nil.
    ///
    /// - Note: Only valid for cards with `cardType == .start`
    var startConfiguration: StartCardConfiguration {
        get {
            guard let data = configurationData else { return StartCardConfiguration() }
            do {
                return try JSONDecoder().decode(StartCardConfiguration.self, from: data)
            } catch {
                AppLogger.data.error("Failed to decode StartCardConfiguration: \(error, privacy: .public)")
                return StartCardConfiguration()
            }
        }
        set {
            do {
                configurationData = try JSONEncoder().encode(newValue)
            } catch {
                configurationData = nil
                AppLogger.data.error("Failed to encode StartCardConfiguration: \(error, privacy: .public)")
            }
        }
    }

    /// Typed access to image generation Process card configuration.
    ///
    /// Decodes the configurationData JSON to ImageGenerationConfiguration.
    /// Returns a default configuration if decoding fails or data is nil.
    ///
    /// - Note: Only valid for cards with `processCardType == .imageGeneration`
    var imageGenerationConfiguration: ImageGenerationConfiguration {
        get {
            guard let data = configurationData else { return ImageGenerationConfiguration() }
            do {
                return try JSONDecoder().decode(ImageGenerationConfiguration.self, from: data)
            } catch {
                AppLogger.data.error("Failed to decode ImageGenerationConfiguration: \(error, privacy: .public)")
                return ImageGenerationConfiguration()
            }
        }
        set {
            do {
                configurationData = try JSONEncoder().encode(newValue)
            } catch {
                configurationData = nil
                AppLogger.data.error("Failed to encode ImageGenerationConfiguration: \(error, privacy: .public)")
            }
        }
    }

    /// Typed access to video generation Process card configuration.
    ///
    /// Decodes the configurationData JSON to VideoGenerationConfiguration.
    /// Returns a default configuration if decoding fails or data is nil.
    ///
    /// - Note: Only valid for cards with `processCardType == .videoGeneration`
    var videoGenerationConfiguration: VideoGenerationConfiguration {
        get {
            guard let data = configurationData else { return VideoGenerationConfiguration() }
            do {
                return try JSONDecoder().decode(VideoGenerationConfiguration.self, from: data)
            } catch {
                AppLogger.data.error("Failed to decode VideoGenerationConfiguration: \(error, privacy: .public)")
                return VideoGenerationConfiguration()
            }
        }
        set {
            do {
                configurationData = try JSONEncoder().encode(newValue)
            } catch {
                configurationData = nil
                AppLogger.data.error("Failed to encode VideoGenerationConfiguration: \(error, privacy: .public)")
            }
        }
    }
}
