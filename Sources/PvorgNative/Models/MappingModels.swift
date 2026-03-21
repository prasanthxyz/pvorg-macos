import Foundation

struct MappingVideoRow: Identifiable, VideoDisplaySortable {
    let id: String
    let filename: String
    let title: String
    let studio: String
    let tgpURL: URL?
    let map: [String: TriState]

    init(filename: String, title: String, studio: String, tgpURL: URL?, map: [String: TriState]) {
        self.id = filename
        self.filename = filename
        self.title = title
        self.studio = studio
        self.tgpURL = tgpURL
        self.map = map
    }
}

struct MappingPageData {
    let total: Int
    let page: Int
    let pageSize: Int
    let columns: [String]
    let videos: [MappingVideoRow]

    static func empty(pageSize: Int) -> MappingPageData {
        MappingPageData(total: 0, page: 1, pageSize: pageSize, columns: [], videos: [])
    }
}
