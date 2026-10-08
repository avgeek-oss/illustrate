// MARK: - SelectionOverlay.swift

// Selection overlay with resize handles for layer transformation.
//
// Displays:
// - Border around selected layer
// - 8 resize handles (corners and edges)
// - Drag gestures for resizing
//
// ## Handle Types
// - Corner handles: Resize both width and height
// - Edge handles: Resize single dimension
//
// ## Constraints
// - Minimum size: 50x50
// - Updates layer position for top/left handles
// - Persists changes on drag end

import SwiftUI

/// Overlay view showing selection border and resize handles.
struct SelectionOverlay: View {
    @Bindable var layer: RealtimeEditLayer
    let dragOffset: CGSize
    let canvasSize: CGSize
    let onUpdate: (RealtimeEditLayer) -> Void

    @State private var resizingHandle: ResizeHandle?
    @State private var resizeDragStart: CGPoint = .zero
    @State private var originalBounds: CGRect = .zero
    @State private var originalAspectRatio: CGFloat = 1.0

    private let handleSize: CGFloat = 12
    private let minSize: CGFloat = 50

    var body: some View {
        ZStack {
            // Selection border
            Rectangle()
                .stroke(Color.accentColor, lineWidth: 2)
                .frame(width: layer.width, height: layer.height)
                .position(
                    x: layer.positionX + layer.width / 2 + dragOffset.width,
                    y: layer.positionY + layer.height / 2 + dragOffset.height
                )

            // Resize handles
            ForEach(ResizeHandle.allCases) { handle in
                handleView(for: handle)
            }
        }
    }

