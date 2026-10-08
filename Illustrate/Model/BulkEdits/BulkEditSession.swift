import SwiftData
import SwiftUI

enum BulkEditSessionStatus: String, Codable {
    case IDLE
    case RUNNING
    case COMPLETED

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "idle", "IDLE": self = .IDLE
        case "running", "RUNNING": self = .RUNNING
        case "completed", "COMPLETED": self = .COMPLETED
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown BulkEditSessionStatus: \(rawValue)"
                )
            )
        }
    }
}

let bulkEditMaxItems = 250

@Model
class BulkEditSession: Identifiable, Codable, Pinnable {
    #Index<BulkEditSession>([\.projectId])

    enum CodingKeys: CodingKey {
        case id
        case projectId
        case createdAt
        case name
        case isPinned
        case concurrencyLimit
        case commonPrompt
        case selectedProviderId
        case selectedModelId
        case configurationData
        case status
    }

    var id = UUID()
    var projectId: UUID = Project.defaultProjectId
    var project: Project?
    var createdAt = Date()
    var name = "Untitled Session"
    var isPinned = false
    var concurrencyLimit = 2
    var commonPrompt = ""
    var selectedProviderId = ""
    var selectedModelId = ""
    var configurationData: Data?
    var status = BulkEditSessionStatus.IDLE

    @Relationship(deleteRule: .cascade, inverse: \BulkEditItem.bulkEditSession)
    var items: [BulkEditItem]? = nil

    init(
        name: String = "Untitled Session",
        projectId: UUID = Project.defaultProjectId
    ) {
        id = UUID()
        self.name = name
        self.projectId = projectId
        createdAt = Date()
        isPinned = false
        concurrencyLimit = 2
        commonPrompt = ""
        selectedProviderId = ""
        selectedModelId = ""
        configurationData = nil
        status = .IDLE
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId) ?? Project.defaultProjectId
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        name = try container.decode(String.self, forKey: .name)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        concurrencyLimit = try container.decodeIfPresent(Int.self, forKey: .concurrencyLimit) ?? 2
        commonPrompt = try container.decodeIfPresent(String.self, forKey: .commonPrompt) ?? ""
        selectedProviderId = try container.decodeIfPresent(String.self, forKey: .selectedProviderId) ?? ""
        selectedModelId = try container.decodeIfPresent(String.self, forKey: .selectedModelId) ?? ""
        configurationData = try container.decodeIfPresent(Data.self, forKey: .configurationData)
        status = try container.decodeIfPresent(BulkEditSessionStatus.self, forKey: .status) ?? .IDLE
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(name, forKey: .name)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(concurrencyLimit, forKey: .concurrencyLimit)
        try container.encode(commonPrompt, forKey: .commonPrompt)
        try container.encode(selectedProviderId, forKey: .selectedProviderId)
        try container.encode(selectedModelId, forKey: .selectedModelId)
        try container.encodeIfPresent(configurationData, forKey: .configurationData)
        try container.encode(status, forKey: .status)
    }

    var savedConfiguration: ImageGenerationConfiguration {
        get {
            guard let data = configurationData else { return ImageGenerationConfiguration() }
            do {
                return try JSONDecoder().decode(ImageGenerationConfiguration.self, from: data)
            } catch {
                AppLogger.data.error("Failed to decode BulkEditSession configuration: \(error, privacy: .public)")
                return ImageGenerationConfiguration()
            }
        }
        set {
            do {
                configurationData = try JSONEncoder().encode(newValue)
            } catch {
                configurationData = nil
                AppLogger.data.error("Failed to encode BulkEditSession configuration: \(error, privacy: .public)")
            }
        }
    }
}
