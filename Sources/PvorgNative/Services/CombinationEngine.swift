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

        for video in videos {
            if !selectedStudios.contains(video.studio) { continue }
            if !selectedCast.isEmpty && !selectedCast.isSubset(of: Set(video.actors)) { continue }
            if !selectedTags.isEmpty && !selectedTags.isSubset(of: Set(video.tags)) { continue }

            for gallery in galleries {
                if selectedGalleries.contains(gallery.name) && video.relatedGalleries.contains(gallery.name) {
                    results.append(Combination(video: video, gallery: gallery))
                }
            }
        }

        return results.shuffled()
    }
}
