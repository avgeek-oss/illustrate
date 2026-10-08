// MARK: - ChatMessage.swift

// Defines the ChatMessage model for chat thread conversations.
//
// ChatMessages represent individual prompt/response pairs in a ChatThread.
// Each message contains the user's prompt and references to generated images.
//
// ## Message Lifecycle
// 1. User submits prompt, message created with status `.processing`
// 2. Generation requests sent for each image (up to imagesPerIteration)
// 3. On success: status → `.generated`, generationIds populated
// 4. On failure: status → `.failed`, errorMessage set
//
// ## Iteration Flow
// When generating, the system uses previous message's generationIds as
// reference images for the new generation, creating visual continuity.

import SwiftData
import SwiftUI

// MARK: - Chat Message Status

/// Tracks the generation state of a chat message.
///
/// Used to display appropriate UI:
/// - `.PROCESSING`: Show loading indicators for pending images
/// - `.GENERATED`: Show the generated images
/// - `.FAILED`: Show error message
enum ChatMessageStatus: String, Codable {
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
                    debugDescription: "Unknown ChatMessageStatus: \(rawValue)"
                )
            )
        }
    }
}

// MARK: - ChatMessage Model

/// SwiftData model representing a single message in a chat thread.
///
/// ChatMessages store the user's prompt and track the resulting
/// image generations. Multiple images can be generated per message.
///
/// ## Queue Integration
/// The `queueItemIds` array links to the generation queue system,
/// allowing the UI to track progress for multiple concurrent generations.
@Model
class ChatMessage: Identifiable, Codable {
    #Index<ChatMessage>([\.threadId])

    enum CodingKeys: CodingKey {
        case id
        case threadId
        case createdAt
        case prompt
        case status
        case generationIdsData
        case errorMessage
        case configurationData
        case queueItemIdsData
        case pendingCount
        case isDelinked
    }

    var id = UUID()
    var threadId = UUID()
    var createdAt = Date()
    var prompt = ""
    var status = ChatMessageStatus.PROCESSING
    var generationIdsData: Data?
    var errorMessage: String?
    var configurationData: Data?
    var queueItemIdsData: Data?
    var pendingCount = 0
    var isDelinked = false

    var generationIds: [UUID] {
        get {
            guard let data = generationIdsData else { return [] }
            do {
                return try JSONDecoder().decode([UUID].self, from: data)
            } catch {
                AppLogger.data.error("Failed to decode generationIds: \(error, privacy: .public)")
                return []
            }
        }
        set {
            do {
                generationIdsData = try JSONEncoder().encode(newValue)
            } catch {
                generationIdsData = nil
                AppLogger.data.error("Failed to encode generationIds: \(error, privacy: .public)")
            }
        }
    }

    var queueItemIds: [UUID] {
        get {
            guard let data = queueItemIdsData else { return [] }
            do {
                return try JSONDecoder().decode([UUID].self, from: data)
            } catch {
                AppLogger.data.error("Failed to decode queueItemIds: \(error, privacy: .public)")
                return []
            }
        }
        set {
            do {
                queueItemIdsData = try JSONEncoder().encode(newValue)
            } catch {
                queueItemIdsData = nil
                AppLogger.data.error("Failed to encode queueItemIds: \(error, privacy: .public)")
            }
        }
    }

    /// Creates a new chat message.
    ///
    /// - Parameters:
    ///   - threadId: Parent thread ID
    ///   - prompt: User's prompt text
    init(threadId: UUID, prompt: String) {
        id = UUID()
        self.threadId = threadId
        self.prompt = prompt
        createdAt = Date()
        status = .PROCESSING
    }

    // MARK: - Codable Implementation

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        threadId = try container.decode(UUID.self, forKey: .threadId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        prompt = try container.decode(String.self, forKey: .prompt)
        status = try container.decode(ChatMessageStatus.self, forKey: .status)
        generationIdsData = try container.decodeIfPresent(Data.self, forKey: .generationIdsData)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        configurationData = try container.decodeIfPresent(Data.self, forKey: .configurationData)
        queueItemIdsData = try container.decodeIfPresent(Data.self, forKey: .queueItemIdsData)
        pendingCount = try container.decodeIfPresent(Int.self, forKey: .pendingCount) ?? 0
        isDelinked = try container.decodeIfPresent(Bool.self, forKey: .isDelinked) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(threadId, forKey: .threadId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(generationIdsData, forKey: .generationIdsData)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try container.encodeIfPresent(configurationData, forKey: .configurationData)
        try container.encodeIfPresent(queueItemIdsData, forKey: .queueItemIdsData)
        try container.encode(pendingCount, forKey: .pendingCount)
        try container.encode(isDelinked, forKey: .isDelinked)
    }

    // MARK: - Configuration Accessor

    /// Typed access to image generation configuration.
    ///
    /// Reuses the ImageGenerationConfiguration struct.
    /// Decodes from configurationData JSON, returns default if unavailable.
    var imageGenerationConfiguration: ImageGenerationConfiguration {
        get {
            guard let data = configurationData else { return ImageGenerationConfiguration() }
            do {
                return try JSONDecoder().decode(ImageGenerationConfiguration.self, from: data)
            } catch {
                AppLogger.data
                    .error("Failed to decode ChatMessage ImageGenerationConfiguration: \(error, privacy: .public)")
                return ImageGenerationConfiguration()
            }
        }
        set {
            do {
                configurationData = try JSONEncoder().encode(newValue)
            } catch {
                configurationData = nil
                AppLogger.data
                    .error("Failed to encode ChatMessage ImageGenerationConfiguration: \(error, privacy: .public)")
            }
        }
    }
}
