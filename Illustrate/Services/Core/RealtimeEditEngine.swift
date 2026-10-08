// MARK: - RealtimeEditEngine.swift

// Engine for real-time image generation based on canvas changes.
//
// Monitors canvas state and triggers generations when:
// 1. Last generation has completed
// 2. Minimum time (500ms) has elapsed since last generation
// 3. Layer content has changed OR seed value has changed
//
// ## Architecture
// - Uses protocol-based image generation for testability
// - StubImageGenerator returns canvas PNG (for initial implementation)
// - LLMImageGenerator will integrate with actual providers (future)
//
// ## Usage
// 1. Create engine and add as @StateObject in view
// 2. Call setCanvasSize() on appear
// 3. Call onCanvasChanged() when layers/prompt/seed change
// 4. Observe currentGeneration for preview updates

import Combine
import Foundation
import IllustrateProviders
import KeychainSwift
import SwiftData
import SwiftUI

// MARK: - Queue Item

/// Represents a single item in the generation queue.
struct RealtimeQueueItem: Identifiable {
    /// Unique identifier for this queue item
    let id: UUID

    /// Timestamp when this item was added to the queue
    let enqueuedAt: Date

    /// The input parameters for generation
    let input: RealtimeEditEngineInput

    init(input: RealtimeEditEngineInput) {
        id = UUID()
        enqueuedAt = Date()
        self.input = input
    }
}

// MARK: - Generation Queue

/// Thread-safe queue with max 2 items: one in-progress and one pending.
///
/// Uses actor isolation for safe concurrent access. The queue enforces
/// FPS-based throttling on enqueue and supports pending slot swapping.
actor RealtimeGenerationQueue {
    /// The item currently being processed (nil if idle)
    private(set) var inProgress: RealtimeQueueItem?

    /// The pending item waiting to be processed (nil if none)
    private(set) var pending: RealtimeQueueItem?

    /// Last time an item entered the in-progress slot.
    private var lastStartTime: Date?

    /// Minimum interval between generation starts based on speed setting (in milliseconds)
    private(set) var minimumEnqueueIntervalMs: Double

    init(minimumEnqueueIntervalMs: Double) {
        self.minimumEnqueueIntervalMs = minimumEnqueueIntervalMs
    }

    /// Updates the minimum interval between enqueues.
    func setMinimumInterval(_ intervalMs: Double) {
        minimumEnqueueIntervalMs = intervalMs
    }

    /// Result of an enqueue attempt
    enum EnqueueResult {
        /// Successfully added to queue
        case enqueued(position: EnqueuePosition)
        /// Request was retained as pending because it is too soon to start it.
        case throttled(remainingMs: Double)
        /// Queue had pending item which was replaced
        case replaced
    }

    enum EnqueuePosition {
        /// Added as pending (in-progress slot occupied)
        case pending
        /// Added directly to in-progress (queue was empty)
        case inProgress
    }

    /// Attempts to add an item to the queue.
    ///
    /// Qualification rules:
    /// 1. Must be > minimumIntervalMs since the last item started
    /// 2. If there's already a pending item, replace it (swap)
    /// 3. If in-progress is empty, go directly to in-progress
    ///
    /// - Parameter input: The generation input to enqueue
    /// - Returns: Result indicating what happened
    func enqueue(input: RealtimeEditEngineInput) -> EnqueueResult {
        let now = Date()
        let item = RealtimeQueueItem(input: input)

        // Check FPS-based qualification
        if let lastTime = lastStartTime {
            let elapsedMs = now.timeIntervalSince(lastTime) * 1000
            if elapsedMs < minimumEnqueueIntervalMs {
                // Keep the latest change so a one-off seed, prompt, or canvas
                // update is not lost merely because it arrived during throttle.
                pending = item
                return .throttled(remainingMs: minimumEnqueueIntervalMs - elapsedMs)
            }
        }

        // If no in-progress, add directly there
        if inProgress == nil {
            inProgress = item
            lastStartTime = now
            return .enqueued(position: .inProgress)
        }

        // Swap pending if exists
        let didReplace = pending != nil
        pending = item
        return didReplace ? .replaced : .enqueued(position: .pending)
    }

    /// Takes the next item from the queue for processing.
    ///
    /// Called by the engine loop when ready to process:
    /// 1. If in-progress is occupied, return it (it's being worked on)
    /// 2. If in-progress is empty but pending exists, promote pending to in-progress
    ///
    /// - Returns: The item to process, or nil if queue is empty
    func dequeue() -> RealtimeQueueItem? {
        // If something is already in-progress, return it
        if let current = inProgress {
            return current
        }

        // Promote pending to in-progress
        if let next = pending {
            if let lastTime = lastStartTime {
                let elapsedMs = Date().timeIntervalSince(lastTime) * 1000
                guard elapsedMs >= minimumEnqueueIntervalMs else {
                    return nil
                }
            }

            pending = nil
            inProgress = next
            lastStartTime = Date()
            return next
        }

        return nil
    }

    /// Marks the in-progress item as complete.
    ///
    /// Called when generation finishes (success or failure).
    /// Clears the in-progress slot so next dequeue can promote pending.
    func markInProgressComplete() {
        inProgress = nil
    }

    /// Clears the entire queue.
    func clear() {
        inProgress = nil
        pending = nil
        lastStartTime = nil
    }

    /// Whether there's an item currently being processed
    var hasInProgress: Bool {
        inProgress != nil
    }

    /// Whether there's a pending item waiting
    var hasPending: Bool {
        pending != nil
    }
}

