import Foundation
import Observation

struct StartupReport {
    var invalidFilenamesSkipped: Int = 0
    var entriesNormalized: Int = 0
    var orphanAssetsRemoved: Int = 0
}

struct SkippedFile: Identifiable {
    let id = UUID()
    let filename: String
    let reasons: [String]
}

struct AppNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

@Observable
@MainActor
final class AppState {
    // Lifecycle
    var isReady: Bool = false
    var progressText: String = "Starting up..."
    var fatalError: String? = nil

    // Data
    var config: AppConfig? = nil
    var videos: [Video] = []
    var galleries: [Gallery] = []
    var combinations: [Combination] = []
    var combinationIndex: Int = 0

    // Selections
    var selectedGalleries: Set<String> = []
    var selectedStudios: Set<String> = []
    var selectedTags: Set<String> = []
    var selectedCast: Set<String> = []

    // Startup report
    var skippedFiles: [SkippedFile] = []
    var startupReport: StartupReport? = nil
    var staleCleanupPreview: StaleConfigCleanupPreview? = nil
    var appNotice: AppNotice? = nil

    private let pipelineGuard = PipelineGuard()

    var allStudios: [String] {
        Array(Set(videos.map(\.studio))).sorted()
    }

    var allTags: [String] {
        config?.tags.sorted() ?? []
    }

    var allCast: [String] {
        Array(Set(videos.flatMap(\.actors))).sorted()
    }

    var allGalleryNames: [String] {
        galleries.map(\.name).sorted()
    }

    var currentCombination: Combination? {
        guard !combinations.isEmpty else { return nil }
        guard combinations.indices.contains(combinationIndex) else { return nil }
        return combinations[combinationIndex]
    }

    func start() {
        Task(priority: .userInitiated) {
            await runStartupPipeline()
        }
    }

    func reload() {
        Task(priority: .userInitiated) {
            await runStartupPipeline()
        }
    }

    func showStaleConfigCleanupPreview() {
        do {
            guard let config else {
                throw NSError(domain: "AppState", code: 2, userInfo: [NSLocalizedDescriptionKey: "Config not loaded yet."])
            }
            staleCleanupPreview = try CleanupService.staleConfigEntriesPreview(config: config)
        } catch {
            appNotice = AppNotice(
                title: "Cleanup Unavailable",
                message: error.localizedDescription
            )
        }
    }

    func dismissStaleConfigCleanupPreview() {
        staleCleanupPreview = nil
    }

    func confirmStaleConfigCleanup() {
        do {
            guard var config else {
                throw NSError(domain: "AppState", code: 3, userInfo: [NSLocalizedDescriptionKey: "Config not loaded yet."])
            }
            guard let preview = staleCleanupPreview else {
                throw NSError(domain: "AppState", code: 4, userInfo: [NSLocalizedDescriptionKey: "No cleanup preview is available."])
            }

            let removed = CleanupService.removeConfigEntries(config: &config, keys: preview.staleEntries)
            try ConfigService.saveConfig(config)
            try rescanFromConfig(config, preserveSelections: true)

            staleCleanupPreview = nil
            appNotice = AppNotice(
                title: "Cleanup Complete",
                message: removed == 0
                    ? "No stale entries were found."
                    : "Removed \(removed) stale config entr\(removed == 1 ? "y" : "ies")."
            )
        } catch {
            appNotice = AppNotice(
                title: "Cleanup Failed",
                message: error.localizedDescription
            )
        }
    }

    func nextCombination() {
        guard !combinations.isEmpty else { return }
        combinationIndex = (combinationIndex + 1) % combinations.count
    }

    func previousCombination() {
        guard !combinations.isEmpty else { return }
        combinationIndex = (combinationIndex - 1 + combinations.count) % combinations.count
    }

    func regenerateCombinations() {
        combinations = CombinationEngine.generate(
            videos: videos,
            galleries: galleries,
            selectedGalleries: selectedGalleries,
            selectedStudios: selectedStudios,
            selectedTags: selectedTags,
            selectedCast: selectedCast
        )
        combinationIndex = 0
    }

    func shuffleCombinations() {
        combinations.shuffle()
        combinationIndex = 0
    }

    func tgpURL(for filename: String) -> URL? {
        guard let config else { return nil }
        return URL(fileURLWithPath: config.videosPath, isDirectory: true)
            .appendingPathComponent("img", isDirectory: true)
            .appendingPathComponent("\(filename).jpg")
    }

    func deleteVideos(_ filenames: [String]) throws -> VideoDeletionResult {
        guard let config else {
            throw NSError(domain: "AppState", code: 1, userInfo: [NSLocalizedDescriptionKey: "Config not loaded"])
        }

        let result = try VideoDeleter.delete(
            filenames: filenames,
            knownFilenames: Set(videos.map(\.filename)),
            config: config,
            configURL: ConfigService.configURL
        )

        try rescanFromConfig(result.updatedConfig, preserveSelections: false)
        return result
    }

