// MARK: - LayersPanelView.swift

// Right-side layers panel for layer management.
//
// Displays all layers with drag-to-reorder support using native List onMove.
// Layers are displayed with highest z-index (newest) at top.

import AvgeekDesignSystem
import SwiftUI

/// Right-side panel showing layer list with management controls.
struct LayersPanelView: View {
    let layers: [RealtimeEditLayer]
    @Binding var selectedLayerIds: Set<UUID>
    let onLayerUpdate: (RealtimeEditLayer) -> Void
    let onLayerDelete: (UUID) -> Void
    let onLayerReorder: ([RealtimeEditLayer]) -> Void
    let onRefreshPreview: () -> Void

    /// Local copy of sorted layers for reordering
    @State private var sortedLayers: [RealtimeEditLayer] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Layers")
                    .font(.headline)
                Spacer()
                Text("\(layers.count)")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Layer list
            if layers.isEmpty {
                AvgeekEmptyStateView(
                    icon: "square.stack.3d.up",
                    title: "No layers found",
                    message: "Start by adding images or draw on the canvas."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(sortedLayers) { layer in
                        LayerRowView(
                            layer: layer,
                            isSelected: selectedLayerIds.contains(layer.id),
                            onSelect: {
                                selectedLayerIds = [layer.id]
                            },
                            onToggleVisibility: {
                                layer.isVisible.toggle()
                                onLayerUpdate(layer)
                                onRefreshPreview()
                            },
                            onDelete: {
                                onLayerDelete(layer.id)
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onMove(perform: moveLayer)
                }
                .listStyle(.plain)
                #if os(iOS)
                .environment(\.editMode, .constant(.active))
                #endif
            }
        }
        .frame(width: 260)
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(uiColor: .systemBackground))
        #endif
        .onAppear {
            sortedLayers = layers.sorted { $0.zIndex > $1.zIndex }
        }
        .onChange(of: layers) { _, newLayers in
            sortedLayers = newLayers.sorted { $0.zIndex > $1.zIndex }
        }
    }

    // MARK: - Reorder

    private func moveLayer(from source: IndexSet, to destination: Int) {
        sortedLayers.move(fromOffsets: source, toOffset: destination)

        // Reassign z-indices: top of list = highest z-index
        for (index, layer) in sortedLayers.enumerated() {
            layer.zIndex = sortedLayers.count - 1 - index
        }

        onLayerReorder(sortedLayers)
    }
}

// MARK: - Layer Row View

private struct LayerRowView: View {
    let layer: RealtimeEditLayer
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleVisibility: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Thumbnail
            layerThumbnail
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
                .clipped()

            // Name and type
            VStack(alignment: .leading, spacing: 1) {
                Text(layer.name)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(layer.layerType.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Visibility toggle
            Button(action: onToggleVisibility) {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .font(.caption)
                    .foregroundStyle(layer.isVisible ? .primary : .tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(layer.isVisible ? "Hide layer" : "Show layer")
            .accessibilityHint("Double tap to toggle layer visibility")

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete layer")
            .accessibilityHint("Double tap to delete this layer")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(layer.name), \(layer.layerType.displayName) layer")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityHint("Double tap to select this layer")
    }

    @ViewBuilder
    private var layerThumbnail: some View {
        switch layer.layerType {
        case .image:
            if let imagePath = layer.imagePath,
               let image = loadImageFromDocumentsDirectory(withName: imagePath)
            {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                #endif
            } else {
                Image(systemName: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

        case .drawing:
            DrawingThumbnailView(layer: layer)

        case .shape:
            if let shapeType = layer.shapeType {
                Image(systemName: shapeType.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Image(systemName: "square.on.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Drawing Thumbnail View

private struct DrawingThumbnailView: View {
    let layer: RealtimeEditLayer

    var body: some View {
        let drawingData = DrawingData.decode(from: layer.drawingData)
        if drawingData.strokes.isEmpty {
            Image(systemName: "paintbrush")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Canvas { context, size in
                let allPoints = drawingData.strokes.flatMap(\.points)
                guard !allPoints.isEmpty else { return }

                let minX = allPoints.map(\.x).min() ?? 0
                let minY = allPoints.map(\.y).min() ?? 0
                let maxX = allPoints.map(\.x).max() ?? 0
                let maxY = allPoints.map(\.y).max() ?? 0

                let strokeWidth = maxX - minX
                let strokeHeight = maxY - minY
                guard strokeWidth > 0, strokeHeight > 0 else { return }

                let padding: CGFloat = 4
                let availableWidth = size.width - padding * 2
                let availableHeight = size.height - padding * 2
                let scale = min(availableWidth / strokeWidth, availableHeight / strokeHeight)

                let scaledWidth = strokeWidth * scale
                let scaledHeight = strokeHeight * scale
                let offsetX = padding + (availableWidth - scaledWidth) / 2 - minX * scale
                let offsetY = padding + (availableHeight - scaledHeight) / 2 - minY * scale

                for stroke in drawingData.strokes {
                    guard stroke.points.count >= 2 else { continue }

                    var path = Path()
                    let scaledPoints = stroke.points.map { point in
                        CGPoint(x: point.x * scale + offsetX, y: point.y * scale + offsetY)
                    }

                    path.move(to: scaledPoints[0])
                    for i in 1 ..< scaledPoints.count {
                        let currentPoint = scaledPoints[i]
                        let previousPoint = scaledPoints[i - 1]
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
                    if let lastPoint = scaledPoints.last {
                        path.addLine(to: lastPoint)
                    }

                    context.stroke(
                        path,
                        with: .color(colorFromHex(stroke.colorHex)),
                        style: StrokeStyle(
                            lineWidth: max(1, stroke.size * scale),
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }
            }
        }
    }
}
