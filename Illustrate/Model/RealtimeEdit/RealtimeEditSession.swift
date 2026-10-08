// MARK: - RealtimeEditSession.swift

// Defines the Realtime Edit session model for canvas-based image editing.
//
// Realtime Edit sessions provide a layer-based editing interface where users
// can combine images, drawings, and shapes into compositions. Each session
// maintains its own canvas viewport state and prompt bar configuration.
//
// ## Structure
// Each session contains:
// - RealtimeEditLayers: Image, drawing, or shape layers positioned on canvas
// - Canvas viewport state (zoom, pan)
// - Prompt bar configuration for LLM integration
//
// ## Canvas State
// Like Flow Canvas and Agent Builder, Realtime Edit persists viewport state
// so users return to their previous view when reopening a session.

import SwiftData
import SwiftUI

// MARK: - Realtime Edit Session Model

/// SwiftData model representing a realtime editing session.
///
/// Sessions provide a canvas-based editor with layer management, drawing tools,
/// and a prompt bar for future LLM-powered editing capabilities.
///
/// ## Layer Management
/// Layers are stored as separate RealtimeEditLayer entities with a sessionId
/// relationship. This allows efficient querying and updating of individual layers.
///
/// ## Configuration Storage
/// The prompt bar configuration (model selection, dimensions, backoff seconds)
/// is stored as JSON in configurationData and accessed via a computed property.
@Model
class RealtimeEditSession: Identifiable, Codable, Pinnable {
    #Index<RealtimeEditSession>([\.projectId])

    enum CodingKeys: CodingKey {
        case id
        case projectId
        case createdAt
        case name
        case canvasScale
        case canvasOffsetX
        case canvasOffsetY
        case isLocked
        case isPinned
        case selectedProviderId
        case selectedModelId
        case selectedDimensions
        case selectedToolRawValue
        case brushColorHex
        case brushSize
        case shapeColorHex
        case selectedShapeTypeRawValue
        case seed
        case generationSpeedMs
        case configurationData
        case lastGenerationFilePath
    }

    var id = UUID()

    var projectId: UUID = Project.defaultProjectId

    var project: Project?

    var createdAt = Date()

    var name = "Untitled Edit"

    // MARK: Canvas State

    /// Current zoom level (1.0 = 100%)
    var canvasScale = 1.0

    /// Horizontal pan offset from origin
    var canvasOffsetX = 0.0

    /// Vertical pan offset from origin
    var canvasOffsetY = 0.0

    /// When true, prevents modifications
    var isLocked = false

    /// When true, the session is pinned to the top of the list
    var isPinned = false

    // MARK: Prompt Bar State (Direct Properties for Change Tracking)

    /// Currently selected provider ID
    var selectedProviderId = ""

    /// Currently selected model ID
    var selectedModelId = ""

    /// Selected image dimensions
    var selectedDimensions = GenerationSettings.defaultDimensions

    /// Selected editing tool
    var selectedToolRawValue = "select"

    // MARK: Brush State

    /// Brush color as hex string (e.g., "FF0000")
    var brushColorHex = RealtimeEditColors.defaultBrush

    /// Brush size in points (16-48)
    var brushSize = BrushSettings.defaultSize

    // MARK: Shape State

    /// Shape fill color as hex string (e.g., "3478F6")
    var shapeColorHex = RealtimeEditColors.defaultShape

    /// Selected shape type raw value
    var selectedShapeTypeRawValue = "square"

    // MARK: Generation Seed

    /// Random seed for deterministic generation
    var seed = Int.random(in: GenerationSettings.seedRange)

    // MARK: Generation Speed

    /// Generation speed in milliseconds (interval between generations)
    var generationSpeedMs = 500.0

    // MARK: Prompt Bar Configuration

    /// JSON-encoded prompt bar configuration for additional settings
    var configurationData: Data?

    // MARK: Last Generation State

    /// File path to the last generated image for this session.
    /// Used to restore the preview when returning to the session.
    var lastGenerationFilePath: String?

    @Relationship(deleteRule: .cascade, inverse: \RealtimeEditLayer.session)
    var layers: [RealtimeEditLayer]? = nil

    /// Typed access to prompt bar configuration.
    ///
    /// Decodes from configurationData JSON, returns default if unavailable.
    var configuration: RealtimeEditConfiguration {
        get {
            guard let data = configurationData else { return RealtimeEditConfiguration() }
            do {
                return try JSONDecoder().decode(RealtimeEditConfiguration.self, from: data)
            } catch {
                AppLogger.data.error("Failed to decode RealtimeEditConfiguration: \(error, privacy: .public)")
                return RealtimeEditConfiguration()
            }
        }
        set {
            do {
                configurationData = try JSONEncoder().encode(newValue)
            } catch {
                configurationData = nil
                AppLogger.data.error("Failed to encode RealtimeEditConfiguration: \(error, privacy: .public)")
            }
        }
    }

