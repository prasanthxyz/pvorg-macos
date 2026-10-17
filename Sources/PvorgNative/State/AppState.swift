import Foundation
import Observation

struct StartupReport {
    var invalidFilenamesSkipped: Int = 0
    var entriesNormalized: Int = 0
    var orphanAssetsRemoved: Int = 0
}

/// What the loading screen shows while the startup pipeline runs.
struct StartupProgress: Equatable {
    var title: String
    var detail: String? = nil
    /// `nil` while the current step has no measurable progress.
    var fraction: Double? = nil
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

/// A video–gallery pairing excluded from the viewer, with what's needed to undo it.
struct PairingExclusion {
    let filename: String
    let galleryName: String
    /// The gallery decision before the exclusion (yes or undecided).
    let previousState: TriState
    /// Whether the video had a pvorg.json entry before; undo removes one it created.
    let hadRelation: Bool
    /// Where the pairing sat in `combinations`, if it was there.
    let index: Int?
}

@Observable
@MainActor
final class AppState {
    // Lifecycle
    var isReady: Bool = false
    var startupProgress = StartupProgress(title: "Starting Up")
    var fatalError: String? = nil

    // Data
    var config: AppConfig? = nil
    var videos: [Video] = [] {
        didSet { sortedVideos = VideoDisplaySort.sorted(videos) }
    }
    var galleries: [Gallery] = []
    var combinations: [Combination] = []
    var combinationIndex: Int = 0

    /// `videos` in display order, computed once per change instead of per render.
    private(set) var sortedVideos: [Video] = []
    /// Bumped whenever the library is (re)loaded from disk or config, so
    /// screens holding derived data know to refresh it.
    private(set) var libraryRevision = 0

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

    /// True when every gallery and studio is included and no tag or cast is required.
    var filtersAreDefault: Bool {
        selectedGalleries == Set(allGalleryNames)
            && selectedStudios == Set(allStudios)
            && selectedTags.isEmpty
            && selectedCast.isEmpty
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

    /// Removes the previewed stale entries and returns how many were removed.
    func confirmStaleConfigCleanup() throws -> Int {
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
        return removed
    }

    func nextCombination() {
        guard !combinations.isEmpty else { return }
        combinationIndex = (combinationIndex + 1) % combinations.count
    }

    func previousCombination() {
        guard !combinations.isEmpty else { return }
        combinationIndex = (combinationIndex - 1 + combinations.count) % combinations.count
    }

    func showCombination(at index: Int) {
        guard combinations.indices.contains(index) else { return }
        combinationIndex = index
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

    /// Restores the startup selection: everything included, nothing required.
    func resetFilters() {
        selectedGalleries = Set(allGalleryNames)
        selectedStudios = Set(allStudios)
        selectedTags = []
        selectedCast = []
        regenerateCombinations()
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

    // MARK: - Mapping

    func mappingColumns(_ kind: MappingKind) -> [String] {
        switch kind {
        case .galleries: allGalleryNames
        case .tags: allTags
        }
    }

    /// Every video with its saved decision per column, in display order.
    /// `hideDecided` drops videos with a yes/no for every column; `query`
    /// matches title, studio, cast and filename.
    func mappingRows(_ kind: MappingKind, hideDecided: Bool, query: String = "") -> [MappingVideoRow] {
        guard let config else { return [] }
        let columns = mappingColumns(kind)
        guard !columns.isEmpty else { return [] }
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)

        var rows: [MappingVideoRow] = []

        for video in sortedVideos {
            if !query.isEmpty && !video.matches(query) {
                continue
            }

            let relation = config.videoRelations[video.filename] ?? VideoRelation()
            let yes = Set(relation[keyPath: kind.yesKeyPath] ?? [])
            let no = Set(relation[keyPath: kind.noKeyPath] ?? [])

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
                actors: video.actors,
                tgpURL: tgpURL(for: video.filename),
                map: map
            ))
        }

        return rows
    }

    func saveMappings(_ kind: MappingKind, changes: [String: [String: TriState]]) throws {
        guard var config else { return }
        applyMappingChanges(kind, changes, to: &config)
        try ConfigService.saveConfig(config)
        try rescanFromConfig(config, preserveSelections: true)
    }

    /// Writes "No" for the video's gallery to pvorg.json, exactly as Gallery
    /// Mapping would, then drops the pairing from `combinations` without
    /// reshuffling: the viewer moves on to the next combination in place.
    func excludePairing(filename: String, galleryName: String) throws -> PairingExclusion {
        guard var config else {
            throw NSError(domain: "AppState", code: 5, userInfo: [NSLocalizedDescriptionKey: "Config not loaded yet."])
        }
        let relation = config.videoRelations[filename]
        let previousState: TriState = relation?.yesGalleries.contains(galleryName) == true ? .yes
            : relation?.noGalleries.contains(galleryName) == true ? .no
            : .undecided

        applyMappingChanges(.galleries, [filename: [galleryName: .no]], to: &config)
        try ConfigService.saveConfig(config)
        self.config = config
        refreshRelatedGalleries(for: filename)

        let index = combinations.firstIndex { $0.video.filename == filename && $0.gallery.name == galleryName }
        if let index {
            combinations.remove(at: index)
            if index < combinationIndex {
                combinationIndex -= 1
            }
            if combinationIndex >= combinations.count {
                combinationIndex = 0
            }
        }
        libraryRevision += 1
        return PairingExclusion(filename: filename, galleryName: galleryName, previousState: previousState, hadRelation: relation != nil, index: index)
    }

