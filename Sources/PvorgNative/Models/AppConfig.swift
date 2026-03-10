import Foundation

struct AppConfig: Codable {
    var videosPath: String
    var galleriesPath: String
    var tags: [String]
    var videoRelations: [String: VideoRelation]
}

struct VideoRelation: Codable {
    var galleries: [String]?
    var excludedGalleries: [String]?
    var tags: [String]?
    var excludedTags: [String]?

    var yesGalleries: [String] { galleries ?? [] }
    var noGalleries: [String] { excludedGalleries ?? [] }
    var yesTags: [String] { tags ?? [] }
    var noTags: [String] { excludedTags ?? [] }
}
