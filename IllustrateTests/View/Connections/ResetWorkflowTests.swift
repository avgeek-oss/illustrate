// MARK: - ResetWorkflowTests.swift

// Tests for the full application erase and project-level reset flows.
//
// Tests cover:
// - Full reset: deletes all entity types across all projects, recreates default
// - Project reset: deletes entities for the current project, preserves others
// - Cascade verification: all child entities removed when parent is deleted
// - Default project recreation: default project exists after reset
// - Count accuracy: loadDataCounts reflects DB state after reset
// - JSONCredentialField: field definitions for JSON key type providers
// - EraseResetView form validation: confirmation phrase matching

import Foundation
import SwiftData
import XCTest
@testable import Illustrate
@testable import IllustrateProviders

@MainActor
final class ResetWorkflowTests: XCTestCase {
    private var container: ModelContainer!
    private var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        container = try makeTestModelContainer()
        modelContext = container.mainContext

        let defaultProject = Project.createDefault()
        modelContext.insert(defaultProject)
        try modelContext.save()
    }

    override func tearDown() async throws {
        container = nil
        modelContext = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private struct SeededProjectAssetFiles {
        var documentFileNames = Set<String>()
        var storyboardAssetIds = Set<UUID>()
    }

    @discardableResult
    private func seedAllEntityTypes(projectId: UUID) throws -> SeededProjectAssetFiles {
        var seededAssetFiles = SeededProjectAssetFiles()

        let imageSet = TestFixtures.makeImageSet(projectId: projectId)
        modelContext.insert(imageSet)

        let gen = TestFixtures.makeGeneration(setId: imageSet.id, projectId: projectId)
        modelContext.insert(gen)

        let providerKey = TestFixtures.makeProviderKey(projectId: projectId)
        modelContext.insert(providerKey)

        let agent = TestFixtures.makeAgent(projectId: projectId)
        modelContext.insert(agent)
        let card = TestFixtures.makeStartCard(agentId: agent.id)
        let startImageFileName = "start_image_\(card.id.uuidString)"
        let startVideoFileName = "start_video_\(card.id.uuidString)"
        var startConfiguration = card.startConfiguration
        startConfiguration.imagePath = startImageFileName
        startConfiguration.videoPath = startVideoFileName
        card.startConfiguration = startConfiguration
        seededAssetFiles.documentFileNames.formUnion([startImageFileName, startVideoFileName])
        modelContext.insert(card)
        let outputCard = TestFixtures.makeOutputCard(agentId: agent.id)
        modelContext.insert(outputCard)
        let processCard = TestFixtures.makeAgentCard(
            agentId: agent.id,
            cardType: .process,
            processCardType: .imageGeneration,
            title: "Image Generation"
        )
        let referenceImageId = UUID()
        var imageConfiguration = processCard.imageGenerationConfiguration
        imageConfiguration.referenceImages = [
            ReferenceImageConfig(id: referenceImageId, imagePath: "", referenceType: "style"),
        ]
        processCard.imageGenerationConfiguration = imageConfiguration
        seededAssetFiles.documentFileNames.insert(
            "imggen_ref_\(processCard.id.uuidString)_\(referenceImageId.uuidString)"
        )
        modelContext.insert(processCard)
        let link = TestFixtures.makeCardLink(
            agentId: agent.id,
            sourceCardId: card.id,
            targetCardId: outputCard.id
        )
        modelContext.insert(link)
        let run = TestFixtures.makeAgentRun(agentId: agent.id, projectId: projectId)
        modelContext.insert(run)

        let brandLogoFileName = "brand_logo_\(projectId.uuidString)"
        let brandModelFileName = "brand_model_\(projectId.uuidString)"
        let brandKit = BrandKit(
            projectId: projectId,
            imageFileNames: ["light": brandLogoFileName],
            modelAssets: [ModelAsset(fileName: brandModelFileName)]
        )
        seededAssetFiles.documentFileNames.formUnion([
            brandLogoFileName,
            "\(brandLogoFileName)_thumb",
            "\(brandLogoFileName)_thumb_large",
            brandModelFileName,
            "\(brandModelFileName)_thumb",
            "\(brandModelFileName)_thumb_large",
        ])
        modelContext.insert(brandKit)

        let chatThread = TestFixtures.makeChatThread(projectId: projectId)
        modelContext.insert(chatThread)
        let chatMessage = ChatMessage(threadId: chatThread.id, prompt: "Test chat message")
        modelContext.insert(chatMessage)

        let playground = TestFixtures.makePlayground(projectId: projectId)
        modelContext.insert(playground)

        let storyboard = TestFixtures.makeStoryboard(projectId: projectId)
        modelContext.insert(storyboard)
        let storyboardAsset = StoryboardAsset(storyboardId: storyboard.id, name: "Reference")
        modelContext.insert(storyboardAsset)
        seededAssetFiles.storyboardAssetIds.insert(storyboardAsset.id)

        let bulkSession = TestFixtures.makeBulkSession(projectId: projectId)
        modelContext.insert(bulkSession)

        let bulkEditSession = BulkEditSession(name: "Test Bulk Edit", projectId: projectId)
        modelContext.insert(bulkEditSession)
        let bulkSourceFileName = "bulk_source_\(projectId.uuidString)"
        let bulkThumbFileName = "\(bulkSourceFileName)_thumb"
        let bulkEditItem = BulkEditItem(
            sessionId: bulkEditSession.id,
            sourceImageFileName: bulkSourceFileName,
            sourceImageThumbFileName: bulkThumbFileName,
            sourceImageName: "Source"
        )
        modelContext.insert(bulkEditItem)
        seededAssetFiles.documentFileNames.formUnion([bulkSourceFileName, bulkThumbFileName])

        let failedRequest = TestFixtures.makeFailedRequest(projectId: projectId)
        modelContext.insert(failedRequest)

        let editSession = TestFixtures.makeRealtimeEditSession(projectId: projectId)
        modelContext.insert(editSession)
        let realtimeLayerFileName = "realtime_layer_\(projectId.uuidString)"
        let realtimeLayer = RealtimeEditLayer(sessionId: editSession.id, layerType: .image)
        realtimeLayer.imagePath = realtimeLayerFileName
        modelContext.insert(realtimeLayer)
        seededAssetFiles.documentFileNames.insert(realtimeLayerFileName)

        let studio = TestFixtures.makeCreativeStudio(projectId: projectId)
        modelContext.insert(studio)

        let photoshoot = TestFixtures.makeProductPhotoshoot(projectId: projectId)
        modelContext.insert(photoshoot)
        let backdropFileName = "photoshoot_backdrop_\(projectId.uuidString)"
        let photoshootItem = ProductPhotoshootItem(
            photoshootId: photoshoot.id,
            projectId: projectId,
            customBackdropFileName: backdropFileName
        )
        modelContext.insert(photoshootItem)
        seededAssetFiles.documentFileNames.insert(backdropFileName)

        let productGalleryFileName = "product_gallery_\(projectId.uuidString)"
        let productGalleryThumbFileName = "\(productGalleryFileName)_thumb"
        let productGalleryLargeThumbFileName = "\(productGalleryFileName)_thumb_large"
        let productGalleryItem = ProductGalleryItem(
            projectId: projectId,
            productName: "Test Product",
            imageFileName: productGalleryFileName,
            thumbFileName: productGalleryThumbFileName,
            largeThumbFileName: productGalleryLargeThumbFileName
        )
        modelContext.insert(productGalleryItem)
        seededAssetFiles.documentFileNames.formUnion([
            productGalleryFileName,
            productGalleryThumbFileName,
            productGalleryLargeThumbFileName,
        ])

        try modelContext.save()
        return seededAssetFiles
    }

    private func performFullReset() throws {
        try modelContext.delete(model: ChatMessage.self)
        try modelContext.delete(model: ProviderKey.self)
        try modelContext.delete(model: Project.self)

        let allModelTypes: [any PersistentModel.Type] = [
            Generation.self, ImageSet.self,
            AgentCard.self, CardLink.self, AgentRun.self, Agent.self,
            BrandKit.self, ChatThread.self,
            PlaygroundCard.self, PlaygroundLink.self, Playground.self,
            RealtimeEditLayer.self, RealtimeEditSession.self,
            CreativeStudioItem.self, CreativeStudio.self,
            StoryboardScene.self, StoryboardAsset.self, Storyboard.self,
            BulkSessionItem.self, BulkSession.self,
            BulkEditItem.self, BulkEditSession.self,
            ProductPhotoshootItem.self, ProductPhotoshoot.self,
            PromptGalleryItem.self, ProductGalleryItem.self,
            FailedRequest.self,
        ]
        for modelType in allModelTypes {
            try modelContext.delete(model: modelType)
        }

        try modelContext.save()
        modelContext.processPendingChanges()

        let defaultProject = Project.createDefault()
        modelContext.insert(defaultProject)
        try modelContext.save()
        modelContext.processPendingChanges()
    }

    // MARK: - Full Reset: All Entity Types Deleted

    func testFullReset_deletesAllGenerations() throws {
        try seedAllEntityTypes(projectId: Project.defaultProjectId)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Generation>()), 1)

        try performFullReset()

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Generation>()), 0)
    }

    func testFullReset_deletesAllImageSets() throws {
        try seedAllEntityTypes(projectId: Project.defaultProjectId)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<ImageSet>()), 1)

        try performFullReset()

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<ImageSet>()), 0)
    }

    func testFullReset_deletesAllProviderKeys() throws {
        try seedAllEntityTypes(projectId: Project.defaultProjectId)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<ProviderKey>()), 1)

        try performFullReset()

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<ProviderKey>()), 0)
    }

    func testFullReset_deletesAllAgents() throws {
        try seedAllEntityTypes(projectId: Project.defaultProjectId)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Agent>()), 1)

        try performFullReset()

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Agent>()), 0)
    }

    func testFullReset_deletesAllAgentCards() throws {
        try seedAllEntityTypes(projectId: Project.defaultProjectId)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<AgentCard>()), 3)

        try performFullReset()

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<AgentCard>()), 0)
    }

    func testFullReset_deletesAllCardLinks() throws {
        try seedAllEntityTypes(projectId: Project.defaultProjectId)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<CardLink>()), 1)

        try performFullReset()

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<CardLink>()), 0)
    }

    func testFullReset_deletesAllAgentRuns() throws {
        try seedAllEntityTypes(projectId: Project.defaultProjectId)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<AgentRun>()), 1)

        try performFullReset()

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<AgentRun>()), 0)
    }

    func testFullReset_deletesAllBrandKits() throws {
        try seedAllEntityTypes(projectId: Project.defaultProjectId)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<BrandKit>()), 1)

        try performFullReset()

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<BrandKit>()), 0)
    }

    func testFullReset_deletesAllChatThreads() throws {
        try seedAllEntityTypes(projectId: Project.defaultProjectId)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<ChatThread>()), 1)

        try performFullReset()

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<ChatThread>()), 0)
    }

    func testFullReset_deletesAllPlaygrounds() throws {
        try seedAllEntityTypes(projectId: Project.defaultProjectId)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Playground>()), 1)

        try performFullReset()

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Playground>()), 0)
    }

    func testFullReset_deletesAllStoryboards() throws {
        try seedAllEntityTypes(projectId: Project.defaultProjectId)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Storyboard>()), 1)

        try performFullReset()

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Storyboard>()), 0)
    }

    func testFullReset_deletesAllBulkSessions() throws {
        try seedAllEntityTypes(projectId: Project.defaultProjectId)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<BulkSession>()), 1)

        try performFullReset()

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<BulkSession>()), 0)
    }

    func testFullReset_deletesAllFailedRequests() throws {
        try seedAllEntityTypes(projectId: Project.defaultProjectId)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<FailedRequest>()), 1)

        try performFullReset()

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<FailedRequest>()), 0)
    }

    func testFullReset_deletesAllRealtimeEditSessions() throws {
        try seedAllEntityTypes(projectId: Project.defaultProjectId)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<RealtimeEditSession>()), 1)

        try performFullReset()

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<RealtimeEditSession>()), 0)
    }

    func testFullReset_deletesAllCreativeStudios() throws {
        try seedAllEntityTypes(projectId: Project.defaultProjectId)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<CreativeStudio>()), 1)

        try performFullReset()

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<CreativeStudio>()), 0)
    }

    func testFullReset_deletesAllProductPhotoshoots() throws {
        try seedAllEntityTypes(projectId: Project.defaultProjectId)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<ProductPhotoshoot>()), 1)

        try performFullReset()

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<ProductPhotoshoot>()), 0)
    }

    func testFullReset_deletesAllProjects() throws {
        try seedAllEntityTypes(projectId: Project.defaultProjectId)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Project>()), 1)

        try performFullReset()

        XCTAssertEqual(
            try modelContext.fetchCount(FetchDescriptor<Project>()),
            1,
            "Default project should be recreated after reset"
        )
    }

    // MARK: - Full Reset: Default Project Recreation

    func testFullReset_recreatesDefaultProject() throws {
        try seedAllEntityTypes(projectId: Project.defaultProjectId)
        try performFullReset()

        let defaultId = Project.defaultProjectId
        let descriptor = FetchDescriptor<Project>(predicate: #Predicate { $0.id == defaultId })
        let projects = try modelContext.fetch(descriptor)
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects.first?.name, "Default Project")
        XCTAssertTrue(projects.first?.isDefault ?? false)
    }

    // MARK: - Full Reset: Multi-Project Wipe

    func testFullReset_deletesDataAcrossMultipleProjects() throws {
        let project2 = Project(name: "Second Project")
        modelContext.insert(project2)
        try modelContext.save()

        try seedAllEntityTypes(projectId: Project.defaultProjectId)
        try seedAllEntityTypes(projectId: project2.id)

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Generation>()), 2)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Project>()), 2)

        try performFullReset()

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Generation>()), 0)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Agent>()), 0)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<BrandKit>()), 0)
        XCTAssertEqual(
            try modelContext.fetchCount(FetchDescriptor<Project>()),
            1,
            "Only recreated default project should exist"
        )
    }

    // MARK: - Full Reset: Empty Database

    func testFullReset_emptyDatabase_doesNotThrow() throws {
        XCTAssertNoThrow(try performFullReset())
        let defaultId = Project.defaultProjectId
        let descriptor = FetchDescriptor<Project>(predicate: #Predicate { $0.id == defaultId })
        XCTAssertEqual(try modelContext.fetchCount(descriptor), 1, "Default project should be recreated")
    }

    // MARK: - Count Accuracy After Reset

    func testLoadDataCounts_reflectsDatabaseState_afterReset() throws {
        try seedAllEntityTypes(projectId: Project.defaultProjectId)

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Generation>()), 1)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<ImageSet>()), 1)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<ProviderKey>()), 1)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Agent>()), 1)

        try performFullReset()

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Generation>()), 0)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<ImageSet>()), 0)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<ProviderKey>()), 0)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Agent>()), 0)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<BrandKit>()), 0)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<ChatThread>()), 0)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Playground>()), 0)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Storyboard>()), 0)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<BulkSession>()), 0)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<FailedRequest>()), 0)
    }

    // MARK: - Project Reset: Current Project Only

    func testProjectStorageCounts_scopeToSelectedProject() throws {
        let project2 = Project(name: "Second Project")
        modelContext.insert(project2)
        try modelContext.save()

        try seedAllEntityTypes(projectId: Project.defaultProjectId)
        try seedAllEntityTypes(projectId: project2.id)

        let counts = ProjectStorageResetService.loadDataCounts(
            projectId: Project.defaultProjectId,
            modelContext: modelContext
        )

        XCTAssertEqual(counts.generations, 1)
        XCTAssertEqual(counts.imageSets, 1)
        XCTAssertEqual(counts.providerKeys, 1)
        XCTAssertEqual(counts.agents, 1)
        XCTAssertEqual(counts.brandKits, 1)
        XCTAssertEqual(counts.chatThreads, 1)
        XCTAssertEqual(counts.playgrounds, 1)
        XCTAssertEqual(counts.storyboards, 1)
        XCTAssertEqual(counts.bulkSessions, 1)
        XCTAssertEqual(counts.failedRequests, 1)
    }

    func testProjectReset_deletesOnlySelectedProjectDataAndPreservesProject() throws {
        let project2 = Project(name: "Second Project")
        modelContext.insert(project2)
        try modelContext.save()

        let defaultAssetFiles = try seedAllEntityTypes(projectId: Project.defaultProjectId)
        try seedAllEntityTypes(projectId: project2.id)

        var deletedMediaIds: [String] = []
        var deletedDocumentFiles: [String] = []
        var deletedStoryboardAssetIds: [UUID] = []
        var cleanupEvents: [String] = []
        try ProjectStorageResetService.resetProjectData(
            projectId: Project.defaultProjectId,
            modelContext: modelContext,
            deleteMediaFiles: {
                deletedMediaIds.append($0)
                cleanupEvents.append("media")
            },
            deleteProviderSecret: { _, _ in cleanupEvents.append("keychain") },
            deleteDocumentFile: {
                deletedDocumentFiles.append($0)
                cleanupEvents.append("document")
            },
            deleteStoryboardAssetFile: {
                deletedStoryboardAssetIds.append($0)
                cleanupEvents.append("storyboard-asset")
            },
            commit: {
                cleanupEvents.append("save")
                try $0.save()
            }
        )

        let defaultCounts = ProjectStorageResetService.loadDataCounts(
            projectId: Project.defaultProjectId,
            modelContext: modelContext
        )
        let secondCounts = ProjectStorageResetService.loadDataCounts(
            projectId: project2.id,
            modelContext: modelContext
        )

        XCTAssertEqual(defaultCounts, .empty)
        XCTAssertEqual(secondCounts.generations, 1)
        XCTAssertEqual(secondCounts.imageSets, 1)
        XCTAssertEqual(secondCounts.providerKeys, 1)
        XCTAssertEqual(secondCounts.agents, 1)
        XCTAssertEqual(secondCounts.brandKits, 1)
        XCTAssertEqual(secondCounts.chatThreads, 1)
        XCTAssertEqual(secondCounts.playgrounds, 1)
        XCTAssertEqual(secondCounts.storyboards, 1)
        XCTAssertEqual(secondCounts.bulkSessions, 1)
        XCTAssertEqual(secondCounts.failedRequests, 1)

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Project>()), 2)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<AgentCard>()), 3)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<CardLink>()), 1)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<AgentRun>()), 1)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<ChatMessage>()), 1)
        XCTAssertEqual(deletedMediaIds.count, 1)
        XCTAssertEqual(Array(cleanupEvents.prefix(3)), ["save", "keychain", "media"])
        XCTAssertEqual(Set(deletedDocumentFiles), defaultAssetFiles.documentFileNames)
        XCTAssertEqual(Set(deletedStoryboardAssetIds), defaultAssetFiles.storyboardAssetIds)
        XCTAssertEqual(
            cleanupEvents.filter { $0 == "document" }.count,
            defaultAssetFiles.documentFileNames.count
        )
        XCTAssertEqual(
            cleanupEvents.filter { $0 == "storyboard-asset" }.count,
            defaultAssetFiles.storyboardAssetIds.count
        )
    }

    func testProjectReset_doesNotDeleteExternalResourcesWhenCommitFails() throws {
        try seedAllEntityTypes(projectId: Project.defaultProjectId)

        let expectedErrorDomain = "ResetWorkflowTests"
        var deletedDocumentFiles: [String] = []
        var deletedStoryboardAssetIds: [UUID] = []
        var cleanupEvents: [String] = []

        XCTAssertThrowsError(try ProjectStorageResetService.resetProjectData(
            projectId: Project.defaultProjectId,
            modelContext: modelContext,
            deleteMediaFiles: { _ in cleanupEvents.append("media") },
            deleteProviderSecret: { _, _ in cleanupEvents.append("keychain") },
            deleteDocumentFile: {
                deletedDocumentFiles.append($0)
                cleanupEvents.append("document")
            },
            deleteStoryboardAssetFile: {
                deletedStoryboardAssetIds.append($0)
                cleanupEvents.append("storyboard-asset")
            },
            commit: { _ in
                cleanupEvents.append("save")
                throw NSError(domain: expectedErrorDomain, code: 1)
            }
        )) { error in
            XCTAssertEqual((error as NSError).domain, expectedErrorDomain)
        }

        XCTAssertEqual(cleanupEvents, ["save"])
        XCTAssertTrue(deletedDocumentFiles.isEmpty)
        XCTAssertTrue(deletedStoryboardAssetIds.isEmpty)
    }

    // MARK: - JSONCredentialField Tests

    func testJSONCredentialFields_cloudflareAI_returnsTwoFields() throws {
        let provider = try XCTUnwrap(providers.first { $0.providerCode == .CLOUDFLARE_AI })
        let fields = provider.jsonCredentialFields

        XCTAssertEqual(fields.count, 2)
        XCTAssertEqual(fields[0].id, "account_id")
        XCTAssertEqual(fields[0].label, "Account ID")
        XCTAssertEqual(fields[0].placeholder, "your-account-id")
        XCTAssertEqual(fields[1].id, "api_token")
        XCTAssertEqual(fields[1].label, "API Token")
        XCTAssertEqual(fields[1].placeholder, "your-api-token")
    }

    func testJSONCredentialFields_apiProvider_returnsEmpty() throws {
        let provider = try XCTUnwrap(providers.first { $0.providerCode == .OPENAI })
        XCTAssertEqual(provider.jsonCredentialFields.count, 0)
    }

    func testJSONCredentialFields_fieldsAreIdentifiable() throws {
        let provider = try XCTUnwrap(providers.first { $0.providerCode == .CLOUDFLARE_AI })
        let fields = provider.jsonCredentialFields
        let ids = fields.map(\.id)
        XCTAssertEqual(Set(ids).count, fields.count, "Field IDs should be unique")
    }

    // MARK: - JSON Credential Serialization

    func testJSONCredentialSerialization_cloudflareAI_producesValidJSON() throws {
        let provider = try XCTUnwrap(providers.first { $0.providerCode == .CLOUDFLARE_AI })
        let fields = provider.jsonCredentialFields

        var fieldValues: [String: String] = [:]
        for field in fields {
            fieldValues[field.id] = "test_\(field.id)_value"
        }

        let dict = Dictionary(
            uniqueKeysWithValues: fields.compactMap { field in
                let val = fieldValues[field.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return val.isEmpty ? nil : (field.id, val)
            }
        )

        let data = try JSONSerialization.data(withJSONObject: dict)
        let jsonString = try XCTUnwrap(String(data: data, encoding: .utf8))
        let decoded = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(jsonString.utf8)) as? [String: String])

        XCTAssertEqual(decoded["account_id"], "test_account_id_value")
        XCTAssertEqual(decoded["api_token"], "test_api_token_value")
    }

    func testJSONCredentialSerialization_emptyField_excludedFromJSON() throws {
        let provider = try XCTUnwrap(providers.first { $0.providerCode == .CLOUDFLARE_AI })
        let fields = provider.jsonCredentialFields

        var fieldValues: [String: String] = [:]
        fieldValues[fields[0].id] = "valid_value"
        fieldValues[fields[1].id] = ""

        let dict = Dictionary(
            uniqueKeysWithValues: fields.compactMap { field in
                let val = fieldValues[field.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return val.isEmpty ? nil : (field.id, val)
            }
        )

        XCTAssertEqual(dict.count, 1)
        XCTAssertEqual(dict[fields[0].id], "valid_value")
        XCTAssertNil(dict[fields[1].id])
    }

    func testJSONCredentialSerialization_roundTripParsableByCloudflareBase() throws {
        let provider = try XCTUnwrap(providers.first { $0.providerCode == .CLOUDFLARE_AI })
        let fields = provider.jsonCredentialFields

        var fieldValues: [String: String] = [:]
        for field in fields {
            fieldValues[field.id] = "test_\(field.id)_value"
        }

        let dict = Dictionary(
            uniqueKeysWithValues: fields.compactMap { field in
                let val = fieldValues[field.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return val.isEmpty ? nil : (field.id, val)
            }
        )

        let data = try JSONSerialization.data(withJSONObject: dict)
        let jsonString = try XCTUnwrap(String(data: data, encoding: .utf8))

        let cfBase = G_CLOUDFLARE_FLUX_1_SCHNELL()
        let parsed = cfBase.parseCredentials(jsonString)

        XCTAssertNotNil(parsed, "Cloudflare base should parse the serialized JSON")
        XCTAssertEqual(parsed?.accountId, "test_account_id_value")
        XCTAssertEqual(parsed?.apiToken, "test_api_token_value")
    }

    // MARK: - Erase Confirmation Validation

    func testEraseConfirmation_exactMatch_isValid() {
        let phrase = "ERASE"
        let input = "ERASE"
        XCTAssertEqual(input.trimmingCharacters(in: .whitespacesAndNewlines), phrase)
    }

    func testEraseConfirmation_withLeadingTrailingWhitespace_isValid() {
        let phrase = "ERASE"
        let input = "  ERASE  "
        XCTAssertEqual(input.trimmingCharacters(in: .whitespacesAndNewlines), phrase)
    }

    func testEraseConfirmation_lowercase_doesNotMatch() {
        let phrase = "ERASE"
        let input = "erase"
        XCTAssertNotEqual(input.trimmingCharacters(in: .whitespacesAndNewlines), phrase)
    }

    func testEraseConfirmation_partialInput_doesNotMatch() {
        let phrase = "ERASE"
        let input = "ERAS"
        XCTAssertNotEqual(input.trimmingCharacters(in: .whitespacesAndNewlines), phrase)
    }

    func testEraseConfirmation_emptyInput_doesNotMatch() {
        let phrase = "ERASE"
        let input = ""
        XCTAssertNotEqual(input.trimmingCharacters(in: .whitespacesAndNewlines), phrase)
    }

    // MARK: - Form Validation (AddProviderView logic)

    func testFormValidation_jsonProvider_allFieldsFilled_isValid() throws {
        let provider = try XCTUnwrap(providers.first { $0.providerCode == .CLOUDFLARE_AI })
        XCTAssertEqual(provider.keyType, .JSON)

        var fieldValues: [String: String] = [:]
        for field in provider.jsonCredentialFields {
            fieldValues[field.id] = "some_value"
        }

        let allFilled = provider.jsonCredentialFields.allSatisfy { field in
            let value = fieldValues[field.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !value.isEmpty
        }
        XCTAssertTrue(allFilled)
    }

    func testFormValidation_jsonProvider_missingField_isInvalid() throws {
        let provider = try XCTUnwrap(providers.first { $0.providerCode == .CLOUDFLARE_AI })

        var fieldValues: [String: String] = [:]
        fieldValues[provider.jsonCredentialFields[0].id] = "some_value"
        fieldValues[provider.jsonCredentialFields[1].id] = ""

        let allFilled = provider.jsonCredentialFields.allSatisfy { field in
            let value = fieldValues[field.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !value.isEmpty
        }
        XCTAssertFalse(allFilled)
    }

    func testFormValidation_apiProvider_nonEmptyKey_isValid() {
        let keyValue = "sk-proj-aaaa"
        XCTAssertTrue(!keyValue.isEmpty)
    }

    func testFormValidation_apiProvider_emptyKey_isInvalid() {
        let keyValue = ""
        XCTAssertFalse(!keyValue.isEmpty)
    }
}
