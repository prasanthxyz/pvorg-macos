import Foundation

struct MetadataCacheEntry: Codable {
    let duration: Double
    let width: Int
    let height: Int
    let fps: Double
    let fileSize: Int

    enum CodingKeys: String, CodingKey {
        case duration
        case width
        case height
        case fps
        case fileSize = "file_size"
    }
}
