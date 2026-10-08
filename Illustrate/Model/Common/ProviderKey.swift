// MARK: - ProviderKey.swift

// Manages the association between providers and their API keys within projects.
//
// This model represents a "connection" between a user's project and an AI provider.
// The actual API key credentials are stored securely in the system Keychain,
// while this SwiftData model tracks which providers are connected to which projects.
//
// ## Security Architecture
// API keys are NOT stored in this model or SwiftData. This model only stores:
// - Which provider is connected (providerId)
// - Which project it belongs to (projectId)
// - When it was added (createdAt)
//
// The actual credentials are stored in Keychain using the providerId as the key.
// This ensures sensitive data is protected by the OS security layer and excluded
// from iCloud sync.

import Foundation
import SwiftData

// MARK: - Provider Key Model

/// SwiftData model tracking provider-to-project associations.
///
/// This model acts as a lightweight reference indicating which providers
/// have been configured for a specific project. The actual API credentials
/// are stored separately in Keychain for security.
///
/// ## Project Scoping
/// Provider keys can be scoped to specific projects, allowing users to use
/// different API keys for different projects. The default project is used
/// if no specific project is specified.
///
/// ## Codable Conformance
/// Implements Codable for potential export/import functionality and
/// SwiftData's automatic serialization requirements.
@Model
final class ProviderKey: Codable {
    #Index<ProviderKey>([\.projectId])

    enum CodingKeys: CodingKey {
        case providerId
        case projectId
        case createdAt
    }

    /// References the provider this key belongs to (maps to Provider.providerId)
    var providerId = UUID()

    /// The project this key is associated with (enables per-project API keys)
    var projectId: UUID = Project.defaultProjectId

    /// Timestamp when this provider connection was established
    var createdAt = Date()

    /// Creates a new provider key association.
    ///
    /// - Parameters:
    ///   - providerId: The UUID of the provider being connected
    ///   - projectId: The project to associate with (defaults to default project)
    ///   - createdAt: Creation timestamp (defaults to now)
    init(providerId: UUID, projectId: UUID = Project.defaultProjectId, createdAt: Date = Date()) {
        self.providerId = providerId
        self.projectId = projectId
        self.createdAt = createdAt
    }

    // MARK: - Codable Implementation

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(providerId, forKey: .providerId)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(createdAt, forKey: .createdAt)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providerId = try container.decode(UUID.self, forKey: .providerId)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId) ?? Project.defaultProjectId
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}
