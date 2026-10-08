// MARK: - ProductPhotoshoot.swift

// Defines the ProductPhotoshoot model for product listing photograph generation.
//
// ProductPhotoshoots allow users to create professional product photographs
// by combining product images with studio backdrops using AI image generation
// models that support reference images.
//
// ## Supported Models
// Models must have `supportsReferenceImages == true` (maxReferenceImages > 0)
// Examples: GPT Image 1.5 variants, etc.
//
// ## Supported Dimensions
// Only specific aspect ratios are supported to match backdrop assets:
// - 9:16 (Portrait)
// - 16:9 (Landscape)
// - 3:4 (Portrait)
// - 4:3 (Landscape)

import SwiftData
import SwiftUI

// MARK: - Camera Angle

/// Camera angle options for product photography.
enum PhotoshootCameraAngle: String, Codable, CaseIterable, Identifiable {
    var id: String {
        rawValue
    }

    case left
    case left45 = "left_45"
    case center
    case right45 = "right_45"
    case right
    case top

    var displayName: String {
        switch self {
        case .left: "Left"
        case .left45: "Left 45°"
        case .center: "Center"
        case .right45: "Right 45°"
        case .right: "Right"
        case .top: "Top"
        }
    }

    var icon: String {
        switch self {
        case .left: "arrow.left"
        case .left45: "arrow.up.left"
        case .center: "circle"
        case .right45: "arrow.up.right"
        case .right: "arrow.right"
        case .top: "arrow.up"
        }
    }
}

// MARK: - Product Positioning

/// Product positioning options for photography.
enum PhotoshootProductPosition: String, Codable, CaseIterable, Identifiable {
    var id: String {
        rawValue
    }

    case onGround = "on_ground"
    case floatingStraight = "floating_straight"
    case floatingTilted = "floating_tilted"

    var displayName: String {
        switch self {
        case .onGround: "On Ground"
        case .floatingStraight: "Floating (Straight)"
        case .floatingTilted: "Floating (Tilted)"
        }
    }

    var icon: String {
        switch self {
        case .onGround: "square.on.square"
        case .floatingStraight: "arrow.up.square"
        case .floatingTilted: "arrow.up.forward.square"
        }
    }
}

// MARK: - Photoshoot Dimension

/// Supported aspect ratios for product photoshoots.
///
/// These dimensions are constrained to match available backdrop assets
/// in the app bundle (shoots_bg_{dimension}_{index}).
enum PhotoshootDimension: String, Codable, CaseIterable, Identifiable {
    var id: String {
        rawValue
    }

    case portrait9x16 = "9:16"
    case landscape16x9 = "16:9"
    case portrait3x4 = "3:4"
    case landscape4x3 = "4:3"
    case portrait2x3 = "2:3"
    case landscape3x2 = "3:2"

    var displayName: String {
        switch self {
        case .portrait9x16: "9:16 Portrait"
        case .landscape16x9: "16:9 Landscape"
        case .portrait3x4: "3:4 Portrait"
        case .landscape4x3: "4:3 Landscape"
        case .portrait2x3: "2:3 Portrait"
        case .landscape3x2: "3:2 Landscape"
        }
    }

    var assetPrefix: String {
        switch self {
        case .portrait9x16: "shoots_bg_9_16"
        case .landscape16x9: "shoots_bg_16_9"
        case .portrait3x4: "shoots_bg_3_4"
        case .landscape4x3: "shoots_bg_4_3"
        case .portrait2x3: "shoots_bg_2_3"
        case .landscape3x2: "shoots_bg_3_2"
        }
    }

    var pixelDimensions: String {
        switch self {
        case .portrait9x16: "1080x1920"
        case .landscape16x9: "1920x1080"
        case .portrait3x4: "1080x1440"
        case .landscape4x3: "1440x1080"
        case .portrait2x3: "1024x1536"
        case .landscape3x2: "1536x1024"
        }
    }

    /// Returns the representation accepted by a selected generation model.
    func generationDimension(supportedDimensions: [String]) -> String {
        if supportedDimensions.contains(rawValue) {
            return rawValue
        }
        return pixelDimensions
    }

    var aspectRatio: CGFloat {
        switch self {
        case .portrait9x16: 9.0 / 16.0
        case .landscape16x9: 16.0 / 9.0
        case .portrait3x4: 3.0 / 4.0
        case .landscape4x3: 4.0 / 3.0
        case .portrait2x3: 2.0 / 3.0
        case .landscape3x2: 3.0 / 2.0
        }
    }

    var isPortrait: Bool {
        switch self {
        case .portrait9x16, .portrait3x4, .portrait2x3: true
        case .landscape16x9, .landscape4x3, .landscape3x2: false
        }
    }
}

// MARK: - ProductPhotoshoot Model

