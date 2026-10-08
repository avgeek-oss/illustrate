// MARK: - ImageLayerView.swift

// Renders image layers on the canvas.
//
// Loads the image from Documents directory using the layer's
// imagePath and displays it at the layer's position and size.

import SwiftUI

/// View for rendering image layers.
struct ImageLayerView: View {
    let layer: RealtimeEditLayer
    let isSelected: Bool
    let selectedTool: EditTool
    let canvasScale: CGFloat
    let canvasOffset: CGPoint
    let canvasSize: CGSize
    let onUpdate: (RealtimeEditLayer) -> Void
    var onDragOffsetChange: ((CGSize) -> Void)?
    var onAutoSelect: (() -> Void)?

    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero

    var body: some View {
        Group {
            if let imagePath = layer.imagePath,
               let image = loadImageFromDocumentsDirectory(withName: imagePath)
            {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .frame(width: layer.width, height: layer.height)
                #else
                Image(uiImage: image)
                    .resizable()
                    .frame(width: layer.width, height: layer.height)
                #endif
            } else {
                // Placeholder for missing image
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: layer.width, height: layer.height)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .position(
            x: layer.positionX + layer.width / 2 + (isDragging ? dragOffset.width : 0),
            y: layer.positionY + layer.height / 2 + (isDragging ? dragOffset.height : 0)
        )
        .gesture(selectedTool == .select ? dragGesture : nil)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Auto-select on first drag if not already selected
                if !isDragging, !isSelected {
                    onAutoSelect?()
                }

                isDragging = true

                // Constrain drag offset to keep layer within bounds in real-time
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
                // Only update position if layer is selected
                // (it might have just been auto-selected)
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
