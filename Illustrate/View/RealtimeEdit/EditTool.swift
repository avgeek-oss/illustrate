// MARK: - EditTool.swift

// Tool enumeration for Realtime Edit canvas.
//
// Defines the available editing tools and their display properties.
// Each tool has:
// - Icon: SF Symbol for toolbar button
// - Label: Display name for tooltips
// - Description: Help text explaining the tool's function
//
// ## Tool Modes
// - **Select**: Default tool for selecting, moving, resizing, and cropping layers
// - **Brush**: Freeform drawing with PencilKit (red strokes)
// - **Shape**: Create geometric shapes (rectangles, circles, lines)
// - **Attach**: Open image picker to add image layers
//
// ## Usage
// The selected tool determines which UI affordances are shown and
// which user interactions are enabled on the canvas.

import SwiftUI

// MARK: - Edit Tool Enum

/// Available editing tools for the Realtime Edit canvas.
///
/// Each tool enables different interaction modes on the canvas.
/// Only one tool can be active at a time.
enum EditTool: String, CaseIterable, Identifiable {
    var id: String {
        rawValue
    }

    /// Select, move, resize, and crop layers
    case select

    /// Freeform brush drawing (PencilKit)
    case brush

    /// Create geometric shapes
    case shape

    /// Add images from photo library
    case attach

    // MARK: - Display Properties

    /// SF Symbol icon name for the tool button
    var icon: String {
        switch self {
        case .select:
            "pointer.arrow"
        case .brush:
            "paintbrush.pointed"
        case .shape:
            "square.on.circle"
        case .attach:
            "photo.on.rectangle.angled"
        }
    }

    /// Display label for tooltips and accessibility
    var label: String {
        switch self {
        case .select:
            "Select"
        case .brush:
            "Brush"
        case .shape:
            "Shape"
        case .attach:
            "Attach"
        }
    }

    /// Detailed description of the tool's function
    var description: String {
        switch self {
        case .select:
            "Select and transform layers. Drag to move, resize with handles, or crop images."
        case .brush:
            "Draw freehand strokes on the canvas. Creates a new drawing layer."
        case .shape:
            "Add geometric shapes like rectangles, circles, and lines."
        case .attach:
            "Attach an image from your photo library as a new layer."
        }
    }

    /// Whether this tool requires user to select a layer first
    var requiresSelection: Bool {
        switch self {
        case .select:
            false // Can be used to make selections
        case .brush, .shape, .attach:
            false // Create new layers
        }
    }
}
