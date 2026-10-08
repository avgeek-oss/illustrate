// MARK: - GalleryCache.swift

// Persistent cache for gallery data to improve view performance.
//
// The gallery can contain thousands of generations. Loading them from
// SwiftData on every view appearance is expensive. This cache maintains
// a pre-loaded, project-scoped list that survives view destruction.
//
// ## Caching Strategy
// - Loads once per project
// - Invalidates on new generation (via notification)
// - Stale after 5 minutes (forces refresh)
// - Pre-warms thumbnail image cache
//
// ## Data Organization
// - `imageSets`: Grouped generation batches
// - `imageGenerations`: Individual 2D images
// - `videoGenerations`: Individual videos
//
// ## Thumbnail Pre-warming
// After loading, the cache pre-fetches thumbnail images (o20 scale)
// for the first 50 images and 30 videos into ImageCache.

import OSLog
import SwiftData
import SwiftUI

/// Notification posted when a new generation is created.
extension Notification.Name {
    static let generationCreated = Notification.Name("generationCreated")
}

/// Singleton cache for gallery generations with thumbnail pre-warming.
///
/// Conforms to `StalenessCheckingCache` for time-based staleness detection.
/// Data becomes stale after 5 minutes and will be refreshed on next access.
@MainActor
class GalleryCache: ObservableObject, StalenessCheckingCache {
    static let shared = GalleryCache()

    @Published private(set) var imageSets: [ImageSet] = []
    @Published private(set) var imageGenerations: [Generation] = []
    @Published private(set) var videoGenerations: [Generation] = []
    @Published private(set) var isLoaded = false

    /// Tracks whether any generations exist (for quick onboarding checks)
    @Published private(set) var hasAnyGenerations = false
    @Published private(set) var hasAnyGenerationsLoaded = false

    private var currentProjectId: UUID?
    private var lastLoadTime: Date?
    private let staleThreshold: TimeInterval = 300 // 5 minutes
    private var notificationObserver: Any?

    init() {
        // Listen for new generation notifications
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .generationCreated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                // Mark as needing refresh but keep existing data visible
                self?.markNeedsRefresh()
            }
        }
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Check if cache needs refresh
    var needsRefresh: Bool {
        guard isLoaded, let lastLoad = lastLoadTime else { return true }
        return Date().timeIntervalSince(lastLoad) > staleThreshold
    }

    /// Quick check if any generations exist for a project (fast, uses count query)
    /// Use this for onboarding checks instead of loading full gallery data
    func checkHasAnyGenerations(projectId: UUID, modelContext: ModelContext) {
        // Skip if already checked for this project
        if hasAnyGenerationsLoaded, currentProjectId == projectId {
            return
        }

        currentProjectId = projectId

        // Use fetchCount for efficient existence check
        var descriptor = FetchDescriptor<Generation>()
        descriptor.predicate = #Predicate<Generation> { generation in
            generation.projectId == projectId && !generation.isHidden
        }
        descriptor.fetchLimit = 1

        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        hasAnyGenerations = count > 0
        hasAnyGenerationsLoaded = true
    }

    /// Load gallery data for a project
    func loadIfNeeded(projectId: UUID, modelContext: ModelContext, force: Bool = false) {
        // Skip if already loaded for this project and not stale
        if !force, isLoaded, currentProjectId == projectId, !needsRefresh {
            return
        }

        currentProjectId = projectId

        // Fetch sets with predicate
        var setsDescriptor = FetchDescriptor<ImageSet>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        setsDescriptor.predicate = #Predicate<ImageSet> { imageSet in
            imageSet.projectId == projectId
        }
        imageSets = (try? modelContext.fetch(setsDescriptor)) ?? []

        // Fetch all generations for this project with predicate, then filter by content type in memory
        // (SwiftData predicates don't reliably support enum comparisons)
        var generationsDescriptor = FetchDescriptor<Generation>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        generationsDescriptor.predicate = #Predicate<Generation> { generation in
            generation.projectId == projectId && !generation.isHidden
        }
        let projectGenerations = (try? modelContext.fetch(generationsDescriptor)) ?? []

        // Split by content type in memory (safer than predicate enum comparison)
        imageGenerations = projectGenerations.filter { $0.contentType == .IMAGE_2D }
        videoGenerations = projectGenerations.filter { $0.contentType == .VIDEO }

        // Update quick check flag
        hasAnyGenerations = !imageGenerations.isEmpty || !videoGenerations.isEmpty
        hasAnyGenerationsLoaded = true

        isLoaded = true
        lastLoadTime = Date()

        // Pre-warm thumbnail cache in background
        prewarmThumbnailCache()
    }

    /// Force refresh the cache
    func refresh(projectId: UUID, modelContext: ModelContext) {
        loadIfNeeded(projectId: projectId, modelContext: modelContext, force: true)
    }

    /// Invalidate cache completely (clears data, shows loading state)
    func invalidate() {
        isLoaded = false
        lastLoadTime = nil
        hasAnyGenerationsLoaded = false
    }

    /// Mark cache as needing refresh without clearing data
    /// Next call to loadIfNeeded will reload data
    func markNeedsRefresh() {
        lastLoadTime = nil
        hasAnyGenerationsLoaded = false
    }

    /// Add a new image set to the cache without full reload
    func addImageSet(_ set: ImageSet) {
        guard set.projectId == currentProjectId else { return }
        guard !imageSets.contains(where: { $0.id == set.id }) else { return }
        imageSets.insert(set, at: 0)
    }

    /// Add a new generation to the cache without full reload
    func addGeneration(_ generation: Generation) {
        guard generation.projectId == currentProjectId else { return }
        // Avoid agent input generations
        guard !generation.isHidden else { return }

        if generation.contentType == .IMAGE_2D {
            // Avoid duplicates
            guard !imageGenerations.contains(where: { $0.id == generation.id }) else { return }
            imageGenerations.insert(generation, at: 0)
            hasAnyGenerations = true
        } else if generation.contentType == .VIDEO {
            guard !videoGenerations.contains(where: { $0.id == generation.id }) else { return }
            videoGenerations.insert(generation, at: 0)
            hasAnyGenerations = true
        }
    }

    /// Remove generations from the cache without full reload
    func removeGenerations(ids: Set<UUID>) {
        imageGenerations.removeAll { ids.contains($0.id) }
        videoGenerations.removeAll { ids.contains($0.id) }
    }

    /// Remove image sets from the cache without full reload
    func removeImageSets(ids: Set<UUID>) {
        imageSets.removeAll { ids.contains($0.id) }
    }

    /// Pre-warm the thumbnail cache for visible items
    private func prewarmThumbnailCache() {
        // Prewarm first 50 image thumbnails
        let imageKeys = imageGenerations.prefix(50).map { ".\($0.id.uuidString)_o50" }
        ImageCache.shared.prefetchImages(keys: Array(imageKeys)) { key in
            loadImageFromiCloud(key)
        }

        // Prewarm first 30 video thumbnails
        let videoKeys = videoGenerations.prefix(30).map { ".\($0.id.uuidString)_o50" }
        ImageCache.shared.prefetchImages(keys: Array(videoKeys)) { key in
            loadImageFromiCloud(key)
        }
    }
}