// MARK: - Engine Input

/// Input parameters for triggering a generation.
struct RealtimeEditEngineInput {
    /// All layers on the canvas
    let layers: [RealtimeEditLayer]

    /// Bounding box for the generation area
    let boundingBox: CGRect

    /// User's text prompt
    let prompt: String

    /// Selected provider UUID string
    let providerId: String

    /// Selected model UUID string
    let modelId: String

    /// Seed value (empty string for random)
    let seed: String

    /// Image dimensions (e.g., "1024x1024")
    let dimensions: String
}

// MARK: - Engine State

/// State of the realtime edit engine.
enum RealtimeEditEngineState: Equatable {
    /// Engine is idle, waiting for changes
    case idle

    /// Engine is generating an image
    case generating

    /// Engine is generating and has a pending request queued
    case generatingWithPending

    /// Engine encountered an error
    case error(String)
}

// MARK: - Realtime Edit Engine

/// Engine for real-time image generation based on canvas changes.
///
/// Monitors canvas state and triggers generations when conditions are met:
/// - Last generation has completed
/// - Minimum interval has elapsed (500ms at 2 FPS)
/// - Canvas content has changed (layers or seed)
@MainActor
class RealtimeEditEngine: ObservableObject {
    // MARK: - Published State

    /// Current engine state
    @Published private(set) var state: RealtimeEditEngineState = .idle

    /// ID of the most recent generation (for preview display via ICloudImageLoader)
    @Published private(set) var lastGenerationId: UUID?

    /// Whether the engine is active (enabled by user)
    @Published var isEnabled = false {
        didSet {
            if isEnabled {
                startEngineLoop()
            } else {
                stopEngineLoop()
            }
        }
    }

    // MARK: - Dependencies

    /// The session this engine is bound to (source of prompt, modelId, etc.)
    private let session: RealtimeEditSession

    /// SwiftData context for creating Generation objects via GenerateImageAdapter
    private let modelContext: ModelContext

    /// Keychain for API key retrieval
    private let keychain: KeychainSwift

    // MARK: - Queue

    /// The generation queue (actor-isolated for thread safety)
    private let queue: RealtimeGenerationQueue

    // MARK: - Private State

    /// Hash of last layer state for change detection
    private var lastLayerStateHash: Int?

    /// Last seed value
    private var lastSeed: String?

    /// Last prompt value
    private var lastPrompt: String?

    /// Engine loop task that processes the queue
    private var engineLoopTask: Task<Void, Never>?

    /// Canvas size for PNG capture
    private var canvasSize: CGSize = .zero

    // MARK: - Configuration

    private let loopIntervalNs = UInt64(RealtimeEngineSettings.engineLoopIntervalMs) * 1_000_000

    // MARK: - Initialization

