// MARK: - StorageAdapter.swift

// Utilities for managing iCloud Documents storage.
//
// Provides functions for cleaning up generated media files from iCloud.
// Used by ManageStorageView for storage management features.
//
// ## Storage Structure
// Generated files are stored in the iCloud Documents container:
// - Images: {generationId}.png
// - Videos: {generationId}.mp4
// - Thumbnails: {generationId}_thumb.png, {generationId}_small.png
// - Client assets: {generationId}_client.png, {generationId}_ref_*.png

import Foundation
import KeychainSwift
import OSLog
import SwiftData

struct ProjectStorageCounts: Equatable {
    var generations = 0
    var imageSets = 0
    var providerKeys = 0
    var agents = 0
    var brandKits = 0
    var chatThreads = 0
    var playgrounds = 0
    var storyboards = 0
    var bulkSessions = 0
    var failedRequests = 0

    static let empty = ProjectStorageCounts()
}

enum ProjectStorageResetService {
    @MainActor
    static func loadDataCounts(projectId: UUID, modelContext: ModelContext) -> ProjectStorageCounts {
        ProjectStorageCounts(
            generations: count(FetchDescriptor<Generation>(
                predicate: #Predicate { $0.projectId == projectId }
            ), in: modelContext),
            imageSets: count(FetchDescriptor<ImageSet>(
                predicate: #Predicate { $0.projectId == projectId }
            ), in: modelContext),
            providerKeys: count(FetchDescriptor<ProviderKey>(
                predicate: #Predicate { $0.projectId == projectId }
            ), in: modelContext),
            agents: count(FetchDescriptor<Agent>(
                predicate: #Predicate { $0.projectId == projectId }
            ), in: modelContext),
            brandKits: count(FetchDescriptor<BrandKit>(
                predicate: #Predicate { $0.projectId == projectId }
            ), in: modelContext),
            chatThreads: count(FetchDescriptor<ChatThread>(
                predicate: #Predicate { $0.projectId == projectId }
            ), in: modelContext),
            playgrounds: count(FetchDescriptor<Playground>(
                predicate: #Predicate { $0.projectId == projectId }
            ), in: modelContext),
            storyboards: count(FetchDescriptor<Storyboard>(
                predicate: #Predicate { $0.projectId == projectId }
            ), in: modelContext),
            bulkSessions: count(FetchDescriptor<BulkSession>(
                predicate: #Predicate { $0.projectId == projectId }
            ), in: modelContext),
            failedRequests: count(FetchDescriptor<FailedRequest>(
                predicate: #Predicate { $0.projectId == projectId }
            ), in: modelContext)
        )
    }