    /// Creates a new Realtime Edit session.
    ///
    /// - Parameters:
    ///   - name: Display name for the session
    ///   - projectId: Parent project
    init(name: String = "Untitled Edit", projectId: UUID = Project.defaultProjectId) {
        id = UUID()
        self.name = name
        self.projectId = projectId
        createdAt = Date()
        canvasScale = CanvasSettings.defaultScale
        canvasOffsetX = CanvasSettings.defaultOffset
        canvasOffsetY = CanvasSettings.defaultOffset
        isLocked = false
        isPinned = false
        selectedProviderId = ""
        selectedModelId = ""
        selectedDimensions = GenerationSettings.defaultDimensions
        selectedToolRawValue = "select"
        brushColorHex = RealtimeEditColors.defaultBrush
        brushSize = BrushSettings.defaultSize
        shapeColorHex = RealtimeEditColors.defaultShape
        selectedShapeTypeRawValue = "square"
        seed = Int.random(in: GenerationSettings.seedRange)
        generationSpeedMs = 500.0
    }

    // MARK: - Codable Implementation

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId) ?? Project.defaultProjectId
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        name = try container.decode(String.self, forKey: .name)
        canvasScale = try container.decodeIfPresent(Double.self, forKey: .canvasScale) ?? CanvasSettings.defaultScale
        canvasOffsetX = try container.decodeIfPresent(Double.self, forKey: .canvasOffsetX) ?? CanvasSettings
            .defaultOffset
        canvasOffsetY = try container.decodeIfPresent(Double.self, forKey: .canvasOffsetY) ?? CanvasSettings
            .defaultOffset
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        selectedProviderId = try container.decodeIfPresent(String.self, forKey: .selectedProviderId) ?? ""
        selectedModelId = try container.decodeIfPresent(String.self, forKey: .selectedModelId) ?? ""
        selectedDimensions = try container
            .decodeIfPresent(String.self, forKey: .selectedDimensions) ?? GenerationSettings.defaultDimensions
        selectedToolRawValue = try container.decodeIfPresent(String.self, forKey: .selectedToolRawValue) ?? "select"
        brushColorHex = try container.decodeIfPresent(String.self, forKey: .brushColorHex) ?? RealtimeEditColors
            .defaultBrush
        brushSize = try container.decodeIfPresent(Double.self, forKey: .brushSize) ?? BrushSettings.defaultSize
        shapeColorHex = try container.decodeIfPresent(String.self, forKey: .shapeColorHex) ?? RealtimeEditColors
            .defaultShape
        selectedShapeTypeRawValue = try container.decodeIfPresent(String.self, forKey: .selectedShapeTypeRawValue) ?? "square"
        seed = try container.decodeIfPresent(Int.self, forKey: .seed) ?? Int.random(in: GenerationSettings.seedRange)
        generationSpeedMs = try container.decodeIfPresent(Double.self, forKey: .generationSpeedMs) ?? 500.0
        configurationData = try container.decodeIfPresent(Data.self, forKey: .configurationData)
        lastGenerationFilePath = try container.decodeIfPresent(String.self, forKey: .lastGenerationFilePath)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(name, forKey: .name)
        try container.encode(canvasScale, forKey: .canvasScale)
        try container.encode(canvasOffsetX, forKey: .canvasOffsetX)
        try container.encode(canvasOffsetY, forKey: .canvasOffsetY)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(selectedProviderId, forKey: .selectedProviderId)
        try container.encode(selectedModelId, forKey: .selectedModelId)
        try container.encode(selectedDimensions, forKey: .selectedDimensions)
        try container.encode(selectedToolRawValue, forKey: .selectedToolRawValue)
        try container.encode(brushColorHex, forKey: .brushColorHex)
        try container.encode(brushSize, forKey: .brushSize)
        try container.encode(shapeColorHex, forKey: .shapeColorHex)
        try container.encode(selectedShapeTypeRawValue, forKey: .selectedShapeTypeRawValue)
        try container.encode(seed, forKey: .seed)
        try container.encode(generationSpeedMs, forKey: .generationSpeedMs)
        try container.encodeIfPresent(configurationData, forKey: .configurationData)
        try container.encodeIfPresent(lastGenerationFilePath, forKey: .lastGenerationFilePath)
    }
}