    /// Creates a new engine bound to a session.
    ///
    /// - Parameters:
    ///   - session: The realtime edit session (source of prompt, modelId, etc.)
    ///   - modelContext: SwiftData context for creating Generation objects
    ///   - keychain: Keychain for API key retrieval
    ///   - speedMs: Initial generation speed in milliseconds
    init(
        session: RealtimeEditSession,
        modelContext: ModelContext,
        keychain: KeychainSwift,
        speedMs: Double = GenerationSpeed.defaultSpeed.intervalMs
    ) {
        self.session = session
        self.modelContext = modelContext
        self.keychain = keychain
        queue = RealtimeGenerationQueue(minimumEnqueueIntervalMs: speedMs)
    }

    // MARK: - Public Methods

    /// Configure the canvas size for PNG rendering.
    ///
    /// - Parameter size: Canvas dimensions in points
    func setCanvasSize(_ size: CGSize) {
        canvasSize = size
    }

    /// Updates the generation speed.
    ///
    /// - Parameter speedMs: New speed in milliseconds (interval between generations)
    func setSpeed(_ speedMs: Double) {
        Task { await queue.setMinimumInterval(speedMs) }
    }

    /// Initializes the engine's tracking state without triggering a generation.
    ///
    /// Call this when loading a session to set the baseline state. This prevents
    /// the engine from seeing the initial load as a "change" and triggering
    /// an unnecessary generation that costs money.
    ///
    /// - Parameter input: Current canvas state to use as baseline
    func initializeState(from input: RealtimeEditEngineInput) {
        lastLayerStateHash = calculateLayerStateHash(
            layers: input.layers,
            boundingBox: input.boundingBox
        )
        lastSeed = input.seed
        lastPrompt = input.prompt
    }

    /// Called when canvas state changes (layers, prompt, seed).
    ///
    /// Enqueues to the generation queue if the request qualifies (FPS throttling).
    /// The engine loop processes the queue automatically.
    ///
    /// - Parameter input: Current canvas state
    func onCanvasChanged(input: RealtimeEditEngineInput) {
        guard isEnabled else { return }

        // Calculate state hash for change detection
        let currentStateHash = calculateLayerStateHash(
            layers: input.layers,
            boundingBox: input.boundingBox
        )

        // Check if anything changed
        let layersChanged = currentStateHash != lastLayerStateHash
        let seedChanged = input.seed != lastSeed
        let promptChanged = input.prompt != lastPrompt

        guard layersChanged || seedChanged || promptChanged else {
            return // No changes detected
        }

        // Store new state
        lastLayerStateHash = currentStateHash
        lastSeed = input.seed
        lastPrompt = input.prompt

        // Enqueue directly - the queue handles FPS throttling
        Task { [weak self] in
            guard let self else { return }
            _ = await queue.enqueue(input: input)
        }
    }

    /// Stop any in-flight generation and clear the queue.
    func cancel() {
        stopEngineLoop()
        Task { await queue.clear() }
        state = .idle
    }

    /// Reset engine state completely.
    ///
    /// Note: This stops the engine loop via cancel(), then restarts it if enabled.
    /// The loop must be restarted because isEnabled doesn't change during this operation,
    /// so the didSet observer (lines 239-245) won't trigger automatically.
    func reset() {
        cancel()
        lastGenerationId = nil
        lastLayerStateHash = nil
        lastSeed = nil
        lastPrompt = nil

        // Restart loop if enabled (cancel() stopped it but isEnabled didn't change)
        if isEnabled {
            startEngineLoop()
        }
    }

    /// Restores a previously saved generation ID.
    ///
    /// Used when returning to a session to display the last generated image
    /// without triggering a new generation request.
    ///
    /// - Parameter id: The generation UUID to restore
    func restoreGeneration(id: UUID) {
        lastGenerationId = id
    }

    // MARK: - Engine Loop