    @MainActor
    static func resetProjectData(
        projectId: UUID,
        modelContext: ModelContext,
        deleteMediaFiles: (String) -> Void = deleteICloudDocuments(containingSubstring:),
        deleteProviderSecret: (UUID, UUID) -> Void = ProjectStorageResetService
            .deleteProviderSecret(projectId:providerId:),
        deleteDocumentFile: (String) -> Void = deleteProjectDocumentFile(named:),
        deleteStoryboardAssetFile: (UUID) -> Void = deleteProjectStoryboardAssetFile(assetId:),
        commit: (ModelContext) throws -> Void = { try $0.save() }
    ) throws {
        var documentFileNames = Set<String>()
        var storyboardAssetIds = Set<UUID>()

        let providerKeys = try modelContext.fetch(FetchDescriptor<ProviderKey>(
            predicate: #Predicate { $0.projectId == projectId }
        ))
        let providerIds = providerKeys.map(\.providerId)
        for providerKey in providerKeys {
            modelContext.delete(providerKey)
        }

        let chatThreads = try modelContext.fetch(FetchDescriptor<ChatThread>(
            predicate: #Predicate { $0.projectId == projectId }
        ))
        let threadIds = Set(chatThreads.map(\.id))
        if !threadIds.isEmpty {
            let chatMessages = try modelContext.fetch(FetchDescriptor<ChatMessage>(
                predicate: #Predicate { threadIds.contains($0.threadId) }
            ))
            deleteEach(chatMessages, in: modelContext)
        }

        let generations = try modelContext.fetch(FetchDescriptor<Generation>(
            predicate: #Predicate { $0.projectId == projectId }
        ))
        let generationMediaIds = generations.map(\.id.uuidString)
        for generation in generations {
            modelContext.delete(generation)
        }

        let agents = try modelContext.fetch(FetchDescriptor<Agent>(
            predicate: #Predicate { $0.projectId == projectId }
        ))
        let agentIds = Set(agents.map(\.id))
        if !agentIds.isEmpty {
            let agentCards = try modelContext.fetch(FetchDescriptor<AgentCard>(
                predicate: #Predicate { agentIds.contains($0.agentId) }
            ))
            collectAgentCardFiles(agentCards, into: &documentFileNames)
            deleteEach(agentCards, in: modelContext)

            try deleteEach(modelContext.fetch(FetchDescriptor<CardLink>(
                predicate: #Predicate { agentIds.contains($0.agentId) }
            )), in: modelContext)
            try deleteEach(modelContext.fetch(FetchDescriptor<AgentRun>(
                predicate: #Predicate { agentIds.contains($0.agentId) }
            )), in: modelContext)
        }

        let playgrounds = try modelContext.fetch(FetchDescriptor<Playground>(
            predicate: #Predicate { $0.projectId == projectId }
        ))
        let playgroundIds = Set(playgrounds.map(\.id))
        if !playgroundIds.isEmpty {
            try deleteEach(modelContext.fetch(FetchDescriptor<PlaygroundCard>(
                predicate: #Predicate { playgroundIds.contains($0.flowCanvasId) }
            )), in: modelContext)
            try deleteEach(modelContext.fetch(FetchDescriptor<PlaygroundLink>(
                predicate: #Predicate { playgroundIds.contains($0.flowCanvasId) }
            )), in: modelContext)
        }

        let realtimeSessions = try modelContext.fetch(FetchDescriptor<RealtimeEditSession>(
            predicate: #Predicate { $0.projectId == projectId }
        ))
        let realtimeSessionIds = Set(realtimeSessions.map(\.id))
        if !realtimeSessionIds.isEmpty {
            let realtimeLayers = try modelContext.fetch(FetchDescriptor<RealtimeEditLayer>(
                predicate: #Predicate { realtimeSessionIds.contains($0.sessionId) }
            ))
            for layer in realtimeLayers {
                appendDocumentFileName(layer.imagePath, to: &documentFileNames)
            }
            deleteEach(realtimeLayers, in: modelContext)
        }

        let storyboards = try modelContext.fetch(FetchDescriptor<Storyboard>(
            predicate: #Predicate { $0.projectId == projectId }
        ))
        let storyboardIds = Set(storyboards.map(\.id))
        if !storyboardIds.isEmpty {
            try deleteEach(modelContext.fetch(FetchDescriptor<StoryboardScene>(
                predicate: #Predicate { storyboardIds.contains($0.storyboardId) }
            )), in: modelContext)

            let storyboardAssets = try modelContext.fetch(FetchDescriptor<StoryboardAsset>(
                predicate: #Predicate { storyboardIds.contains($0.storyboardId) }
            ))
            storyboardAssetIds.formUnion(storyboardAssets.map(\.id))
            deleteEach(storyboardAssets, in: modelContext)
        }

        let bulkSessions = try modelContext.fetch(FetchDescriptor<BulkSession>(
            predicate: #Predicate { $0.projectId == projectId }
        ))
        let bulkSessionIds = Set(bulkSessions.map(\.id))
        if !bulkSessionIds.isEmpty {
            try deleteEach(modelContext.fetch(FetchDescriptor<BulkSessionItem>(
                predicate: #Predicate { bulkSessionIds.contains($0.sessionId) }
            )), in: modelContext)
        }

        let bulkEditSessions = try modelContext.fetch(FetchDescriptor<BulkEditSession>(
            predicate: #Predicate { $0.projectId == projectId }
        ))
        let bulkEditSessionIds = Set(bulkEditSessions.map(\.id))
        if !bulkEditSessionIds.isEmpty {
            let bulkEditItems = try modelContext.fetch(FetchDescriptor<BulkEditItem>(
                predicate: #Predicate { bulkEditSessionIds.contains($0.sessionId) }
            ))
            for item in bulkEditItems {
                appendDocumentFileName(item.sourceImageFileName, to: &documentFileNames)
                appendDocumentFileName(item.sourceImageThumbFileName, to: &documentFileNames)
            }
            deleteEach(bulkEditItems, in: modelContext)
        }

        let creativeStudios = try modelContext.fetch(FetchDescriptor<CreativeStudio>(
            predicate: #Predicate { $0.projectId == projectId }
        ))
        let studioIds = Set(creativeStudios.map(\.id))
        if !studioIds.isEmpty {
            try deleteEach(modelContext.fetch(FetchDescriptor<CreativeStudioItem>(
                predicate: #Predicate { studioIds.contains($0.studioId) }
            )), in: modelContext)
        }

        let productPhotoshoots = try modelContext.fetch(FetchDescriptor<ProductPhotoshoot>(
            predicate: #Predicate { $0.projectId == projectId }
        ))
        let photoshootIds = Set(productPhotoshoots.map(\.id))
        if !photoshootIds.isEmpty {
            let photoshootItems = try modelContext.fetch(FetchDescriptor<ProductPhotoshootItem>(
                predicate: #Predicate { photoshootIds.contains($0.photoshootId) }
            ))
            for item in photoshootItems {
                appendDocumentFileName(item.customBackdropFileName, to: &documentFileNames)
            }
            deleteEach(photoshootItems, in: modelContext)
        }

        try deleteEach(modelContext.fetch(FetchDescriptor<ImageSet>(
            predicate: #Predicate { $0.projectId == projectId }
        )), in: modelContext)
        deleteEach(agents, in: modelContext)
        let brandKits = try modelContext.fetch(FetchDescriptor<BrandKit>(
            predicate: #Predicate { $0.projectId == projectId }
        ))
        collectBrandKitFiles(brandKits, into: &documentFileNames)
        deleteEach(brandKits, in: modelContext)
        deleteEach(chatThreads, in: modelContext)
        deleteEach(playgrounds, in: modelContext)
        deleteEach(realtimeSessions, in: modelContext)
        deleteEach(storyboards, in: modelContext)
        deleteEach(bulkSessions, in: modelContext)
        deleteEach(bulkEditSessions, in: modelContext)
        deleteEach(creativeStudios, in: modelContext)
        deleteEach(productPhotoshoots, in: modelContext)
        try deleteEach(modelContext.fetch(FetchDescriptor<FailedRequest>(
            predicate: #Predicate { $0.projectId == projectId }
        )), in: modelContext)
        try deleteEach(modelContext.fetch(FetchDescriptor<PromptGalleryItem>(
            predicate: #Predicate { $0.projectId == projectId }
        )), in: modelContext)
        let productGalleryItems = try modelContext.fetch(FetchDescriptor<ProductGalleryItem>(
            predicate: #Predicate { $0.projectId == projectId }
        ))
        for item in productGalleryItems {
            appendDocumentFileName(item.imageFileName, to: &documentFileNames)
            appendDocumentFileName(item.thumbFileName, to: &documentFileNames)
            appendDocumentFileName(item.largeThumbFileName, to: &documentFileNames)
        }
        deleteEach(productGalleryItems, in: modelContext)

        try commit(modelContext)
        modelContext.processPendingChanges()

        for providerId in providerIds {
            deleteProviderSecret(projectId, providerId)
        }

        for mediaId in generationMediaIds {
            deleteMediaFiles(mediaId)
        }

        for fileName in documentFileNames.sorted() {
            deleteDocumentFile(fileName)
        }

        for assetId in storyboardAssetIds.sorted(by: { $0.uuidString < $1.uuidString }) {
            deleteStoryboardAssetFile(assetId)
        }
    }

