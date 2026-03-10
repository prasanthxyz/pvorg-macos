import Foundation

enum CleanupService {
    static func cleanupOrphanedTGPAssets(videosPath: String, validFilenames: Set<String>) -> Int {
        let imgURL = URL(fileURLWithPath: videosPath, isDirectory: true).appendingPathComponent("img", isDirectory: true)
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: imgURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return 0
        }

        var removed = 0
        for file in files where file.pathExtension.lowercased() == "jpg" {
            let videoFilename = file.deletingPathExtension().lastPathComponent
            if !validFilenames.contains(videoFilename) {
                do {
                    try fm.removeItem(at: file)
                    removed += 1
                    Log.io.info("Removed orphan TGP asset: \(file.path, privacy: .public)")
                } catch {
                    Log.io.error("Failed removing orphan asset: \(file.path, privacy: .public) - \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        return removed
    }

    static func cleanupStaleConfigEntries(config: inout AppConfig) -> Int {
        let videosDir = URL(fileURLWithPath: config.videosPath, isDirectory: true)
        let fm = FileManager.default

        let stale = config.videoRelations.keys.filter { filename in
            !fm.fileExists(atPath: videosDir.appendingPathComponent(filename).path)
        }

        for key in stale {
            config.videoRelations.removeValue(forKey: key)
            Log.io.info("Removed stale config entry: \(key, privacy: .public)")
        }

        return stale.count
    }
}
