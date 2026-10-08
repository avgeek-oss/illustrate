// MARK: - ShapeLayerView.swift

// Renders geometric shape layers on the canvas.
//
// Displays shapes (triangle, square, circle) with fill color
// and supports drag-to-move with the select tool.
//
// ## Rendering
// - Triangle: Custom Triangle shape
// - Square: SwiftUI Rectangle
// - Circle: SwiftUI Circle
// All shapes are filled with the layer's fillColor.

import SwiftUI

/// View for rendering shape layers.
struct ShapeLayerView: View {
    let layer: RealtimeEditLayer
    let isSelected: Bool
    let selectedTool: EditTool
    let canvasSize: CGSize
    let onUpdate: (RealtimeEditLayer) -> Void
    var onDragOffsetChange: ((CGSize) -> Void)?
    var onAutoSelect: (() -> Void)?

    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero

    /// Fill color from layer, defaults to blue
    private var fillColor: Color {
        if let hex = layer.fillColor {
            return colorFromHex(hex)
        }
        return Color.blue
    }

    var body: some View {
        Group {
            if let shapeType = layer.shapeType {
                shapeView(for: shapeType)
                    .frame(width: layer.width, height: layer.height)
            }
        }
        .position(
            x: layer.positionX + layer.width / 2 + (isDragging ? dragOffset.width : 0),
            y: layer.positionY + layer.height / 2 + (isDragging ? dragOffset.height : 0)
        )
        .gesture(selectedTool == .select ? dragGesture : nil)
    }

    // MARK: - Shape Rendering

    @ViewBuilder
    private func shapeView(for type: ShapeType) -> some View {
        switch type {
        case .triangle:
            Triangle()
                .fill(fillColor)
        case .square:
            Rectangle()
                .fill(fillColor)
        case .circle:
            Circle()
                .fill(fillColor)
        }
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Auto-select on first drag if not already selected
                if !isDragging, !isSelected {
                    onAutoSelect?()
                }

                isDragging = true

                // Constrain drag offset to keep layer within bounds
                var proposedX = layer.positionX + value.translation.width
                var proposedY = layer.positionY + value.translation.height

                // Clamp to canvas bounds
                proposedX = max(0, min(proposedX, canvasSize.width - layer.width))
                proposedY = max(0, min(proposedY, canvasSize.height - layer.height))

                // Calculate constrained offset
                let constrainedOffset = CGSize(
                    width: proposedX - layer.positionX,
                    height: proposedY - layer.positionY
                )

                dragOffset = constrainedOffset
                onDragOffsetChange?(constrainedOffset)
            }
            .onEnded { _ in
                if isSelected {
                    isDragging = false

                    // Update layer position using the constrained offset
                    layer.positionX += dragOffset.width
                    layer.positionY += dragOffset.height

                    // Persist changes
                    onUpdate(layer)

                    // Reset drag offset
                    dragOffset = .zero
                    onDragOffsetChange?(.zero)
                } else {
                    // If not selected (auto-select failed), just reset
                    isDragging = false
                    dragOffset = .zero
                    onDragOffsetChange?(.zero)
                }
            }
    }
}

// MARK: - Triangle Shape

/// Triangle shape for shape layers.
///
/// Points upward by default:
/// - Top vertex at midX, minY
/// - Bottom-left vertex at minX, maxY
/// - Bottom-right vertex at maxX, maxY
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
