import SwiftData
import SwiftUI

@Model
class PromptGalleryItem: Identifiable, Codable {
    enum CodingKeys: CodingKey {
        case id
        case projectId
        case title
        case prompt
        case tags
        case createdAt
        case updatedAt
    }

    var id = UUID()
    var projectId: UUID = Project.defaultProjectId
    var project: Project?
    var title = ""
    var prompt = ""
    var tags: [String] = []
    var createdAt = Date()
    var updatedAt = Date()

    init(
        projectId: UUID = Project.defaultProjectId,
        title: String = "",
        prompt: String = "",
        tags: [String] = []
    ) {
        id = UUID()
        self.projectId = projectId
        self.title = title
        self.prompt = prompt
        self.tags = tags
        createdAt = Date()
        updatedAt = Date()
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId) ?? Project.defaultProjectId
        title = try container.decode(String.self, forKey: .title)
        prompt = try container.decode(String.self, forKey: .prompt)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(title, forKey: .title)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(tags, forKey: .tags)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
