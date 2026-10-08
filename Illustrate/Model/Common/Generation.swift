// MARK: - Generation.swift

// Core model for tracking individual generated images and videos.
//
// Each Generation instance represents a single output from an AI model,
// storing both the result metadata and the parameters used to create it.
// This enables users to view their generation history, retry with similar
// settings, or analyze their usage patterns.

import CloudKit
import IllustrateProviders
import SwiftData
import SwiftUI

// MARK: - Generation Content Type Enumeration

/// Classifies the type of content produced by a generation.
///
/// Determines how the content is displayed and processed:
/// - IMAGE_2D: Standard raster images (PNG, JPEG)
/// - VIDEO: Video files (MP4)
/// - IMAGE_3D: 3D content (future support)
enum EnumGenerationContentType: String, Codable, CaseIterable, Identifiable {
    var id: String {
        rawValue
    }

    /// Standard 2D raster image
    case IMAGE_2D
    /// Video content
    case VIDEO
    /// 3D content (reserved for future use)
    case IMAGE_3D
}

// MARK: - Generation Model

/// SwiftData model representing a single generated image or video.
@Model
class Generation: Identifiable, Codable {
    #Index<Generation>(
        [\.projectId, \.isHidden, \.createdAt],
        [\.setId],
        [\.modelId]
    )

    enum CodingKeys: CodingKey {
        case id
        case setId
        case projectId
        case createdAt
        case modelId
        case prompt
        case promptEnhanceOpted
        case promptAfterEnhance
        case style
        case variant
        case quality
        case dimensions
        case size
        case creditUsed
        case status
        case colorPalette
        case modelRevisedPrompt
        case hasClientImage
        case hasClientMask
        case clientReferenceImagesCount
        case negativePrompt
        case searchPrompt
        case contentType
        case metadata
        case runId
        case agentId
        case isHidden
        case realtimeSessionId
    }

    /// Unique identifier for this generation (also used as filename)
    var id = UUID()

    /// Groups related generations (same request produces same setId)
    var setId = UUID()

    var imageSet: ImageSet?

    var projectId: UUID = Project.defaultProjectId

    var createdAt = Date()

    /// The model UUID used for generation (as string for SwiftData compatibility)
    var modelId = ""

    /// Original user prompt
    var prompt = ""

    /// Whether prompt enhancement was enabled
    var promptEnhanceOpted = false

    /// Enhanced version of the prompt (if enhancement was used)
    var promptAfterEnhance = ""

    /// Style option selected (model-dependent)
    var style = ""

    /// Variant option selected (model-dependent)
    var variant = ""

    /// Quality tier selected (model-dependent)
    var quality = ""

    /// Output dimensions as "WIDTHxHEIGHT"
    var dimensions = "1024x1024"

    /// File size in bytes
    var size = 0

    /// Cost incurred for this generation
    var creditUsed: Double = 0

    /// Whether generation succeeded or failed
    var status = EnumGenerationStatus.GENERATED

    /// Extracted dominant colors for UI theming
    var colorPalette: [String] = []

    /// Prompt as modified by the model (some models revise prompts)
    var modelRevisedPrompt: String? = nil

    /// Path/ID of source image for image-to-image generation
    var hasClientImage = false

    var hasClientMask = false

    /// Number of reference images used in generation
    var clientReferenceImagesCount = 0

    /// Negative prompt (what to avoid)
    var negativePrompt: String? = nil

    /// Search prompt for search-and-replace operations
    var searchPrompt: String? = nil

    /// Type of content generated (image, video, 3D)
    var contentType = EnumGenerationContentType.IMAGE_2D

    /// Provider-specific metadata (e.g., Veo generation URI)
    var metadata: [String: String] = [:]

    /// Agent run ID (if created during agent execution)
    var runId: UUID? = nil

    /// Parent agent ID (if created by an agent)
    var agentId: UUID? = nil

    /// Whether this generation is hidden from the main gallery
    var isHidden = false

    /// Links this generation to a realtime editing session (nil for normal generations)
    var realtimeSessionId: UUID? = nil

    init(
        id: UUID,
        setId: UUID,
        projectId: UUID = Project.defaultProjectId,
        modelId: String,
        prompt: String,
        promptEnhanceOpted: Bool,
        promptAfterEnhance: String,
        style: String = "Natural",
        variant: String = "Normal",
        quality: String = "",
        dimensions: String,
        size: Int,
        creditUsed: Double,
        status: EnumGenerationStatus,
        colorPalette: [String],
        modelRevisedPrompt: String? = nil,
        clientImage: String? = nil,
        clientMask: String? = nil,
        clientReferenceImagesCount: Int = 0,
        negativePrompt: String? = nil,
        searchPrompt: String? = nil,
        contentType: EnumGenerationContentType = EnumGenerationContentType.IMAGE_2D,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.setId = setId
        self.projectId = projectId
        createdAt = Date()
        self.modelId = modelId
        self.prompt = prompt
        self.promptEnhanceOpted = promptEnhanceOpted
        self.promptAfterEnhance = promptAfterEnhance
        self.style = style
        self.variant = variant
        self.quality = quality
        self.dimensions = dimensions
        self.size = size
        self.creditUsed = creditUsed
        self.status = status
        self.colorPalette = colorPalette
        self.modelRevisedPrompt = modelRevisedPrompt
        hasClientImage = clientImage != nil
        hasClientMask = clientMask != nil
        self.clientReferenceImagesCount = clientReferenceImagesCount
        self.negativePrompt = negativePrompt
        self.searchPrompt = searchPrompt
        self.contentType = contentType

        self.metadata = metadata
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        setId = try container.decode(UUID.self, forKey: .setId)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId) ?? Project.defaultProjectId
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modelId = try container.decode(String.self, forKey: .modelId)
        prompt = try container.decode(String.self, forKey: .prompt)
        promptEnhanceOpted = try container.decode(Bool.self, forKey: .promptEnhanceOpted)
        promptAfterEnhance = try container.decode(String.self, forKey: .promptAfterEnhance)
        style = try container.decode(String.self, forKey: .style)
        variant = try container.decode(String.self, forKey: .variant)
        quality = try container.decode(String.self, forKey: .quality)
        dimensions = try container.decode(String.self, forKey: .dimensions)
        size = try container.decode(Int.self, forKey: .size)
        creditUsed = try container.decode(Double.self, forKey: .creditUsed)
        status = try container.decode(EnumGenerationStatus.self, forKey: .status)
        colorPalette = try container.decode([String].self, forKey: .colorPalette)
        modelRevisedPrompt = try container.decodeIfPresent(String.self, forKey: .modelRevisedPrompt)
        hasClientImage = try container.decodeIfPresent(Bool.self, forKey: .hasClientImage) ?? false
        hasClientMask = try container.decodeIfPresent(Bool.self, forKey: .hasClientMask) ?? false
        clientReferenceImagesCount = try container.decodeIfPresent(Int.self, forKey: .clientReferenceImagesCount) ?? 0
        negativePrompt = try container.decodeIfPresent(String.self, forKey: .negativePrompt)
        searchPrompt = try container.decodeIfPresent(String.self, forKey: .searchPrompt)
        contentType = try container.decode(EnumGenerationContentType.self, forKey: .contentType)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
        runId = try container.decodeIfPresent(UUID.self, forKey: .runId)
        agentId = try container.decodeIfPresent(UUID.self, forKey: .agentId)
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        realtimeSessionId = try container.decodeIfPresent(UUID.self, forKey: .realtimeSessionId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(setId, forKey: .setId)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modelId, forKey: .modelId)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(promptEnhanceOpted, forKey: .promptEnhanceOpted)
        try container.encode(promptAfterEnhance, forKey: .promptAfterEnhance)
        try container.encode(style, forKey: .style)
        try container.encode(variant, forKey: .variant)
        try container.encode(quality, forKey: .quality)
        try container.encode(dimensions, forKey: .dimensions)
        try container.encode(size, forKey: .size)
        try container.encode(creditUsed, forKey: .creditUsed)
        try container.encode(status, forKey: .status)
        try container.encode(colorPalette, forKey: .colorPalette)
        try container.encodeIfPresent(modelRevisedPrompt, forKey: .modelRevisedPrompt)
        try container.encode(hasClientImage, forKey: .hasClientImage)
        try container.encode(hasClientMask, forKey: .hasClientMask)
        try container.encode(clientReferenceImagesCount, forKey: .clientReferenceImagesCount)
        try container.encodeIfPresent(negativePrompt, forKey: .negativePrompt)
        try container.encodeIfPresent(searchPrompt, forKey: .searchPrompt)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(metadata, forKey: .metadata)
        try container.encodeIfPresent(runId, forKey: .runId)
        try container.encodeIfPresent(agentId, forKey: .agentId)
        try container.encode(isHidden, forKey: .isHidden)
        try container.encodeIfPresent(realtimeSessionId, forKey: .realtimeSessionId)
    }
}
