// MARK: - CanvasGridView.swift

// Grid background for infinite canvas views.
//
// Draws a coordinate grid that scales and pans with the canvas.
// Uses Canvas API for efficient drawing.
//
// ## Grid Lines
// - Minor lines: Every baseGridSpacing pixels
// - Major lines: Every 5th line (heavier weight)
//
// ## Scale Adaptation
// Grid spacing adjusts with canvas scale:
// - Zoomed out: Lines spread out
// - Lines hidden when too dense (< 4px spacing)
//
// ## Offset Handling
// Grid aligns with canvas offset so lines appear fixed
// to the virtual canvas coordinate system.

import SwiftUI

// MARK: - Canvas Grid View

/// Infinite grid background that scales and pans with the canvas.
struct CanvasGridView: View {
    let scale: CGFloat
    let offset: CGPoint

    var body: some View {
        Canvas { context, size in
            drawGrid(context: context, size: size)
        }
        .background(secondarySystemBackground)
    }

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let effectiveSpacing = CanvasConstants.baseGridSpacing * scale

        guard effectiveSpacing >= 4 else { return }

        let centerX = size.width / 2
        let centerY = size.height / 2
        let totalOffsetX = centerX + offset.x
        let totalOffsetY = centerY + offset.y

        let gridOffsetX = totalOffsetX.truncatingRemainder(dividingBy: effectiveSpacing)
        let gridOffsetY = totalOffsetY.truncatingRemainder(dividingBy: effectiveSpacing)

        let startIndexX = Int(floor(-totalOffsetX / effectiveSpacing))
        let startIndexY = Int(floor(-totalOffsetY / effectiveSpacing))

        // Draw vertical lines
        var screenX = gridOffsetX
        if screenX > effectiveSpacing { screenX -= effectiveSpacing }
        if screenX < 0 { screenX += effectiveSpacing }
        var indexX = startIndexX + Int(round((screenX - gridOffsetX) / effectiveSpacing))

        while screenX <= size.width {
            let isMajorLine = indexX % CanvasConstants.majorGridEvery == 0
            let path = Path { p in
                p.move(to: CGPoint(x: screenX, y: 0))
                p.addLine(to: CGPoint(x: screenX, y: size.height))
            }
            context.stroke(
                path,
                with: .color(isMajorLine ? CanvasConstants.majorGridColor : CanvasConstants.gridColor),
                lineWidth: isMajorLine ? CanvasConstants.gridLineWidth * 2 : CanvasConstants.gridLineWidth
            )
            screenX += effectiveSpacing
            indexX += 1
        }

        // Draw horizontal lines
        var screenY = gridOffsetY
        if screenY > effectiveSpacing { screenY -= effectiveSpacing }
        if screenY < 0 { screenY += effectiveSpacing }
        var indexY = startIndexY + Int(round((screenY - gridOffsetY) / effectiveSpacing))

        while screenY <= size.height {
            let isMajorLine = indexY % CanvasConstants.majorGridEvery == 0
            let path = Path { p in
                p.move(to: CGPoint(x: 0, y: screenY))
                p.addLine(to: CGPoint(x: size.width, y: screenY))
            }
            context.stroke(
                path,
                with: .color(isMajorLine ? CanvasConstants.majorGridColor : CanvasConstants.gridColor),
                lineWidth: isMajorLine ? CanvasConstants.gridLineWidth * 2 : CanvasConstants.gridLineWidth
            )
            screenY += effectiveSpacing
            indexY += 1
        }
    }
}
