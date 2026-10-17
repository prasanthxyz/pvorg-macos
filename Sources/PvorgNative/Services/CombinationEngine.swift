import Foundation

enum CombinationEngine {
    static func generate(
        videos: [Video],
        galleries: [Gallery],
        selectedGalleries: Set<String>,
        selectedStudios: Set<String>,
        selectedTags: Set<String>,
        selectedCast: Set<String>
    ) -> [Combination] {
        var results: [Combination] = []

        for video in videos where includes(video, selectedStudios: selectedStudios, selectedTags: selectedTags, selectedCast: selectedCast) {
            for gallery in galleries where includes(gallery, for: video, selectedGalleries: selectedGalleries) {
                results.append(Combination(video: video, gallery: gallery))
            }
        }

        return results.shuffled()
    }

    /// Whether the video passes the studio, tag and cast filters.
    static func includes(_ video: Video, selectedStudios: Set<String>, selectedTags: Set<String>, selectedCast: Set<String>) -> Bool {
        if !selectedStudios.contains(video.studio) { return false }
        if !selectedCast.isEmpty && !selectedCast.isSubset(of: Set(video.actors)) { return false }
        if !selectedTags.isEmpty && !selectedTags.isSubset(of: Set(video.tags)) { return false }
        return true
    }

    /// Whether the gallery is included and the video isn't excluded from it.
    static func includes(_ gallery: Gallery, for video: Video, selectedGalleries: Set<String>) -> Bool {
        selectedGalleries.contains(gallery.name) && video.relatedGalleries.contains(gallery.name)
    }
}
