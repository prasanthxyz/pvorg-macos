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

            let targets = [
                videosPath.appendingPathComponent(filename),
                videosPath.appendingPathComponent("img", isDirectory: true).appendingPathComponent("\(filename).jpg"),
            ]

            var deletedSomething = false
            for target in targets where fm.fileExists(atPath: target.path) {
                do {
                    try fm.removeItem(at: target)
                    deletedSomething = true
                } catch {
                    errors.append("Failed deleting \(target.path): \(error.localizedDescription)")
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
