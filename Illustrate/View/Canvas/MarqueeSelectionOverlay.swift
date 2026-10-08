// MARK: - MarqueeSelectionOverlay.swift

// Visual overlay for drag-to-select rectangle.
//
// Displays a dashed rectangle when user drags to select
// multiple cards. Uses MarqueeSelectionState for coordinates.
//
// ## Appearance
// - Semi-transparent accent color fill
// - Dashed border stroke

import SwiftUI

// MARK: - Marquee Selection Overlay

/// Dashed rectangle overlay for drag-to-select.
struct MarqueeSelectionOverlay: View {
    let marquee: MarqueeSelectionState?

    var body: some View {
        if let marquee {
            Rectangle()
                .fill(Color.accentColor.opacity(0.2))
                .overlay(
                    Rectangle()
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
                )
                .frame(width: marquee.rect.width, height: marquee.rect.height)
                .position(
                    x: marquee.rect.midX,
                    y: marquee.rect.midY
                )
        }
    }
}
