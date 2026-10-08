// MARK: - RealtimeEditLayer.swift

// Defines the layer model for Realtime Edit canvas.
//
// Layers represent individual elements on the editing canvas. Each layer can be:
// - Image: A static image loaded from the photo library or generated content
// - Drawing: Freeform brush strokes created with PencilKit
// - Shape: Geometric shapes (rectangles, circles, lines)
//
// ## Layer Management
// Layers are ordered using zIndex (higher values appear on top). Each layer
// can be independently moved, resized, shown/hidden, and locked to prevent
// accidental modifications.
//
// ## Content Storage
// - Images: Stored in Documents/iCloud, referenced by imagePath
// - Drawings: PKDrawing serialized to drawingData (Data)
// - Shapes: Path data serialized to shapePathData (Data)

import SwiftData
import SwiftUI

// MARK: - Layer Type Enum

/// Specifies the type of content a layer contains.
enum LayerType: String, Codable, CaseIterable, Identifiable {
    var id: String {
        rawValue
    }

    /// Static image layer
    case image
    /// Freeform drawing layer (PencilKit)
    case drawing
    /// Geometric shape layer
    case shape

    /// Human-readable name for UI display
    var displayName: String {
        switch self {
        case .image: "Image"
        case .drawing: "Drawing"
        case .shape: "Shape"
        }
    }

    /// SF Symbol icon name
    var icon: String {
        switch self {
        case .image: "photo.fill"
        case .drawing: "paintbrush.fill"
        case .shape: "square.on.circle"
        }
    }
}

// MARK: - Shape Type Enum

/// Specifies the geometric shape for shape layers.
enum ShapeType: String, Codable, CaseIterable, Identifiable {
    var id: String {
        rawValue
    }

    case triangle
    case square
    case circle

    /// Human-readable name for UI display
    var displayName: String {
        switch self {
        case .triangle: "Triangle"
        case .square: "Square"
        case .circle: "Circle"
        }
    }

    /// SF Symbol icon name
    var icon: String {
        switch self {
        case .triangle: "triangle"
        case .square: "square"
        case .circle: "circle"
        }
    }

    /// SF Symbol filled icon name
    var filledIcon: String {
        switch self {
        case .triangle: "triangle.fill"
        case .square: "square.fill"
        case .circle: "circle.fill"
        }
    }
}

// MARK: - Realtime Edit Layer Model

/// SwiftData model representing a layer on the realtime edit canvas.
///
/// Layers are the building blocks of compositions. Each layer has:
/// - Position and size on the canvas
/// - Z-index for ordering (higher = on top)
/// - Visibility and lock state
/// - Type-specific content (image path, drawing data, or shape data)
///
/// ## Canvas Positioning
/// Conforms to CanvasPositionable protocol for coordinate system integration.
@Model
class RealtimeEditLayer: Identifiable, Codable {
    #Index<RealtimeEditLayer>([\.sessionId])

    enum CodingKeys: CodingKey {
        case id
        case sessionId
        case layerType
        case name
        case createdAt
        case positionX
        case positionY
        case width
        case height
        case zIndex
        case isVisible
        case isLocked
        case imagePath
        case drawingData
        case shapeType
        case shapePathData
        case strokeColor
        case fillColor
    }

    var id = UUID()

    /// Parent session this layer belongs to
    var sessionId = UUID()

    var session: RealtimeEditSession?

    /// Type of layer (image, drawing, or shape)
    var layerType = LayerType.image

    /// Display name shown in layers panel
    var name = "Layer"

    var createdAt = Date()

    // MARK: Position and Transform

    /// X position on the canvas (world coordinates)
    var positionX: CGFloat = 0

    /// Y position on the canvas (world coordinates)
    var positionY: CGFloat = 0

    /// Width of the layer
    var width: CGFloat = ImageProcessing.defaultLayerSize

    /// Height of the layer
    var height: CGFloat = ImageProcessing.defaultLayerSize

    /// Stacking order (higher values appear on top)
    var zIndex = 0

