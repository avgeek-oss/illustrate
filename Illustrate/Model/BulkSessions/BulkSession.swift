// MARK: - BulkSession.swift

// Defines the BulkSession model for bulk image generation from CSV.
//
// BulkSessions allow users to generate multiple images from a list of prompts
// imported from CSV files. Each session stores generation configuration,
// concurrency settings, and a common prompt suffix.
//
// ## Session Lifecycle
// 1. User creates session with name
// 2. Configures model, dimensions, and other parameters
// 3. Imports CSV with prompts (max 250 items)
// 4. Starts generation with configurable concurrency
// 5. Can cancel to stop pending items

import SwiftData
import SwiftUI

// MARK: - Bulk Session Status

/// Tracks the overall state of a bulk generation session.
enum BulkSessionStatus: String, Codable {
    /// Session is idle, ready to start
    case IDLE
    case RUNNING
    /// Generation completed (all items processed)
    case COMPLETED

    // MARK: - Backward Compatible Decoding

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "idle", "IDLE": self = .IDLE
        case "running", "RUNNING": self = .RUNNING
        case "completed", "COMPLETED": self = .COMPLETED
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown BulkSessionStatus: \(rawValue)"
                )
            )
        }
    }
}

// MARK: - BulkSession Model

/// SwiftData model representing a bulk image generation session.
///
/// BulkSessions provide batch processing of image generation requests.
/// Users import prompts from CSV, configure generation settings once,
/// and generate all images with rate-limit-aware concurrency control.
///
/// ## Configuration
/// Each session stores:
/// - `concurrencyLimit`: How many concurrent generations (1-10)
/// - `commonPrompt`: Suffix appended to all prompts
/// - Provider/model selection and generation parameters
@Model
class BulkSession: Identifiable, Codable, Pinnable {
    #Index<BulkSession>([\.projectId])

    enum CodingKeys: CodingKey {
        case id
        case projectId
        case createdAt
        case name
        case isPinned
        case concurrencyLimit
        case commonPrompt
        case selectedProviderId
        case selectedModelId
        case configurationData
        case status
    }

    var id = UUID()

    var projectId: UUID = Project.defaultProjectId

    var project: Project?

    var createdAt = Date()

    var name = "Untitled Session"

    /// When true, the session is pinned to the top of the list
    var isPinned = false

    /// Maximum concurrent generations (1-10)
    var concurrencyLimit = 2

    /// Common prompt suffix appended to all CSV prompts
    var commonPrompt = ""

    /// Currently selected provider ID
    var selectedProviderId = ""

    /// Currently selected model ID
    var selectedModelId = ""

    var configurationData: Data?

    /// Current session status
    var status = BulkSessionStatus.IDLE

    @Relationship(deleteRule: .cascade, inverse: \BulkSessionItem.bulkSession)
    var items: [BulkSessionItem]? = nil

    /// Creates a new bulk session.
    ///
    /// - Parameters:
    ///   - name: Display name for the session
    ///   - projectId: Parent project
    init(
        name: String = "Untitled Session",
        projectId: UUID = Project.defaultProjectId
    ) {
        id = UUID()
        self.name = name
        self.projectId = projectId
        createdAt = Date()
        isPinned = false
        concurrencyLimit = 2
        commonPrompt = ""
        selectedProviderId = ""
        selectedModelId = ""
        configurationData = nil
        status = .IDLE
    }

    // MARK: - Codable Implementation

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId) ?? Project.defaultProjectId
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        name = try container.decode(String.self, forKey: .name)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        concurrencyLimit = try container.decodeIfPresent(Int.self, forKey: .concurrencyLimit) ?? 2
        commonPrompt = try container.decodeIfPresent(String.self, forKey: .commonPrompt) ?? ""
        selectedProviderId = try container.decodeIfPresent(String.self, forKey: .selectedProviderId) ?? ""
        selectedModelId = try container.decodeIfPresent(String.self, forKey: .selectedModelId) ?? ""
        configurationData = try container.decodeIfPresent(Data.self, forKey: .configurationData)
        status = try container.decodeIfPresent(BulkSessionStatus.self, forKey: .status) ?? .IDLE
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(name, forKey: .name)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(concurrencyLimit, forKey: .concurrencyLimit)
        try container.encode(commonPrompt, forKey: .commonPrompt)
        try container.encode(selectedProviderId, forKey: .selectedProviderId)
        try container.encode(selectedModelId, forKey: .selectedModelId)
        try container.encodeIfPresent(configurationData, forKey: .configurationData)
        try container.encode(status, forKey: .status)
    }

    // MARK: - Configuration Accessor

    /// Typed access to persisted generation configuration.
    var savedConfiguration: ImageGenerationConfiguration {
        get {
            guard let data = configurationData else { return ImageGenerationConfiguration() }
            do {
                return try JSONDecoder().decode(ImageGenerationConfiguration.self, from: data)
            } catch {
                AppLogger.data
                    .error("Failed to decode BulkSession ImageGenerationConfiguration: \(error, privacy: .public)")
                return ImageGenerationConfiguration()
            }
        }
        set {
            do {
                configurationData = try JSONEncoder().encode(newValue)
            } catch {
                configurationData = nil
                AppLogger.data
                    .error("Failed to encode BulkSession ImageGenerationConfiguration: \(error, privacy: .public)")
            }
        }
    }
}

// MARK: - Constants

/// Maximum number of items allowed per bulk session
let bulkSessionMaxItems = 250
