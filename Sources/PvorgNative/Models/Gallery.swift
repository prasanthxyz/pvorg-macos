import Foundation

struct Gallery: Identifiable, Hashable {
    let id: String
    let name: String
    let imageFiles: [URL]

    init(name: String, imageFiles: [URL]) {
        self.id = name
        self.name = name
        self.imageFiles = imageFiles
    }
}
