// MARK: - CreativeStudio.swift

// Defines the CreativeStudio model for brand-focused asset generation.
//
// CreativeStudios provide a focused interface for generating brand-consistent
// assets like posters, invitations, social media content, and more.
// Each studio automatically injects brand context (colors, personality,
// logos) into generation prompts.
//
// ## CreativeStudio vs ChatThread vs Flow Canvas
// - **CreativeStudios**: Brand-focused generation with auto-injected brand context
// - **ChatThreads**: Conversational interface for iterative generation
// - **Flow Canvas**: Quick experimentation with visual Flow Canvas layout
//
// ## Asset Types
// Studios support different asset types:
// - General Purpose, Poster, Invitation, Social Media Post, Banner, Flyer, Business Card

import SwiftData
import SwiftUI

// MARK: - Creative Asset Type

/// Predefined asset types for brand content generation.
///
/// Each type provides context for the AI model about what kind of
/// asset to generate, influencing composition and style.
enum CreativeAssetType: String, Codable, CaseIterable, Identifiable {
    var id: String {
        rawValue
    }

    case generalPurpose = "general_purpose"
    case poster
    case invitation
    case socialMediaPost = "social_media_post"
    case banner
    case flyer
    case businessCard = "business_card"

    /// Human-readable name for UI display
    var displayName: String {
        switch self {
        case .generalPurpose: "General Purpose"
        case .poster: "Poster"
        case .invitation: "Invitation"
        case .socialMediaPost: "Social Media Post"
        case .banner: "Banner"
        case .flyer: "Flyer"
        case .businessCard: "Business Card"
        }
    }

    /// Description for prompt context
    var promptDescription: String {
        switch self {
        case .generalPurpose: "brand asset"
        case .poster: "promotional poster"
        case .invitation: "event invitation"
        case .socialMediaPost: "social media post"
        case .banner: "banner advertisement"
        case .flyer: "promotional flyer"
        case .businessCard: "business card design"
        }
    }

    /// SF Symbol icon name
    var icon: String {
        switch self {
        case .generalPurpose: "sparkles"
        case .poster: "rectangle.portrait"
        case .invitation: "envelope"
        case .socialMediaPost: "square.and.arrow.up"
        case .banner: "rectangle.split.3x1"
        case .flyer: "doc.richtext"
        case .businessCard: "rectangle.on.rectangle"
        }
    }
}

// MARK: - CreativeStudio Model

/// SwiftData model representing a creative studio for asset generation.
///
/// CreativeStudios are project-scoped and linked to a BrandKit.
/// They persist model selection and configuration across sessions.
///
/// ## Configuration
/// Each studio stores:
/// - `selectedProviderId/ModelId`: Persisted provider/model selection
/// - `configurationData`: Full generation configuration
@Model
class CreativeStudio: Identifiable, Codable {
    enum CodingKeys: CodingKey {
        case id
        case projectId
        case createdAt
        case selectedProviderId
        case selectedModelId
        case configurationData
    }

    var id = UUID()

    var projectId: UUID = Project.defaultProjectId

    var project: Project?

    var createdAt = Date()

    /// Currently selected provider ID
    var selectedProviderId = ""

    /// Currently selected model ID
    var selectedModelId = ""

    var configurationData: Data?

    @Relationship(deleteRule: .cascade, inverse: \CreativeStudioItem.studio)
    var items: [CreativeStudioItem]? = nil

    /// Creates a new creative studio.
    ///
    /// - Parameters:
    ///   - projectId: Parent project
    init(
        projectId: UUID = Project.defaultProjectId
    ) {
        id = UUID()
        self.projectId = projectId
        createdAt = Date()
        selectedProviderId = ""
        selectedModelId = ""
        configurationData = nil
    }

    // MARK: - Codable Implementation

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId) ?? Project.defaultProjectId
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        selectedProviderId = try container.decodeIfPresent(String.self, forKey: .selectedProviderId) ?? ""
        selectedModelId = try container.decodeIfPresent(String.self, forKey: .selectedModelId) ?? ""
        configurationData = try container.decodeIfPresent(Data.self, forKey: .configurationData)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(selectedProviderId, forKey: .selectedProviderId)
        try container.encode(selectedModelId, forKey: .selectedModelId)
        try container.encodeIfPresent(configurationData, forKey: .configurationData)
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
