import SwiftData
import SwiftUI

enum BulkEditItemStatus: String, Codable {
    case PENDING
    case IN_PROGRESS
    case COMPLETED
    case FAILED
    case CANCELLED

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
                    debugDescription: "Unknown BulkEditItemStatus: \(rawValue)"
                )
            )
        }
    }
}

@Model
class BulkEditItem: Identifiable, Codable {
    #Index<BulkEditItem>([\.sessionId])

    enum CodingKeys: CodingKey {
        case id
        case sessionId
        case createdAt
        case sourceImageFileName
        case sourceImageThumbFileName
        case sourceImageName
        case status
        case generationId
        case errorMessage
        case queueItemId
    }

    var id = UUID()
    var sessionId = UUID()
    var bulkEditSession: BulkEditSession?
    var createdAt = Date()
    var sourceImageFileName: String?
    var sourceImageThumbFileName: String?
    var sourceImageName: String?
    var status = BulkEditItemStatus.PENDING
    var generationId: UUID?
    var errorMessage: String?
    var queueItemId: UUID?

    init(
        sessionId: UUID,
        sourceImageFileName: String? = nil,
        sourceImageThumbFileName: String? = nil,
        sourceImageName: String? = nil
    ) {
        id = UUID()
        self.sessionId = sessionId
        self.sourceImageFileName = sourceImageFileName
        self.sourceImageThumbFileName = sourceImageThumbFileName
        self.sourceImageName = sourceImageName
        createdAt = Date()
        status = .PENDING
        generationId = nil
        errorMessage = nil
        queueItemId = nil
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sessionId = try container.decode(UUID.self, forKey: .sessionId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        sourceImageFileName = try container.decodeIfPresent(String.self, forKey: .sourceImageFileName)
        sourceImageThumbFileName = try container.decodeIfPresent(String.self, forKey: .sourceImageThumbFileName)
        sourceImageName = try container.decodeIfPresent(String.self, forKey: .sourceImageName)
        status = try container.decodeIfPresent(BulkEditItemStatus.self, forKey: .status) ?? .PENDING
        generationId = try container.decodeIfPresent(UUID.self, forKey: .generationId)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        queueItemId = try container.decodeIfPresent(UUID.self, forKey: .queueItemId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(sourceImageFileName, forKey: .sourceImageFileName)
        try container.encodeIfPresent(sourceImageThumbFileName, forKey: .sourceImageThumbFileName)
        try container.encodeIfPresent(sourceImageName, forKey: .sourceImageName)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(generationId, forKey: .generationId)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try container.encodeIfPresent(queueItemId, forKey: .queueItemId)
    }
}