    func galleryMappingPage(page: Int, pageSize: Int, hideDecided: Bool) -> MappingPageData {
        guard let config else { return .empty(pageSize: pageSize) }
        let columns = allGalleryNames
        guard !columns.isEmpty else { return .empty(pageSize: pageSize) }

        var rows: [MappingVideoRow] = []

        for video in videos {
            let relation = config.videoRelations[video.filename] ?? VideoRelation()
            let yes = Set(relation.yesGalleries)
            let no = Set(relation.noGalleries)

            var map: [String: TriState] = [:]
            for column in columns {
                if yes.contains(column) {
                    map[column] = .yes
                } else if no.contains(column) {
                    map[column] = .no
                } else {
                    map[column] = .undecided
                }
            }

            if hideDecided && map.values.allSatisfy({ $0 != .undecided }) {
                continue
            }

            rows.append(MappingVideoRow(
                filename: video.filename,
                title: video.title,
                studio: video.studio,
                tgpURL: tgpURL(for: video.filename),
                map: map
            ))
        }

        let total = rows.count
        let totalPages = max(1, Int(ceil(Double(total) / Double(pageSize))))
        let clampedPage = min(max(page, 1), totalPages)
        let start = (clampedPage - 1) * pageSize
        let end = min(start + pageSize, rows.count)
        let pageRows = start < end ? Array(rows[start..<end]) : []

        return MappingPageData(total: total, page: clampedPage, pageSize: pageSize, columns: columns, videos: pageRows)
    }

    func tagMappingPage(page: Int, pageSize: Int, hideDecided: Bool) -> MappingPageData {
        guard let config else { return .empty(pageSize: pageSize) }
        let columns = allTags
        guard !columns.isEmpty else { return .empty(pageSize: pageSize) }

        var rows: [MappingVideoRow] = []

        for video in videos {
            let relation = config.videoRelations[video.filename] ?? VideoRelation()
            let yes = Set(relation.yesTags)
            let no = Set(relation.noTags)

            var map: [String: TriState] = [:]
            for column in columns {
                if yes.contains(column) {
                    map[column] = .yes
                } else if no.contains(column) {
                    map[column] = .no
                } else {
                    map[column] = .undecided
                }
            }

            if hideDecided && map.values.allSatisfy({ $0 != .undecided }) {
                continue
            }

            rows.append(MappingVideoRow(
                filename: video.filename,
                title: video.title,
                studio: video.studio,
                tgpURL: tgpURL(for: video.filename),
                map: map
            ))
        }

        let total = rows.count
        let totalPages = max(1, Int(ceil(Double(total) / Double(pageSize))))
        let clampedPage = min(max(page, 1), totalPages)
        let start = (clampedPage - 1) * pageSize
        let end = min(start + pageSize, rows.count)
        let pageRows = start < end ? Array(rows[start..<end]) : []

        return MappingPageData(total: total, page: clampedPage, pageSize: pageSize, columns: columns, videos: pageRows)
    }

    func saveGalleryMappings(_ changes: [String: [String: TriState]]) throws {
        guard var config else { return }
        let knownColumns = Set(allGalleryNames)
        let orderedKnownColumns = allGalleryNames

        for (filename, fileChanges) in changes {
            var relation = config.videoRelations[filename] ?? VideoRelation(
                galleries: [],
                excludedGalleries: [],
                tags: [],
                excludedTags: []
            )

            var yes = Set(relation.galleries ?? [])
            var no = Set(relation.excludedGalleries ?? [])

            for (column, state) in fileChanges where knownColumns.contains(column) {
                switch state {
                case .yes:
                    yes.insert(column)
                    no.remove(column)
                case .no:
                    no.insert(column)
                    yes.remove(column)
                case .undecided:
                    yes.remove(column)
                    no.remove(column)
                }
            }

            let preservedUnknownYes = (relation.galleries ?? []).filter { !knownColumns.contains($0) && yes.contains($0) }
            let preservedUnknownNo = (relation.excludedGalleries ?? []).filter { !knownColumns.contains($0) && no.contains($0) }

            relation.galleries = orderedKnownColumns.filter { yes.contains($0) } + preservedUnknownYes
            relation.excludedGalleries = orderedKnownColumns.filter { no.contains($0) } + preservedUnknownNo
            relation.tags = relation.tags ?? []
            relation.excludedTags = relation.excludedTags ?? []
            config.videoRelations[filename] = relation
        }

        try ConfigService.saveConfig(config)
        try rescanFromConfig(config, preserveSelections: true)
    }

