// MARK: - QueueManager.swift

// Manages the generation queue for image and video creation requests.
//
// QueueManager is the central coordinator for all generation requests in the app.
// It provides:
// - A visible queue of pending/completed/failed generations
// - Async submission of generation requests
// - Progress tracking for long-running operations
// - Cancellation support
// - Integration with FailedRequestsManager for error logging
//
// ## Architecture
// QueueManager is a singleton that runs on the main actor for UI safety.
// Generation requests are submitted as QueueItems, which wrap the async task
// and track status/results.
//
// ## Queue Item Lifecycle
// 1. `submitImageGeneration` / `submitVideoGeneration` creates a QueueItem
// 2. Item starts with `.IN_PROGRESS` status
// 3. Async task runs the generation adapter
// 4. On completion: status → `.SUCCESSFUL` or `.FAILED`
// 5. Results (setId or error) stored on the item
//
// ## UI Integration
// The queue is displayed in QueueSidebarView/MobileQueueView, showing:
// - In-progress items with optional progress percentage
// - Completed items (clickable to view results)
// - Failed items with error details
//
// ## Agent Integration
// Special `submitXAndAwait` methods support agent workflows that need
// to wait for results before continuing to the next step.

import Combine
import Foundation
import KeychainSwift
import OSLog
import SwiftData
import SwiftUI

// MARK: - Queue Item Status

/// Tracks the state of a generation request in the queue.
enum QueueItemStatus: String, Codable {
    /// Request is being processed
    case IN_PROGRESS
    /// Request completed successfully
    case SUCCESSFUL
    /// Request failed with error
    case FAILED

    /// Backward-compatible decoding for legacy raw values.
    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        switch rawValue {
        case "in_progress", "IN_PROGRESS", "inProgress": self = .IN_PROGRESS
        case "successful", "SUCCESSFUL": self = .SUCCESSFUL
        case "failed", "FAILED": self = .FAILED
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown QueueItemStatus: \(rawValue)"
                )
            )
        }
    }
}

// MARK: - Queue Item Source

/// Identifies the feature that triggered the generation request.
///
/// Used to:
/// - Tag queue items with their origin feature
/// - Determine auto-removal behavior for successful generations
enum QueueItemSource: String, Codable {
    /// Manual generation from Image Generate view
    case IMAGE_GENERATE
    /// Manual generation from Video Generate view
    case VIDEO_GENERATE
    /// Chat Threads feature
    case CHAT_THREADS
    /// Flow Canvas / Playground feature
    case FLOW_CANVAS
    /// Bulk Generate / Bulk Sessions feature
    case BULK_GENERATE
    /// Bulk Edits feature
    case BULK_EDIT
    /// Storyboard feature
    case STORYBOARD
    /// Creative Studio feature
    case CREATIVE_STUDIO
    /// Product Photoshoots feature
    case PRODUCT_PHOTOSHOOTS
    /// Agent Builder feature
    case AGENT_BUILDER
    /// macOS Menu Bar quick generate
    case MENU_BAR

    /// Backward-compatible decoding for legacy raw values.
    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        switch rawValue {
        case "imageGenerate", "IMAGE_GENERATE": self = .IMAGE_GENERATE
        case "videoGenerate", "VIDEO_GENERATE": self = .VIDEO_GENERATE
        case "chatThreads", "CHAT_THREADS": self = .CHAT_THREADS
        case "flowCanvas", "FLOW_CANVAS": self = .FLOW_CANVAS
        case "bulkGenerate", "BULK_GENERATE": self = .BULK_GENERATE
        case "bulkEdit", "BULK_EDIT": self = .BULK_EDIT
        case "storyboard", "STORYBOARD": self = .STORYBOARD
        case "creativeStudio", "CREATIVE_STUDIO": self = .CREATIVE_STUDIO
        case "productPhotoshoots", "PRODUCT_PHOTOSHOOTS": self = .PRODUCT_PHOTOSHOOTS
        case "agentBuilder", "AGENT_BUILDER": self = .AGENT_BUILDER
        case "menuBar", "MENU_BAR": self = .MENU_BAR
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown QueueItemSource: \(rawValue)"
                )
            )
        }
    }

    /// Whether successful items from this source should be auto-removed from queue
    var shouldAutoRemoveOnSuccess: Bool {
        switch self {
        case .CHAT_THREADS, .FLOW_CANVAS, .BULK_GENERATE, .BULK_EDIT, .STORYBOARD,
             .CREATIVE_STUDIO, .PRODUCT_PHOTOSHOOTS, .AGENT_BUILDER, .MENU_BAR:
            true
        case .IMAGE_GENERATE, .VIDEO_GENERATE:
            false
        }
    }
}

