import Foundation

enum CleanupService {
    static func staleConfigEntriesPreview(config: AppConfig) throws -> StaleConfigCleanupPreview {
        let videosDir = URL(fileURLWithPath: config.videosPath, isDirectory: true)
        let fm = FileManager.default
        var isDirectory: ObjCBool = false

        guard fm.fileExists(atPath: videosDir.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw NSError(
                domain: "CleanupService",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "Videos directory is missing: \(config.videosPath)"]
            )
        }

        guard fm.isReadableFile(atPath: videosDir.path) else {
            throw NSError(
                domain: "CleanupService",
                code: 11,
                userInfo: [NSLocalizedDescriptionKey: "Videos directory is not readable: \(config.videosPath)"]
            )
        }

        let files = try fm.contentsOfDirectory(
            at: videosDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        let videoFileCount = files.filter { url in
            FilesystemScanner.videoExtensions.contains(url.pathExtension.lowercased()) && !url.lastPathComponent.hasPrefix(".")
        }.count

        let staleEntries = config.videoRelations.keys
            .filter { filename in
                !fm.fileExists(atPath: videosDir.appendingPathComponent(filename).path)
            }
            .sorted()

        return StaleConfigCleanupPreview(
            videosPath: config.videosPath,
            videoFileCount: videoFileCount,
            totalRelationCount: config.videoRelations.count,
            staleEntries: staleEntries
        )
    }

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

    static func removeConfigEntries(config: inout AppConfig, keys: [String]) -> Int {
        var removed = 0

        for key in keys {
            if config.videoRelations.removeValue(forKey: key) != nil {
                removed += 1
            }
            Log.io.info("Removed stale config entry: \(key, privacy: .public)")
        }

        return removed
    }
}
