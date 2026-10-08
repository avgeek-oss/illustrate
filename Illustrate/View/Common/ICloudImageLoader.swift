// MARK: - ICloudImageLoader.swift

// Async image loading with caching for iCloud-stored images.
//
// This file provides two key components:
// 1. ImageCache: Thread-safe in-memory image cache
// 2. ICloudImageLoader: SwiftUI view for async image loading
//
// ## ImageCache Features
// - NSCache-based with 500 image limit
// - Thread-safe using OSAllocatedUnfairLock
// - Failed attempt tracking with 5-second retry interval
// - Request coalescing to avoid duplicate loads
// - Batch prefetch support for gallery pre-warming
//
// ## Request Coalescing
// Multiple views requesting the same image will share a single
// load operation. Only the first requester triggers the load,
// others await the same result.
//
// ## ICloudImageLoader Usage
// ```swift
// ICloudImageLoader(imageName: generation.id.uuidString) { image in
//     if let image { Image(image) } else { placeholder }
// }
// ```

import os
#if os(iOS)
import UIKit
#endif
import SwiftUI

/// Thread-safe in-memory image cache with request coalescing.
class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, PlatformImage>()
    private let failedAttemptRetryInterval: TimeInterval = 5.0

    private struct LockedState {
        var failedAttempts: [String: Date] = [:]
        var inFlightTasks: [String: Task<PlatformImage?, Never>] = [:]
    }

    private let lockedState = OSAllocatedUnfairLock(initialState: LockedState())

    private var memoryWarningObservers: [Any] = []
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    init() {
        cache.countLimit = 500
        cache.totalCostLimit = 200 * 1024 * 1024

        #if os(iOS)
        let observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cache.removeAllObjects()
        }
        memoryWarningObservers.append(observer)
        #elseif os(macOS)
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in
            self?.cache.removeAllObjects()
        }
        source.resume()
        memoryPressureSource = source
        #endif
    }

    deinit {
        for observer in memoryWarningObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        memoryPressureSource?.cancel()
    }

    func set(_ image: PlatformImage, forKey key: String) {
        let cost = image.pixelCount * 4
        cache.setObject(image, forKey: key as NSString, cost: cost)
        lockedState.withLock { state in
            _ = state.failedAttempts.removeValue(forKey: key)
        }
    }

    func get(forKey key: String) -> PlatformImage? {
        cache.object(forKey: key as NSString)
    }

    func setFailedAttempt(forKey key: String) {
        lockedState.withLock { state in
            state.failedAttempts[key] = Date()
        }
    }

    func isFailedAttempt(forKey key: String) -> Bool {
        lockedState.withLock { state in
            guard let failedDate = state.failedAttempts[key] else {
                return false
            }
            if Date().timeIntervalSince(failedDate) > failedAttemptRetryInterval {
                state.failedAttempts.removeValue(forKey: key)
                return false
            }
            return true
        }
    }

    func clearFailedAttempts() {
        lockedState.withLock { state in
            state.failedAttempts.removeAll()
        }
    }

    func removeAllImages() {
        cache.removeAllObjects()
        clearFailedAttempts()
    }

    /// Clears a specific failed attempt, allowing the image to be reloaded.
    ///
    /// Call this when you know a file has been saved and should now be loadable.
    func clearFailedAttempt(forKey key: String) {
        lockedState.withLock { state in
            _ = state.failedAttempts.removeValue(forKey: key)
        }
    }

    /// Coalesces multiple requests for the same image into a single load operation
    func loadImageCoalesced(
        forKey key: String,
        loader: @escaping @Sendable () -> PlatformImage?
    ) async -> PlatformImage? {
        // Check cache first
        if let cached = get(forKey: key) {
            return cached
        }

        // Check if already failed recently
        if isFailedAttempt(forKey: key) {
            return nil
        }

        // Atomically check for existing task or create new one
        let (taskToAwait, isNewTask) = lockedState.withLock { state -> (Task<PlatformImage?, Never>, Bool) in
            if let existingTask = state.inFlightTasks[key] {
                return (existingTask, false)
            }

            let newTask = Task<PlatformImage?, Never>.detached(priority: .userInitiated) {
                loader()
            }

            state.inFlightTasks[key] = newTask
            return (newTask, true)
        }

        let loadedImage = await taskToAwait.value

        // Only the original task creator handles caching and cleanup
        if isNewTask {
            if let image = loadedImage {
                set(image, forKey: key)
            } else {
                setFailedAttempt(forKey: key)
            }

            lockedState.withLock { state in
                _ = state.inFlightTasks.removeValue(forKey: key)
            }
        }

        return loadedImage
    }

    /// Prefetch multiple images in batch (fire-and-forget)
    func prefetchImages(keys: [String], loader: @escaping (String) -> PlatformImage?) {
        let keysToLoad = keys.filter { get(forKey: $0) == nil && !isFailedAttempt(forKey: $0) }
        guard !keysToLoad.isEmpty else { return }

        Task.detached(priority: .utility) {
            for key in keysToLoad.prefix(20) { // Limit concurrent prefetches
                if Task.isCancelled { break }
                if self.get(forKey: key) != nil { continue }

                if let image = loader(key) {
                    self.set(image, forKey: key)
                }
            }
        }
    }
}

struct ICloudImageLoader<Content: View>: View {
    let imageName: String
    let aspectRatio: CGFloat
    let showLoading: Bool
    let content: (PlatformImage?) -> Content

    @State private var image: PlatformImage? = nil
    @State private var isLoading = true
    @State private var loadTask: Task<Void, Never>?

    init(
        imageName: String,
        aspectRatio: CGFloat = 1.0,
        showLoading: Bool = true,
        @ViewBuilder content: @escaping (PlatformImage?) -> Content
    ) {
        self.imageName = imageName
        self.aspectRatio = aspectRatio
        self.showLoading = showLoading
        self.content = content
    }

    var body: some View {
        Group {
            if isLoading, showLoading {
                Color.clear
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .overlay(
                        GradientSpinner()
                    )
            } else if isLoading {
                Color.clear
                    .aspectRatio(aspectRatio, contentMode: .fit)
            } else {
                content(image)
            }
        }
        .task(id: imageName) {
            await loadImage()
        }
        .onDisappear {
            loadTask?.cancel()
        }
    }

    private func loadImage() async {
        // Quick cache check first (synchronous)
        if let cachedImage = ImageCache.shared.get(forKey: imageName) {
            image = cachedImage
            isLoading = false
            return
        }

        // Check if already failed recently
        if ImageCache.shared.isFailedAttempt(forKey: imageName) {
            image = nil
            isLoading = false
            return
        }

        // Use coalesced loading to avoid duplicate loads
        let loadedImage = await ImageCache.shared.loadImageCoalesced(forKey: imageName) {
            loadImageFromiCloud(imageName)
        }

        // Check if task was cancelled
        if Task.isCancelled { return }

        image = loadedImage
        isLoading = false
    }
}
