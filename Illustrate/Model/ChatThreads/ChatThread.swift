// MARK: - ChatThread.swift

// Defines the ChatThread model for conversational image generation.
//
// ChatThreads provide a chat-based interface for iterative image generation.
// Users submit prompts and receive generated images in a conversation flow,
// with each new generation using previous outputs as references.
//
// ## ChatThread vs Flow Canvas vs Agent
// - **Agents**: Complex workflows with configurations, designed for reuse
// - **Flow Canvas**: Quick experimentation with visual Flow Canvas layout
// - **ChatThreads**: Conversational interface for iterative generation
//
// ## Conversation Flow
// Each thread contains ChatMessages representing prompt/response pairs.
// New generations automatically reference previous outputs for continuity.

import SwiftData
import SwiftUI

// MARK: - ChatThread Model

/// SwiftData model representing a conversational generation thread.
///
/// ChatThreads provide a familiar chat interface for image generation.
/// Users type prompts and see generated images appear in a scrolling
/// conversation, with automatic iteration using previous results.
///
/// ## Configuration
/// Each thread stores:
/// - `imagesPerIteration`: How many images to generate per prompt (default: 2)
/// - `selectedProviderId/ModelId`: Persisted provider/model selection
@Model
class ChatThread: Identifiable, Codable, Pinnable {
    #Index<ChatThread>([\.projectId])

    enum CodingKeys: CodingKey {
        case id
        case projectId
        case createdAt
        case name
        case imagesPerIteration
        case selectedProviderId
        case selectedModelId
        case configurationData
        case isPinned
    }

    var id = UUID()

    var projectId: UUID = Project.defaultProjectId

    var project: Project?

    var createdAt = Date()

    var name = "Untitled Thread"

    /// Number of images to generate per prompt (default: 4)
    var imagesPerIteration = 4

    /// Currently selected provider ID
    var selectedProviderId = ""

    /// Currently selected model ID
    var selectedModelId = ""

    var configurationData: Data?

    /// When true, the thread is pinned to the top of the list
    var isPinned = false

    /// Creates a new chat thread.
    ///
    /// - Parameters:
    ///   - name: Display name for the thread
    ///   - projectId: Parent project
    ///   - imagesPerIteration: Number of images per prompt (default: 2)
    init(
        name: String = "Untitled Thread",
        projectId: UUID = Project.defaultProjectId,
        imagesPerIteration: Int = 4
    ) {
        id = UUID()
        self.name = name
        self.projectId = projectId
        createdAt = Date()
        self.imagesPerIteration = imagesPerIteration
        selectedProviderId = ""
        selectedModelId = ""
        configurationData = nil
        isPinned = false
    }

    // MARK: - Codable Implementation

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId) ?? Project.defaultProjectId
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        name = try container.decode(String.self, forKey: .name)
        imagesPerIteration = try container.decodeIfPresent(Int.self, forKey: .imagesPerIteration) ?? 4
        selectedProviderId = try container.decodeIfPresent(String.self, forKey: .selectedProviderId) ?? ""
        selectedModelId = try container.decodeIfPresent(String.self, forKey: .selectedModelId) ?? ""
        configurationData = try container.decodeIfPresent(Data.self, forKey: .configurationData)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(name, forKey: .name)
        try container.encode(imagesPerIteration, forKey: .imagesPerIteration)
        try container.encode(selectedProviderId, forKey: .selectedProviderId)
        try container.encode(selectedModelId, forKey: .selectedModelId)
        try container.encodeIfPresent(configurationData, forKey: .configurationData)
        try container.encode(isPinned, forKey: .isPinned)
    }

    // MARK: - Configuration Accessor

    /// Typed access to persisted generation configuration.
    var savedConfiguration: ImageGenerationConfiguration {
        get {
            guard let data = configurationData,
                  let config = try? JSONDecoder().decode(ImageGenerationConfiguration.self, from: data)
            else {
                return ImageGenerationConfiguration()
            }
            return config
        }
        set {
            configurationData = try? JSONEncoder().encode(newValue)
        }
    }
}
