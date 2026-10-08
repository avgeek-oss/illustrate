// MARK: - ProductPhotoshootItem.swift

// Defines the ProductPhotoshootItem model for individual generated photos.
//
// ProductPhotoshootItems represent generated product photographs within a
// photoshoot. Each item tracks its generation status, the backdrop used,
// and the resulting image.
//
// ## Item Lifecycle
// 1. Item created with status `.processing`
// 2. Generation request sent to API with product objects and backdrop
// 3. On success: status → `.generated`, generationId set
// 4. On failure: status → `.failed`, errorMessage set

import SwiftData
import SwiftUI

// MARK: - Photoshoot Item Status

/// Tracks the generation state of a photoshoot item.
///
/// Used to display appropriate UI:
/// - `.PROCESSING`: Show shimmer loading indicator
/// - `.GENERATED`: Show the generated thumbnail
/// - `.FAILED`: Show error state
enum PhotoshootItemStatus: String, Codable {
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
                    debugDescription: "Unknown PhotoshootItemStatus: \(rawValue)"
                )
            )
        }
    }
}

// MARK: - ProductPhotoshootItem Model

/// SwiftData model representing a generated photo in a product photoshoot.
///
/// Each item stores the backdrop used, generation result, and status.
/// Items are displayed in a gallery grid within the photoshoot editor.
///
/// ## Queue Integration
/// The `queueItemId` links to the generation queue system, allowing
/// the UI to track progress and update status when generation completes.
@Model
class ProductPhotoshootItem: Identifiable, Codable {
    enum CodingKeys: CodingKey {
        case id
        case photoshootId
        case projectId
        case createdAt
        case status
        case generationId
        case errorMessage
        case backdropAssetName
        case customBackdropFileName
        case configurationData
        case queueItemId
    }

    var id = UUID()

    var photoshootId = UUID()

    var photoshoot: ProductPhotoshoot?

    var projectId: UUID = Project.defaultProjectId

    var createdAt = Date()

    var status = PhotoshootItemStatus.PROCESSING

    var generationId: UUID?

    var errorMessage: String?

    /// Name of the backdrop asset used (from app bundle)
    var backdropAssetName: String?

    /// File name for custom uploaded backdrop (stored in iCloud)
    var customBackdropFileName: String?

    var configurationData: Data?

    var queueItemId: UUID?

    /// Creates a new photoshoot item.
    ///
    /// - Parameters:
    ///   - photoshootId: Parent photoshoot
    ///   - projectId: Parent project
    ///   - backdropAssetName: Name of backdrop asset (for bundled backdrops)
    ///   - customBackdropFileName: File name for custom backdrop
    init(
        photoshootId: UUID,
        projectId: UUID = Project.defaultProjectId,
        backdropAssetName: String? = nil,
        customBackdropFileName: String? = nil
    ) {
        id = UUID()
        self.photoshootId = photoshootId
        self.projectId = projectId
        createdAt = Date()
        status = .PROCESSING
        self.backdropAssetName = backdropAssetName
        self.customBackdropFileName = customBackdropFileName
    }

    // MARK: - Codable Implementation

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        photoshootId = try container.decode(UUID.self, forKey: .photoshootId)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId) ?? Project.defaultProjectId
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        status = try container.decode(PhotoshootItemStatus.self, forKey: .status)
        generationId = try container.decodeIfPresent(UUID.self, forKey: .generationId)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        backdropAssetName = try container.decodeIfPresent(String.self, forKey: .backdropAssetName)
        customBackdropFileName = try container.decodeIfPresent(String.self, forKey: .customBackdropFileName)
        configurationData = try container.decodeIfPresent(Data.self, forKey: .configurationData)
        queueItemId = try container.decodeIfPresent(UUID.self, forKey: .queueItemId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(photoshootId, forKey: .photoshootId)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(generationId, forKey: .generationId)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try container.encodeIfPresent(backdropAssetName, forKey: .backdropAssetName)
        try container.encodeIfPresent(customBackdropFileName, forKey: .customBackdropFileName)
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
}
