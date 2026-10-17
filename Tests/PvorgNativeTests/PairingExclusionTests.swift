import Foundation
import XCTest
@testable import PvorgNative

@MainActor
final class PairingExclusionTests: XCTestCase {
    private var configURL: URL!

    override func setUp() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        configURL = root.appendingPathComponent("pvorg.json")
        setenv("PVORG_CONFIG", configURL.path, 1)
    }

    override func tearDown() async throws {
        unsetenv("PVORG_CONFIG")
        try? FileManager.default.removeItem(at: configURL.deletingLastPathComponent())
    }

    func testExcludingWritesNoAndShowsTheNextCombinationInPlace() throws {
        let appState = makeAppState()
        appState.showCombination(at: 1)
        let excluded = try XCTUnwrap(appState.currentCombination)
        let next = appState.combinations[2]
        let order = appState.combinations.map(\.id)

        let exclusion = try appState.excludePairing(filename: excluded.video.filename, galleryName: excluded.gallery.name)

        XCTAssertEqual(exclusion.previousState, .undecided)
        XCTAssertEqual(exclusion.index, 1)
        XCTAssertEqual(appState.combinations.map(\.id), order.filter { $0 != excluded.id }, "Order is kept, not reshuffled")
        XCTAssertEqual(appState.currentCombination?.id, next.id)
        let relation = try XCTUnwrap(appState.config?.videoRelations[excluded.video.filename])
        XCTAssertEqual(relation.excludedGalleries, [excluded.gallery.name])
        XCTAssertEqual(relation.galleries, [])
        XCTAssertEqual(relation.tags, [])
        XCTAssertEqual(relation.excludedTags, [])
        XCTAssertFalse(appState.videos.first { $0.filename == excluded.video.filename }!.relatedGalleries.contains(excluded.gallery.name))

        let saved = try ConfigService.loadConfig(from: configURL)
        XCTAssertEqual(saved.videoRelations[excluded.video.filename]?.excludedGalleries, [excluded.gallery.name])
    }

    func testRestorePutsThePairingBackWhereItWas() throws {
        let appState = makeAppState()
        appState.showCombination(at: 2)
        let excluded = try XCTUnwrap(appState.currentCombination)
        let order = appState.combinations.map(\.id)

        let exclusion = try appState.excludePairing(filename: excluded.video.filename, galleryName: excluded.gallery.name)
        try appState.restorePairing(exclusion)

        XCTAssertEqual(appState.combinations.map(\.id), order)
        XCTAssertEqual(appState.currentCombination?.id, excluded.id)
        XCTAssertNil(appState.config?.videoRelations[excluded.video.filename], "The entry the exclusion created is removed again")
        XCTAssertNil(try ConfigService.loadConfig(from: configURL).videoRelations[excluded.video.filename])
    }

    func testRestoreKeepsAnEntryThatOtherDecisionsNowUse() throws {
        let appState = makeAppState()
        let target = appState.combinations[0]
        let exclusion = try appState.excludePairing(filename: target.video.filename, galleryName: target.gallery.name)
        appState.config?.videoRelations[target.video.filename]?.excludedTags = ["night"]

        try appState.restorePairing(exclusion)

        XCTAssertEqual(appState.config?.videoRelations[target.video.filename]?.excludedTags, ["night"])
        XCTAssertEqual(appState.config?.videoRelations[target.video.filename]?.excludedGalleries, [])
    }

    func testRestoreBringsBackAnEarlierYes() throws {
        let appState = makeAppState()
        let target = appState.combinations[0]
        appState.config?.videoRelations[target.video.filename] = VideoRelation(
            galleries: [target.gallery.name],
            excludedGalleries: [],
            tags: [],
            excludedTags: []
        )

        let exclusion = try appState.excludePairing(filename: target.video.filename, galleryName: target.gallery.name)
        XCTAssertEqual(exclusion.previousState, .yes)
        XCTAssertEqual(appState.config?.videoRelations[target.video.filename]?.galleries, [])

        try appState.restorePairing(exclusion)
        XCTAssertEqual(appState.config?.videoRelations[target.video.filename]?.galleries, [target.gallery.name])
        XCTAssertEqual(appState.config?.videoRelations[target.video.filename]?.excludedGalleries, [])
    }

    func testExcludingTheLastCombinationWrapsToTheFirst() throws {
        let appState = makeAppState()
        let lastIndex = appState.combinations.count - 1
        appState.showCombination(at: lastIndex)
        let first = appState.combinations[0]
        let last = try XCTUnwrap(appState.currentCombination)

        _ = try appState.excludePairing(filename: last.video.filename, galleryName: last.gallery.name)

        XCTAssertEqual(appState.combinationIndex, 0)
        XCTAssertEqual(appState.currentCombination?.id, first.id)
    }

    func testExcludingAnEarlierPairingKeepsTheCurrentOne() throws {
        let appState = makeAppState()
        appState.showCombination(at: 2)
        let current = try XCTUnwrap(appState.currentCombination)
        let earlier = appState.combinations[0]

        _ = try appState.excludePairing(filename: earlier.video.filename, galleryName: earlier.gallery.name)

        XCTAssertEqual(appState.currentCombination?.id, current.id)
    }

    func testRestoreSkipsPairingsTheFiltersNowHide() throws {
        let appState = makeAppState()
        let target = appState.combinations[0]
        let exclusion = try appState.excludePairing(filename: target.video.filename, galleryName: target.gallery.name)

        appState.selectedGalleries.remove(target.gallery.name)
        appState.regenerateCombinations()
        try appState.restorePairing(exclusion)

        XCTAssertFalse(appState.combinations.contains { $0.id == target.id })
        XCTAssertNil(appState.config?.videoRelations[target.video.filename], "The decision is still restored")
    }

    private func makeAppState() -> AppState {
        let appState = AppState()
        appState.config = AppConfig(videosPath: "/tmp/videos", galleriesPath: "/tmp/galleries", tags: [], videoRelations: [:])
        appState.galleries = [Gallery(name: "G1", imageFiles: []), Gallery(name: "G2", imageFiles: [])]
        appState.videos = [
            Video(filename: "acme-jane-one.mp4", studio: "acme", actors: ["jane"], title: "one", fileURL: URL(fileURLWithPath: "/tmp/1.mp4"), relatedGalleries: ["G1", "G2"], tags: []),
            Video(filename: "globex-sam-two.mp4", studio: "globex", actors: ["sam"], title: "two", fileURL: URL(fileURLWithPath: "/tmp/2.mp4"), relatedGalleries: ["G1", "G2"], tags: []),
        ]
        appState.resetFilters()
        XCTAssertEqual(appState.combinations.count, 4)
        return appState
    }
}
