// MARK: - EditorCanvasView.swift

// Left-side canvas editor with tools and layers.
//
// The editor canvas is where users interact with layers:
// - Select and transform layers
// - Draw with brush tool
// - Create shapes
// - Attach images
//
// ## Layout
// - Canvas grid background
// - Layer stack rendered in z-order
// - Tool palette overlayed on left edge
// - Zoom controls on bottom right
//
// ## Drawing
// All drawing gesture handling is centralized here to ensure proper
// coordination between layer creation and stroke capture.

import SwiftUI

/// Left-side editing canvas with tool palette and layer interaction.
struct EditorCanvasView: View {
    let session: RealtimeEditSession
    let layers: [RealtimeEditLayer]
    @Binding var selectedLayerIds: Set<UUID>
    @Binding var selectedTool: EditTool
    let previousTool: EditTool
    @Binding var canvasScale: CGFloat
    @Binding var canvasOffset: CGPoint
    let canvasSize: CGSize
    let brushColor: Color
    let brushSize: CGFloat
    let shapeColor: Color
    let selectedShapeType: ShapeType
    @Binding var activeDrawingLayerId: UUID?
    let onLayerUpdate: (RealtimeEditLayer) -> Void
    let onLayerCreate: (RealtimeEditLayer) -> Void
    let onAddStroke: (RealtimeEditLayer, BrushStroke) -> Void
    @Binding var showImagePicker: Bool

    // Drawing state
    @State private var currentStrokePoints: [CGPoint] = []
    @State private var isDrawing = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            #if os(macOS)
            Color(nsColor: .controlBackgroundColor)
            #else
            Color(uiColor: .systemBackground)
            #endif

            // Canvas grid
            CanvasGridView(scale: canvasScale, offset: canvasOffset)