/// SwiftData model representing a product photoshoot project.
///
/// A ProductPhotoshoot is a container for generating product listing photographs.
/// Users configure the model, dimensions, and product description once, then
/// can generate multiple photos with different backdrops and object arrangements.
///
/// ## Configuration
/// - `modelId/providerId`: AI model for generation (must support reference images)
/// - `dimensions`: Aspect ratio for generated images
/// - `productDescription`: Optional description to enhance prompts
@Model
class ProductPhotoshoot: Identifiable, Codable, Pinnable {
    enum CodingKeys: CodingKey {
        case id
        case projectId
        case createdAt
        case name
        case isPinned
        case modelId
        case providerId
        case dimensions
        case productDescription
        case selectedBackdropIndex
        case customBackdropData
        case productObjectsData
        case cameraAngle
        case productPosition
    }

    var id = UUID()
    var projectId: UUID = Project.defaultProjectId
    var project: Project?
    var createdAt = Date()
    var name = "Untitled Photoshoot"
    var isPinned = false
    var modelId = ""
    var providerId = ""
    var dimensions = PhotoshootDimension.portrait9x16.rawValue
    var productDescription = ""

    var selectedBackdropIndex: Int?

    @Attribute(.externalStorage)
    var customBackdropData: Data?

    @Attribute(.externalStorage)
    var productObjectsData: [Data] = []

    var cameraAngle = PhotoshootCameraAngle.center.rawValue
    var productPosition = PhotoshootProductPosition.onGround.rawValue

    @Relationship(deleteRule: .cascade, inverse: \ProductPhotoshootItem.photoshoot)
    var items: [ProductPhotoshootItem]? = nil

    var cameraAngleEnum: PhotoshootCameraAngle {
        get { PhotoshootCameraAngle(rawValue: cameraAngle) ?? .center }
        set { cameraAngle = newValue.rawValue }
    }

    var productPositionEnum: PhotoshootProductPosition {
        get { PhotoshootProductPosition(rawValue: productPosition) ?? .onGround }
        set { productPosition = newValue.rawValue }
    }

    /// Creates a new product photoshoot with the specified configuration.
    ///
    /// - Parameters:
    ///   - name: Display name for the photoshoot
    ///   - projectId: Parent project
    ///   - modelId: Image generation model ID
    ///   - providerId: Provider ID for the model
    ///   - dimensions: Aspect ratio for images
    ///   - productDescription: Optional product description
    init(
        name: String = "Untitled Photoshoot",
        projectId: UUID = Project.defaultProjectId,
        modelId: String = "",
        providerId: String = "",
        dimensions: PhotoshootDimension = .portrait9x16,
        productDescription: String = ""
    ) {
        id = UUID()
        self.name = name
        self.projectId = projectId
        createdAt = Date()
        isPinned = false
        self.modelId = modelId
        self.providerId = providerId
        self.dimensions = dimensions.rawValue
        self.productDescription = productDescription
    }

    var dimensionsEnum: PhotoshootDimension {
        PhotoshootDimension(rawValue: dimensions) ?? .portrait9x16
    }

    // MARK: - Codable Implementation

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId) ?? Project.defaultProjectId
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        name = try container.decode(String.self, forKey: .name)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        modelId = try container.decodeIfPresent(String.self, forKey: .modelId) ?? ""
        providerId = try container.decodeIfPresent(String.self, forKey: .providerId) ?? ""
        dimensions = try container.decodeIfPresent(String.self, forKey: .dimensions) ?? PhotoshootDimension.portrait9x16
            .rawValue
        productDescription = try container.decodeIfPresent(String.self, forKey: .productDescription) ?? ""
        selectedBackdropIndex = try container.decodeIfPresent(Int.self, forKey: .selectedBackdropIndex)
        customBackdropData = try container.decodeIfPresent(Data.self, forKey: .customBackdropData)
        productObjectsData = try container.decodeIfPresent([Data].self, forKey: .productObjectsData) ?? []
        cameraAngle = try container.decodeIfPresent(String.self, forKey: .cameraAngle) ?? PhotoshootCameraAngle.center
            .rawValue
        productPosition = try container
            .decodeIfPresent(String.self, forKey: .productPosition) ?? PhotoshootProductPosition
            .onGround.rawValue
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(name, forKey: .name)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(modelId, forKey: .modelId)
        try container.encode(providerId, forKey: .providerId)
        try container.encode(dimensions, forKey: .dimensions)
        try container.encode(productDescription, forKey: .productDescription)
        try container.encodeIfPresent(selectedBackdropIndex, forKey: .selectedBackdropIndex)
        try container.encodeIfPresent(customBackdropData, forKey: .customBackdropData)
        try container.encode(productObjectsData, forKey: .productObjectsData)
        try container.encode(cameraAngle, forKey: .cameraAngle)
        try container.encode(productPosition, forKey: .productPosition)
    }
}
