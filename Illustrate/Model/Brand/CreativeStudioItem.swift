// MARK: - CreativeStudioItem.swift

// Defines the CreativeStudioItem model for individual studio assets.
//
// CreativeStudioItems represent generated assets within a studio.
// Each item tracks its generation status, the prompt used, and the
// asset type that was selected.
//
// ## Item Lifecycle
// 1. Item created with status `.processing`
// 2. Generation request sent to API with brand context
// 3. On success: status → `.generated`, generationId set
// 4. On failure: status → `.failed`, errorMessage set

import SwiftData
import SwiftUI

// MARK: - Studio Item Status

/// Tracks the generation state of a studio item.
///
/// Used to display appropriate UI:
/// - `.PROCESSING`: Show loading indicator
/// - `.GENERATED`: Show the generated content
/// - `.FAILED`: Show error message
enum CreativeStudioItemStatus: String, Codable {
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
                    debugDescription: "Unknown CreativeStudioItemStatus: \(rawValue)"
                )
            )
        }
    }
}

// MARK: - CreativeStudioItem Model

/// SwiftData model representing a generated asset in a creative studio.
///
/// Each item stores the prompt, asset type, and generation result.
/// Items are displayed in a grid within the studio view.
///
/// ## Queue Integration
/// The `queueItemId` links to the generation queue system, allowing
/// the UI to track progress and update status when generation completes.
@Model
class CreativeStudioItem: Identifiable, Codable {
    enum CodingKeys: CodingKey {
        case id
        case studioId
        case projectId
        case createdAt
        case status
        case assetType
        case userPrompt
        case fullPrompt
        case generationId
        case errorMessage
        case configurationData
        case queueItemId
    }

    var id = UUID()
    var studioId = UUID()
    var studio: CreativeStudio?
    var projectId: UUID = Project.defaultProjectId
    var createdAt = Date()
    var status = CreativeStudioItemStatus.PROCESSING
    var assetType = CreativeAssetType.generalPurpose.rawValue
    var userPrompt = ""
    var fullPrompt = ""
    var generationId: UUID?
    var errorMessage: String?
    var configurationData: Data?
    var queueItemId: UUID?

    /// Creates a new studio item.
    ///
    /// - Parameters:
    ///   - studioId: Parent studio
    ///   - projectId: Parent project
    ///   - assetType: Type of creative asset
    ///   - userPrompt: User's original prompt
    ///   - fullPrompt: Full prompt with brand context
    init(
        studioId: UUID,
        projectId: UUID = Project.defaultProjectId,
        assetType: CreativeAssetType = .generalPurpose,
        userPrompt: String = "",
        fullPrompt: String = ""
    ) {
        id = UUID()
        self.studioId = studioId
        self.projectId = projectId
        createdAt = Date()
        status = .PROCESSING
        self.assetType = assetType.rawValue
        self.userPrompt = userPrompt
        self.fullPrompt = fullPrompt
    }

    // MARK: - Codable Implementation

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        studioId = try container.decode(UUID.self, forKey: .studioId)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId) ?? Project.defaultProjectId
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        status = try container.decode(CreativeStudioItemStatus.self, forKey: .status)
        assetType = try container.decodeIfPresent(String.self, forKey: .assetType) ?? CreativeAssetType
            .generalPurpose.rawValue
        userPrompt = try container.decodeIfPresent(String.self, forKey: .userPrompt) ?? ""
        fullPrompt = try container.decodeIfPresent(String.self, forKey: .fullPrompt) ?? ""
        generationId = try container.decodeIfPresent(UUID.self, forKey: .generationId)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        configurationData = try container.decodeIfPresent(Data.self, forKey: .configurationData)
        queueItemId = try container.decodeIfPresent(UUID.self, forKey: .queueItemId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(studioId, forKey: .studioId)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(status, forKey: .status)
        try container.encode(assetType, forKey: .assetType)
        try container.encode(userPrompt, forKey: .userPrompt)
        try container.encode(fullPrompt, forKey: .fullPrompt)
        try container.encodeIfPresent(generationId, forKey: .generationId)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try container.encodeIfPresent(configurationData, forKey: .configurationData)
        try container.encodeIfPresent(queueItemId, forKey: .queueItemId)
    }

    // MARK: - Configuration Accessor

    /// Typed access to image generation configuration.
    var imageGenerationConfiguration: ImageGenerationConfiguration {
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

    var assetTypeEnum: CreativeAssetType {
        CreativeAssetType(rawValue: assetType) ?? .generalPurpose
    }
}
