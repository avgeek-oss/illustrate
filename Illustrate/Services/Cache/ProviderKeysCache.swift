// MARK: - ProviderKeysCache.swift

// Persistent cache for provider API key associations.
//
// Provider keys are checked frequently (model selection, generation,
// provider filtering). This cache avoids repeated SwiftData queries
// by maintaining a project-scoped list.
//
// ## Caching Strategy
// - Loads once per project
// - Invalidates via notification when keys change
// - No time-based expiration (keys change rarely)
//
// ## Helper Methods
// - `hasProvider(_:)`: Check if provider is configured
// - `supportedProviders(for:)`: Get providers that support a set type
// - `supportedModels(for:providerId:)`: Get models for provider/type

import IllustrateProviders
import OSLog
import SwiftData
import SwiftUI

/// Notification posted when provider keys are modified (added/removed).
extension Notification.Name {
    static let providerKeysChanged = Notification.Name("providerKeysChanged")
}

/// Singleton cache for provider key associations with query helpers.
///
/// Conforms to `CacheProtocol` for basic cache operations.
/// Uses notification-based invalidation (no time-based staleness).
@MainActor
class ProviderKeysCache: ObservableObject, CacheProtocol {
    static let shared = ProviderKeysCache()

    @Published private(set) var providerKeys: [ProviderKey] = []
    @Published private(set) var isLoaded = false

    private var currentProjectId: UUID?
    private var notificationObserver: Any?

    init() {
        // Listen for provider key change notifications
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .providerKeysChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.invalidate()
            }
        }
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Load provider keys for a project (only loads if needed)
    func loadIfNeeded(projectId: UUID, modelContext: ModelContext, force: Bool = false) {
        // Skip if already loaded for this project
        if !force, isLoaded, currentProjectId == projectId {
            return
        }

        currentProjectId = projectId

        let descriptor = FetchDescriptor<ProviderKey>(
            predicate: #Predicate { $0.projectId == projectId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let projectKeys = (try? modelContext.fetch(descriptor)) ?? []

        // Deduplicate by providerId, keeping the most recent (first due to reverse sort order)
        var seenProviderIds = Set<UUID>()
        providerKeys = projectKeys.filter { key in
            if seenProviderIds.contains(key.providerId) {
                return false
            }
            seenProviderIds.insert(key.providerId)
            return true
        }

        isLoaded = true
        let keyCount = providerKeys.count
        AppLogger.cache.debug("ProviderKeysCache: Loaded \(keyCount, privacy: .public) keys for project")
    }

    /// Force refresh the cache
    func refresh(projectId: UUID, modelContext: ModelContext) {
        loadIfNeeded(projectId: projectId, modelContext: modelContext, force: true)
    }

    /// Invalidate cache (call when provider keys change)
    func invalidate() {
        AppLogger.cache.debug("ProviderKeysCache: Cache invalidated")
        isLoaded = false
    }

    /// Get provider keys for a specific project (returns cached if available)
    func keys(for projectId: UUID) -> [ProviderKey] {
        guard currentProjectId == projectId else { return [] }
        return providerKeys
    }

    /// Check if a provider is configured for the current project
    func hasProvider(_ providerId: UUID) -> Bool {
        providerKeys.contains { $0.providerId == providerId }
    }

    /// Get supported providers for a set type
    func supportedProviders(for setType: EnumSetType) -> [Provider] {
        let keyProviderIds = Set(providerKeys.map(\.providerId))
        let modelProviderIds = Set(ProviderService.shared.models(for: setType).map(\.providerId))
        return providers.filter { keyProviderIds.contains($0.providerId) && modelProviderIds.contains($0.providerId) }
    }

    func supportedModels(for setType: EnumSetType, providerId: String) -> [ProviderModel] {
        guard !providerId.isEmpty else { return [] }
        return ProviderService.shared.models(for: setType).filter {
            $0.providerId.uuidString == providerId
        }
    }
}
