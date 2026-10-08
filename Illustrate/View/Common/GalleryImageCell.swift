// MARK: - GalleryImageCell.swift

// Reusable gallery cell component with hover effects.
//
// A modular image cell for use in gallery grids throughout the app.
// Provides consistent hover effects, selection states, and display modes.
//
// ## Features
// - Hover effects with border and shadow highlighting
// - Optional selection state with checkmark overlay
// - Configurable display mode (fit/fill)
//
// ## Usage
// Use within LazyVGrid or similar grid layouts for galleries.

import SwiftUI

/// Display mode for gallery grid cells.
enum GalleryDisplayMode: String, CaseIterable {
    case fit = "Fit"
    case fill = "Fill"

    var contentMode: ContentMode {
        switch self {
        case .fit: .fit
        case .fill: .fill
        }
    }

    var icon: String {
        switch self {
        case .fit: "arrow.down.right.and.arrow.up.left"
        case .fill: "arrow.up.left.and.arrow.down.right"
        }
    }
}

/// Reusable gallery image cell with hover effects.
struct GalleryImageCell: View {
    let image: PlatformImage
    var isSelected = false
    var isVideo = false
    var displayMode: GalleryDisplayMode = .fill
    var aspectRatio: CGFloat = 1.0
    var onExpand: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        #if os(macOS)
        Group {
            if displayMode == .fill {
                Color.clear
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .overlay(
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fill)
                    )
                    .clipped()
            } else {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topLeading) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .background(
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 24, height: 24)
                    )
                    .padding(6)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isHovered, !isVideo, let onExpand {
                Button {
                    onExpand()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.5))
                        )
                }
                .buttonStyle(.plain)
                .padding(6)
                .transition(.opacity)
                .accessibilityLabel("Expand")
                .accessibilityHint("View this image larger")
            }
        }
        .overlay {
            if isVideo {
                videoPlayOverlay
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    isSelected ? Color.accentColor : (isHovered ? Color.accentColor.opacity(0.6) : Color.clear),
                    lineWidth: isSelected ? 3 : 2
                )
        )
        .shadow(
            color: isSelected ? Color.accentColor.opacity(0.6) : (
                isHovered ? Color.accentColor.opacity(0.4) : Color
                    .clear
            ),
            radius: isSelected ? 8 : 6
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isVideo ? "Generated video" : "Generated image")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to open")
        #else
        Group {
            if displayMode == .fill {
                Color.clear
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .overlay(
                        Image(uiImage: image)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fill)
                    )
                    .clipped()
            } else {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(maxWidth: .infinity)
        .overlay {
            if isVideo {
                videoPlayOverlay
            }
        }
        #endif
    }

    private var videoPlayOverlay: some View {
        Circle()
            .fill(.black.opacity(0.5))
            .frame(width: 42, height: 42)
            .overlay {
                Image(systemName: "play.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .offset(x: 2)
            }
            .accessibilityHidden(true)
    }
}

/// Placeholder view for loading or missing images in gallery.
struct GalleryImagePlaceholder: View {
    var aspectRatio: CGFloat = 1.0

    var body: some View {
        Color(secondaryLabel).opacity(0.3)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .accessibilityLabel("Loading image")
    }
}