// MARK: - Queue Item

/// Represents a single generation request in the queue.
///
/// QueueItem wraps a generation request and tracks its lifecycle:
/// - Status (in progress, successful, failed)
/// - Results (setId for navigation, error message for debugging)
/// - Progress (percentage for video generation)
/// - Cancellation (via the stored Task reference)
///
/// ## Observable
/// QueueItem is an ObservableObject so the UI updates as status changes.
class QueueItem: Identifiable, ObservableObject {
    /// Unique identifier for queue tracking
    let id: UUID

    /// The prompt submitted for generation (displayed in queue UI)
    let prompt: String

    /// When this request was submitted
    let createdAt: Date

    /// The feature that triggered this generation request
    let source: QueueItemSource

    /// Current status of the generation
    @Published var status: QueueItemStatus

    /// Resulting ImageSet ID on success (for images)
    @Published var resultSetId: UUID?

    /// Error message on failure
    @Published var errorMessage: String?

    /// Raw API response on failure (for debugging)
    @Published var rawResponse: String?

    /// Resulting ImageSet ID on success (for videos)
    @Published var resultVideoSetId: UUID?

    /// First generation ID (for preview thumbnail lookup)
    @Published var resultGenerationId: UUID?

    /// Whether this is a video generation (affects UI display)
    @Published var isVideoGeneration: Bool

    /// Progress percentage for long-running operations (0-100)
    @Published var progress: Int?

    /// Reference to the async Task for cancellation support
    var task: Task<Void, Never>?

    init(
        id: UUID = UUID(),
        prompt: String,
        source: QueueItemSource,
        status: QueueItemStatus = .IN_PROGRESS,
        resultSetId: UUID? = nil,
        errorMessage: String? = nil,
        rawResponse: String? = nil,
        isVideoGeneration: Bool = false,
        progress: Int? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.source = source
        createdAt = Date()
        self.status = status
        self.resultSetId = resultSetId
        self.errorMessage = errorMessage
        self.rawResponse = rawResponse
        self.isVideoGeneration = isVideoGeneration
        self.progress = progress
    }

    /// Cancels the generation request if still in progress.
    func cancel() {
        task?.cancel()
        task = nil
    }
}

// MARK: - Queue Manager

/// Singleton manager coordinating all generation requests.
///
/// QueueManager provides a central point for:
/// - Submitting image and video generation requests
/// - Tracking request status and results
/// - Displaying queue state in the UI
/// - Supporting cancellation and cleanup
///
/// ## Main Actor
/// This class is annotated with `@MainActor` to ensure all
/// state modifications happen on the main thread for UI safety.
@MainActor
class QueueManager: ObservableObject {
    /// Shared singleton instance
    static let shared = QueueManager()

    /// All queue items, ordered by submission time (newest first)
    @Published var items: [QueueItem] = []

    func addItem(_ item: QueueItem) {
        items.insert(item, at: 0)
        AppLogger.queue
            .info(
                "Queue: Added \(item.isVideoGeneration ? "video" : "image", privacy: .public) generation to queue (id: \(item.id, privacy: .public))"
            )
    }

    func removeItem(_ item: QueueItem) {
        items.removeAll { $0.id == item.id }
    }

    func removeItem(by id: UUID) {
        items.removeAll { $0.id == id }
    }

    func cancelItem(_ item: QueueItem) {
        item.cancel()
        item.status = .FAILED
        item.errorMessage = "Cancelled by user"
        objectWillChange.send()
        AppLogger.queue.info("Queue: Item cancelled by user (id: \(item.id, privacy: .public))")
    }

    func cancelItem(by id: UUID) {
        if let item = items.first(where: { $0.id == id }) {
            cancelItem(item)
        }
    }