    /// Undoes `excludePairing`: restores the previous decision and, if the
    /// pairing passes the current filters, puts it back where it was and shows it.
    func restorePairing(_ exclusion: PairingExclusion) throws {
        guard var config else {
            throw NSError(domain: "AppState", code: 6, userInfo: [NSLocalizedDescriptionKey: "Config not loaded yet."])
        }
        applyMappingChanges(.galleries, [exclusion.filename: [exclusion.galleryName: exclusion.previousState]], to: &config)
        // Leave pvorg.json exactly as it was if the exclusion created the entry
        // and nothing else has been decided for the video since.
        if !exclusion.hadRelation, let relation = config.videoRelations[exclusion.filename],
           [relation.galleries, relation.excludedGalleries, relation.tags, relation.excludedTags].allSatisfy({ $0?.isEmpty ?? true }) {
            config.videoRelations.removeValue(forKey: exclusion.filename)
        }
        try ConfigService.saveConfig(config)
        self.config = config
        refreshRelatedGalleries(for: exclusion.filename)

        if let video = videos.first(where: { $0.filename == exclusion.filename }),
           let gallery = galleries.first(where: { $0.name == exclusion.galleryName }),
           !combinations.contains(where: { $0.video.filename == video.filename && $0.gallery.name == gallery.name }),
           CombinationEngine.includes(video, selectedStudios: selectedStudios, selectedTags: selectedTags, selectedCast: selectedCast),
           CombinationEngine.includes(gallery, for: video, selectedGalleries: selectedGalleries) {
            let index = min(exclusion.index ?? combinationIndex, combinations.count)
            combinations.insert(Combination(video: video, gallery: gallery), at: index)
            combinationIndex = index
        }
        libraryRevision += 1
    }

    /// Recomputes a video's galleries from config the same way the scanner does.
    private func refreshRelatedGalleries(for filename: String) {
        guard let index = videos.firstIndex(where: { $0.filename == filename }) else { return }
        let excluded = Set(config?.videoRelations[filename]?.noGalleries ?? [])
        videos[index].relatedGalleries = galleries.map(\.name).filter { !excluded.contains($0) }
    }

    private func applyMappingChanges(_ kind: MappingKind, _ changes: [String: [String: TriState]], to config: inout AppConfig) {
        let orderedKnownColumns = mappingColumns(kind)
        let knownColumns = Set(orderedKnownColumns)

        for (filename, fileChanges) in changes {
            var relation = config.videoRelations[filename] ?? VideoRelation(
                galleries: [],
                excludedGalleries: [],
                tags: [],
                excludedTags: []
            )

            let originalYes = relation[keyPath: kind.yesKeyPath] ?? []
            let originalNo = relation[keyPath: kind.noKeyPath] ?? []
            var yes = Set(originalYes)
            var no = Set(originalNo)

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

            let preservedUnknownYes = originalYes.filter { !knownColumns.contains($0) && yes.contains($0) }
            let preservedUnknownNo = originalNo.filter { !knownColumns.contains($0) && no.contains($0) }

            relation[keyPath: kind.yesKeyPath] = orderedKnownColumns.filter { yes.contains($0) } + preservedUnknownYes
            relation[keyPath: kind.noKeyPath] = orderedKnownColumns.filter { no.contains($0) } + preservedUnknownNo
            for keyPath in kind.preservedKeyPaths {
                relation[keyPath: keyPath] = relation[keyPath: keyPath] ?? []
            }
            config.videoRelations[filename] = relation
        }
    }

    // MARK: - Loading

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

            startupProgress = StartupProgress(title: "Loading Configuration", detail: ConfigService.configURL.path)
            var config = try ConfigService.loadConfig()

            startupProgress = StartupProgress(title: "Scanning Library", detail: config.videosPath)
            var galleries = try FilesystemScanner.scanGalleries(config: config)
            var scan = try FilesystemScanner.scanVideos(config: config, galleryNames: galleries.map(\.name))
            var videos = scan.videos
            var skipped = scan.skipped

            startupProgress = StartupProgress(title: "Updating pvorg.json")
            let normalized = ConfigService.normalizeRelations(&config)
            if normalized > 0 {
                try ConfigService.saveConfig(config)
                galleries = try FilesystemScanner.scanGalleries(config: config)
                scan = try FilesystemScanner.scanVideos(config: config, galleryNames: galleries.map(\.name))
                videos = scan.videos
                skipped = scan.skipped
            }

            startupProgress = StartupProgress(title: "Cleaning Up Previews")
            let orphaned = CleanupService.cleanupOrphanedTGPAssets(
                videosPath: config.videosPath,
                validFilenames: Set(videos.map(\.filename))
            )

            startupProgress = StartupProgress(title: "Preparing Previews", fraction: 0)
            await Preprocessor.run(videos: videos, videosPath: config.videosPath) { progress in
                await MainActor.run {
                    self.startupProgress = StartupProgress(
                        title: "Preparing Previews",
                        detail: "\(progress.completed + 1) of \(progress.total) · \(progress.filename)",
                        fraction: Double(progress.completed) / Double(max(progress.total, 1))
                    )
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

            isReady = true
        } catch {
            fatalError = error.localizedDescription
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
        libraryRevision += 1
    }
}

extension Video {
    /// Case- and diacritic-insensitive match against everything the UI shows for a video.
    func matches(_ query: String) -> Bool {
        let fields = [DisplayName.title(for: self), filename, DisplayName.humanize(studio)] + actors.map(DisplayName.humanize)
        return fields.contains { $0.localizedStandardContains(query) }
    }
}
