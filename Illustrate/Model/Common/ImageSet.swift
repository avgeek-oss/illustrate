// MARK: - ImageSet.swift

// Defines the ImageSet model for grouping related generations.
//
// When a user generates content, the results are organized into "sets":
// - All images from a single generation request share a setId
// - Sets preserve the context (prompt, model, settings) for the group
// - Sets enable batch operations and gallery organization
//
// ## Relationship to Generation
// ImageSet is the parent grouping, Generation is the individual output:
// - One ImageSet can contain multiple Generations (batch generation)
// - Generations reference their ImageSet via setId
// - ImageSet stores shared request parameters
//
// ## Set Types
// Different types of generation workflows:
// - IMAGE_GENERATE: Standard text-to-image generation
// - VIDEO_GENERATE: Text/image-to-video generation
// - VIDEO_EXTEND: Extend existing video with new content

import CloudKit
import IllustrateProviders
import SwiftData
import SwiftUI

// MARK: - Set Type Helper Functions

/// Returns the display label for a set type.
/// Used in navigation menus and headers.
func labelForSetType(_ item: EnumSetType) -> String {
    switch item {
    case .IMAGE_GENERATE:
        AppLocalization.string("Generate Image")
    case .VIDEO_GENERATE:
        AppLocalization.string("Generate Video")
    case .VIDEO_EXTEND:
        AppLocalization.string("Extend Video")
    }
}

/// Returns a descriptive subtitle for a set type.
/// Used in feature cards and onboarding.
func subLabelForSetType(_ item: EnumSetType) -> String {
    switch item {
    case .IMAGE_GENERATE:
        AppLocalization.string("Imagine an image and generate in seconds")
    case .VIDEO_GENERATE:
        AppLocalization.string("Bring your ideas to life with audio")
    case .VIDEO_EXTEND:
        AppLocalization.string("Extend video with your imagination")
    }
}

/// Returns the SF Symbol icon name for a set type.
/// Used throughout the UI for visual identification.
func iconForSetType(_ item: EnumSetType) -> String {
    item.icon
}

/// Maps navigation items to their corresponding set types.
/// Used when navigating to determine which generation type to show.
func setTypeForItem(_ item: EnumNavigationItem) -> EnumSetType {
    switch item {
    case .imageGenerate:
        .IMAGE_GENERATE
    case .videoGenerate:
        .VIDEO_GENERATE
    default:
        .IMAGE_GENERATE
    }
}

// MARK: - ImageSet Model

/// SwiftData model grouping related generations from a single request.
///
/// When a user generates content, an ImageSet is created to store the
/// shared parameters. Individual outputs (Generation entities) reference
/// this set via their `setId` property.
///
/// ## Why ImageSet?
/// - Groups batch generations (multiple images from one request)
/// - Stores shared request context (prompt, model, settings)
/// - Enables set-level operations (star, delete all, retry)
/// - Provides gallery organization
///
/// ## Star System
/// Sets can be starred for quick access. Starred sets appear in a
/// dedicated section of the gallery.
///
/// ## Prompt Storage
/// The set stores all prompt variants:
/// - `prompt`: Main generation prompt
/// - `negativePrompt`: What to avoid
/// - `searchPrompt`: For search-and-replace models
@Model
class ImageSet: Identifiable, Codable {
    #Index<ImageSet>([\.projectId, \.createdAt])

    enum CodingKeys: CodingKey {
        case id
        case projectId
        case createdAt
        case prompt
        case starred
        case modelId
        case style
        case variant
        case dimensions
        case setType
        case negativePrompt
        case searchPrompt
    }

    /// Unique identifier (referenced by Generation.setId)
    var id = UUID()

    var projectId: UUID = Project.defaultProjectId

    var project: Project?

    /// When this generation request was made
    var createdAt = Date()

    /// The main prompt used for generation
    var prompt = ""

    /// Whether this set is starred/favorited
    var starred = false

    /// Model used for generation (UUID as string)
    var modelId = ""

    /// Style option selected
    var style = "Natural"

    /// Variant option selected
    var variant = "Normal"

    /// Output dimensions as "WIDTHxHEIGHT"
    var dimensions = "1024x1024"

    /// Type of generation (image, video, video extend)
    var setType = EnumSetType.IMAGE_GENERATE

    /// Negative prompt (what to avoid)
    var negativePrompt: String? = nil

    @Relationship(deleteRule: .cascade, inverse: \Generation.imageSet)
    var generations: [Generation]? = nil

    /// Search prompt for search-and-replace models
    var searchPrompt: String? = nil

    init(
        prompt: String,
        projectId: UUID = Project.defaultProjectId,
        modelId: String,
        style: String = "Natural",
        variant: String = "Normal",
        dimensions: String,
        setType: EnumSetType,
        negativePrompt: String? = nil,
        searchPrompt: String? = nil
    ) {
        id = UUID()
        self.projectId = projectId
        createdAt = Date()
        self.prompt = prompt
        starred = false
        self.modelId = modelId
        self.style = style
        self.variant = variant
        self.dimensions = dimensions
        self.setType = setType
        self.negativePrompt = negativePrompt
        self.searchPrompt = searchPrompt
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId) ?? Project.defaultProjectId
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        prompt = try container.decode(String.self, forKey: .prompt)
        starred = try container.decode(Bool.self, forKey: .starred)
        modelId = try container.decode(String.self, forKey: .modelId)
        style = try container.decode(String.self, forKey: .style)
        variant = try container.decode(String.self, forKey: .variant)
        dimensions = try container.decode(String.self, forKey: .dimensions)
        setType = try container.decode(EnumSetType.self, forKey: .setType)
        negativePrompt = try container.decodeIfPresent(String.self, forKey: .negativePrompt)
        searchPrompt = try container.decodeIfPresent(String.self, forKey: .searchPrompt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(starred, forKey: .starred)
        try container.encode(modelId, forKey: .modelId)
        try container.encode(style, forKey: .style)
        try container.encode(variant, forKey: .variant)
        try container.encode(dimensions, forKey: .dimensions)
        try container.encode(setType, forKey: .setType)
        try container.encode(negativePrompt, forKey: .negativePrompt)
        try container.encode(searchPrompt, forKey: .searchPrompt)
    }
}