    private static func count(_ descriptor: FetchDescriptor<some PersistentModel>, in modelContext: ModelContext)
        -> Int
    {
        (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    private static func deleteEach(_ models: [some PersistentModel], in modelContext: ModelContext) {
        for model in models {
            modelContext.delete(model)
        }
    }

    private static func deleteProviderSecret(projectId: UUID, providerId: UUID) {
        let keychain = KeychainSwift()
        keychain.accessGroup = TEAM_KEYCHAIN_AG
        keychain.synchronizable = true
        keychain.delete(ProjectManager.keychainKey(projectId: projectId, providerId: providerId))
    }

    private static func collectAgentCardFiles(_ cards: [AgentCard], into fileNames: inout Set<String>) {
        for card in cards {
            if card.cardType == .start {
                let config = card.startConfiguration
                appendDocumentFileName(config.imagePath, to: &fileNames)
                appendDocumentFileName(config.videoPath, to: &fileNames)
            }

            if card.processCardType == .imageGeneration {
                let config = card.imageGenerationConfiguration
                for referenceImage in config.referenceImages {
                    appendDocumentFileName(referenceImage.imagePath, to: &fileNames)
                    appendDocumentFileName(
                        "imggen_ref_\(card.id.uuidString)_\(referenceImage.id.uuidString)",
                        to: &fileNames
                    )
                }
            }
        }
    }

    private static func collectBrandKitFiles(_ brandKits: [BrandKit], into fileNames: inout Set<String>) {
        for brandKit in brandKits {
            for fileName in brandKit.imageFileNames.values {
                appendDocumentFileName(fileName, to: &fileNames)
                appendDocumentFileName("\(fileName)_thumb", to: &fileNames)
                appendDocumentFileName("\(fileName)_thumb_large", to: &fileNames)
            }

            for asset in brandKit.modelAssets {
                appendDocumentFileName(asset.fileName, to: &fileNames)
                appendDocumentFileName(asset.thumbFileName, to: &fileNames)
                appendDocumentFileName(asset.largeThumbFileName, to: &fileNames)
            }
        }
    }

    private static func appendDocumentFileName(_ fileName: String?, to fileNames: inout Set<String>) {
        guard let fileName = fileName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !fileName.isEmpty
        else {
            return
        }

        fileNames.insert(fileName)
    }
}

/// Deletes all files from iCloud Documents container.
///
/// Use with caution - this removes ALL generated media permanently.
/// Primarily for development/testing or complete storage reset.
func deleteAllICloudDocuments() {
    guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
        .appendingPathComponent("Documents")
    else {
        AppLogger.storage.error("iCloud container not available")
        return
    }

    do {
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: containerURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for fileURL in fileURLs {
            try FileManager.default.removeItem(at: fileURL)
            AppLogger.storage.debug("Deleted file: \(fileURL.lastPathComponent, privacy: .public)")
        }

        AppLogger.storage.info("All iCloud documents have been deleted")
    } catch {
        AppLogger.storage.error("Error deleting iCloud documents: \(error.localizedDescription, privacy: .public)")
    }
}

func deleteICloudDocuments(containingSubstring substring: String) {
    guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
        .appendingPathComponent("Documents")
    else {
        AppLogger.storage.error("iCloud container not available")
        return
    }

    do {
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: containerURL,
            includingPropertiesForKeys: nil,
            options: []
        )

        var deletedCount = 0

        for fileURL in fileURLs {
            let filename = fileURL.lastPathComponent
            if filename.contains(substring) {
                try FileManager.default.removeItem(at: fileURL)
                AppLogger.storage.debug("Deleted file: \(filename, privacy: .public)")
                deletedCount += 1
            }
        }

        if deletedCount > 0 {
            AppLogger.storage
                .info(
                    "Deleted \(deletedCount, privacy: .public) file(s) containing '\(substring, privacy: .public)' in the name"
                )
        } else {
            AppLogger.storage.debug("No files found containing '\(substring, privacy: .public)' in the name")
        }
    } catch {
        AppLogger.storage.error("Error deleting iCloud documents: \(error.localizedDescription, privacy: .public)")
    }
}

func deleteProjectDocumentFile(named fileName: String) {
    let fileManager = FileManager.default
    var urls: [URL] = []

    if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
        urls.append(contentsOf: projectDocumentFileCandidates(for: fileName, in: documentsURL))
    }