    func updateItemStatus(
        _ id: UUID,
        status: QueueItemStatus,
        resultSetId: UUID? = nil,
        resultGenerationId: UUID? = nil,
        errorMessage: String? = nil,
        rawResponse: String? = nil
    ) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].status = status
            items[index].resultSetId = resultSetId
            items[index].resultGenerationId = resultGenerationId
            items[index].errorMessage = errorMessage
            items[index].rawResponse = rawResponse
            objectWillChange.send()
        }
    }

    func updateVideoItemStatus(
        _ id: UUID,
        status: QueueItemStatus,
        resultVideoSetId: UUID? = nil,
        resultGenerationId: UUID? = nil,
        errorMessage: String? = nil,
        rawResponse: String? = nil
    ) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].status = status
            items[index].resultVideoSetId = resultVideoSetId
            items[index].resultGenerationId = resultGenerationId
            items[index].errorMessage = errorMessage
            items[index].rawResponse = rawResponse
            objectWillChange.send()
        }
    }

    func clearAllFailed() {
        items.removeAll { $0.status == .FAILED }
    }

    func clearAllCompleted() {
        items.removeAll { $0.status == .SUCCESSFUL }
    }

    var inProgressItems: [QueueItem] {
        items.filter { $0.status == .IN_PROGRESS }
    }

    var successfulItems: [QueueItem] {
        items.filter { $0.status == .SUCCESSFUL }
    }

    var failedItems: [QueueItem] {
        items.filter { $0.status == .FAILED }
    }

    var partitionedItems: (inProgress: [QueueItem], successful: [QueueItem], failed: [QueueItem]) {
        var inProgress: [QueueItem] = []
        var successful: [QueueItem] = []
        var failed: [QueueItem] = []
        for item in items {
            switch item.status {
            case .IN_PROGRESS: inProgress.append(item)
            case .SUCCESSFUL: successful.append(item)
            case .FAILED: failed.append(item)
            }
        }
        return (inProgress, successful, failed)
    }

    var hasActiveItems: Bool {
        !inProgressItems.isEmpty
    }

    var totalCount: Int {
        items.count
    }

    #if os(macOS)
    private func sendBackgroundCompletionNotification(isVideo: Bool) {
        guard NSApplication.shared.isActive == false else { return }
        GenerationNotificationService.shared.sendCompletionNotification(isVideo: isVideo)
    }
    #endif

    func submitImageGeneration(
        request: ImageGenerationRequest,
        modelContext: ModelContext,
        source: QueueItemSource
    ) -> QueueItem {
        let item = QueueItem(
            prompt: request.prompt,
            source: source,
            isVideoGeneration: false
        )

        addItem(item)

        item.task = Task {
            await performImageGeneration(
                queueItemId: item.id,
                request: request,
                modelContext: modelContext,
                source: source
            )
        }

        return item
    }

    private func performImageGeneration(
        queueItemId: UUID,
        request: ImageGenerationRequest,
        modelContext: ModelContext,
        source: QueueItemSource
    ) async {
        let adapter = GenerateImageAdapter(
            imageGenerationRequest: request,
            modelContext: modelContext
        )

        let response = await adapter.makeRequest()

        await MainActor.run {
            if response.status == .GENERATED, let setId = response.set?.id {
                // Always update item properties so any waiting code (e.g., bulk generation) can see the result
                // Only update if the item is still in progress (not cancelled by the user)
                if let item = items.first(where: { $0.id == queueItemId }), item.status == .IN_PROGRESS {
                    item.status = .SUCCESSFUL
                    item.resultSetId = setId
                    objectWillChange.send()
                }

                if source.shouldAutoRemoveOnSuccess {
                    removeItem(by: queueItemId)
                    AppLogger.queue
                        .notice(
                            "Queue: Image generation completed and auto-removed (id: \(queueItemId, privacy: .public), setId: \(setId, privacy: .public), source: \(source.rawValue, privacy: .public))"
                        )
                } else {
                    AppLogger.queue
                        .notice(
                            "Queue: Image generation completed (id: \(queueItemId, privacy: .public), setId: \(setId, privacy: .public))"
                        )
                }

                #if os(macOS)
                if source != .BULK_GENERATE, source != .BULK_EDIT {
                    sendBackgroundCompletionNotification(isVideo: false)
                }
                #endif
            } else {
                updateItemStatus(
                    queueItemId,
                    status: .FAILED,
                    errorMessage: response.errorMessage ?? "Generation failed",
                    rawResponse: response.rawResponse
                )
                AppLogger.queue
                    .error(
                        "Queue: Image generation failed (id: \(queueItemId, privacy: .public)) - \(response.errorMessage ?? "Unknown error", privacy: .public)"
                    )

                FailedRequestsManager.shared.addFailedRequest(
                    modelContext: modelContext,
                    projectId: request.providerKey.projectId,
                    prompt: request.prompt,
                    modelId: request.modelId,
                    dimensions: request.dimensions,
                    isVideoGeneration: false,
                    errorMessage: response.errorMessage ?? "Generation failed",
                    errorCode: response.errorCode?.rawValue ?? "",
                    rawResponse: response.rawResponse
                )
            }
        }

        await BalanceService.shared.fetchBalance(
            for: request.providerKey.providerId,
            projectId: request.providerKey.projectId
        )
    }

    func submitVideoGeneration(
        request: VideoGenerationRequest,
        modelContext: ModelContext,
        source: QueueItemSource
    ) -> QueueItem {
        let item = QueueItem(
            prompt: request.prompt ?? "",
            source: source,
            isVideoGeneration: true
        )

        addItem(item)

        item.task = Task {
            await performVideoGeneration(
                queueItemId: item.id,
                request: request,
                modelContext: modelContext,
                source: source
            )
        }

        return item
    }

    private func performVideoGeneration(
        queueItemId: UUID,
        request: VideoGenerationRequest,
        modelContext: ModelContext,
        source: QueueItemSource
    ) async {
        var requestWithCallback = request
        requestWithCallback.progressCallback = { progress in
            Task { @MainActor in
                if let item = self.items.first(where: { $0.id == queueItemId }) {
                    item.progress = progress
                    self.objectWillChange.send()
                }
            }
        }

        let adapter = GenerateVideoAdapter(
            videoGenerationRequest: requestWithCallback,
            modelContext: modelContext
        )

        let response = await adapter.makeRequest()

        await MainActor.run {
            if response.status == .GENERATED, let setId = response.set?.id {
                // Always update item properties so any waiting code can see the result
                // Only update if the item is still in progress (not cancelled by the user)
                if let item = items.first(where: { $0.id == queueItemId }), item.status == .IN_PROGRESS {
                    item.status = .SUCCESSFUL
                    item.resultVideoSetId = setId
                    objectWillChange.send()
                }

                if source.shouldAutoRemoveOnSuccess {
                    removeItem(by: queueItemId)
                    AppLogger.queue
                        .notice(
                            "Queue: Video generation completed and auto-removed (id: \(queueItemId, privacy: .public), setId: \(setId, privacy: .public), source: \(source.rawValue, privacy: .public))"
                        )
                } else {
                    AppLogger.queue
                        .notice(
                            "Queue: Video generation completed (id: \(queueItemId, privacy: .public), setId: \(setId, privacy: .public))"
                        )
                }

                #if os(macOS)
                if source != .BULK_GENERATE, source != .BULK_EDIT {
                    sendBackgroundCompletionNotification(isVideo: true)
                }
                #endif
            } else {
                updateVideoItemStatus(
                    queueItemId,
                    status: .FAILED,
                    errorMessage: response.errorMessage ?? "Video generation failed",
                    rawResponse: response.rawResponse
                )
                AppLogger.queue
                    .error(
                        "Queue: Video generation failed (id: \(queueItemId, privacy: .public)) - \(response.errorMessage ?? "Unknown error", privacy: .public)"
                    )

                FailedRequestsManager.shared.addFailedRequest(
                    modelContext: modelContext,
                    projectId: request.providerKey.projectId,
                    prompt: request.prompt ?? "",
                    modelId: request.modelId,
                    dimensions: request.dimensions,
                    isVideoGeneration: true,
                    errorMessage: response.errorMessage ?? "Video generation failed",
                    errorCode: response.errorCode?.rawValue ?? "",

                    rawResponse: response.rawResponse
                )
            }
        }

        await BalanceService.shared.fetchBalance(
            for: request.providerKey.providerId,
            projectId: request.providerKey.projectId
        )
    }

    func submitImageGenerationAndAwait(
        request: ImageGenerationRequest,
        modelContext: ModelContext,
        runId: UUID,
        agentId: UUID,
        source: QueueItemSource = .AGENT_BUILDER
    ) async -> ImageSetResponse {
        let item = QueueItem(
            prompt: request.prompt,
            source: source,
            isVideoGeneration: false
        )

        addItem(item)

        let adapter = GenerateImageAdapter(
            imageGenerationRequest: request,
            modelContext: modelContext
        )

        let response = await adapter.makeRequest()

        await MainActor.run {
            if response.status == .GENERATED, let setId = response.set?.id {
                let firstGenerationId = response.generations?.first?.id

                if source.shouldAutoRemoveOnSuccess {
                    removeItem(by: item.id)
                    AppLogger.queue
                        .notice(
                            "Queue: Image generation completed and auto-removed (id: \(item.id, privacy: .public), setId: \(setId, privacy: .public), source: \(source.rawValue, privacy: .public))"
                        )
                } else {
                    updateItemStatus(
                        item.id,
                        status: .SUCCESSFUL,
                        resultSetId: setId,
                        resultGenerationId: firstGenerationId
                    )
                }

                if let generations = response.generations {
                    for generation in generations {
                        generation.runId = runId
                        generation.agentId = agentId
                    }
                    // SwiftData autosave handles persistence - avoid explicit saves
                    // to reduce WAL checkpoint contention during concurrent operations
                }
            } else {
                updateItemStatus(
                    item.id,
                    status: .FAILED,
                    errorMessage: response.errorMessage ?? "Generation failed",
                    rawResponse: response.rawResponse
                )

                FailedRequestsManager.shared.addFailedRequest(
                    modelContext: modelContext,
                    projectId: request.providerKey.projectId,
                    prompt: request.prompt,
                    modelId: request.modelId,
                    dimensions: request.dimensions,
                    isVideoGeneration: false,
                    errorMessage: response.errorMessage ?? "Generation failed",
                    errorCode: response.errorCode?.rawValue ?? "",
                    rawResponse: response.rawResponse
                )
            }
        }

        await BalanceService.shared.fetchBalance(
            for: request.providerKey.providerId,
            projectId: request.providerKey.projectId
        )

        return response
    }

    func submitVideoGenerationAndAwait(
        request: VideoGenerationRequest,
        modelContext: ModelContext,
        runId: UUID,
        agentId: UUID,
        source: QueueItemSource = .AGENT_BUILDER
    ) async -> VideoSetResponse {
        let item = QueueItem(
            prompt: request.prompt ?? "",
            source: source,
            isVideoGeneration: true
        )

        addItem(item)

        let adapter = GenerateVideoAdapter(
            videoGenerationRequest: request,
            modelContext: modelContext
        )

        let response = await adapter.makeRequest()

        await MainActor.run {
            if response.status == .GENERATED, let setId = response.set?.id {
                let firstGenerationId = response.generations?.first?.id

                if source.shouldAutoRemoveOnSuccess {
                    removeItem(by: item.id)
                    AppLogger.queue
                        .notice(
                            "Queue: Video generation completed and auto-removed (id: \(item.id, privacy: .public), setId: \(setId, privacy: .public), source: \(source.rawValue, privacy: .public))"
                        )
                } else {
                    updateVideoItemStatus(
                        item.id,
                        status: .SUCCESSFUL,
                        resultVideoSetId: setId,
                        resultGenerationId: firstGenerationId
                    )
                }

                if let generations = response.generations {
                    for generation in generations {
                        generation.runId = runId
                        generation.agentId = agentId
                    }
                    // SwiftData autosave handles persistence - avoid explicit saves
                    // to reduce WAL checkpoint contention during concurrent operations
                }
            } else {
                updateVideoItemStatus(
                    item.id,
                    status: .FAILED,
                    errorMessage: response.errorMessage ?? "Video generation failed",
                    rawResponse: response.rawResponse
                )

                FailedRequestsManager.shared.addFailedRequest(
                    modelContext: modelContext,
                    projectId: request.providerKey.projectId,
                    prompt: request.prompt ?? "",
                    modelId: request.modelId,
                    dimensions: request.dimensions,
                    isVideoGeneration: true,
                    errorMessage: response.errorMessage ?? "Video generation failed",
                    errorCode: response.errorCode?.rawValue ?? "",
                    rawResponse: response.rawResponse
                )
            }
        }

        await BalanceService.shared.fetchBalance(
            for: request.providerKey.providerId,
            projectId: request.providerKey.projectId
        )

        return response
    }
}
