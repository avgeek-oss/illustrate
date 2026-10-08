// MARK: - DrawingLayerView.swift

// Renders drawing layers created with brush tool.
//
// This is a pure renderer - it displays completed strokes from layer.drawingData
// plus an optional in-progress stroke passed from the parent view.
//
// Drawing gesture handling is done in EditorCanvasView to ensure proper
// coordination between layer creation and stroke capture.
//
// Supports dragging to move the layer when select tool is active.

import SwiftUI

/// View for rendering drawing layers.
struct DrawingLayerView: View {
    let layer: RealtimeEditLayer
    let isSelected: Bool
    let selectedTool: EditTool
    let canvasSize: CGSize
    let onUpdate: (RealtimeEditLayer) -> Void

    /// Current stroke being drawn (passed from parent)
    var currentStroke: BrushStroke?

    /// Callback when drag offset changes (for selection overlay sync)
    var onDragOffsetChange: ((CGSize) -> Void)?

    /// Callback to auto-select layer on drag start
    var onAutoSelect: (() -> Void)?

    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero

    /// Completed strokes computed directly from layer data
    private var strokes: [BrushStroke] {
        DrawingData.decode(from: layer.drawingData).strokes
    }

    var body: some View {
        Canvas { context, _ in
            // Draw all completed strokes
            for stroke in strokes {
                drawStroke(stroke, in: &context)
            }

            // Draw current stroke in progress
            if let currentStroke, !currentStroke.points.isEmpty {
                drawStroke(currentStroke, in: &context)
            }
        }
        .frame(width: layer.width, height: layer.height)
        .position(
            x: layer.positionX + layer.width / 2 + (isDragging ? dragOffset.width : 0),
            y: layer.positionY + layer.height / 2 + (isDragging ? dragOffset.height : 0)
        )
        .allowsHitTesting(selectedTool == .select)
        .gesture(selectedTool == .select ? dragGesture : nil)
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

                    // Update layer position
                    layer.positionX += dragOffset.width
                    layer.positionY += dragOffset.height

                    // Persist changes
                    onUpdate(layer)

                    // Reset drag offset
                    dragOffset = .zero
                    onDragOffsetChange?(.zero)
                } else {
                    isDragging = false
                    dragOffset = .zero
                    onDragOffsetChange?(.zero)
                }
            }
    }

    // MARK: - Stroke Rendering

    private func drawStroke(_ stroke: BrushStroke, in context: inout GraphicsContext) {
        guard stroke.points.count >= 2 else {
            // Single point: draw a dot
            if let point = stroke.points.first {
                let rect = CGRect(
                    x: point.x - stroke.size / 2,
                    y: point.y - stroke.size / 2,
                    width: stroke.size,
                    height: stroke.size
                )
                context.fill(
                    Circle().path(in: rect),
                    with: .color(colorFromHex(stroke.colorHex))
                )
            }
            return
        }

        // Create smooth path through points
        var path = Path()
        path.move(to: stroke.points[0])

        if stroke.points.count == 2 {
            path.addLine(to: stroke.points[1])
        } else {
            for i in 1 ..< stroke.points.count {
                let currentPoint = stroke.points[i]
                let previousPoint = stroke.points[i - 1]
                let midPoint = CGPoint(
                    x: (previousPoint.x + currentPoint.x) / 2,
                    y: (previousPoint.y + currentPoint.y) / 2
                )

                if i == 1 {
                    path.addLine(to: midPoint)
                } else {
                    path.addQuadCurve(to: midPoint, control: previousPoint)
                }
            }
            // Add final line to last point
            if let lastPoint = stroke.points.last {
                path.addLine(to: lastPoint)
            }
        }

        // Stroke the path
        context.stroke(
            path,
            with: .color(colorFromHex(stroke.colorHex)),
            style: StrokeStyle(
                lineWidth: stroke.size,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }
}
