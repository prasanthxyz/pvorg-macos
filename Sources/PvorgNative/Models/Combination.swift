import Foundation

struct Combination: Identifiable {
    let id: String
    let video: Video
    let gallery: Gallery

    init(video: Video, gallery: Gallery) {
        self.id = "\(video.filename)_\(gallery.name)"
        self.video = video
        self.gallery = gallery
    }
}
