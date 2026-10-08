// MARK: - CanvasZoomControls.swift

// Reusable zoom control widget for canvas views.
//
// Provides:
// - Zoom out button (-)
// - Zoom percentage display (also resets to 100%)
// - Zoom in button (+)
//
// ## Zoom Behavior
// - Steps by 5% increments
// - Respects min/max scale from CanvasConstants
// - Animated transitions
//
// ## Reset
// Tapping the percentage resets to 100% zoom and centers the canvas.

import SwiftUI

// MARK: - Canvas Zoom Controls

/// Zoom control widget with +/- buttons and percentage display.
struct CanvasZoomControls: View {
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGPoint
    @Binding var lastOffset: CGPoint
    var onScaleChange: ((CGFloat) -> Void)?
    var onOffsetChange: ((CGPoint) -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            // Zoom out button
            Button {
                zoomOut()
            } label: {
                Image(systemName: "minus")
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
                    .frame(
                        minWidth: CanvasConstants.zoomWidgetButtonHeight,
                        minHeight: CanvasConstants.zoomWidgetButtonHeight
                    )
                    .background(secondarySystemFill)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(scale <= CanvasConstants.minScale)
            .help("Zoom out (−5%)")

            // Zoom percentage / reset button
            Button {
                resetCanvas()
            } label: {
                Text("\(Int(scale * 100))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(
                        minWidth: CanvasConstants.zoomPercentageWidth,
                        minHeight: CanvasConstants.zoomWidgetButtonHeight
                    )
                    .background(secondarySystemFill)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("Reset to 100%")

            // Zoom in button
            Button {
                zoomIn()
            } label: {
                Image(systemName: "plus")
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
                    .frame(
                        minWidth: CanvasConstants.zoomWidgetButtonHeight,
                        minHeight: CanvasConstants.zoomWidgetButtonHeight
                    )
                    .background(secondarySystemFill)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(scale >= CanvasConstants.maxScale)
            .help("Zoom in (+5%)")
        }
    }

    private func zoomIn() {
        let newScale = min(scale + CanvasConstants.zoomStep, CanvasConstants.maxScale)
        withAnimation(.easeOut(duration: CanvasConstants.zoomAnimationDuration)) {
            scale = newScale
            lastScale = newScale
        }
        onScaleChange?(newScale)
    }

    private func zoomOut() {
        let newScale = max(scale - CanvasConstants.zoomStep, CanvasConstants.minScale)
        withAnimation(.easeOut(duration: CanvasConstants.zoomAnimationDuration)) {
            scale = newScale
            lastScale = newScale
        }
        onScaleChange?(newScale)
    }

    private func resetCanvas() {
        withAnimation(.easeOut(duration: CanvasConstants.resetAnimationDuration)) {
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
        }
        onScaleChange?(1.0)
        onOffsetChange?(.zero)
    }
}