    /// Starts the engine processing loop.
    ///
    /// The loop runs continuously while engine is enabled:
    /// 1. Check queue for items to process
    /// 2. If item found, execute generation
    /// 3. Mark complete and check for pending
    /// 4. Sleep briefly before next check
    private func startEngineLoop() {
        guard engineLoopTask == nil else { return }

        engineLoopTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                // Check if enabled
                guard isEnabled else {
                    try? await Task.sleep(nanoseconds: loopIntervalNs)
                    continue
                }

                // Try to get next item from queue
                if let item = await queue.dequeue() {
                    // Update state based on queue
                    await updateStateFromQueue()

                    // Execute generation
                    await executeGeneration(input: item.input)

                    // Mark complete
                    await queue.markInProgressComplete()

                    // Update state again
                    await updateStateFromQueue()
                }

                // Sleep before next check
                try? await Task.sleep(nanoseconds: loopIntervalNs)
            }
        }
    }

    /// Stops the engine processing loop.
    private func stopEngineLoop() {
        engineLoopTask?.cancel()
        engineLoopTask = nil
    }

    /// Updates published state based on current queue state.
    private func updateStateFromQueue() async {
        let hasInProgress = await queue.hasInProgress
        let hasPending = await queue.hasPending

        if hasInProgress, hasPending {
            state = .generatingWithPending
        } else if hasInProgress {
            state = .generating
        } else {
            state = .idle
        }
    }

    // MARK: - Private Methods

    /// Execute the actual generation using GenerateImageAdapter.
    private func executeGeneration(input: RealtimeEditEngineInput) async {
        // Capture canvas as PNG and convert to base64
        guard let canvasImage = captureCanvasAsPNG(
            layers: input.layers,
            canvasSize: canvasSize
        ),
            let base64Image = canvasImage.toBase64PNG()
        else {
            AppLogger.generation.error("[RealtimeEngine] Failed to capture canvas as PNG")
            return
        }

        // Get provider UUID
        guard let providerUUID = UUID(uuidString: input.providerId) else {
            AppLogger.generation.error("[RealtimeEngine] Invalid provider ID: \(input.providerId, privacy: .public)")
            return
        }

        // Get provider to access providerCode
        guard let provider = getProvider(providerId: providerUUID) else {
            AppLogger.generation.error("[RealtimeEngine] Provider not found: \(input.providerId, privacy: .public)")
            return
        }

        // Get API key from keychain
        let keychainKey = ProjectManager.keychainKey(
            projectId: ProjectManager.shared.currentProjectId,
            providerId: providerUUID
        )
        guard let apiKey = keychain.get(keychainKey) else {
            AppLogger.generation.error("[RealtimeEngine] API key not found for provider")
            return
        }

        // Build ProviderKeyInfo using provider's providerCode
        let providerKeyInfo = ProviderKeyInfo(
            providerId: providerUUID,
            providerCode: provider.providerCode,
            projectId: ProjectManager.shared.currentProjectId
        )

        let selectedModel = ProviderService.shared.model(by: input.modelId)

        // Parse seed safely for models that actually support seed.
        var seedValue: Int?
        if selectedModel?.modelParams.supportsSeed == true, !input.seed.isEmpty {
            guard let parsedSeed = Int(input.seed) else {
                AppLogger.generation.error("[RealtimeEngine] Invalid seed value: \(input.seed, privacy: .public)")
                return
            }
            seedValue = parsedSeed
        }

        // Build ImageGenerationRequest
        let request = ImageGenerationRequest(
            modelId: input.modelId,
            prompt: input.prompt,
            dimensions: input.dimensions,
            clientImage: base64Image,
            providerKey: providerKeyInfo,
            providerSecret: apiKey,
            numberOfImages: 1,
            seed: seedValue
        )

        // Use GenerateImageAdapter with realtimeSessionId
        let adapter = GenerateImageAdapter(
            imageGenerationRequest: request,
            modelContext: modelContext,
            realtimeSessionId: session.id
        )

        let response = await adapter.makeRequest()

        if response.status == EnumGenerationStatus.GENERATED,
           let generation = response.generations?.first
        {
            // Update session's last generation path
            session.lastGenerationFilePath = generation.id.uuidString
            try? modelContext.save()

            // Publish for view
            lastGenerationId = generation.id

            AppLogger.generation
                .notice("[RealtimeEngine] Generation complete: \(generation.id, privacy: .public)")
        } else {
            AppLogger.generation
                .error("[RealtimeEngine] Generation failed: \(response.errorMessage ?? "unknown", privacy: .public)")
        }
    }

    /// Calculate hash of layer state for change detection.
    private func calculateLayerStateHash(
        layers: [RealtimeEditLayer],
        boundingBox: CGRect
    ) -> Int {
        var hasher = Hasher()

        // Hash visible layers in z-order
        for layer in layers.filter(\.isVisible).sorted(by: { $0.zIndex < $1.zIndex }) {
            hasher.combine(layer.id)
            hasher.combine(layer.positionX)
            hasher.combine(layer.positionY)
            hasher.combine(layer.width)
            hasher.combine(layer.height)
            hasher.combine(layer.zIndex)
            hasher.combine(layer.layerType.rawValue)
            hasher.combine(layer.drawingData)
            hasher.combine(layer.imagePath)
            hasher.combine(layer.shapeType?.rawValue)
            hasher.combine(layer.fillColor)
            hasher.combine(layer.strokeColor)
        }

        // Hash bounding box
        hasher.combine(boundingBox.origin.x)
        hasher.combine(boundingBox.origin.y)
        hasher.combine(boundingBox.size.width)
        hasher.combine(boundingBox.size.height)

        return hasher.finalize()
    }

    /// Capture the canvas composition as PNG.
    private func captureCanvasAsPNG(
        layers: [RealtimeEditLayer],
        canvasSize: CGSize
    ) -> PlatformImage? {
        let visibleLayers = layers.filter(\.isVisible).sorted { $0.zIndex < $1.zIndex }

        guard !visibleLayers.isEmpty else {
            return nil
        }

        let size = canvasSize.width > 0 ? canvasSize : CGSize(width: 1024, height: 1024)

        // Use ImageRenderer to capture SwiftUI view as image
        let canvasView = CanvasSnapshotView(layers: visibleLayers, canvasSize: size)
        let renderer = ImageRenderer(content: canvasView)
        renderer.scale = 1.0

        #if os(macOS)
        return renderer.nsImage
        #else
        return renderer.uiImage
        #endif
    }
}