    func saveTagMappings(_ changes: [String: [String: TriState]]) throws {
        guard var config else { return }
        let knownColumns = Set(allTags)
        let orderedKnownColumns = allTags

        for (filename, fileChanges) in changes {
            var relation = config.videoRelations[filename] ?? VideoRelation(
                galleries: [],
                excludedGalleries: [],
                tags: [],
                excludedTags: []
            )

            var yes = Set(relation.tags ?? [])
            var no = Set(relation.excludedTags ?? [])

            for (column, state) in fileChanges where knownColumns.contains(column) {
                switch state {
                case .yes:
                    yes.insert(column)
                    no.remove(column)
                case .no:
                    no.insert(column)
                    yes.remove(column)
                case .undecided:
                    yes.remove(column)
                    no.remove(column)
                }
            }

            let preservedUnknownYes = (relation.tags ?? []).filter { !knownColumns.contains($0) && yes.contains($0) }
            let preservedUnknownNo = (relation.excludedTags ?? []).filter { !knownColumns.contains($0) && no.contains($0) }

            relation.tags = orderedKnownColumns.filter { yes.contains($0) } + preservedUnknownYes
            relation.excludedTags = orderedKnownColumns.filter { no.contains($0) } + preservedUnknownNo
            relation.galleries = relation.galleries ?? []
            relation.excludedGalleries = relation.excludedGalleries ?? []
            config.videoRelations[filename] = relation
        }

        try ConfigService.saveConfig(config)
        try rescanFromConfig(config, preserveSelections: true)
    }

    private func runStartupPipeline() async {
        guard await pipelineGuard.claim() else {
            Log.pipeline.info("Pipeline already running; skipping duplicate request")
            return
        }
        defer {
            Task { await pipelineGuard.release() }
        }

        do {
            fatalError = nil
            isReady = false

            progressText = "Loading configuration..."
            var config = try ConfigService.loadConfig()

            progressText = "Scanning filesystem..."
            var galleries = try FilesystemScanner.scanGalleries(config: config)
            var scan = try FilesystemScanner.scanVideos(config: config, galleryNames: galleries.map(\.name))
            var videos = scan.videos
            var skipped = scan.skipped

            progressText = "Normalizing pvorg.json..."
            let normalized = ConfigService.normalizeRelations(&config)
            if normalized > 0 {
                try ConfigService.saveConfig(config)
                galleries = try FilesystemScanner.scanGalleries(config: config)
                scan = try FilesystemScanner.scanVideos(config: config, galleryNames: galleries.map(\.name))
                videos = scan.videos
                skipped = scan.skipped
            }

            progressText = "Cleaning orphaned assets..."
            let orphaned = CleanupService.cleanupOrphanedTGPAssets(
                videosPath: config.videosPath,
                validFilenames: Set(videos.map(\.filename))
            )

            progressText = "Running preprocessing..."
            await Preprocessor.run(videos: videos, videosPath: config.videosPath) { message in
                await MainActor.run {
                    if !message.isEmpty {
                        self.progressText = message
                    }
                }
            }

            startupReport = StartupReport(
                invalidFilenamesSkipped: skipped.count,
                entriesNormalized: normalized,
                orphanAssetsRemoved: orphaned
            )

            applyLoadedData(
                config: config,
                galleries: galleries,
                videos: videos,
                skipped: skipped,
                resetSelections: true
            )

            Log.pipeline.info("""
            Startup Cleanup Summary
            -----------------------
            Invalid filenames skipped:    \(skipped.count)
            Entries normalized:           \(normalized)
            Orphan assets removed:        \(orphaned)
            """)

            progressText = ""
            isReady = true
        } catch {
            fatalError = "Startup failed: \(error.localizedDescription)"
            Log.pipeline.error("Startup pipeline failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func rescanFromConfig(_ config: AppConfig, preserveSelections: Bool) throws {
        let galleries = try FilesystemScanner.scanGalleries(config: config)
        let scan = try FilesystemScanner.scanVideos(config: config, galleryNames: galleries.map(\.name))
        applyLoadedData(
            config: config,
            galleries: galleries,
            videos: scan.videos,
            skipped: scan.skipped,
            resetSelections: !preserveSelections
        )

        if preserveSelections {
            selectedGalleries = selectedGalleries.intersection(Set(allGalleryNames))
            if selectedGalleries.isEmpty { selectedGalleries = Set(allGalleryNames) }

            selectedStudios = selectedStudios.intersection(Set(allStudios))
            if selectedStudios.isEmpty { selectedStudios = Set(allStudios) }

            selectedTags = selectedTags.intersection(Set(allTags))
            selectedCast = selectedCast.intersection(Set(allCast))
            regenerateCombinations()
        }
    }

    private func applyLoadedData(
        config: AppConfig,
        galleries: [Gallery],
        videos: [Video],
        skipped: [(String, [String])],
        resetSelections: Bool
    ) {
        self.config = config
        self.galleries = galleries
        self.videos = videos
        self.skippedFiles = skipped.map { SkippedFile(filename: $0.0, reasons: $0.1) }

        if resetSelections {
            selectedGalleries = Set(galleries.map(\.name))
            selectedStudios = Set(videos.map(\.studio))
            selectedTags = []
            selectedCast = []
        }

        regenerateCombinations()
    }
}
