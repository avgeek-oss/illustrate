import SwiftData
import SwiftUI

@Model
class ProductGalleryItem: Identifiable, Codable {
    enum CodingKeys: CodingKey {
        case id
        case projectId
        case productName
        case tags
        case imageFileName
        case thumbFileName
        case largeThumbFileName
        case createdAt
        case updatedAt
    }

    var id = UUID()
    var projectId: UUID = Project.defaultProjectId
    var project: Project?
    var productName = ""
    var tags: [String] = []
    var imageFileName: String?
    var thumbFileName: String?
    var largeThumbFileName: String?
    var createdAt = Date()
    var updatedAt = Date()

    init(
        projectId: UUID = Project.defaultProjectId,
        productName: String = "",
        tags: [String] = [],
        imageFileName: String? = nil,
        thumbFileName: String? = nil,
        largeThumbFileName: String? = nil
    ) {
        id = UUID()
        self.projectId = projectId
        self.productName = productName
        self.tags = tags
        self.imageFileName = imageFileName
        self.thumbFileName = thumbFileName
        self.largeThumbFileName = largeThumbFileName
        createdAt = Date()
        updatedAt = Date()
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId) ?? Project.defaultProjectId
        productName = try container.decode(String.self, forKey: .productName)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        thumbFileName = try container.decodeIfPresent(String.self, forKey: .thumbFileName)
        largeThumbFileName = try container.decodeIfPresent(String.self, forKey: .largeThumbFileName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(productName, forKey: .productName)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(imageFileName, forKey: .imageFileName)
        try container.encodeIfPresent(thumbFileName, forKey: .thumbFileName)
        try container.encodeIfPresent(largeThumbFileName, forKey: .largeThumbFileName)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
