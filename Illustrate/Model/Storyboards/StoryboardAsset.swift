// MARK: - StoryboardAsset.swift

// Defines reference assets for storyboard scenes.
//
// StoryboardAssets are user-uploaded images that can be used as:
// - First frame references (starting point for a scene)
// - Last frame references (ending point for a scene)
// - Visual reference for prompt guidance
//
// ## Storage
// Asset images are stored in iCloud Documents using the asset's UUID,
// following the same pattern as Generation entities.
//
// ## Usage
// In frame-based storyboards, assets are dragged from the assets panel
// onto scenes in the timeline to set first/last frames.

import SwiftData
import SwiftUI

// MARK: - Storyboard Asset Model

/// SwiftData model representing a reference image for storyboard scenes.
///
/// Assets are uploaded by users and stored in iCloud Documents.
/// They can be assigned to scenes as first/last frame references
/// in frame-based storyboard mode.
///
/// ## File Storage
/// The asset image is stored at:
/// `{iCloudDocuments}/storyboard-assets/{id}.png`
///
/// ## Thumbnail
/// A thumbnail is generated and cached for display in the assets panel.
@Model
class StoryboardAsset: Identifiable, Codable {
    #Index<StoryboardAsset>([\.storyboardId])

    enum CodingKeys: CodingKey {
        case id
        case storyboardId
        case createdAt
        case name
        case width
        case height
    }

    var id = UUID()

    var storyboardId = UUID()

    var storyboard: Storyboard?

    /// When this asset was uploaded
    var createdAt = Date()

    var name = "Untitled Asset"

    /// Image width in pixels
    var width = 0

    /// Image height in pixels
    var height = 0

    /// Creates a new storyboard asset.
    ///
    /// - Parameters:
    ///   - storyboardId: Parent storyboard
    ///   - name: Display name
    ///   - width: Image width
    ///   - height: Image height
    init(
        storyboardId: UUID,
        name: String = "Untitled Asset",
        width: Int = 0,
        height: Int = 0
    ) {
        id = UUID()
        self.storyboardId = storyboardId
        createdAt = Date()
        self.name = name
        self.width = width
        self.height = height
    }

    // MARK: - Codable Implementation

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        storyboardId = try container.decode(UUID.self, forKey: .storyboardId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        name = try container.decode(String.self, forKey: .name)
        width = try container.decodeIfPresent(Int.self, forKey: .width) ?? 0
        height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(storyboardId, forKey: .storyboardId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(name, forKey: .name)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }

    // MARK: - Computed Properties

    /// Dimensions as a formatted string
    var dimensionsString: String {
        guard width > 0, height > 0 else { return "" }
        return "\(width)×\(height)"
    }

    /// Aspect ratio of the image
    var aspectRatio: CGFloat {
        guard width > 0, height > 0 else { return 16.0 / 9.0 }
        return CGFloat(width) / CGFloat(height)
    }
}
