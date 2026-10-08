// MARK: - RealtimeEditCanvasView.swift

// Main canvas editor for Realtime Edit.

import AvgeekDesignSystem
import IllustrateProviders
import KeychainSwift
import OSLog
import SwiftData
import SwiftUI

#if !os(macOS)
import Photos
#endif

// MARK: - Keyboard Monitor

#if os(macOS)
/// View that monitors keyboard shortcuts for undo/redo and delete.
struct KeyboardMonitorView: NSViewRepresentable {
    func makeNSView(context: Context) -> KeyMonitorNSView {
        KeyMonitorNSView()
    }

    func updateNSView(_ nsView: KeyMonitorNSView, context: Context) {}

    class KeyMonitorNSView: NSView {
        private var eventMonitor: Any?

        override var acceptsFirstResponder: Bool {
            true
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            if window != nil, eventMonitor == nil {
                // Add local event monitor for keyboard shortcuts
                eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    guard self?.window != nil else { return event }

                    // Don't intercept keys when user is typing in a text field
                    // Use event.window to check the actual window receiving the event
                    if let eventWindow = event.window,
                       let firstResponder = eventWindow.firstResponder,
                       firstResponder is NSTextView || firstResponder is NSTextField
                    {
                        return event
                    }

                    // Check for Cmd+Z (undo)
                    if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "z" {
                        NotificationCenter.default.post(name: NSNotification.Name("UndoKeyPressed"), object: nil)
                        return nil
                    }
                    // Check for Delete key
                    else if event.keyCode == 51 {
                        NotificationCenter.default.post(name: NSNotification.Name("DeleteKeyPressed"), object: nil)
                        return nil
                    }
                    return event
                }
            }
        }

        deinit {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
#else
struct KeyboardMonitorView: View {
    var body: some View {
        EmptyView()
    }
}
#endif

// MARK: - Layer History

/// Snapshot of a layer's complete state at a point in time.
/// Uses copy-on-write semantics for efficient data handling.
final class LayerSnapshot {
    let layerId: UUID
    let sessionId: UUID
    let layerType: LayerType
    let name: String
    let positionX: CGFloat
    let positionY: CGFloat
    let width: CGFloat
    let height: CGFloat
    let zIndex: Int
    let isVisible: Bool
    let isLocked: Bool
    let imagePath: String?
    let shapeType: ShapeType?
    let shapePathData: Data?
    let strokeColor: String?
    let fillColor: String?

    /// Drawing data captured at snapshot creation time.
    /// Swift's Data type uses copy-on-write, so this is efficient.
    let drawingData: Data?

    init(from layer: RealtimeEditLayer, captureDrawingDataNow: Bool = false) {
        layerId = layer.id
        sessionId = layer.sessionId
        layerType = layer.layerType
        name = layer.name
        positionX = layer.positionX
        positionY = layer.positionY
        width = layer.width
        height = layer.height
        zIndex = layer.zIndex
        isVisible = layer.isVisible
        isLocked = layer.isLocked
        imagePath = layer.imagePath
        shapeType = layer.shapeType
        shapePathData = layer.shapePathData
        strokeColor = layer.strokeColor
        fillColor = layer.fillColor
        // Always capture drawing data at snapshot time.
        // Swift's Data uses copy-on-write, so this is memory-efficient.
        drawingData = layer.drawingData
    }

    func restore(to layer: RealtimeEditLayer) {
        layer.positionX = positionX
        layer.positionY = positionY
        layer.width = width
        layer.height = height
        layer.zIndex = zIndex
        layer.isVisible = isVisible
        layer.isLocked = isLocked
        layer.drawingData = drawingData
        layer.imagePath = imagePath
        layer.shapeType = shapeType
        layer.shapePathData = shapePathData
        layer.strokeColor = strokeColor
        layer.fillColor = fillColor
    }

    func recreateLayer() -> RealtimeEditLayer {
        let layer = RealtimeEditLayer(
            sessionId: sessionId,
            layerType: layerType,
            name: name,
            position: CGPoint(x: positionX, y: positionY),
            size: CGSize(width: width, height: height),
            zIndex: zIndex
        )
        layer.id = layerId
        layer.isVisible = isVisible
        layer.isLocked = isLocked
        layer.imagePath = imagePath
        layer.drawingData = drawingData
        layer.shapeType = shapeType
        layer.shapePathData = shapePathData
        layer.strokeColor = strokeColor
        layer.fillColor = fillColor
        return layer
    }
}

/// Represents a single change to a layer for incremental history.
enum LayerChange {
    /// A layer was added (store ID to remove on undo)
    case added(layerId: UUID)
    /// A layer was deleted (store full snapshot to restore on undo)
    case deleted(snapshot: LayerSnapshot)
    /// A layer was modified (store before snapshot to restore on undo)
    case modified(layerId: UUID, beforeSnapshot: LayerSnapshot)
}

/// Incremental history action storing only changes, not full state.
struct IncrementalHistoryAction {
    let changes: [LayerChange]
    let timestamp: Date

    init(changes: [LayerChange]) {
        self.changes = changes
        timestamp = Date()
    }
}

/// Manager for undo history of layer modifications.
/// Uses incremental storage to only track changed layers.
@Observable
class LayerHistoryManager {
    private var undoStack: [IncrementalHistoryAction] = []

    private let maxHistorySize = HistorySettings.maxHistorySize

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    /// Records a modification to specific layers (stores before state).
    func recordModification(of layers: [RealtimeEditLayer]) {
        let changes = layers.map { layer in
            LayerChange.modified(layerId: layer.id, beforeSnapshot: LayerSnapshot(from: layer))
        }
        pushAction(IncrementalHistoryAction(changes: changes))
    }

    /// Records the addition of a new layer.
    func recordAddition(of layerId: UUID) {
        let changes = [LayerChange.added(layerId: layerId)]
        pushAction(IncrementalHistoryAction(changes: changes))
    }

    /// Records the deletion of layers (captures full state for restore).
    func recordDeletion(of layers: [RealtimeEditLayer]) {
        let changes = layers.map { layer in
            // Capture drawing data immediately since layer is being deleted
            LayerChange.deleted(snapshot: LayerSnapshot(from: layer, captureDrawingDataNow: true))
        }
        pushAction(IncrementalHistoryAction(changes: changes))
    }

    private func pushAction(_ action: IncrementalHistoryAction) {
        undoStack.append(action)

        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }
    }

    /// Performs undo and returns the changes to apply.
    func undo() -> IncrementalHistoryAction? {
        guard let action = undoStack.popLast() else {
            return nil
        }
        return action
    }

    func clear() {
        undoStack.removeAll()
    }
}

/// Main canvas editor view.
struct RealtimeEditCanvasView: View {
    @Environment(\.modelContext) private var modelContext