            // Bounding box border
            Rectangle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)

            // Layers (in z-order)
            ForEach(sortedLayers) { layer in
                LayerView(
                    layer: layer,
                    isSelected: selectedLayerIds.contains(layer.id),
                    selectedTool: selectedTool,
                    canvasScale: canvasScale,
                    canvasOffset: canvasOffset,
                    canvasSize: canvasSize,
                    currentStroke: currentStroke,
                    isActiveDrawingLayer: activeDrawingLayerId == layer.id,
                    onUpdate: onLayerUpdate,
                    onTap: { handleLayerTap(layer.id) }
                )
            }
        }
        .contentShape(Rectangle())
        .gesture(selectedTool == .brush ? canvasDrawGesture : nil)
        .gesture(selectedTool == .shape ? shapePlacementGesture : nil)
        .onTapGesture {
            handleCanvasTap()
        }
        .imageSelection(
            id: "realtimeEditCanvas",
            isPickerOpen: $showImagePicker,
            enableCrop: false,
            onImageSelected: { image in
                handleImageSelection(image)
            }
        )
    }

    private var sortedLayers: [RealtimeEditLayer] {
        layers.sorted { $0.zIndex < $1.zIndex }
    }

    /// Current stroke being drawn (for rendering)
    private var currentStroke: BrushStroke? {
        guard !currentStrokePoints.isEmpty else { return nil }
        return BrushStroke(
            points: currentStrokePoints,
            colorHex: hexFromColor(brushColor),
            size: brushSize
        )
    }

    // MARK: - Image Selection

    private func handleImageSelection(_ image: PlatformImage) {
        // 1. Resize to max dimension on longest side (for saved image quality)
        let maxSaveDimension = ImageProcessing.maxSaveDimension
        let size = image.pixelSize
        let saveScale = min(maxSaveDimension / size.width, maxSaveDimension / size.height, 1.0)
        let saveSize = CGSize(width: size.width * saveScale, height: size.height * saveScale)

        guard let resizedImage = image.resizeImage(targetSize: saveSize) else { return }

        // 2. Save to Documents directory
        guard let pngData = resizedImage.toPNGData() else { return }
        let filename = UUID().uuidString
        guard saveImageToDocumentsDirectory(imageData: pngData, withName: filename) != nil else { return }

        // 3. Calculate display size (max dimension on longest side for canvas preview)
        let maxDisplayDimension = ImageProcessing.maxDisplayDimension
        let displayScale = min(maxDisplayDimension / saveSize.width, maxDisplayDimension / saveSize.height, 1.0)
        let displaySize = CGSize(width: saveSize.width * displayScale, height: saveSize.height * displayScale)

        // 4. Create layer at center of canvas
        let centerX: CGFloat = canvasSize.width / 2
        let centerY: CGFloat = canvasSize.height / 2

        let layer = RealtimeEditLayer(
            sessionId: session.id,
            layerType: .image,
            name: "Image \(layers.count + 1)",
            position: CGPoint(x: centerX - displaySize.width / 2, y: centerY - displaySize.height / 2),
            size: displaySize,
            zIndex: layers.count
        )
        layer.imagePath = filename

        // 5. Add to canvas
        onLayerCreate(layer)

        // 6. Select layer and switch to select tool
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            selectedLayerIds = [layer.id]
            selectedTool = .select
        }
    }

    // MARK: - Layer Selection

    private func handleLayerTap(_ layerId: UUID) {
        guard selectedTool == .select else { return }
        selectedLayerIds = [layerId]
    }

    private func handleCanvasTap() {
        guard selectedTool == .select else { return }
        selectedLayerIds.removeAll()
    }

    // MARK: - Drawing

    /// Gesture for drawing on the canvas
    private var canvasDrawGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Create layer if needed
                if activeDrawingLayerId == nil {
                    createDrawingLayer()
                }

                // Add point to current stroke
                let point = value.location

                // Clamp to canvas bounds
                let clampedPoint = CGPoint(
                    x: max(0, min(canvasSize.width, point.x)),
                    y: max(0, min(canvasSize.height, point.y))
                )

                if !isDrawing {
                    isDrawing = true
                    currentStrokePoints = [clampedPoint]
                } else {
                    // Only add point if it's far enough from the last point (reduces noise)
                    if let lastPoint = currentStrokePoints.last {
                        let distance = hypot(clampedPoint.x - lastPoint.x, clampedPoint.y - lastPoint.y)
                        if distance >= 1.0 {
                            currentStrokePoints.append(clampedPoint)
                        }
                    }
                }
            }
            .onEnded { _ in
                finishStroke()
            }
    }

    /// Creates a new drawing layer that fills the entire canvas
    private func createDrawingLayer() {
        let layer = RealtimeEditLayer(
            sessionId: session.id,
            layerType: .drawing,
            name: "Drawing \(layers.filter { $0.layerType == .drawing }.count + 1)",
            position: .zero,
            size: canvasSize,
            zIndex: layers.count
        )
        layer.strokeColor = hexFromColor(brushColor)

        onLayerCreate(layer)

        // Set as active drawing layer immediately
        activeDrawingLayerId = layer.id
    }

    /// Finishes the current stroke and adds it to the active layer
    private func finishStroke() {
        guard !currentStrokePoints.isEmpty,
              let layerId = activeDrawingLayerId,
              let layer = layers.first(where: { $0.id == layerId })
        else {
            currentStrokePoints = []
            isDrawing = false
            return
        }

        // Create and simplify the stroke to reduce memory footprint
        var stroke = BrushStroke(
            points: currentStrokePoints,
            colorHex: hexFromColor(brushColor),
            size: brushSize
        )
        stroke.simplify()

        // Clear current stroke
        currentStrokePoints = []
        isDrawing = false

        // Add stroke to layer (this will save history first)
        onAddStroke(layer, stroke)
    }

    // MARK: - Shape Placement

    /// Gesture for placing shapes on the canvas
    private var shapePlacementGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { event in
                handleShapePlacement(at: event.location)
            }
    }

    /// Places a shape at the specified location on the canvas
    private func handleShapePlacement(at location: CGPoint) {
        let defaultSize: CGFloat = 100

        // Calculate position centered on tap location
        let positionX = max(0, min(location.x - defaultSize / 2, canvasSize.width - defaultSize))
        let positionY = max(0, min(location.y - defaultSize / 2, canvasSize.height - defaultSize))

        let layer = RealtimeEditLayer(
            sessionId: session.id,
            layerType: .shape,
            name: "\(selectedShapeType.displayName) \(layers.filter { $0.layerType == .shape }.count + 1)",
            position: CGPoint(x: positionX, y: positionY),
            size: CGSize(width: defaultSize, height: defaultSize),
            zIndex: layers.count
        )
        layer.shapeType = selectedShapeType
        layer.fillColor = hexFromColor(shapeColor)

        // Add to canvas
        onLayerCreate(layer)

        // Auto-select and switch to select tool
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            selectedLayerIds = [layer.id]
            selectedTool = .select
        }
    }
}
