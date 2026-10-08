// MARK: - StoryboardViewModel.swift

// ViewModel for managing storyboard editor state and operations.
//
// StoryboardViewModel handles:
// - Loading and persisting storyboard data (scenes, assets)
// - Scene management (add, reorder, delete)
// - Playback state (current scene, play/pause)
// - Scene generation through the queue system
//
// ## Architecture
// Uses SwiftData for persistence and QueueManager for async generation.
// Observes queue item status changes to update scene generation progress.

import AVFoundation
import Combine
import Foundation
import IllustrateProviders
import KeychainSwift
import OSLog
import SwiftData
import SwiftUI

/// ViewModel managing storyboard editor state and scene generation.
@MainActor
class StoryboardViewModel: ObservableObject {
    // MARK: - Dependencies

    private let providerService = ProviderService.shared
    private let keychain: KeychainSwift

    // MARK: - Published State

    /// The storyboard being edited
    @Published var storyboard: Storyboard

    /// All scenes in this storyboard, ordered by index
    @Published var scenes: [StoryboardScene] = []

    /// All reference assets for this storyboard
    @Published var assets: [StoryboardAsset] = []

    /// Currently selected scene index
    @Published var selectedSceneIndex: Int? = nil

    /// Sheet state for adding new scenes
    @Published var showAddSceneSheet = false

    /// Alert state for errors
    @Published var showErrorAlert = false
    @Published var errorMessage = ""

    /// Export state
    @Published var isExporting = false
    @Published var showExportSuccessAlert = false

    /// Reference images per scene (keyed by scene ID, used during generation)
    private var sceneReferenceImages: [UUID: [ReferenceImageData]] = [:]

    // MARK: - Computed Properties

    /// The currently selected scene
    var selectedScene: StoryboardScene? {
        guard let index = selectedSceneIndex, index < scenes.count else { return nil }
        return scenes[index]
    }

    /// The model being used for this storyboard
    var model: ProviderModel? {
        providerService.model(by: storyboard.modelId)
    }

    /// Total duration of all completed scenes
    var totalDuration: Double {
        Double(scenes.filter { $0.status == .COMPLETED }.count) * storyboard.sceneDuration
    }

    /// Whether we can add more scenes (last scene must be completed, or no scenes yet)
    var canAddScene: Bool {
        guard let lastScene = scenes.last else {
            return true
        }
        return lastScene.status == .COMPLETED
    }

    /// Number of completed scenes
    var completedSceneCount: Int {
        scenes.filter { $0.status == .COMPLETED }.count
    }

    /// Whether there's a next scene available to play
    var hasNextScene: Bool {
        guard let current = selectedSceneIndex else { return false }
        let nextIndex = current + 1
        guard nextIndex < scenes.count else { return false }
        return scenes[nextIndex].status == .COMPLETED
    }

    /// Whether this storyboard uses Google provider with auto-extend mode.
    /// In this mode, the last scene contains the full video.
    var isGoogleAutoExtend: Bool {
        storyboard.mode == .AUTO_EXTEND &&
            storyboard.providerId == EnumProviderCode.GOOGLE_CLOUD.providerId.uuidString
    }

    /// Whether the storyboard can be exported (at least one completed scene)
    var canExport: Bool {
        completedSceneCount > 0
    }

    // MARK: - Initialization

    init(storyboard: Storyboard) {
        self.storyboard = storyboard

        let kc = KeychainSwift()
        kc.accessGroup = TEAM_KEYCHAIN_AG
        kc.synchronizable = true
        keychain = kc
    }

    // MARK: - Data Loading

