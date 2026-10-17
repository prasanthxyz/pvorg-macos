import Foundation

struct PreprocessProgress: Sendable {
    let completed: Int
    let total: Int
    let filename: String
}

enum Preprocessor {
    private static let tgpCols = 4
    private static let tgpRows = 4
    private static let tgpTileWidth = 480

    static func run(
        videos: [Video],
        videosPath: String,
        progress: @escaping @Sendable (PreprocessProgress) async -> Void
    ) async {
        var tgpGenerated = 0
        var tgpExisting = 0
        var tgpFailed = 0
        var metadataExisting = 0
        var metadataExtracted = 0
        var metadataFailed = 0

        let videosDir = URL(fileURLWithPath: videosPath, isDirectory: true)
        let imgDir = videosDir.appendingPathComponent("img", isDirectory: true)
        do {
            try imgDir.createDirectoryIfNeeded()
        } catch {
            logError("Failed creating img directory: \(error.localizedDescription)")
        }

        let cacheURL = videosDir.appendingPathComponent("cache.json")
        let cache = MetadataCache(cacheURL: cacheURL)
        await cache.load()

        for (index, video) in videos.enumerated() {
            let progressMessage = "Processing \(index + 1)/\(videos.count): \(video.filename)"
            await progress(PreprocessProgress(completed: index, total: videos.count, filename: video.filename))
            Log.preprocess.info("\(progressMessage, privacy: .public)")
            print(progressMessage)

            let tgpURL = imgDir.appendingPathComponent("\(video.filename).jpg")
            if !FileManager.default.fileExists(atPath: tgpURL.path) {
                do {
                    Log.preprocess.info("Generating TGP for \(video.filename)...")
                    try await generateTGP(videoURL: video.fileURL, outputURL: tgpURL)
                    tgpGenerated += 1
                    let msg = "TGP generated: \(video.filename)"
                    Log.preprocess.info("\(msg, privacy: .public)")
                    print(msg)
                } catch {
                    tgpFailed += 1
                    logError("TGP generation failed for \(video.filename): \(error.localizedDescription)")
                }
            } else {
                tgpExisting += 1
            }

            if await cache.has(video.filename) {
                metadataExisting += 1
            } else {
                do {
                    Log.preprocess.info("Extracting metadata for \(video.filename)...")
                    let metadata = try await extractMetadata(videoURL: video.fileURL)
                    await cache.set(video.filename, value: metadata)
                    metadataExtracted += 1
                } catch {
                    metadataFailed += 1
                    logError("Metadata extraction failed for \(video.filename): \(error.localizedDescription)")
                }
            }
        }

        do {
            try await cache.save()
        } catch {
            logError("Failed saving cache: \(error.localizedDescription)")
        }

        let summary = """
        Preprocess Summary
        ------------------
        Videos scanned:            \(videos.count)
        TGP generated:             \(tgpGenerated)
        TGP already existing:      \(tgpExisting)
        TGP failed:                \(tgpFailed)
        Metadata from cache:       \(metadataExisting)
        Metadata newly extracted:  \(metadataExtracted)
        Metadata extraction failed:\(metadataFailed)
        Cache file:                \(cacheURL.path)
        """
        Log.preprocess.info("\(summary, privacy: .public)")
        print(summary)
    }

    static func generateTGP(videoURL: URL, outputURL: URL) async throws {
        let duration = try await getVideoDuration(videoURL: videoURL)
        guard duration >= 1 else {
            throw ProcessError.executionFailed("Video duration is too short (<1s): \(duration)")
        }

        let numTiles = tgpCols * tgpRows
        let interval = duration / Double(numTiles)
        let offset = interval / 2

        var args: [String] = ["-hide_banner", "-v", "error", "-nostats"]
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
        guard result.exitCode == 0 else {
            throw ProcessError.executionFailed("""
            ffmpeg failed (exit \(result.exitCode)) for \(videoURL.lastPathComponent)
            stderr: \(trim(result.stderr))
            stdout: \(trim(result.stdout))
            """)
        }
    }

    static func getVideoDuration(videoURL: URL) async throws -> Double {
        let args = [
            "-v", "error",
            "-select_streams", "v:0",
            // Matroska and WebM report no per-stream duration, so fall back to the container's.
            "-show_entries", "stream=duration:format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            videoURL.path,
        ]
        let result = try await FFmpegRunner.runProcess(executable: "ffprobe", arguments: args)
        guard result.exitCode == 0 else {
            throw ProcessError.executionFailed("""
            ffprobe duration failed (exit \(result.exitCode)) for \(videoURL.lastPathComponent)
            stderr: \(trim(result.stderr))
            stdout: \(trim(result.stdout))
            """)
        }

        let durationText = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = durationText.split(whereSeparator: \.isNewline).compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard let duration = candidates.first(where: { $0.isFinite && $0 > 0 }) else {
            throw ProcessError.executionFailed("ffprobe duration parse failed for \(videoURL.lastPathComponent). Raw: \(durationText)")
        }
        return duration
    }

    static func extractMetadata(videoURL: URL) async throws -> MetadataCacheEntry {
        let args = [
            "-v", "error",
            "-select_streams", "v:0",
            "-show_entries", "stream=duration,width,height,r_frame_rate",
            "-show_entries", "format=size,duration",
            "-of", "json",
            videoURL.path,
        ]

        let result = try await FFmpegRunner.runProcess(executable: "ffprobe", arguments: args)
        guard result.exitCode == 0 else {
            throw ProcessError.executionFailed("""
            ffprobe metadata failed (exit \(result.exitCode)) for \(videoURL.lastPathComponent)
            stderr: \(trim(result.stderr))
            stdout: \(trim(result.stdout))
            """)
        }

        let data = Data(result.stdout.utf8)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let streams = json["streams"] as? [[String: Any]] ?? []
        let firstStream = streams.first ?? [:]
        let format = json["format"] as? [String: Any] ?? [:]

        let duration = (firstStream["duration"] as? String).flatMap(Double.init)
            ?? (firstStream["duration"] as? Double)
            ?? (format["duration"] as? String).flatMap(Double.init)
            ?? 0
        let width = firstStream["width"] as? Int ?? 0
        let height = firstStream["height"] as? Int ?? 0
        let fpsRaw = firstStream["r_frame_rate"] as? String ?? "0/1"
        let fps = FFmpegRunner.parseFPS(fpsRaw)
        let fileSizeString = format["size"] as? String ?? "0"
        let fileSize = Int(fileSizeString) ?? 0

        return MetadataCacheEntry(duration: duration, width: width, height: height, fps: fps, fileSize: fileSize)
    }

    private static func logError(_ message: String) {
        Log.preprocess.error("\(message, privacy: .public)")
        print("ERROR [preprocess] \(message)")
    }

    private static func trim(_ text: String, maxLength: Int = 800) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.count <= maxLength {
            return normalized
        }
        let idx = normalized.index(normalized.startIndex, offsetBy: maxLength)
        return String(normalized[..<idx]) + "..."
    }
}
