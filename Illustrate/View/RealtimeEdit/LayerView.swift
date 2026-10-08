// MARK: - LayerView.swift

// Router view for rendering different layer types.
//
// Delegates to the appropriate layer view based on layer type:
// - ImageLayerView for image layers
// - DrawingLayerView for drawing layers
// - ShapeLayerView for shape layers
//
// Also handles common layer properties like visibility,
// selection state, and transforms.

import SwiftUI

/// Router view that renders the appropriate layer type view.
struct LayerView: View {
    let layer: RealtimeEditLayer
    let isSelected: Bool
    let selectedTool: EditTool
    let canvasScale: CGFloat
    let canvasOffset: CGPoint
    let canvasSize: CGSize
    let currentStroke: BrushStroke?
    let isActiveDrawingLayer: Bool
    let onUpdate: (RealtimeEditLayer) -> Void
    var onTap: (() -> Void)?

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        Group {
            switch layer.layerType {
            case .image:
                ImageLayerView(
                    layer: layer,
                    isSelected: isSelected,
                    selectedTool: selectedTool,
                    canvasScale: canvasScale,
                    canvasOffset: canvasOffset,
                    canvasSize: canvasSize,
                    onUpdate: onUpdate,
                    onDragOffsetChange: { offset in
                        dragOffset = offset
                    },
                    onAutoSelect: {
                        onTap?()
                    }
                )
            case .drawing:
                DrawingLayerView(
                    layer: layer,
                    isSelected: isSelected,
                    selectedTool: selectedTool,
                    canvasSize: canvasSize,
                    onUpdate: onUpdate,
                    currentStroke: isActiveDrawingLayer ? currentStroke : nil,
                    onDragOffsetChange: { offset in
                        dragOffset = offset
                    },
                    onAutoSelect: {
                        onTap?()
                    }
                )
            case .shape:
                ShapeLayerView(
                    layer: layer,
                    isSelected: isSelected,
                    selectedTool: selectedTool,
                    canvasSize: canvasSize,
                    onUpdate: onUpdate,
                    onDragOffsetChange: { offset in
                        dragOffset = offset
                    },
                    onAutoSelect: {
                        onTap?()
                    }
                )
            }
        }
        .opacity(layer.isVisible ? 1.0 : 0.3)
        .overlay {
            if isSelected, selectedTool == .select {
                // Drawing layers don't show resize handles - they're not resizable
                if layer.layerType == .drawing {
                    selectionBorder
                } else {
                    SelectionOverlay(layer: layer, dragOffset: dragOffset, canvasSize: canvasSize, onUpdate: onUpdate)
                }
            } else if isSelected {
                selectionBorder
            }
        }
        .onTapGesture {
            onTap?()
        }
    }

    private var selectionBorder: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(Color.accentColor, lineWidth: 2)
            .frame(width: layer.width, height: layer.height)
            .position(
                x: layer.positionX + layer.width / 2 + dragOffset.width,
                y: layer.positionY + layer.height / 2 + dragOffset.height
            )
    }
}