    /// Loads scenes and assets for this storyboard from the model context.
    func loadData(modelContext: ModelContext) {
        let storyboardId = storyboard.id

        // Load scenes
        var sceneDescriptor = FetchDescriptor<StoryboardScene>(
            predicate: #Predicate { $0.storyboardId == storyboardId },
            sortBy: [SortDescriptor(\.orderIndex, order: .forward)]
        )
        sceneDescriptor.fetchLimit = 100

        do {
            scenes = try modelContext.fetch(sceneDescriptor)
        } catch {
            AppLogger.data.error("Failed to load scenes: \(error.localizedDescription, privacy: .public)")
            scenes = []
        }

        // Load assets
        var assetDescriptor = FetchDescriptor<StoryboardAsset>(
            predicate: #Predicate { $0.storyboardId == storyboardId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        assetDescriptor.fetchLimit = 50

        do {
            assets = try modelContext.fetch(assetDescriptor)
        } catch {
            AppLogger.data.error("Failed to load assets: \(error.localizedDescription, privacy: .public)")
            assets = []
        }

        // Auto-select first scene if none selected
        if selectedSceneIndex == nil, !scenes.isEmpty {
            selectedSceneIndex = 0
        }
    }

    // MARK: - Scene Management

    /// Adds a new scene to the storyboard and automatically starts generation.
    func addScene(
        prompt: String,
        negativePrompt: String? = nil,
        firstFrameImage: PlatformImage? = nil,
        lastFrameImage: PlatformImage? = nil,
        referenceImages: [PlatformImage] = [],
        projectId: UUID,
        queueManager: QueueManager,
        modelContext: ModelContext
    ) async {
        // Generate UUIDs for frame images if provided
        var firstFrameId: UUID?
        var lastFrameId: UUID?

        if let firstImage = firstFrameImage {
            firstFrameId = UUID()
            saveFrameImage(firstImage, frameId: firstFrameId!)
        }

        if let lastImage = lastFrameImage {
            lastFrameId = UUID()
            saveFrameImage(lastImage, frameId: lastFrameId!)
        }

        // Convert reference images to ReferenceImageData
        let referenceImageData: [ReferenceImageData] = referenceImages.compactMap { image -> ReferenceImageData? in
            guard let base64 = image.toBase64PNG() else { return nil }
            return ReferenceImageData(base64Image: base64, referenceType: "style")
        }

        let scene = StoryboardScene(
            storyboardId: storyboard.id,
            orderIndex: scenes.count,
            prompt: prompt,
            negativePrompt: negativePrompt,
            firstFrameAssetId: firstFrameId,
            lastFrameAssetId: lastFrameId
        )

        // Store reference images for this scene (used during generation)
        sceneReferenceImages[scene.id] = referenceImageData

        modelContext.insert(scene)

        do {
            try modelContext.save()
            scenes.append(scene)

            // Auto-select the new scene
            selectedSceneIndex = scenes.count - 1

            // Automatically start generation
            await generateScene(scene, projectId: projectId, queueManager: queueManager, modelContext: modelContext)
        } catch {
            AppLogger.data.error("Failed to add scene: \(error.localizedDescription, privacy: .public)")
            showError("Failed to add scene")
        }
    }

    /// Reorders a scene from one index to another.
    func reorderScene(from sourceIndex: Int, to destinationIndex: Int, modelContext: ModelContext) {
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < scenes.count,
              destinationIndex >= 0, destinationIndex <= scenes.count
        else { return }

        // Move in local array
        let scene = scenes.remove(at: sourceIndex)
        let adjustedDestination = destinationIndex > sourceIndex ? destinationIndex - 1 : destinationIndex
        scenes.insert(scene, at: adjustedDestination)

        // Update order indices
        for (index, scene) in scenes.enumerated() {
            scene.orderIndex = index
        }

        do {
            try modelContext.save()

            // Update selection to follow the moved scene
            if selectedSceneIndex == sourceIndex {
                selectedSceneIndex = adjustedDestination
            }
        } catch {
            AppLogger.data.error("Failed to reorder scenes: \(error.localizedDescription, privacy: .public)")
            loadData(modelContext: modelContext) // Reload to restore order
        }
    }

    func duplicateScene(at index: Int, modelContext: ModelContext) {
        guard index >= 0, index < scenes.count else { return }

        let original = scenes[index]
        let newScene = StoryboardScene(
            storyboardId: original.storyboardId,
            orderIndex: scenes.count,
            prompt: original.prompt,
            negativePrompt: original.negativePrompt,
            firstFrameAssetId: original.firstFrameAssetId,
            lastFrameAssetId: original.lastFrameAssetId
        )

        modelContext.insert(newScene)
        scenes.append(newScene)

        do {
            try modelContext.save()
        } catch {
            AppLogger.data.error("Failed to duplicate scene: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Deletes a scene from the storyboard.
    func deleteScene(at index: Int, modelContext: ModelContext) {
        guard index >= 0, index < scenes.count else { return }

        let scene = scenes[index]
        scenes.remove(at: index)

        // Update order indices for remaining scenes
        for (i, s) in scenes.enumerated() {
            s.orderIndex = i
        }

        modelContext.delete(scene)

        do {
            try modelContext.save()

            // Adjust selection
            if let selected = selectedSceneIndex {
                if selected == index {
                    selectedSceneIndex = scenes.isEmpty ? nil : min(selected, scenes.count - 1)
                } else if selected > index {
                    selectedSceneIndex = selected - 1
                }
            }
        } catch {
            AppLogger.data.error("Failed to delete scene: \(error.localizedDescription, privacy: .public)")
            loadData(modelContext: modelContext) // Reload to restore state
        }
    }

    // MARK: - Frame Image Helpers

    /// Saves a frame image to the documents directory.
    private func saveFrameImage(_ image: PlatformImage, frameId: UUID) {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let framesDir = documentsURL.appendingPathComponent("storyboard-frames", isDirectory: true)

        do {
            if !fileManager.fileExists(atPath: framesDir.path) {
                try fileManager.createDirectory(at: framesDir, withIntermediateDirectories: true)
            }

            let fileURL = framesDir.appendingPathComponent("\(frameId.uuidString).png")

            #if os(macOS)
            if let tiffData = image.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapImage.representation(using: .png, properties: [:])
            {
                try pngData.write(to: fileURL)
            }
            #else
            if let pngData = image.pngData() {
                try pngData.write(to: fileURL)
            }
            #endif
        } catch {
            AppLogger.storage.error("Failed to save frame image: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Deletes a frame image from the documents directory.
    private func deleteFrameImage(frameId: UUID) {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let fileURL = documentsURL
            .appendingPathComponent("storyboard-frames", isDirectory: true)
            .appendingPathComponent("\(frameId.uuidString).png")

        try? fileManager.removeItem(at: fileURL)
    }

    /// Loads a frame image from the documents directory.
    func loadFrameImage(frameId: UUID) -> PlatformImage? {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let fileURL = documentsURL
            .appendingPathComponent("storyboard-frames", isDirectory: true)
            .appendingPathComponent("\(frameId.uuidString).png")

        guard let data = try? Data(contentsOf: fileURL) else { return nil }

        #if os(macOS)
        return NSImage(data: data)
        #else
        return UIImage(data: data)
        #endif
    }

    /// Loads the last frame image from the previous completed scene's generation.
    /// Used to auto-populate the first frame when adding a new scene.
    func getPreviousSceneLastFrame() -> PlatformImage? {
        guard let lastCompletedScene = scenes.last(where: { $0.status == .COMPLETED }),
              let generationId = lastCompletedScene.generationId
        else {
            return nil
        }

        let fileName = ".\(generationId.uuidString)_lastframe"
        return loadImageFromiCloud(fileName)
    }

    // MARK: - Asset Management

    /// Adds a reference asset to the storyboard.
    func addAsset(image: PlatformImage, name: String, modelContext: ModelContext) async {
        let asset = StoryboardAsset(
            storyboardId: storyboard.id,
            name: name,
            width: Int(image.size.width),
            height: Int(image.size.height)
        )

        modelContext.insert(asset)

        do {
            try modelContext.save()

            // Save image to documents directory using cross-platform PNG conversion
            let fileManager = FileManager.default
            if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let assetsDir = documentsURL.appendingPathComponent("storyboard-assets", isDirectory: true)

                if !fileManager.fileExists(atPath: assetsDir.path) {
                    try fileManager.createDirectory(at: assetsDir, withIntermediateDirectories: true)
                }

                let fileURL = assetsDir.appendingPathComponent("\(asset.id.uuidString).png")

                #if os(macOS)
                if let tiffData = image.tiffRepresentation,
                   let bitmapImage = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmapImage.representation(using: .png, properties: [:])
                {
                    try pngData.write(to: fileURL)
                }
                #else
                if let pngData = image.pngData() {
                    try pngData.write(to: fileURL)
                }
                #endif
            }

            assets.insert(asset, at: 0)
        } catch {
            AppLogger.data.error("Failed to add asset: \(error.localizedDescription, privacy: .public)")
            showError("Failed to save asset")
        }
    }

    /// Deletes a reference asset.
    func deleteAsset(_ asset: StoryboardAsset, modelContext: ModelContext) {
        assets.removeAll { $0.id == asset.id }
        modelContext.delete(asset)

        // Delete file
        let fileManager = FileManager.default
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsURL
                .appendingPathComponent("storyboard-assets", isDirectory: true)
                .appendingPathComponent("\(asset.id.uuidString).png")
            try? fileManager.removeItem(at: fileURL)
        }

        do {
            try modelContext.save()
        } catch {
            AppLogger.data.error("Failed to delete asset: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Loads an asset image from disk.
    func loadAssetImage(asset: StoryboardAsset) -> PlatformImage? {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let fileURL = documentsURL
            .appendingPathComponent("storyboard-assets", isDirectory: true)
            .appendingPathComponent("\(asset.id.uuidString).png")

        guard let data = try? Data(contentsOf: fileURL) else { return nil }

        #if os(macOS)
        return NSImage(data: data)
        #else
        return UIImage(data: data)
        #endif
    }

    // MARK: - Playback Controls

    /// Selects a scene and optionally starts playback.
    func selectScene(at index: Int, autoPlay: Bool = false) {
        guard index >= 0, index < scenes.count else { return }

        selectedSceneIndex = index

        // Scene selected - native player handles playback
    }

    /// Moves to the next scene.
    func nextScene() {
        guard let current = selectedSceneIndex else {
            if !scenes.isEmpty {
                selectedSceneIndex = 0
            }
            return
        }

        if current < scenes.count - 1 {
            selectedSceneIndex = current + 1
        } else {
            // Loop to beginning
            selectedSceneIndex = 0
        }
    }

    /// Moves to the previous scene.
    func previousScene() {
        guard let current = selectedSceneIndex else { return }

        if current > 0 {
            selectedSceneIndex = current - 1
        } else {
            // Loop to end
            selectedSceneIndex = scenes.count - 1
        }
    }

    // MARK: - Scene Generation

    /// Starts generating a scene.
    func generateScene(
        _ scene: StoryboardScene,
        projectId: UUID,
        queueManager: QueueManager,
        modelContext: ModelContext
    ) async {
        guard let model else {
            showError("Model not found")
            return
        }

        // Get provider key
        guard let providerKey = ProviderKeysCache.shared.providerKeys.first(where: {
            $0.providerId.uuidString == storyboard.providerId
        }) else {
            showError("Provider not configured")
            return
        }

        guard let providerKeyInfo = try? providerKey.toProviderKeyInfo() else {
            showError("Provider not found")
            return
        }

        // Get provider secret
        let keychainKey = ProjectManager.keychainKey(
            projectId: projectId,
            providerId: providerKey.providerId
        )
        guard let providerSecret = keychain.get(keychainKey) else {
            showError("Provider credentials not found")
            return
        }

        // Update scene status
        scene.status = .GENERATING
        try? modelContext.save()

        // Build the generation request based on storyboard mode
        if storyboard.mode == .AUTO_EXTEND {
            await generateExtendScene(
                scene: scene,
                model: model,
                providerKeyInfo: providerKeyInfo,
                providerSecret: providerSecret,
                queueManager: queueManager,
                modelContext: modelContext
            )
        } else {
            await generateFrameBasedScene(
                scene: scene,
                model: model,
                providerKeyInfo: providerKeyInfo,
                providerSecret: providerSecret,
                queueManager: queueManager,
                modelContext: modelContext
            )
        }
    }

    /// Generates a scene using video extend (auto-extend mode).
    private func generateExtendScene(
        scene: StoryboardScene,
        model: ProviderModel,
        providerKeyInfo: ProviderKeyInfo,
        providerSecret: String,
        queueManager: QueueManager,
        modelContext: ModelContext
    ) async {
        let sceneIndex = scenes.firstIndex(where: { $0.id == scene.id }) ?? 0

        // For the first scene, we need a source - use frame-based generation instead
        if sceneIndex == 0 {
            // First scene in auto-extend mode: generate without extending
            let request = VideoGenerationRequest(
                modelId: storyboard.modelId,
                prompt: scene.prompt,
                negativePrompt: scene.negativePrompt,
                dimensions: storyboard.dimensions,
                clientReferenceImages: sceneReferenceImages[scene.id],
                providerKey: providerKeyInfo,
                providerSecret: providerSecret,
                durationSeconds: Int(storyboard.sceneDuration),
                resolution: storyboard.resolution.isEmpty ? nil : storyboard.resolution
            )

            let queueItem = queueManager.submitVideoGeneration(
                request: request,
                modelContext: modelContext,
                source: .STORYBOARD
            )

            scene.queueItemId = queueItem.id
            try? modelContext.save()

            await monitorQueueItem(queueItem.id, for: scene, queueManager: queueManager, modelContext: modelContext)
            return
        }

        // Get the previous scene's generation to extend from
        guard let prevGenerationId = scenes[sceneIndex - 1].generationId else {
            scene.status = .FAILED
            scene.errorMessage = "Previous scene has no generated video to extend"
            try? modelContext.save()
            return
        }

        // Fetch the previous generation to get its metadata
        let descriptor = FetchDescriptor<Generation>(
            predicate: #Predicate { $0.id == prevGenerationId }
        )
        guard let previousGeneration = try? modelContext.fetch(descriptor).first else {
            scene.status = .FAILED
            scene.errorMessage = "Could not load previous generation"
            try? modelContext.save()
            return
        }

        // Load the video data from the previous generation
        guard let videoURL = loadVideoFromiCloud(prevGenerationId.uuidString),
              let videoData = try? Data(contentsOf: videoURL)
        else {
            scene.status = .FAILED
            scene.errorMessage = "Could not load previous video file"
            try? modelContext.save()
            return
        }

        // Create the extend request with video data and metadata
        let request = VideoGenerationRequest(
            modelId: storyboard.modelId,
            prompt: scene.prompt,
            negativePrompt: scene.negativePrompt,
            dimensions: storyboard.dimensions,
            clientVideo: videoData.base64EncodedString(),
            clientReferenceImages: sceneReferenceImages[scene.id],
            providerKey: providerKeyInfo,
            providerSecret: providerSecret,
            durationSeconds: Int(storyboard.sceneDuration),
            resolution: storyboard.resolution.isEmpty ? nil : storyboard.resolution,
            sourceMetadata: previousGeneration.metadata.isEmpty ? nil : previousGeneration.metadata
        )

        let queueItem = queueManager.submitVideoGeneration(
            request: request,
            modelContext: modelContext,
            source: .STORYBOARD
        )

        scene.queueItemId = queueItem.id
        try? modelContext.save()

        await monitorQueueItem(queueItem.id, for: scene, queueManager: queueManager, modelContext: modelContext)
    }

    /// Generates a scene using first/last frame (frame-based mode).
    private func generateFrameBasedScene(
        scene: StoryboardScene,
        model: ProviderModel,
        providerKeyInfo: ProviderKeyInfo,
        providerSecret: String,
        queueManager: QueueManager,
        modelContext: ModelContext
    ) async {
        // Load first frame image if specified
        var sourceImage: String?
        if let firstFrameId = scene.firstFrameAssetId,
           let image = loadFrameImage(frameId: firstFrameId),
           let base64 = image.toBase64PNG()
        {
            sourceImage = base64
        }

        // Load last frame image if specified
        var lastFrameImage: String?
        if let lastFrameId = scene.lastFrameAssetId,
           let image = loadFrameImage(frameId: lastFrameId),
           let base64 = image.toBase64PNG()
        {
            lastFrameImage = base64
        }

        let request = VideoGenerationRequest(
            modelId: storyboard.modelId,
            prompt: scene.prompt,
            negativePrompt: scene.negativePrompt,
            dimensions: storyboard.dimensions,
            clientImage: sourceImage,
            clientLastFrame: lastFrameImage,
            clientReferenceImages: sceneReferenceImages[scene.id],
            providerKey: providerKeyInfo,
            providerSecret: providerSecret,
            durationSeconds: Int(storyboard.sceneDuration),
            resolution: storyboard.resolution.isEmpty ? nil : storyboard.resolution
        )

        let queueItem = queueManager.submitVideoGeneration(
            request: request,
            modelContext: modelContext,
            source: .STORYBOARD
        )

        scene.queueItemId = queueItem.id
        try? modelContext.save()

        // Monitor queue item for completion
        await monitorQueueItem(queueItem.id, for: scene, queueManager: queueManager, modelContext: modelContext)
    }

    /// Monitors a queue item and updates scene status on completion.
    private func monitorQueueItem(
        _ queueItemId: UUID,
        for scene: StoryboardScene,
        queueManager: QueueManager,
        modelContext: ModelContext
    ) async {
        // Poll for status changes - re-fetch the item each time to get current status
        var attempts = 0
        let maxAttempts = 600 // 5 minutes max (600 * 500ms)

        while attempts < maxAttempts {
            // Re-fetch the queue item to get current status
            guard let queueItem = queueManager.items.first(where: { $0.id == queueItemId }) else {
                // Item was removed - check if generation exists anyway
                await updateSceneFromGeneration(scene, queueItemId: queueItemId, modelContext: modelContext)
                return
            }

            if queueItem.status != .IN_PROGRESS {
                // Status changed - process result
                await processQueueItemResult(queueItem, for: scene, modelContext: modelContext)
                return
            }

            attempts += 1
            try? await Task.sleep(for: .milliseconds(500))
        }

        // Timeout - mark as failed
        await MainActor.run {
            scene.status = .FAILED
            scene.errorMessage = "Generation timed out"
            try? modelContext.save()
        }
    }

    /// Updates scene status based on queue item result.
    private func processQueueItemResult(
        _ queueItem: QueueItem,
        for scene: StoryboardScene,
        modelContext: ModelContext
    ) async {
        if queueItem.status == .SUCCESSFUL, let videoSetId = queueItem.resultVideoSetId {
            var generationId: UUID?
            for attempt in 1 ... 5 {
                try? await Task.sleep(for: .milliseconds(500 * attempt))

                let fetchedId = await MainActor.run { () -> UUID? in
                    var descriptor = FetchDescriptor<Generation>(
                        predicate: #Predicate { $0.setId == videoSetId }
                    )
                    descriptor.fetchLimit = 1
                    return try? modelContext.fetch(descriptor).first?.id
                }

                if let id = fetchedId {
                    generationId = id
                    break
                }
            }

            await MainActor.run {
                if let generationId {
                    scene.generationId = generationId
                    scene.status = .COMPLETED
                    scene.errorMessage = nil
                } else {
                    scene.status = .FAILED
                    scene.errorMessage = "Could not find generation record"
                }
                try? modelContext.save()
            }
        } else if queueItem.status == .SUCCESSFUL {
            await MainActor.run {
                scene.status = .FAILED
                scene.errorMessage = "Generation ID not found"
                try? modelContext.save()
            }
        } else {
            await MainActor.run {
                scene.status = .FAILED
                scene.errorMessage = queueItem.errorMessage ?? "Generation failed"
                try? modelContext.save()
            }
        }
    }

    /// Fallback: check if generation exists when queue item is gone.
    private func updateSceneFromGeneration(
        _ scene: StoryboardScene,
        queueItemId: UUID,
        modelContext: ModelContext
    ) async {
        await MainActor.run {
            let cutoff = Date().addingTimeInterval(-120)
            var descriptor = FetchDescriptor<Generation>(
                predicate: #Predicate { $0.createdAt >= cutoff },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 10

            if let generations = try? modelContext.fetch(descriptor) {
                for generation in generations {
                    if generation.createdAt.timeIntervalSinceNow > -60 {
                        scene.generationId = generation.id
                        scene.status = .COMPLETED
                        scene.errorMessage = nil
                        try? modelContext.save()
                        return
                    }
                }
            }

            scene.status = .FAILED
            scene.errorMessage = "Queue item not found"
            try? modelContext.save()
        }
    }

    /// Regenerates a scene (resets and generates again).
    func regenerateScene(
        _ scene: StoryboardScene,
        projectId: UUID,
        queueManager: QueueManager,
        modelContext: ModelContext
    ) async {
        await MainActor.run {
            scene.status = .PENDING
            scene.generationId = nil
            scene.queueItemId = nil
            scene.errorMessage = nil
            try? modelContext.save()
        }

        await generateScene(scene, projectId: projectId, queueManager: queueManager, modelContext: modelContext)
    }

    // MARK: - Video Export

    /// Exports the storyboard as a single video file.
    ///
    /// For Google + Auto-extend mode, exports the last scene's video which contains
    /// the full combined content. For other modes, combines all scene videos.
    func exportVideo() async {
        guard canExport else {
            showError("No completed scenes to export")
            return
        }

        await MainActor.run {
            isExporting = true
        }

        // Gather video URLs for completed scenes
        let completedScenes = scenes.filter { $0.status == .COMPLETED }

        if isGoogleAutoExtend {
            // For Google auto-extend, only need the last scene's video
            guard let lastScene = completedScenes.last,
                  let generationId = lastScene.generationId,
                  let videoURL = loadVideoFromiCloud(generationId.uuidString)
            else {
                await MainActor.run {
                    isExporting = false
                    showError("Could not load video for export")
                }
                return
            }

            await exportSingleVideo(videoURL: videoURL)
        } else {
            // For other modes, collect all scene videos
            var videoURLs: [URL] = []

            for scene in completedScenes {
                if let generationId = scene.generationId,
                   let videoURL = loadVideoFromiCloud(generationId.uuidString)
                {
                    videoURLs.append(videoURL)
                }
            }

            guard !videoURLs.isEmpty else {
                await MainActor.run {
                    isExporting = false
                    showError("Could not load any videos for export")
                }
                return
            }

            await exportCombinedVideo(videoURLs: videoURLs)
        }
    }

    /// Exports a single video file (for Google auto-extend mode).
    private func exportSingleVideo(videoURL: URL) async {
        let outputFileName =
            "storyboard_\(storyboard.name.replacingOccurrences(of: " ", with: "_"))_\(Date().timeIntervalSince1970.description.prefix(10))"

        let result = await VideoExportService.shared.exportStoryboard(
            videoURLs: [videoURL],
            isAutoExtendGoogle: true,
            outputFileName: outputFileName
        )

        await handleExportResult(result, suggestedName: "\(storyboard.name).mp4")
    }

    /// Exports combined video from multiple scenes.
    private func exportCombinedVideo(videoURLs: [URL]) async {
        let outputFileName =
            "storyboard_\(storyboard.name.replacingOccurrences(of: " ", with: "_"))_\(Date().timeIntervalSince1970.description.prefix(10))"

        let result = await VideoExportService.shared.exportStoryboard(
            videoURLs: videoURLs,
            isAutoExtendGoogle: false,
            outputFileName: outputFileName
        )

        await handleExportResult(result, suggestedName: "\(storyboard.name).mp4")
    }

    /// Handles the export result by showing save panel or error.
    private func handleExportResult(_ result: VideoExportResult, suggestedName: String) async {
        if result.success, let outputURL = result.outputURL {
            #if os(macOS)
            let saved = await VideoExportService.shared.saveWithPanel(
                sourceURL: outputURL,
                suggestedName: suggestedName
            )

            await MainActor.run {
                isExporting = false
                if saved {
                    showExportSuccessAlert = true
                }
            }

            // Clean up temp file
            try? FileManager.default.removeItem(at: outputURL)
            #else
            // iOS: Use share sheet or save to Photos
            await MainActor.run {
                isExporting = false
                showExportSuccessAlert = true
            }
            #endif
        } else {
            await MainActor.run {
                isExporting = false
                showError(result.errorMessage ?? "Export failed")
            }
        }
    }

    // MARK: - Helpers

    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }
}
