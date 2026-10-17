import Foundation

enum FilesystemScanner {
    static let videoExtensions: Set<String> = ["mp4", "mkv", "avi", "mov", "wmv", "webm"]
    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "bmp", "gif"]

    static func scanGalleries(config: AppConfig) throws -> [Gallery] {
        let baseURL = URL(fileURLWithPath: config.galleriesPath, isDirectory: true)
        let fm = FileManager.default

        guard fm.fileExists(atPath: baseURL.path) else {
            return []
        }

        let entries = try fm.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var galleries: [Gallery] = []

        for dir in entries {
            let resourceValues = try dir.resourceValues(forKeys: [.isDirectoryKey])
            guard resourceValues.isDirectory == true else { continue }

            let images = try fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
                .filter { url in
                    imageExtensions.contains(url.pathExtension.lowercased()) && !url.lastPathComponent.hasPrefix(".")
                }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            galleries.append(Gallery(name: dir.lastPathComponent, imageFiles: images))
        }

        return galleries.sorted { $0.name < $1.name }
    }

    static func scanVideos(config: AppConfig, galleryNames: [String]) throws -> (videos: [Video], skipped: [(String, [String])]) {
        let videosURL = URL(fileURLWithPath: config.videosPath, isDirectory: true)
        let fm = FileManager.default

        guard fm.fileExists(atPath: videosURL.path) else {
            return ([], [])
        }

        let entries = try fm.contentsOfDirectory(
            at: videosURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
            .filter { url in
                videoExtensions.contains(url.pathExtension.lowercased()) && !url.lastPathComponent.hasPrefix(".")
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var videos: [Video] = []
        var skipped: [(String, [String])] = []

        for fileURL in entries {
            let filename = fileURL.lastPathComponent
            let validation = FilenameValidator.validate(filename)
            guard validation.isValid else {
                skipped.append((filename, validation.reasons))
                Log.io.warning("Invalid filename skipped: \(filename, privacy: .public) Reason: \(validation.reasons.joined(separator: ", "), privacy: .public)")
                continue
            }

            let parsed = FilenameValidator.parse(filename)
            let relation = config.videoRelations[filename]

            // Galleries are opt-out: a video pairs with every gallery it isn't excluded from.
            let excludedGalleries = Set(relation?.noGalleries ?? [])
            let relatedGalleries = galleryNames.filter { !excludedGalleries.contains($0) }

            // Tags are opt-in: a video has a tag only when it's explicitly marked "yes",
            // so a required tag matches only videos tagged with it.
            let tags = relation?.yesTags ?? []

            videos.append(Video(
                filename: filename,
                studio: parsed.studio,
                actors: parsed.actors,
                title: parsed.title,
                fileURL: fileURL,
                relatedGalleries: relatedGalleries,
                tags: tags
            ))
        }

        return (videos, skipped)
    }
}