    if let iCloudDocumentsURL = fileManager.url(forUbiquityContainerIdentifier: nil)?
        .appendingPathComponent("Documents")
    {
        urls.append(contentsOf: projectDocumentFileCandidates(for: fileName, in: iCloudDocumentsURL))
    }

    deleteProjectFiles(at: urls)
}

func deleteProjectStoryboardAssetFile(assetId: UUID) {
    let fileManager = FileManager.default
    var urls: [URL] = []

    if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
        urls.append(
            documentsURL
                .appendingPathComponent("storyboard-assets", isDirectory: true)
                .appendingPathComponent("\(assetId.uuidString).png")
        )
    }

    if let iCloudDocumentsURL = fileManager.url(forUbiquityContainerIdentifier: nil)?
        .appendingPathComponent("Documents")
    {
        urls.append(
            iCloudDocumentsURL
                .appendingPathComponent("storyboard-assets", isDirectory: true)
                .appendingPathComponent("\(assetId.uuidString).png")
        )
    }

    deleteProjectFiles(at: urls)
}

private func projectDocumentFileCandidates(for fileName: String, in directory: URL) -> [URL] {
    if fileName.hasSuffix(".png") || fileName.hasSuffix(".mp4") {
        return [directory.appendingPathComponent(fileName)]
    }

    return [
        directory.appendingPathComponent(fileName),
        directory.appendingPathComponent("\(fileName).png"),
        directory.appendingPathComponent("\(fileName).mp4"),
    ]
}

private func deleteProjectFiles(at urls: [URL]) {
    let fileManager = FileManager.default
    var seenPaths = Set<String>()

    for url in urls where seenPaths.insert(url.path).inserted {
        guard fileManager.fileExists(atPath: url.path) else { continue }

        do {
            try fileManager.removeItem(at: url)
            AppLogger.storage.debug("Deleted file: \(url.lastPathComponent, privacy: .public)")
        } catch {
            AppLogger.storage
                .error(
                    "Error deleting file \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
        }
    }
}
