import Foundation
import XCTest
@testable import PvorgNative

@MainActor
final class MappingSessionTests: XCTestCase {
    func testCyclingBackToSavedStateClearsThePendingChange() {
        let (appState, _) = makeAppState()
        let session = MappingSession(kind: .galleries)
        session.refresh(from: appState)
        let row = try! XCTUnwrap(session.rows.first)

        session.cycle(row, column: "Gallery A") // undecided → yes
        XCTAssertEqual(session.state(for: row, column: "Gallery A"), .yes)
        XCTAssertTrue(session.isModified(row, column: "Gallery A"))
        XCTAssertEqual(session.changeCount, 1)

        session.cycle(row, column: "Gallery A") // yes → no
        session.cycle(row, column: "Gallery A") // no → undecided (saved state)
        XCTAssertFalse(session.hasChanges)
    }

    func testChangingScopeOrSearchKeepsPendingChanges() {
        let (appState, _) = makeAppState()
        let session = MappingSession(kind: .galleries)
        session.refresh(from: appState)
        let row = try! XCTUnwrap(session.rows.first)
        session.cycle(row, column: "Gallery A")

        session.showsDecidedVideos = true
        session.refresh(from: appState)
        session.query = "nothing matches this"
        session.refresh(from: appState)

        XCTAssertTrue(session.rows.isEmpty)
        XCTAssertEqual(session.changeCount, 1)
    }

    func testRefreshDropsChangesForVideosThatNoLongerExist() {
        let (appState, _) = makeAppState()
        let session = MappingSession(kind: .galleries)
        session.refresh(from: appState)
        for row in session.rows {
            session.cycle(row, column: "Gallery A")
        }
        XCTAssertEqual(session.changeCount, 2)

        appState.videos.removeFirst()
        session.refresh(from: appState)

        XCTAssertEqual(session.changeCount, 1)
    }

    func testColumnBulkSetAppliesToShownRowsOnly() {
        let (appState, _) = makeAppState()
        let session = MappingSession(kind: .galleries)
        session.query = "harbor"
        session.refresh(from: appState)

        session.set(.no, column: "Gallery B")

        XCTAssertEqual(session.pendingChanges.keys.sorted(), ["acme-jane-harbor_lights.mp4"])
        XCTAssertEqual(session.pendingChanges["acme-jane-harbor_lights.mp4"], ["Gallery B": .no])
    }

    func testSavePreservesTheOtherRelationAndUnknownValues() throws {
        let (appState, configURL) = makeAppState()
        appState.config?.videoRelations["acme-jane-harbor_lights.mp4"] = VideoRelation(
            galleries: ["Retired Gallery"],
            excludedGalleries: [],
            tags: ["tag-a"],
            excludedTags: nil
        )
        let session = MappingSession(kind: .galleries)
        session.refresh(from: appState)
        let row = try XCTUnwrap(session.rows.first { $0.filename == "acme-jane-harbor_lights.mp4" })
        session.set(.yes, for: row, column: "Gallery B")

        let saved = try withConfig(at: configURL) { try session.save(to: appState) }

        XCTAssertEqual(saved, 1)
        XCTAssertFalse(session.hasChanges)
        let relation = try XCTUnwrap(appState.config?.videoRelations["acme-jane-harbor_lights.mp4"])
        XCTAssertEqual(relation.galleries, ["Gallery B", "Retired Gallery"])
        XCTAssertEqual(relation.tags, ["tag-a"])
        XCTAssertEqual(relation.excludedTags, [])
    }

    func testHideDecidedFiltersFullyDecidedVideos() {
        let (appState, _) = makeAppState()
        appState.config?.videoRelations["acme-jane-harbor_lights.mp4"] = VideoRelation(
            galleries: ["Gallery A"],
            excludedGalleries: ["Gallery B"],
            tags: [],
            excludedTags: []
        )

        XCTAssertEqual(appState.mappingRows(.galleries, hideDecided: true).map(\.filename), ["globex-sam-desert_road.mp4"])
        XCTAssertEqual(appState.mappingRows(.galleries, hideDecided: false).count, 2)
    }

    // MARK: Fixture

    private func makeAppState() -> (AppState, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }

        let appState = AppState()
        appState.config = AppConfig(
            videosPath: root.appendingPathComponent("videos").path,
            galleriesPath: root.appendingPathComponent("galleries").path,
            tags: ["tag-a"],
            videoRelations: [:]
        )
        appState.galleries = [Gallery(name: "Gallery A", imageFiles: []), Gallery(name: "Gallery B", imageFiles: [])]
        appState.videos = [
            video("acme-jane-harbor_lights.mp4", studio: "acme", actors: ["jane"], title: "harbor_lights"),
            video("globex-sam-desert_road.mp4", studio: "globex", actors: ["sam"], title: "desert_road"),
        ]
        return (appState, root.appendingPathComponent("pvorg.json"))
    }

    private func video(_ filename: String, studio: String, actors: [String], title: String) -> Video {
        Video(filename: filename, studio: studio, actors: actors, title: title, fileURL: URL(fileURLWithPath: "/tmp/\(filename)"), relatedGalleries: [], tags: [])
    }

    /// Points `ConfigService.configURL` at a temporary file for the duration of `body`.
    private func withConfig<T>(at url: URL, _ body: () throws -> T) rethrows -> T {
        let previous = ProcessInfo.processInfo.environment["PVORG_CONFIG"]
        setenv("PVORG_CONFIG", url.path, 1)
        defer {
            if let previous { setenv("PVORG_CONFIG", previous, 1) } else { unsetenv("PVORG_CONFIG") }
        }
        return try body()
    }
}
