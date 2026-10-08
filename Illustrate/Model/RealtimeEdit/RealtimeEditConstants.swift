// MARK: - RealtimeEditConstants.swift

// Constants for Realtime Edit feature.
//
// Centralizes default values, limits, and configuration constants
// to improve maintainability and avoid magic numbers throughout the codebase.

import Foundation

// MARK: - Default Colors

enum RealtimeEditColors {
    static let defaultBrush = "73353D"

    static let defaultShape = "73353D"
}

// MARK: - Brush Settings

enum BrushSettings {
    /// Default brush size in points
    static let defaultSize: CGFloat = 24.0

    /// Minimum brush size in points
    static let minSize: CGFloat = 16.0

    /// Maximum brush size in points
    static let maxSize: CGFloat = 48.0
}

// MARK: - Image Processing

enum ImageProcessing {
    /// Maximum dimension for saved images (optimizes storage and memory)
    static let maxSaveDimension: CGFloat = 1024

    /// Maximum dimension for canvas display (optimizes rendering performance)
    static let maxDisplayDimension: CGFloat = 300

    /// Default layer size when creating new layers
    static let defaultLayerSize: CGFloat = 512
}

// MARK: - Canvas Settings

enum CanvasSettings {
    /// Default canvas zoom level (1.0 = 100%)
    static let defaultScale: CGFloat = 1.0

    /// Default canvas offset from origin
    static let defaultOffset: CGFloat = 0.0

    /// Default canvas dimensions
    static let defaultWidth: CGFloat = 1024
    static let defaultHeight: CGFloat = 1024
}

// MARK: - History Settings

enum HistorySettings {
    /// Maximum number of undo/redo actions to retain
    static let maxHistorySize = 50
}

// MARK: - Generation Settings

enum GenerationSettings {
    /// Default image dimensions for generation
    static let defaultDimensions = "1024x1024"

    /// Random seed range
    static let seedRange = 0 ... 999_999_999
}

// MARK: - Generation Speed Options

/// Available generation speed options for realtime editing.
enum GenerationSpeed: Double, CaseIterable, Identifiable {
    case fivePerSecond = 200.0
    case twoPerSecond = 500.0
    case onePerSecond = 1000.0
    case onePerTwoSeconds = 2000.0
    case onePerFiveSeconds = 5000.0

    var id: Double {
        rawValue
    }

    /// Human-readable label for the speed option
    var label: String {
        switch self {
        case .fivePerSecond: "5 per second"
        case .twoPerSecond: "2 per second"
        case .onePerSecond: "1 per second"
        case .onePerTwoSeconds: "1 per 2 seconds"
        case .onePerFiveSeconds: "1 per 5 seconds"
        }
    }

    /// Interval in milliseconds
    var intervalMs: Double {
        rawValue
    }

    /// Default speed option
    static let defaultSpeed: GenerationSpeed = .twoPerSecond

    /// Creates a GenerationSpeed from a millisecond value, defaulting if not found
    static func from(ms: Double) -> GenerationSpeed {
        allCases.first { $0.rawValue == ms } ?? .defaultSpeed
    }
}

// MARK: - Realtime Engine Settings

enum RealtimeEngineSettings {
    /// Engine loop polling interval in milliseconds
    static let engineLoopIntervalMs = 50.0
}
