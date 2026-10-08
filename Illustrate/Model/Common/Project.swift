// MARK: - Project.swift

// Defines the Project model for organizing content and settings.
//
// Projects are the top-level organizational unit in Illustrate. They allow
// users to separate work into distinct contexts, each with its own:
// - Generated images and videos
// - Agent workflows
// - Provider API key associations
// - Brand kit settings
//
// ## Default Project
// A default project is automatically created with a well-known UUID
// (`defaultProjectId`). This ensures all models have a valid project
// reference even if the user hasn't explicitly created projects.
//
// ## Project Scoping
// Most models include a `projectId` field referencing the containing project.
// This enables filtering content by project and implementing project-specific
// settings like different API keys for different projects.

import Foundation
import SwiftData

// MARK: - Project Model

/// SwiftData model representing a project for content organization.
///
/// Projects group related work together:
/// - Generations (images/videos)
/// - Agents and workflows
/// - API key associations
/// - Brand kit settings
///
/// ## Default Project
/// A default project with a well-known UUID is always available. It's
/// created automatically when the app first runs and cannot be deleted.
///
/// ## Multi-Project Workflow
/// Users can create multiple projects to separate different work contexts.
/// The ProjectManager handles project switching and ensures a project
/// is always selected.
@Model
final class Project: Codable, Identifiable {
    enum CodingKeys: CodingKey {
        case id
        case name
        case createdAt
        case isDefault
    }

    var id = UUID()

    /// User-defined project name
    var name = ""

    var createdAt = Date()

    /// Whether this is the default project (cannot be deleted)
    var isDefault = false

    // MARK: Relationships

    @Relationship(deleteRule: .cascade, inverse: \ImageSet.project)
    var imageSets: [ImageSet]? = nil

    @Relationship(deleteRule: .cascade, inverse: \Agent.project)
    var agents: [Agent]? = nil

    @Relationship(deleteRule: .cascade, inverse: \ChatThread.project)
    var chatThreads: [ChatThread]? = nil

    @Relationship(deleteRule: .cascade, inverse: \Playground.project)
    var playgrounds: [Playground]? = nil

    @Relationship(deleteRule: .cascade, inverse: \RealtimeEditSession.project)
    var realtimeEditSessions: [RealtimeEditSession]? = nil

    @Relationship(deleteRule: .cascade, inverse: \Storyboard.project)
    var storyboards: [Storyboard]? = nil

    @Relationship(deleteRule: .cascade, inverse: \BulkSession.project)
    var bulkSessions: [BulkSession]? = nil

    @Relationship(deleteRule: .cascade, inverse: \BulkEditSession.project)
    var bulkEdits: [BulkEditSession]? = nil

    @Relationship(deleteRule: .cascade, inverse: \CreativeStudio.project)
    var creativeStudios: [CreativeStudio]? = nil

    @Relationship(deleteRule: .cascade, inverse: \ProductPhotoshoot.project)
    var productPhotoshoots: [ProductPhotoshoot]? = nil

    @Relationship(deleteRule: .cascade, inverse: \FailedRequest.project)
    var failedRequests: [FailedRequest]? = nil

    @Relationship(deleteRule: .cascade, inverse: \BrandKit.project)
    var brandKits: [BrandKit]? = nil

    @Relationship(deleteRule: .cascade, inverse: \PromptGalleryItem.project)
    var promptGalleryItems: [PromptGalleryItem]? = nil

    @Relationship(deleteRule: .cascade, inverse: \ProductGalleryItem.project)
    var productGalleryItems: [ProductGalleryItem]? = nil

    /// Well-known UUID for the default project.
    /// Using a fixed UUID ensures consistency across devices and iCloud sync.
    static let defaultProjectId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    /// Creates a new project.
    ///
    /// - Parameters:
    ///   - id: Project UUID (auto-generated if not provided)
    ///   - name: Display name for the project
    ///   - createdAt: Creation timestamp
    ///   - isDefault: Whether this is the default project
    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.isDefault = isDefault
    }

    /// Factory method to create the default project.
    ///
    /// Called during app initialization to ensure the default project exists.
    /// Uses `defaultProjectId` to ensure consistency across devices.
    ///
    /// - Returns: The default project instance
    static func createDefault() -> Project {
        Project(
            id: defaultProjectId,
            name: "Default Project",
            createdAt: Date(),
            isDefault: true
        )
    }

    // MARK: - Codable Implementation

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isDefault, forKey: .isDefault)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
    }
}
