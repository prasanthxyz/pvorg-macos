import Foundation

struct VideoDeletionResult {
    let deletedCount: Int
    let errors: [String]
    let updatedConfig: AppConfig
}

enum VideoDeleter {
    static func delete(
        filenames: [String],
        knownFilenames: Set<String>,
        config: AppConfig,
        configURL: URL
    ) throws -> VideoDeletionResult {
        var config = config
        let fm = FileManager.default
        let videosPath = URL(fileURLWithPath: config.videosPath, isDirectory: true)
        let uniqueNames = Array(Set(filenames)).sorted()

        var deletedCount = 0
        var errors: [String] = []

        let cacheURL = videosPath.appendingPathComponent("cache.json")
        var cache: [String: MetadataCacheEntry] = [:]
        if let data = try? Data(contentsOf: cacheURL),
           let decoded = try? JSONDecoder().decode([String: MetadataCacheEntry].self, from: data) {
            cache = decoded
        }

        var cacheChanged = false

        for filename in uniqueNames {
            guard knownFilenames.contains(filename) else {
                errors.append("Rejected unknown filename: \(filename)")
                continue
            }

            let videoURL = videosPath.appendingPathComponent(filename)
            let contactSheetURL = videosPath.appendingPathComponent("img", isDirectory: true).appendingPathComponent("\(filename).jpg")

            var deletedSomething = false
            if fm.fileExists(atPath: videoURL.path) {
                do {
                    try fm.removeItem(at: videoURL)
                    deletedSomething = true
                } catch {
                    // The file is still there, so keep its decisions and metadata.
                    errors.append("Failed deleting \(videoURL.path): \(error.localizedDescription)")
                    continue
                }
            }
            // A missing contact sheet is fine; one that can't be removed is reported
            // and cleaned up as an orphan at the next startup.
            if fm.fileExists(atPath: contactSheetURL.path) {
                do {
                    try fm.removeItem(at: contactSheetURL)
                } catch {
                    errors.append("Failed deleting \(contactSheetURL.path): \(error.localizedDescription)")
                }
            }

            if config.videoRelations.removeValue(forKey: filename) != nil {
                deletedSomething = true
            }

            if cache.removeValue(forKey: filename) != nil {
                cacheChanged = true
                deletedSomething = true
            }

            if deletedSomething {
                deletedCount += 1
            }
        }

        try ConfigService.saveConfig(config, to: configURL)

        if cacheChanged {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(cache)
            try data.write(to: cacheURL, options: .atomic)
        }

        return VideoDeletionResult(deletedCount: deletedCount, errors: errors, updatedConfig: config)
    }
}
