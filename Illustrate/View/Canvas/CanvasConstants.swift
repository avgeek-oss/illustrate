// MARK: - CanvasConstants.swift

// Shared constants for infinite canvas views.
//
// Defines grid spacing, zoom limits, and UI dimensions used by
// both AgentCanvasView and PlaygroundCanvasView.
//
// ## Grid Configuration
// - baseGridSpacing: Pixels between minor grid lines
// - majorGridEvery: Major lines every N minor lines
// - Colors with transparency for subtle appearance
//
// ## Zoom Limits
// - minScale: 25% (0.25) - Maximum zoom out
// - maxScale: 100% (1.0) - No zoom in beyond actual size
// - zoomStep: 5% increments for zoom buttons

import SwiftUI

// MARK: - Canvas Constants

/// Shared constants for infinite canvas grid, zoom, and UI.
enum CanvasConstants {
    // MARK: - Grid

    static let baseGridSpacing: CGFloat = 20
    static let gridLineWidth: CGFloat = 0.5
    static let majorGridEvery = 5
    static let gridColor = secondaryLabel.opacity(0.1)
    static let majorGridColor = secondaryLabel.opacity(0.15)

    // MARK: - Zoom

    static let minScale: CGFloat = 0.25
    static let maxScale: CGFloat = 1.0
    static let zoomStep: CGFloat = 0.05
    static let zoomAnimationDuration = 0.15
    static let resetAnimationDuration = 0.2

    // MARK: - UI

    static let zoomWidgetButtonHeight: CGFloat = 24
    static let zoomPercentageWidth: CGFloat = 48
}

// MARK: - Marquee Selection State

struct MarqueeSelectionState {
    var startPoint: CGPoint
    var currentPoint: CGPoint

    var rect: CGRect {
        CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }
}