    private let keychain: KeychainSwift = {
        let kc = KeychainSwift()
        kc.accessGroup = TEAM_KEYCHAIN_AG
        kc.synchronizable = true
        return kc
    }()

    @ObservedObject private var providerKeysCache = ProviderKeysCache.shared

    @Bindable var session: RealtimeEditSession

    // Layer state
    @State private var layers: [RealtimeEditLayer] = []
    @State private var selectedLayerIds: Set<UUID> = []

    // Tool state
    @State private var selectedTool: EditTool = .select
    @State private var previousTool: EditTool = .select

    // Canvas viewport state
    @State private var canvasScale: CGFloat = 1.0
    @State private var canvasOffset: CGPoint = .zero

    /// Preview refresh trigger
    @State private var previewRefreshTrigger = UUID()

    /// Layers popover
    @State private var showLayersPopover = false

    /// Image picker state
    @State private var showImagePicker = false

    /// Canvas visibility
    @State private var showCanvas = false

    /// Undo/redo history
    @State private var historyManager = LayerHistoryManager()

    /// Brush drawing state
    @State private var activeDrawingLayerId: UUID?

    /// Realtime generation engine (initialized lazily with actual image generator)
    @State private var realtimeEngine: RealtimeEditEngine?

    /// Tracks whether initial load has completed to prevent triggering engine on view appear
    @State private var hasCompletedInitialLoad = false

    /// Whether to show the realtime edit warning modal
    @State private var showRealtimeWarning = false

    /// User preference to hide the warning modal permanently
    @AppStorage("hideRealtimeEditWarning") private var hideRealtimeEditWarning = false

    /// Toggle between Canvas and Gallery view
    @State private var showGalleryView = false

    /// Generations linked to this realtime session (queried by realtimeSessionId)
    @State private var sessionGenerations: [Generation] = []

    /// Whether to show the first-generation info modal
    @State private var showFirstGenerationInfo = false

    /// User preference to hide the first-generation info modal permanently
    @AppStorage("hideFirstGenerationInfo") private var hideFirstGenerationInfo = false

    /// Guide popover visibility
    @State private var showGuide = false

    /// Layout constants
    private let referenceCanvasSize: CGFloat = 560 // Reference size for layer coordinates

    // MARK: - Brush State

    /// Current brush color derived from session hex value
    private var brushColor: Color {
        colorFromHex(session.brushColorHex)
    }

    // MARK: - Shape State

    /// Current shape color derived from session hex value
    private var shapeColor: Color {
        colorFromHex(session.shapeColorHex)
    }

