// MARK: - CanvasCoordinateHelper.swift

// Coordinate system utilities for infinite canvas views.
//
// The canvas uses two coordinate systems:
// - Screen space: Pixel positions on the display
// - World space: Virtual canvas coordinates
//
// ## Transformations
// - screenToWorld: Convert mouse position to canvas coordinates
// - worldToScreen: Convert card position to display coordinates
//
// ## CanvasPositionable Protocol
// Common interface for items that can be positioned on canvas
// (AgentCard, PlaygroundCard, etc.)
//
// ## Bounds Calculation
// getBoundsInWorldSpace: Calculate bounding rect of all cards
// for fit-to-content and tidy-up operations.

import SwiftUI

// MARK: - Canvas Positionable Protocol

/// Protocol for items that can be positioned on the canvas.
protocol CanvasPositionable {
    var id: UUID { get }
    var positionX: CGFloat { get }
    var positionY: CGFloat { get }
}

// MARK: - Canvas Coordinate Helper

enum CanvasCoordinateHelper {
    /// Convert screen position to world (canvas) coordinates
    static func screenToWorld(
        screenPosition: CGPoint,
        viewSize: CGSize,
        offset: CGPoint,
        scale: CGFloat
    ) -> CGPoint {
        let centerX = viewSize.width / 2
        let centerY = viewSize.height / 2

        let screenRelativeX = screenPosition.x - centerX - offset.x
        let screenRelativeY = screenPosition.y - centerY - offset.y

        return CGPoint(
            x: screenRelativeX / scale,
            y: screenRelativeY / scale
        )
    }

    /// Convert world (canvas) coordinates to screen position
    static func worldToScreen(
        worldPosition: CGPoint,
        viewSize: CGSize,
        offset: CGPoint,
        scale: CGFloat
    ) -> CGPoint {
        let centerX = viewSize.width / 2
        let centerY = viewSize.height / 2

        return CGPoint(
            x: worldPosition.x * scale + centerX + offset.x,
            y: worldPosition.y * scale + centerY + offset.y
        )
    }

    /// Get the output connection point position (right side of card) for horizontal layouts
    static func getOutputPosition(
        for positionX: CGFloat,
        positionY: CGFloat,
        centerOffset: CGPoint,
        scale: CGFloat,
        cardWidth: CGFloat,
        dragOffset: CGSize = .zero
    ) -> CGPoint {
        let cardScreenX = positionX * scale + centerOffset.x + dragOffset.width
        let cardScreenY = positionY * scale + centerOffset.y + dragOffset.height
        let cardHalfWidth = (cardWidth / 2) * scale

        return CGPoint(x: cardScreenX + cardHalfWidth, y: cardScreenY)
    }

    /// Get the input connection point position (left side of card) for horizontal layouts
    static func getInputPosition(
        for positionX: CGFloat,
        positionY: CGFloat,
        centerOffset: CGPoint,
        scale: CGFloat,
        cardWidth: CGFloat,
        dragOffset: CGSize = .zero
    ) -> CGPoint {
        let cardScreenX = positionX * scale + centerOffset.x + dragOffset.width
        let cardScreenY = positionY * scale + centerOffset.y + dragOffset.height
        let cardHalfWidth = (cardWidth / 2) * scale

        return CGPoint(x: cardScreenX - cardHalfWidth, y: cardScreenY)
    }

    /// Get the bottom connection point position (for vertical layouts like Flow Canvas)
    static func getBottomPosition(
        for positionX: CGFloat,
        positionY: CGFloat,
        centerOffset: CGPoint,
        scale: CGFloat,
        cardHeight: CGFloat,
        dragOffset: CGSize = .zero
    ) -> CGPoint {
        let cardScreenX = positionX * scale + centerOffset.x + dragOffset.width
        let cardScreenY = positionY * scale + centerOffset.y + dragOffset.height
        let cardHalfHeight = (cardHeight / 2) * scale

        return CGPoint(x: cardScreenX, y: cardScreenY + cardHalfHeight)
    }

    /// Get the top connection point position (for vertical layouts like Flow Canvas)
    static func getTopPosition(
        for positionX: CGFloat,
        positionY: CGFloat,
        centerOffset: CGPoint,
        scale: CGFloat,
        cardHeight: CGFloat,
        dragOffset: CGSize = .zero
    ) -> CGPoint {
        let cardScreenX = positionX * scale + centerOffset.x + dragOffset.width
        let cardScreenY = positionY * scale + centerOffset.y + dragOffset.height
        let cardHalfHeight = (cardHeight / 2) * scale

        return CGPoint(x: cardScreenX, y: cardScreenY - cardHalfHeight)
    }
}

// MARK: - Flow Canvas Card Dimensions

let playgroundCardHeight: CGFloat = 280
let playgroundCardSpacing: CGFloat = 100
