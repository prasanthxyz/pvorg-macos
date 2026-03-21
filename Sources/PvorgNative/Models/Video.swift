import Foundation

struct Video: Identifiable, Hashable, VideoDisplaySortable {
    let id: String
    let filename: String
    let studio: String
    let actors: [String]
    let title: String
    let fileURL: URL
    var relatedGalleries: [String]
    var tags: [String]

    init(
        filename: String,
        studio: String,
        actors: [String],
        title: String,
        fileURL: URL,
        relatedGalleries: [String],
        tags: [String]
    ) {
        self.id = filename
        self.filename = filename
        self.studio = studio
        self.actors = actors
        self.title = title
        self.fileURL = fileURL
        self.relatedGalleries = relatedGalleries
        self.tags = tags
    }
}