    /// Selected shape type from session
    private var selectedShapeType: ShapeType {
        ShapeType(rawValue: session.selectedShapeTypeRawValue) ?? .square
    }

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width < canvasMinWidth || !showCanvas {
                // Show expand window view when window is too narrow OR no model selected
                VStack(spacing: 0) {
                    Spacer()

                    if geometry.size.width < canvasMinWidth {
                        ExpandWindowView()
                    } else {
                        AvgeekEmptyStateView(
                            icon: "wand.and.rays.inverse",
                            title: "Select a Model",
                            message: "Choose a provider and model below to start creating."
                        )
                    }

                    Spacer()

                    Divider()

                    // Bottom: Prompt Bar
                    RealtimeEditPromptBar(
                        session: session,
                        providerKeys: providerKeysCache.providerKeys,
                        layers: layers,
                        selectedTool: $selectedTool,
                        showCanvas: $showCanvas,
                        showLayersPopover: $showLayersPopover,
                        selectedLayerIds: $selectedLayerIds,
                        previewRefreshTrigger: $previewRefreshTrigger,
                        showImagePicker: $showImagePicker,
                        onLayerUpdate: updateLayerWithHistory,
                        onLayerDelete: deleteLayer,
                        onLayerReorder: reorderLayers,
                        onClearAllLayers: clearAllLayers,
                        onBrushSettingsChanged: finalizeActiveDrawingLayer
                    )
                    .background(.ultraThinMaterial)
                }
            } else {
                let panelWidth = (geometry.size.width / 2)

                // Get aspect ratio from selected dimensions
                let aspectRatio: CGFloat = if let parts = parseDimensions(session.selectedDimensions) {
                    CGFloat(parts.height) / CGFloat(parts.width)
                } else {
                    1.0
                }

                // Calculate reference canvas dimensions with aspect ratio
                let referenceWidth = referenceCanvasSize
                let referenceHeight = referenceCanvasSize * aspectRatio

                // Calculate max height available
                let estimatedPromptBarHeight: CGFloat = 254
                let minTopSpacing: CGFloat = 20
                let totalReservedSpace = estimatedPromptBarHeight + minTopSpacing
                let maxAvailableHeight = max(geometry.size.height - totalReservedSpace, 300)

                // Calculate scale to fit within available space
                let widthScale = panelWidth / referenceWidth
                let heightScale = maxAvailableHeight / referenceHeight
                let canvasScale = min(widthScale, heightScale)

                // Calculate displayed dimensions
                let displayedWidth = referenceWidth * canvasScale
                let displayedHeight = referenceHeight * canvasScale

                VStack(spacing: 0) {
                    // View mode toggle (Canvas/Gallery)
                    HStack(alignment: .center, spacing: 0) {
                        Picker("", selection: $showGalleryView) {
                            Label("Canvas", systemImage: "pencil.and.outline")
                                .tag(false)
                            Label("Gallery", systemImage: "square.grid.2x2")
                                .tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        Spacer()

                        Text("\(sessionGenerations.count) frames")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        guideButton
                            .padding(.leading, 12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(tertiarySystemFill)

                    if showGalleryView {
                        // Gallery view
                        realtimeGalleryView
                    } else {
                        // Main content: Equal-width panels
                        HStack(spacing: 0) {
                            // Left: Editor Canvas
                            EditorCanvasView(
                                session: session,
                                layers: layers,
                                selectedLayerIds: $selectedLayerIds,
                                selectedTool: $selectedTool,
                                previousTool: previousTool,
                                canvasScale: $canvasScale,
                                canvasOffset: $canvasOffset,
                                canvasSize: CGSize(width: referenceWidth, height: referenceHeight),
                                brushColor: brushColor,
                                brushSize: CGFloat(session.brushSize),
                                shapeColor: shapeColor,
                                selectedShapeType: selectedShapeType,
                                activeDrawingLayerId: $activeDrawingLayerId,
                                onLayerUpdate: updateLayerWithHistory,
                                onLayerCreate: createLayer,
                                onAddStroke: addStrokeToLayer,
                                showImagePicker: $showImagePicker
                            )
                            .frame(width: referenceWidth, height: referenceHeight)
                            .scaleEffect(canvasScale)
                            .frame(width: displayedWidth, height: displayedHeight)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                            // Right: Preview
                            PreviewCanvasView(
                                layers: layers,
                                refreshTrigger: previewRefreshTrigger,
                                canvasSize: CGSize(width: referenceWidth, height: referenceHeight),
                                generationId: realtimeEngine?.lastGenerationId,
                                isGenerating: realtimeEngine?.state == .generating ||
                                    realtimeEngine?.state == .generatingWithPending,
                                onSaveToGallery: { generationId in
                                    // Find the Generation by ID and reveal it in gallery
                                    if let generation = sessionGenerations.first(where: { $0.id == generationId }) {
                                        saveGenerationToGallery(generation)
                                    }
                                }
                            )
                            .frame(width: referenceWidth, height: referenceHeight)
                            .scaleEffect(canvasScale)
                            .frame(width: displayedWidth, height: displayedHeight)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    Divider()

                    // Bottom: Prompt Bar (fixed at bottom)
                    RealtimeEditPromptBar(
                        session: session,
                        providerKeys: providerKeysCache.providerKeys,
                        layers: layers,
                        selectedTool: $selectedTool,
                        showCanvas: $showCanvas,
                        showLayersPopover: $showLayersPopover,
                        selectedLayerIds: $selectedLayerIds,
                        previewRefreshTrigger: $previewRefreshTrigger,
                        showImagePicker: $showImagePicker,
                        onLayerUpdate: updateLayer,
                        onLayerDelete: deleteLayer,
                        onLayerReorder: reorderLayers,
                        onClearAllLayers: clearAllLayers,
                        onBrushSettingsChanged: finalizeActiveDrawingLayer
                    )
                    .background(.ultraThinMaterial)
                }
            }
        }
        .navigationTitle("Realtime Edit")
        .onAppear {
            loadLayers()
            loadCanvasState()
            loadSessionGenerations()
            // Initialize showCanvas based on whether a model is already selected
            showCanvas = !session.selectedModelId.isEmpty
            // Always start with select tool when entering a session
            selectedTool = .select
            // Initialize realtime engine
            if realtimeEngine == nil {
                realtimeEngine = RealtimeEditEngine(
                    session: session,
                    modelContext: modelContext,
                    keychain: keychain,
                    speedMs: session.generationSpeedMs
                )
            }
            realtimeEngine?.setCanvasSize(CGSize(width: referenceCanvasSize, height: referenceCanvasSize))
            realtimeEngine?.setSpeed(session.generationSpeedMs)

            // Initialize engine state from current canvas BEFORE enabling
            // This prevents triggering a generation on session load when nothing changed
            let initialInput = RealtimeEditEngineInput(
                layers: layers,
                boundingBox: CGRect(
                    origin: .zero,
                    size: CGSize(width: referenceCanvasSize, height: referenceCanvasSize)
                ),
                prompt: session.configuration.prompt,
                providerId: session.selectedProviderId,
                modelId: session.selectedModelId,
                seed: String(session.seed),
                dimensions: session.selectedDimensions
            )
            realtimeEngine?.initializeState(from: initialInput)
            realtimeEngine?.isEnabled = true

            // Load the last generation from disk if available
            loadLastGeneration()

            // Mark initial load as complete after a short delay
            // This prevents onChange handlers from triggering engine on initial data load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasCompletedInitialLoad = true
            }

            // Show warning modal if user hasn't dismissed it permanently
            if !hideRealtimeEditWarning {
                showRealtimeWarning = true
            }
        }
        .onDisappear {
            saveCanvasState()
            historyManager.clear() // Release history memory when leaving view
            realtimeEngine?.cancel()
        }
        .onChange(of: session.id) { oldSessionId, newSessionId in
            // Save old session state before switching
            if oldSessionId != newSessionId {
                saveCanvasStateForSession(oldSessionId)
            }

            // Clear selection and history when switching sessions
            selectedLayerIds.removeAll()
            historyManager.clear()
            activeDrawingLayerId = nil
            hasCompletedInitialLoad = false
            selectedTool = .select
            realtimeEngine?.reset()

            // Load new session state
            loadLayers()
            loadCanvasState()
            loadSessionGenerations()
            showCanvas = !session.selectedModelId.isEmpty
            previewRefreshTrigger = UUID()

            // Initialize engine state from new session's canvas BEFORE any triggers
            let sessionInput = RealtimeEditEngineInput(
                layers: layers,
                boundingBox: CGRect(
                    origin: .zero,
                    size: CGSize(width: referenceCanvasSize, height: referenceCanvasSize)
                ),
                prompt: session.configuration.prompt,
                providerId: session.selectedProviderId,
                modelId: session.selectedModelId,
                seed: String(session.seed),
                dimensions: session.selectedDimensions
            )
            realtimeEngine?.initializeState(from: sessionInput)
            realtimeEngine?.isEnabled = true

            // Load the last generation for the new session
            loadLastGeneration()

            // Mark initial load as complete after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasCompletedInitialLoad = true
            }
        }
        .onChange(of: selectedTool) { oldValue, newValue in
            // Save previous tool when switching to temporary tools (attach, shape)
            if newValue == .attach || newValue == .shape {
                // Only save if coming from a persistent tool (select, brush)
                if oldValue == .select || oldValue == .brush {
                    previousTool = oldValue
                }
            }

            if newValue == .attach {
                showImagePicker = true
            }

            // Finalize drawing layer when switching away from brush
            if oldValue == .brush {
                finalizeActiveDrawingLayer()
            }
        }
        .onChange(of: session.brushColorHex) { _, _ in
            // Finalize active layer when color changes
            finalizeActiveDrawingLayer()
        }
        .onChange(of: session.brushSize) { _, _ in
            // Finalize active layer when size changes
            finalizeActiveDrawingLayer()
        }
        .onChange(of: selectedLayerIds) { _, newSelection in
            // Finalize active drawing layer if it's no longer selected
            // This handles the case where user selects a different layer via layers panel
            if let activeId = activeDrawingLayerId, !newSelection.contains(activeId) {
                finalizeActiveDrawingLayer()
            }
        }
        .onChange(of: layers) { _, _ in
            // Trigger realtime engine when layers change (only after initial load)
            guard hasCompletedInitialLoad else { return }
            triggerRealtimeEngine()
        }
        .onChange(of: previewRefreshTrigger) { _, _ in
            // Trigger realtime engine when layer properties change (position, drawing, etc.)
            // This fires when updateLayer(), addStrokeToLayer(), etc. set previewRefreshTrigger = UUID()
            guard hasCompletedInitialLoad else { return }
            triggerRealtimeEngine()
        }
        .onChange(of: session.seed) { _, _ in
            // Trigger realtime engine when seed changes (only after initial load)
            guard hasCompletedInitialLoad else { return }
            triggerRealtimeEngine()
        }
        .onChange(of: session.generationSpeedMs) { _, newSpeed in
            // Update engine speed when user changes the speed setting
            realtimeEngine?.setSpeed(newSpeed)
        }
        .onChange(of: session.configuration.prompt) { _, _ in
            // Trigger realtime engine when prompt changes (only after initial load)
            guard hasCompletedInitialLoad else { return }
            triggerRealtimeEngine()
        }
        .onChange(of: realtimeEngine?.lastGenerationId) { _, newId in
            // Reload gallery to include new generation (engine handles persistence)
            if newId != nil {
                loadSessionGenerations()

                // Show first-generation info modal once (persisted across sessions)
                if !hideFirstGenerationInfo {
                    hideFirstGenerationInfo = true
                    showFirstGenerationInfo = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UndoKeyPressed"))) { _ in
            performUndo()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DeleteKeyPressed"))) { _ in
            handleDeleteKey()
        }
        .background(KeyboardMonitorView())
        .sheet(isPresented: $showRealtimeWarning) {
            RealtimeEditWarningModal(
                hideWarningPermanently: $hideRealtimeEditWarning,
                isPresented: $showRealtimeWarning
            )
        }
        .sheet(isPresented: $showFirstGenerationInfo) {
            FirstGenerationInfoModal(isPresented: $showFirstGenerationInfo)
        }
    }

    // MARK: - Layout Calculations

    private func calculateCanvasHeight(for size: CGSize, panelWidth: CGFloat) -> CGFloat {
        let dimensions = session.selectedDimensions

        let aspectRatio: CGFloat = if let parts = parseDimensions(dimensions) {
            CGFloat(parts.height) / CGFloat(parts.width)
        } else {
            1.0
        }

        let calculatedHeight = panelWidth * aspectRatio
        let estimatedPromptBarHeight: CGFloat = 254
        let minTopSpacing: CGFloat = 20
        let totalReservedSpace = estimatedPromptBarHeight + minTopSpacing
        let maxHeight = max(size.height - totalReservedSpace, 300)

        return min(calculatedHeight, maxHeight)
    }

    private func parseDimensions(_ dimensions: String) -> (width: Int, height: Int)? {
        let parts = dimensions.split(separator: "x")
        guard parts.count == 2,
              let width = Int(parts[0]),
              let height = Int(parts[1])
        else {
            return nil
        }
        return (width, height)
    }

    // MARK: - Layer Management

    private func loadLayers() {
        let descriptor = FetchDescriptor<RealtimeEditLayer>(
            predicate: #Predicate { $0.sessionId == session.id },
            sortBy: [SortDescriptor(\.zIndex)]
        )

        do {
            layers = try modelContext.fetch(descriptor)
        } catch {
            AppLogger.data.error("RealtimeEdit: Error loading layers: \(error.localizedDescription, privacy: .public)")
            layers = []
        }
    }

    private func createLayer(_ layer: RealtimeEditLayer) {
        modelContext.insert(layer)

        do {
            try modelContext.save()
            loadLayers()
            previewRefreshTrigger = UUID()
        } catch {
            AppLogger.data.error("RealtimeEdit: Error creating layer: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func updateLayer(_ layer: RealtimeEditLayer) {
        do {
            try modelContext.save()
            loadLayers()
            previewRefreshTrigger = UUID()
        } catch {
            AppLogger.data.error("RealtimeEdit: Error updating layer: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func updateLayerWithHistory(_ layer: RealtimeEditLayer) {
        // Record modification before changes (incremental - only this layer)
        historyManager.recordModification(of: [layer])

        // Perform update
        updateLayer(layer)
    }

    private func addStrokeToLayer(_ layer: RealtimeEditLayer, _ stroke: BrushStroke) {
        // Record modification BEFORE adding the stroke (for undo)
        historyManager.recordModification(of: [layer])

        // Add stroke to layer's drawing data
        var drawingData = DrawingData.decode(from: layer.drawingData)
        drawingData.strokes.append(stroke)
        layer.drawingData = drawingData.encode()

        // Save changes
        updateLayer(layer)
    }

    private func deleteLayer(_ layerId: UUID) {
        guard let layer = layers.first(where: { $0.id == layerId }) else { return }

        // Record deletion for undo (captures full state)
        historyManager.recordDeletion(of: [layer])

        modelContext.delete(layer)

        do {
            try modelContext.save()
            selectedLayerIds.remove(layerId)
            loadLayers()
            previewRefreshTrigger = UUID()
        } catch {
            AppLogger.data.error("RealtimeEdit: Error deleting layer: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func reorderLayers(_ reorderedLayers: [RealtimeEditLayer]) {
        // z-indices already updated by the caller
        do {
            try modelContext.save()
            loadLayers()
            previewRefreshTrigger = UUID()
        } catch {
            AppLogger.data
                .error("RealtimeEdit: Error reordering layers: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func clearAllLayers() {
        // Delete all layers from the database
        for layer in layers {
            modelContext.delete(layer)
        }

        do {
            try modelContext.save()
            selectedLayerIds.removeAll()
            loadLayers()
            previewRefreshTrigger = UUID()
            realtimeEngine?.reset()
        } catch {
            AppLogger.data.error("RealtimeEdit: Error clearing layers: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Drawing Layer Finalization

    /// Finalizes the active drawing layer, preventing further edits.
    ///
    /// Called when:
    /// - Brush color changes
    /// - Brush size changes
    /// - Tool switches from brush to select
    ///
    /// Also trims the layer bounds to fit the actual strokes.
    private func finalizeActiveDrawingLayer() {
        guard let layerId = activeDrawingLayerId,
              let layer = layers.first(where: { $0.id == layerId })
        else {
            activeDrawingLayerId = nil
            return
        }

        // Trim the layer bounds to fit the strokes
        trimDrawingLayerBounds(layer)

        activeDrawingLayerId = nil
    }

    /// Trims a drawing layer's bounds to fit its strokes with padding.
    private func trimDrawingLayerBounds(_ layer: RealtimeEditLayer) {
        var drawingData = DrawingData.decode(from: layer.drawingData)
        guard !drawingData.strokes.isEmpty else { return }

        // Collect all points and find the max stroke size for padding
        var allPoints: [CGPoint] = []
        var maxStrokeSize: CGFloat = 0

        for stroke in drawingData.strokes {
            allPoints.append(contentsOf: stroke.points)
            maxStrokeSize = max(maxStrokeSize, stroke.size)
        }

        guard !allPoints.isEmpty else { return }

        // Calculate bounding box
        let minX = allPoints.map(\.x).min() ?? 0
        let minY = allPoints.map(\.y).min() ?? 0
        let maxX = allPoints.map(\.x).max() ?? 0
        let maxY = allPoints.map(\.y).max() ?? 0

        // Add padding (half the max stroke size on each side)
        let padding = maxStrokeSize / 2 + 2
        let newX = max(0, minX - padding)
        let newY = max(0, minY - padding)
        let newWidth = (maxX - minX) + padding * 2
        let newHeight = (maxY - minY) + padding * 2

        // Transform all stroke points to be relative to the new position
        let offsetX = newX
        let offsetY = newY

        for i in drawingData.strokes.indices {
            drawingData.strokes[i].points = drawingData.strokes[i].points.map { point in
                CGPoint(x: point.x - offsetX, y: point.y - offsetY)
            }
        }

        // Update layer
        layer.positionX = newX
        layer.positionY = newY
        layer.width = newWidth
        layer.height = newHeight
        layer.drawingData = drawingData.encode()

        // Save changes
        updateLayer(layer)
    }

    // MARK: - Canvas State

    private func loadCanvasState() {
        canvasScale = session.canvasScale
        canvasOffset = CGPoint(x: session.canvasOffsetX, y: session.canvasOffsetY)
    }

    private func saveCanvasState() {
        session.canvasScale = canvasScale
        session.canvasOffsetX = canvasOffset.x
        session.canvasOffsetY = canvasOffset.y

        try? modelContext.save()
    }

    /// Saves canvas state for a specific session ID (used when switching sessions).
    private func saveCanvasStateForSession(_ sessionId: UUID) {
        let descriptor = FetchDescriptor<RealtimeEditSession>(
            predicate: #Predicate { $0.id == sessionId }
        )

        do {
            if let oldSession = try modelContext.fetch(descriptor).first {
                oldSession.canvasScale = canvasScale
                oldSession.canvasOffsetX = canvasOffset.x
                oldSession.canvasOffsetY = canvasOffset.y
                try modelContext.save()
            }
        } catch {
            AppLogger.data
                .error(
                    "RealtimeEdit: Error saving canvas state for session: \(error.localizedDescription, privacy: .public)"
                )
        }
    }

    // MARK: - Realtime Engine

    /// Triggers the realtime generation engine with current canvas state.
    private func triggerRealtimeEngine() {
        let input = RealtimeEditEngineInput(
            layers: layers,
            boundingBox: CGRect(
                origin: .zero,
                size: CGSize(width: referenceCanvasSize, height: referenceCanvasSize)
            ),
            prompt: session.configuration.prompt,
            providerId: session.selectedProviderId,
            modelId: session.selectedModelId,
            seed: String(session.seed),
            dimensions: session.selectedDimensions
        )
        realtimeEngine?.onCanvasChanged(input: input)
    }

    /// Restores the last generation ID if saved in the session.
    ///
    /// The actual image is loaded via ICloudImageLoader in PreviewCanvasView.
    private func loadLastGeneration() {
        guard let fileName = session.lastGenerationFilePath,
              !fileName.isEmpty,
              let generationId = UUID(uuidString: fileName)
        else {
            return
        }

        // Restore just the ID - image loaded by ICloudImageLoader
        realtimeEngine?.restoreGeneration(id: generationId)
    }

    /// Loads all generations linked to this realtime session.
    private func loadSessionGenerations() {
        let sessionId = session.id
        var descriptor = FetchDescriptor<Generation>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.predicate = #Predicate<Generation> { generation in
            generation.realtimeSessionId == sessionId
        }

        do {
            sessionGenerations = try modelContext.fetch(descriptor)
        } catch {
            AppLogger.data
                .error(
                    "RealtimeEdit: Error loading session generations: \(error.localizedDescription, privacy: .public)"
                )
            sessionGenerations = []
        }
    }

    // MARK: - Undo

    private func performUndo() {
        guard let action = historyManager.undo() else {
            return
        }

        // Apply each change in reverse
        for change in action.changes {
            switch change {
            case let .added(layerId):
                // Undo addition = delete the layer
                if let layer = layers.first(where: { $0.id == layerId }) {
                    modelContext.delete(layer)
                }

            case let .deleted(snapshot):
                // Undo deletion = recreate the layer
                let recreatedLayer = snapshot.recreateLayer()
                modelContext.insert(recreatedLayer)

            case let .modified(layerId, beforeSnapshot):
                // Undo modification = restore previous state
                if let layer = layers.first(where: { $0.id == layerId }) {
                    beforeSnapshot.restore(to: layer)
                }
            }
        }

        // Save changes
        do {
            try modelContext.save()
            loadLayers()
            previewRefreshTrigger = UUID()
        } catch {
            AppLogger.data.error("RealtimeEdit: Error performing undo: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Delete

    private func handleDeleteKey() {
        guard !selectedLayerIds.isEmpty else { return }
        deleteSelectedLayers()
    }

    private func deleteSelectedLayers() {
        // Get layers to delete
        let layersToDelete = layers.filter { selectedLayerIds.contains($0.id) }
        guard !layersToDelete.isEmpty else { return }

        // Record deletion for undo (captures full state of all deleted layers)
        historyManager.recordDeletion(of: layersToDelete)

        // Delete all selected layers
        for layer in layersToDelete {
            modelContext.delete(layer)
        }

        do {
            try modelContext.save()
            selectedLayerIds.removeAll()
            loadLayers()
            previewRefreshTrigger = UUID()
        } catch {
            AppLogger.data.error("RealtimeEdit: Error deleting layers: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Gallery View

    /// Gallery view showing all generations for this session.
    private var realtimeGalleryView: some View {
        GeometryReader { geometry in
            if sessionGenerations.isEmpty {
                AvgeekEmptyStateView(
                    icon: "photo.on.rectangle.angled",
                    title: "No Generations",
                    message: "Generations will appear here as you edit the canvas."
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: galleryColumns(for: geometry.size.width), spacing: 2) {
                        // Already sorted by createdAt descending (newest first)
                        ForEach(sessionGenerations) { generation in
                            galleryCell(generation: generation)
                        }
                    }
                    .padding(2)
                }
            }
        }
    }

    /// Calculate responsive grid columns based on available width.
    private func galleryColumns(for width: CGFloat) -> [GridItem] {
        #if os(macOS)
        var columnCount = 6
        if width < 600 {
            columnCount = 3
        } else if width < 900 {
            columnCount = 4
        }
        return Array(repeating: GridItem(.flexible(), spacing: 2), count: columnCount)
        #else
        let columnCount = UIDevice.current.userInterfaceIdiom == .pad ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 2), count: columnCount)
        #endif
    }

    /// Individual gallery cell for a generation.
    private func galleryCell(generation: Generation) -> some View {
        ICloudImageLoader(imageName: generation.id.uuidString, aspectRatio: 1.0) { image in
            if let image {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(1.0, contentMode: .fill)
                    .clipped()
                    .contextMenu {
                        generationContextMenu(generation: generation, image: image)
                    }
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(1.0, contentMode: .fill)
                    .clipped()
                    .contextMenu {
                        generationContextMenu(generation: generation, image: image)
                    }
                #endif
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .aspectRatio(1.0, contentMode: .fill)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }

    @ViewBuilder
    private func generationContextMenu(generation: Generation, image: PlatformImage) -> some View {
        Button {
            saveGenerationToGallery(generation)
        } label: {
            Label("Save to Image Gallery", systemImage: "photo.badge.plus")
        }

        Button {
            #if os(macOS)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
            #else
            UIPasteboard.general.image = image
            #endif
            showToast(.success("Copied to clipboard"))
        } label: {
            Label("Copy image", systemImage: "doc.on.doc")
        }

        Button {
            #if os(macOS)
            image.saveImageToDownloads(fileName: generation.id.uuidString)
            #else
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                DispatchQueue.main.async {
                    if status == .authorized || status == .limited {
                        PHPhotoLibrary.shared().performChanges {
                            PHAssetChangeRequest.creationRequestForAsset(from: image)
                        }
                    }
                }
            }
            #endif
        } label: {
            Label("Download image", systemImage: "arrow.down")
        }

        Button {
            #if os(macOS)
            image.shareImage()
            #else
            UIPasteboard.general.image = image
            showToast(.success("Copied to clipboard for sharing"))
            #endif
        } label: {
            Label("Share image", systemImage: "square.and.arrow.up")
        }
    }

    /// Saves a realtime generation to the main gallery.
    ///
    /// Creates an ImageSet to properly group the generation, updates the generation's
    /// setId, and reveals it in the gallery by setting isHidden to false.
    private func saveGenerationToGallery(_ generation: Generation) {
        // Create an ImageSet to properly integrate with the gallery
        let imageSet = ImageSet(
            prompt: generation.prompt,
            projectId: generation.projectId,
            modelId: generation.modelId,
            style: generation.style,
            variant: generation.variant,
            dimensions: generation.dimensions,
            setType: .IMAGE_GENERATE
        )
        modelContext.insert(imageSet)

        // Link generation to the new set and reveal it
        generation.setId = imageSet.id
        generation.isHidden = false

        do {
            try modelContext.save()

            // Add both set and generation to cache for immediate UI update
            GalleryCache.shared.addImageSet(imageSet)
            GalleryCache.shared.addGeneration(generation)

            // Notify other observers
            NotificationCenter.default.post(name: .generationCreated, object: nil)
            showToast(.success("Saved to Image Gallery"))
            AppLogger.data.info("RealtimeEdit: Generation saved to gallery with set: \(imageSet.id, privacy: .public)")
        } catch {
            showToast(.error("Failed to save", subtitle: error.localizedDescription))
            AppLogger.data
                .error("RealtimeEdit: Error saving generation: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Guide Button

    private var guideButton: some View {
        GuidePopover(
            title: "Realtime Edit Guide",
            sections: [
                GuideSection(
                    title: "What is Realtime Edit?",
                    content: "Realtime Edit provides a canvas-based image editing experience with live AI generation. As you draw, add images, or modify layers, the preview updates with AI-generated interpretations of your canvas in realtime."
                ),
                GuideSection(
                    title: "Canvas Tools",
                    items: [
                        GuideItem(
                            icon: "cursorarrow",
                            text: "Select: Click to select layers. Drag to move. Resize using corner handles."
                        ),
                        GuideItem(
                            icon: "paintbrush",
                            text: "Brush: Draw freehand strokes. Adjust color and size in the toolbar."
                        ),
                        GuideItem(
                            icon: "square.on.square",
                            text: "Shape: Add geometric shapes like rectangles, circles, and lines."
                        ),
                        GuideItem(
                            icon: "photo.badge.plus",
                            text: "Attach: Import images from your device to use as reference layers."
                        ),
                    ]
                ),
                GuideSection(
                    title: "Quick Reference",
                    items: [
                        GuideItem(
                            icon: "command",
                            text: "Press ⌘Z to undo actions. Press Delete to remove selected layers."
                        ),
                        GuideItem(
                            icon: "square.stack.3d.up",
                            text: "Use the Layers panel to reorder, show/hide, or lock layers."
                        ),
                        GuideItem(
                            icon: "photo.badge.plus",
                            text: "Right-click preview images to save them to your main Image Gallery."
                        ),
                        GuideItem(
                            icon: "gauge.with.dots.needle.67percent",
                            text: "Adjust generation speed in settings. Faster speeds use more credits."
                        ),
                    ]
                ),
            ],
            isPresented: $showGuide
        )
    }
}

// MARK: - Realtime Edit Warning Modal

/// Warning modal shown when users first enter Realtime Edit.
///
/// Displays important information about credit consumption, network requirements,
/// and the experimental nature of the feature. Includes a "Don't show again"
/// checkbox that persists the preference using AppStorage.
struct RealtimeEditWarningModal: View {
    @Binding var hideWarningPermanently: Bool
    @Binding var isPresented: Bool

    @State private var dontShowAgain = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)

                    Text("Before You Begin")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 24)

                Divider()

                // Warning items
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        warningItem(
                            icon: "creditcard.fill",
                            title: "High Credit Consumption",
                            description: "Realtime edits consume credits rapidly with each canvas change. Ensure you have sufficient credits and a clear use case before proceeding."
                        )

                        warningItem(
                            icon: "wifi",
                            title: "Fast Internet Required",
                            description: "A high-speed internet connection is essential. Slow connections cause latency issues with image uploads and downloads, degrading the realtime experience."
                        )

                        warningItem(
                            icon: "flask.fill",
                            title: "Experimental Feature",
                            description: "This feature is experimental and requires caution. Excessive usage may result in irreversible credit loss and rate limits being applied to your account."
                        )
                    }
                    .padding(.all, 24)
                }

                Divider()

                // Footer with checkbox
                HStack {
                    Toggle(isOn: $dontShowAgain) {
                        Text("Don't show this again")
                            .font(.callout)
                    }
                    #if os(macOS)
                    .toggleStyle(.checkbox)
                    #endif
                    Spacer()
                }
                .padding(.all, 24)
            }
            .frame(width: 420)
            #if os(macOS)
            .background(Color(nsColor: .windowBackgroundColor))
            #else
            .background(Color(uiColor: .systemBackground))
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Continue") {
                        if dontShowAgain {
                            hideWarningPermanently = true
                        }
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func warningItem(
        icon: String,
        title: String,
        description: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.primary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - First Generation Info Modal

/// Info modal shown when the first image generates in a session.
///
/// Explains that realtime edit images are not in the main gallery and
/// provides instructions for saving them using the context menu.
struct FirstGenerationInfoModal: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(
                        "The images generated as part of realtime edit sessions are stored within this session and are not automatically added to your main Image Gallery."
                    )
                    .font(.callout)

                    Text("To save an image to your Image Gallery:")
                        .font(.callout)
                        .fontWeight(.medium)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        infoStep(
                            number: "1",
                            text: "Right-click (or Control-click) on any image in the Gallery tab or the Preview panel"
                        )

                        infoStep(
                            number: "2",
                            text: "Select \"Save to Image Gallery\" from the context menu to copy the image to your main gallery"
                        )
                    }
                }
                .padding(24)
            }
            .navigationTitle("Saving Realtime Generations")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got It") {
                        isPresented = false
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(uiColor: .systemBackground))
        #endif
    }

    private func infoStep(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.callout)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(Circle())

            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