// MARK: - Canvas Snapshot View

/// SwiftUI view for rendering layers to an image.
private struct CanvasSnapshotView: View {
    let layers: [RealtimeEditLayer]
    let canvasSize: CGSize

    var body: some View {
        ZStack {
            // White background
            Color.white

            // Render each layer
            ForEach(layers) { layer in
                SnapshotLayerView(layer: layer)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }
}

/// Simplified layer view for snapshot rendering.
private struct SnapshotLayerView: View {
    let layer: RealtimeEditLayer

    var body: some View {
        Group {
            switch layer.layerType {
            case .image:
                imageLayerView
            case .drawing:
                drawingLayerView
            case .shape:
                shapeLayerView
            }
        }
        .frame(width: layer.width, height: layer.height)
        .position(
            x: layer.positionX + layer.width / 2,
            y: layer.positionY + layer.height / 2
        )
    }

    @ViewBuilder
    private var imageLayerView: some View {
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
        }
    }

    @ViewBuilder
    private var drawingLayerView: some View {
        let strokes = DrawingData.decode(from: layer.drawingData).strokes

        Canvas { context, _ in
            for stroke in strokes {
                drawStroke(stroke, in: &context)
            }
        }
    }

    @ViewBuilder
    private var shapeLayerView: some View {
        if let shapeType = layer.shapeType {
            let fillColor = colorFromHex(layer.fillColor ?? RealtimeEditColors.defaultShape)

            switch shapeType {
            case .triangle:
                Triangle()
                    .fill(fillColor)
            case .square:
                Rectangle()
                    .fill(fillColor)
            case .circle:
                Circle()
                    .fill(fillColor)
            }
        }
    }

    /// Draw a stroke path in the graphics context.
    private func drawStroke(_ stroke: BrushStroke, in context: inout GraphicsContext) {
        guard stroke.points.count >= 2 else {
            // Single point: draw a dot
            if let point = stroke.points.first {
                let rect = CGRect(
                    x: point.x - stroke.size / 2,
                    y: point.y - stroke.size / 2,
                    width: stroke.size,
                    height: stroke.size
                )
                context.fill(
                    Circle().path(in: rect),
                    with: .color(colorFromHex(stroke.colorHex))
                )
            }
            return
        }

        // Create smooth path through points
        var path = Path()
        path.move(to: stroke.points[0])

        if stroke.points.count == 2 {
            path.addLine(to: stroke.points[1])
        } else {
            for i in 1 ..< stroke.points.count {
                let currentPoint = stroke.points[i]
                let previousPoint = stroke.points[i - 1]
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
            // Add final line to last point
            if let lastPoint = stroke.points.last {
                path.addLine(to: lastPoint)
            }
        }

        // Stroke the path
        context.stroke(
            path,
            with: .color(colorFromHex(stroke.colorHex)),
            style: StrokeStyle(
                lineWidth: stroke.size,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }
}
