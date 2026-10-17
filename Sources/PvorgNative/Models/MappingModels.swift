import Foundation

/// The two relation types edited with the tri-state matrix.
enum MappingKind: String, CaseIterable, Identifiable {
    case galleries
    case tags

    var id: String { rawValue }

    var title: String {
        switch self {
        case .galleries: "Gallery Mapping"
        case .tags: "Tag Mapping"
        }
    }

    /// Singular noun for a column, used in sentences ("every gallery").
    var columnNoun: String {
        switch self {
        case .galleries: "gallery"
        case .tags: "tag"
        }
    }

    var yesKeyPath: WritableKeyPath<VideoRelation, [String]?> {
        switch self {
        case .galleries: \.galleries
        case .tags: \.tags
        }
    }

    var noKeyPath: WritableKeyPath<VideoRelation, [String]?> {
        switch self {
        case .galleries: \.excludedGalleries
        case .tags: \.excludedTags
        }
    }

    /// The other relation pair, which a save must leave untouched (but normalized).
    var preservedKeyPaths: [WritableKeyPath<VideoRelation, [String]?>] {
        switch self {
        case .galleries: [\.tags, \.excludedTags]
        case .tags: [\.galleries, \.excludedGalleries]
        }
    }
}

struct MappingVideoRow: Identifiable, VideoDisplaySortable {
    let id: String
    let filename: String
    let title: String
    let studio: String
    let actors: [String]
    let tgpURL: URL?
    let map: [String: TriState]

    init(filename: String, title: String, studio: String, actors: [String] = [], tgpURL: URL?, map: [String: TriState]) {
        self.id = filename
        self.filename = filename
        self.title = title
        self.studio = studio
        self.actors = actors
        self.tgpURL = tgpURL
        self.map = map
    }
}
