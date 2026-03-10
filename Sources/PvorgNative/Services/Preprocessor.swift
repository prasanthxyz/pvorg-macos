import Foundation

enum Preprocessor {
    private static let tgpCols = 4
    private static let tgpRows = 4
    private static let tgpTileWidth = 480

    static func run(
        videos: [Video],
        videosPath: String,
        progress: @escaping @Sendable (String) async -> Void
    ) async {
        let videosDir = URL(fileURLWithPath: videosPath, isDirectory: true)
        let imgDir = videosDir.appendingPathComponent("img", isDirectory: true)
        do {
            try imgDir.createDirectoryIfNeeded()
        } catch {
            Log.preprocess.error("Failed creating img directory: \(error.localizedDescription, privacy: .public)")
        }

        let cacheURL = videosDir.appendingPathComponent("cache.json")
        let cache = MetadataCache(cacheURL: cacheURL)
        await cache.load()

        for (index, video) in videos.enumerated() {
            await progress("Processing \(index + 1)/\(videos.count): \(video.filename)")

            let tgpURL = imgDir.appendingPathComponent("\(video.filename).jpg")
            if !FileManager.default.fileExists(atPath: tgpURL.path) {
                do {
                    _ = try await generateTGP(videoURL: video.fileURL, outputURL: tgpURL)
                } catch {
                    Log.preprocess.error("TGP generation failed for \(video.filename, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }

            if !(await cache.has(video.filename)) {
                if let metadata = try? await extractMetadata(videoURL: video.fileURL) {
                    await cache.set(video.filename, value: metadata)
                }
            }
        }

        do {
            try await cache.save()
        } catch {
            Log.preprocess.error("Failed saving cache: \(error.localizedDescription, privacy: .public)")
        }

        await progress("")
    }

    static func generateTGP(videoURL: URL, outputURL: URL) async throws -> Bool {
        guard let duration = try await getVideoDuration(videoURL: videoURL), duration >= 1 else {
            return false
        }

        let numTiles = tgpCols * tgpRows
        let interval = duration / Double(numTiles)
        let offset = interval / 2

        var args: [String] = []
        var streamLabels: [String] = []
        var layoutParts: [String] = []

        for i in 0..<numTiles {
            let timestamp = offset + (Double(i) * interval)
            args.append(contentsOf: ["-ss", String(format: "%.2f", timestamp), "-i", videoURL.path])
            streamLabels.append("[\(i):v]")

            let col = i % tgpCols
            let row = i / tgpCols
            let x = col == 0 ? "0" : Array(repeating: "w0", count: col).joined(separator: "+")
            let y = row == 0 ? "0" : Array(repeating: "h0", count: row).joined(separator: "+")
            layoutParts.append("\(x)_\(y)")
        }

        let filter = "\(streamLabels.joined())xstack=inputs=\(numTiles):layout=\(layoutParts.joined(separator: "|"))[v];[v]scale=\(tgpCols * tgpTileWidth):-1[scaled]"

        args.append(contentsOf: [
            "-frames:v", "1",
            "-y",
            "-filter_complex", filter,
            "-map", "[scaled]",
            outputURL.path,
        ])

        let result = try await FFmpegRunner.runProcess(executable: "ffmpeg", arguments: args)
        return result.exitCode == 0
    }

    static func getVideoDuration(videoURL: URL) async throws -> Double? {
        let args = [
            "-v", "error",
            "-select_streams", "v:0",
            "-show_entries", "stream=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            videoURL.path,
        ]
        let result = try await FFmpegRunner.runProcess(executable: "ffprobe", arguments: args)
        guard result.exitCode == 0 else { return nil }
        return Double(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func extractMetadata(videoURL: URL) async throws -> MetadataCacheEntry {
        let args = [
            "-v", "error",
            "-select_streams", "v:0",
            "-show_entries", "stream=duration,width,height,r_frame_rate",
            "-show_entries", "format=size",
            "-of", "json",
            videoURL.path,
        ]

        let result = try await FFmpegRunner.runProcess(executable: "ffprobe", arguments: args)
        guard result.exitCode == 0 else {
            throw ProcessError.executionFailed("ffprobe failed: \(result.stderr)")
        }

        let data = Data(result.stdout.utf8)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let streams = json["streams"] as? [[String: Any]] ?? []
        let firstStream = streams.first ?? [:]
        let format = json["format"] as? [String: Any] ?? [:]

        let duration = (firstStream["duration"] as? String).flatMap(Double.init) ?? (firstStream["duration"] as? Double) ?? 0
        let width = firstStream["width"] as? Int ?? 0
        let height = firstStream["height"] as? Int ?? 0
        let fpsRaw = firstStream["r_frame_rate"] as? String ?? "0/1"
        let fps = FFmpegRunner.parseFPS(fpsRaw)
        let fileSizeString = format["size"] as? String ?? "0"
        let fileSize = Int(fileSizeString) ?? 0

        return MetadataCacheEntry(duration: duration, width: width, height: height, fps: fps, fileSize: fileSize)
    }
}