    // MARK: Visibility and State

    /// When false, layer is hidden from canvas and preview
    var isVisible = true

    /// When true, layer cannot be selected or modified
    var isLocked = false

    // MARK: Content Storage

    /// Image file name (for image layers)
    /// File is stored in Documents/iCloud directory
    var imagePath: String?

    /// Serialized PKDrawing data (for drawing layers)
    var drawingData: Data?

    /// Shape type (for shape layers)
    var shapeType: ShapeType?

    /// Serialized Path data (for shape layers)
    var shapePathData: Data?

    /// Hex color string for shape stroke (e.g., "#FF0000")
    var strokeColor: String?

    /// Hex color string for shape fill (e.g., "#FF0000")
    var fillColor: String?

    // MARK: - Computed Properties

    /// Convenient CGPoint access to layer position.
    var position: CGPoint {
        get { CGPoint(x: positionX, y: positionY) }
        set {
            positionX = newValue.x
            positionY = newValue.y
        }
    }

    /// Convenient CGSize access to layer dimensions.
    var size: CGSize {
        get { CGSize(width: width, height: height) }
        set {
            width = newValue.width
            height = newValue.height
        }
    }

    /// Layer bounds in world coordinates.
    var bounds: CGRect {
        CGRect(x: positionX, y: positionY, width: width, height: height)
    }

    /// Creates a new layer.
    ///
    /// - Parameters:
    ///   - sessionId: Parent session UUID
    ///   - layerType: Type of layer (image, drawing, shape)
    ///   - name: Display name
    ///   - position: Initial position on canvas
    ///   - size: Initial size
    ///   - zIndex: Stacking order
    init(
        sessionId: UUID,
        layerType: LayerType,
        name: String = "Layer",
        position: CGPoint = .zero,
        size: CGSize = CGSize(width: ImageProcessing.defaultLayerSize, height: ImageProcessing.defaultLayerSize),
        zIndex: Int = 0
    ) {
        id = UUID()
        self.sessionId = sessionId
        self.layerType = layerType
        self.name = name
        createdAt = Date()
        positionX = position.x
        positionY = position.y
        width = size.width
        height = size.height
        self.zIndex = zIndex
        isVisible = true
        isLocked = false
    }

    // MARK: - Codable Implementation

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sessionId = try container.decode(UUID.self, forKey: .sessionId)
        layerType = try container.decode(LayerType.self, forKey: .layerType)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        positionX = try container.decode(CGFloat.self, forKey: .positionX)
        positionY = try container.decode(CGFloat.self, forKey: .positionY)
        width = try container.decode(CGFloat.self, forKey: .width)
        height = try container.decode(CGFloat.self, forKey: .height)
        zIndex = try container.decode(Int.self, forKey: .zIndex)
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
        drawingData = try container.decodeIfPresent(Data.self, forKey: .drawingData)
        shapeType = try container.decodeIfPresent(ShapeType.self, forKey: .shapeType)
        shapePathData = try container.decodeIfPresent(Data.self, forKey: .shapePathData)
        strokeColor = try container.decodeIfPresent(String.self, forKey: .strokeColor)
        fillColor = try container.decodeIfPresent(String.self, forKey: .fillColor)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(layerType, forKey: .layerType)
        try container.encode(name, forKey: .name)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(positionX, forKey: .positionX)
        try container.encode(positionY, forKey: .positionY)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(zIndex, forKey: .zIndex)
        try container.encode(isVisible, forKey: .isVisible)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encodeIfPresent(imagePath, forKey: .imagePath)
        try container.encodeIfPresent(drawingData, forKey: .drawingData)
        try container.encodeIfPresent(shapeType, forKey: .shapeType)
        try container.encodeIfPresent(shapePathData, forKey: .shapePathData)
        try container.encodeIfPresent(strokeColor, forKey: .strokeColor)
        try container.encodeIfPresent(fillColor, forKey: .fillColor)
    }
}

// MARK: - CanvasPositionable Conformance

extension RealtimeEditLayer: CanvasPositionable {}
