// MARK: - BulkSessionItem.swift

// Defines the BulkSessionItem model for individual prompts in a bulk session.
//
// Each BulkSessionItem represents a single prompt from the imported CSV file.
// Items track their generation status and link to the resulting Generation
// on success.
//
// ## Item Lifecycle
// 1. Created from CSV import with status `.pending`
// 2. When generation starts: status → `.inProgress`
// 3. On success: status → `.completed`, generationId set
// 4. On failure: status → `.failed`, errorMessage set
// 5. On cancel: status → `.cancelled` (for pending items only)

import SwiftData
import SwiftUI

// MARK: - Bulk Session Item Status

/// Tracks the generation state of an individual bulk session item.
enum BulkSessionItemStatus: String, Codable {
    /// Item is waiting to be processed
    case PENDING
    case IN_PROGRESS
    case COMPLETED
    case FAILED
    /// Item was cancelled by user
    case CANCELLED

    // MARK: - Backward Compatible Decoding

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "pending", "PENDING": self = .PENDING
        case "inProgress", "IN_PROGRESS", "in_progress": self = .IN_PROGRESS
        case "completed", "COMPLETED": self = .COMPLETED
        case "failed", "FAILED": self = .FAILED
        case "cancelled", "CANCELLED": self = .CANCELLED
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown BulkSessionItemStatus: \(rawValue)"
                )
            )
        }
    }
}

// MARK: - BulkSessionItem Model

/// SwiftData model representing a single prompt in a bulk generation session.
///
/// BulkSessionItems store the prompt text and track generation status.
/// On successful generation, the item links to the resulting Generation
/// via generationId.
///
/// ## Deletion Behavior
/// Deleting an item does NOT delete the associated gallery image.
/// The generationId simply becomes orphaned.
@Model
class BulkSessionItem: Identifiable, Codable {
    #Index<BulkSessionItem>([\.sessionId])

    enum CodingKeys: CodingKey {
        case id
        case sessionId
        case createdAt
        case prompt
        case filename
        case status
        case generationId
        case errorMessage
        case queueItemId
    }

    var id = UUID()

    var sessionId = UUID()

    var bulkSession: BulkSession?

    var createdAt = Date()

    /// The prompt text (from CSV or manually added)
    var prompt = ""

    /// Optional filename override from CSV (used when exporting)
    var filename: String?

    var status = BulkSessionItemStatus.PENDING

    /// Generation ID on success (links to Generation model)
    var generationId: UUID?

    /// Error message on failure
    var errorMessage: String?

    /// Queue item ID for tracking in-progress generation
    var queueItemId: UUID?

    /// Creates a new bulk session item.
    ///
    /// - Parameters:
    ///   - sessionId: Parent session ID
    ///   - prompt: The prompt text
    ///   - filename: Optional filename override for export
    init(sessionId: UUID, prompt: String, filename: String? = nil) {
        id = UUID()
        self.sessionId = sessionId
        self.prompt = prompt
        self.filename = filename
        createdAt = Date()
        status = .PENDING
        generationId = nil
        errorMessage = nil
        queueItemId = nil
    }

    // MARK: - Codable Implementation

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sessionId = try container.decode(UUID.self, forKey: .sessionId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        prompt = try container.decode(String.self, forKey: .prompt)
        filename = try container.decodeIfPresent(String.self, forKey: .filename)
        status = try container.decodeIfPresent(BulkSessionItemStatus.self, forKey: .status) ?? .PENDING
        generationId = try container.decodeIfPresent(UUID.self, forKey: .generationId)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        queueItemId = try container.decodeIfPresent(UUID.self, forKey: .queueItemId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(prompt, forKey: .prompt)
        try container.encodeIfPresent(filename, forKey: .filename)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(generationId, forKey: .generationId)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try container.encodeIfPresent(queueItemId, forKey: .queueItemId)
    }
}