    private func handleView(for handle: ResizeHandle) -> some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: handleSize, height: handleSize)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .position(handlePosition(for: handle))
            .gesture(resizeGesture(for: handle))
    }

    private func handlePosition(for handle: ResizeHandle) -> CGPoint {
        let x = layer.positionX + dragOffset.width
        let y = layer.positionY + dragOffset.height
        let width = layer.width
        let height = layer.height

        switch handle {
        case .topLeft:
            return CGPoint(x: x, y: y)
        case .topCenter:
            return CGPoint(x: x + width / 2, y: y)
        case .topRight:
            return CGPoint(x: x + width, y: y)
        case .middleLeft:
            return CGPoint(x: x, y: y + height / 2)
        case .middleRight:
            return CGPoint(x: x + width, y: y + height / 2)
        case .bottomLeft:
            return CGPoint(x: x, y: y + height)
        case .bottomCenter:
            return CGPoint(x: x + width / 2, y: y + height)
        case .bottomRight:
            return CGPoint(x: x + width, y: y + height)
        }
    }

    private func resizeGesture(for handle: ResizeHandle) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if resizingHandle == nil {
                    resizingHandle = handle
                    resizeDragStart = value.startLocation
                    originalBounds = CGRect(
                        x: layer.positionX,
                        y: layer.positionY,
                        width: layer.width,
                        height: layer.height
                    )
                    originalAspectRatio = layer.width / layer.height
                }

                let delta = CGSize(
                    width: value.location.x - resizeDragStart.x,
                    height: value.location.y - resizeDragStart.y
                )

                #if os(macOS)
                let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
                #else
                let isShiftPressed = false
                #endif

                applyResize(for: handle, delta: delta, maintainAspectRatio: isShiftPressed)
            }
            .onEnded { _ in
                resizingHandle = nil
                onUpdate(layer)
            }
    }

    private func applyResize(for handle: ResizeHandle, delta: CGSize, maintainAspectRatio: Bool) {
        var newX = originalBounds.origin.x
        var newY = originalBounds.origin.y
        var newWidth = originalBounds.width
        var newHeight = originalBounds.height

        switch handle {
        case .topLeft:
            newX = originalBounds.origin.x + delta.width
            newY = originalBounds.origin.y + delta.height
            newWidth = originalBounds.width - delta.width
            newHeight = originalBounds.height - delta.height

        case .topCenter:
            newY = originalBounds.origin.y + delta.height
            newHeight = originalBounds.height - delta.height

        case .topRight:
            newY = originalBounds.origin.y + delta.height
            newWidth = originalBounds.width + delta.width
            newHeight = originalBounds.height - delta.height

        case .middleLeft:
            newX = originalBounds.origin.x + delta.width
            newWidth = originalBounds.width - delta.width

        case .middleRight:
            newWidth = originalBounds.width + delta.width

        case .bottomLeft:
            newX = originalBounds.origin.x + delta.width
            newWidth = originalBounds.width - delta.width
            newHeight = originalBounds.height + delta.height

        case .bottomCenter:
            newHeight = originalBounds.height + delta.height

        case .bottomRight:
            newWidth = originalBounds.width + delta.width
            newHeight = originalBounds.height + delta.height
        }

        // Apply aspect ratio constraint if Shift is pressed
        if maintainAspectRatio {
            switch handle {
            // Corner handles: maintain aspect ratio based on width
            case .topLeft, .topRight, .bottomLeft, .bottomRight:
                newHeight = newWidth / originalAspectRatio

                // Adjust position for top handles
                if handle == .topLeft || handle == .topRight {
                    newY = originalBounds.maxY - newHeight
                }
                if handle == .topLeft || handle == .bottomLeft {
                    newX = originalBounds.maxX - newWidth
                }

            // Top/bottom center handles: maintain aspect ratio based on height
            case .topCenter, .bottomCenter:
                newWidth = newHeight * originalAspectRatio

                // Center the width change
                newX = originalBounds.origin.x - (newWidth - originalBounds.width) / 2

            // Left/right center handles: maintain aspect ratio based on width
            case .middleLeft, .middleRight:
                newHeight = newWidth / originalAspectRatio

                // Center the height change
                newY = originalBounds.origin.y - (newHeight - originalBounds.height) / 2
            }
        }

        // Enforce minimum size
        if newWidth < minSize {
            if handle == .topLeft || handle == .middleLeft || handle == .bottomLeft {
                newX = originalBounds.maxX - minSize
            }
            newWidth = minSize

            if maintainAspectRatio {
                newHeight = newWidth / originalAspectRatio
            }
        }

        if newHeight < minSize {
            if handle == .topLeft || handle == .topCenter || handle == .topRight {
                newY = originalBounds.maxY - minSize
            }
            newHeight = minSize

            if maintainAspectRatio {
                newWidth = newHeight * originalAspectRatio
            }
        }

        // Constrain to canvas bounds
        var boundsAdjusted = false

        if newX < 0 {
            newWidth += newX
            newX = 0
            boundsAdjusted = true
        }
        if newY < 0 {
            newHeight += newY
            newY = 0
            boundsAdjusted = true
        }
        if newX + newWidth > canvasSize.width {
            newWidth = canvasSize.width - newX
            boundsAdjusted = true
        }
        if newY + newHeight > canvasSize.height {
            newHeight = canvasSize.height - newY
            boundsAdjusted = true
        }

        // If bounds were adjusted and we're maintaining aspect ratio,
        // proportionally reduce both dimensions to fit within bounds
        if boundsAdjusted, maintainAspectRatio {
            // Calculate available space
            let availableWidth = canvasSize.width - newX
            let availableHeight = canvasSize.height - newY

            // Determine which dimension is more constrained
            let widthConstraint = availableWidth / originalAspectRatio // Height if width is limiting
            let heightConstraint = availableHeight * originalAspectRatio // Width if height is limiting

            if widthConstraint <= availableHeight {
                // Width is the limiting factor
                newWidth = availableWidth
                newHeight = widthConstraint
            } else {
                // Height is the limiting factor
                newWidth = heightConstraint
                newHeight = availableHeight
            }

            // Adjust position based on handle type to maintain anchor point
            let widthChange = originalBounds.width - newWidth
            let heightChange = originalBounds.height - newHeight

            switch handle {
            case .topLeft:
                newX = originalBounds.maxX - newWidth
                newY = originalBounds.maxY - newHeight
            case .topCenter:
                newX = originalBounds.origin.x + widthChange / 2
                newY = originalBounds.maxY - newHeight
            case .topRight:
                newY = originalBounds.maxY - newHeight
            case .middleLeft:
                newX = originalBounds.maxX - newWidth
                newY = originalBounds.origin.y + heightChange / 2
            case .middleRight:
                newY = originalBounds.origin.y + heightChange / 2
            case .bottomLeft:
                newX = originalBounds.maxX - newWidth
            case .bottomCenter:
                newX = originalBounds.origin.x + widthChange / 2
            case .bottomRight:
                break // Keep position as-is
            }
        }

        // Update layer
        layer.positionX = newX
        layer.positionY = newY
        layer.width = max(minSize, newWidth)
        layer.height = max(minSize, newHeight)
    }
}

// MARK: - Resize Handle Enum

enum ResizeHandle: String, CaseIterable, Identifiable {
    case topLeft
    case topCenter
    case topRight
    case middleLeft
    case middleRight
    case bottomLeft
    case bottomCenter
    case bottomRight

    var id: String {
        rawValue
    }
}
