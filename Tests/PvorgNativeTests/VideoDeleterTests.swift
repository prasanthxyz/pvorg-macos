import Foundation
import XCTest
@testable import PvorgNative

final class VideoDeleterTests: XCTestCase {
    private var root: URL!
    private var videos: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        videos = root.appendingPathComponent("videos", isDirectory: true)
        try FileManager.default.createDirectory(at: videos.appendingPathComponent("img"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: videos.path)
        try? FileManager.default.removeItem(at: root)
    }

    func testDeletingRemovesFileContactSheetRelationAndCacheEntry() throws {
        let name = "acme-jane-one.mp4"
        try makeVideo(name, contactSheet: true)
        try writeCache([name, "acme-jane-keep.mp4"])

        let result = try VideoDeleter.delete(filenames: [name], knownFilenames: [name], config: config(relations: [name]), configURL: configURL)

        XCTAssertEqual(result.deletedCount, 1)
        XCTAssertEqual(result.errors, [])
        XCTAssertFalse(exists(name))
        XCTAssertFalse(exists("img/\(name).jpg"))
        XCTAssertNil(result.updatedConfig.videoRelations[name])
        XCTAssertEqual(try readCache().keys.sorted(), ["acme-jane-keep.mp4"])
    }

    func testMissingContactSheetIsNotAnError() throws {
        let name = "acme-jane-one.mp4"
        try makeVideo(name, contactSheet: false)

        let result = try VideoDeleter.delete(filenames: [name], knownFilenames: [name], config: config(relations: [name]), configURL: configURL)

        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(result.deletedCount, 1)
    }

    func testAVideoThatCantBeDeletedKeepsItsDecisionsAndMetadata() throws {
        let name = "acme-jane-one.mp4"
        try makeVideo(name, contactSheet: true)
        try writeCache([name])
        // A read-only folder makes the video file undeletable.
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: videos.path)

        let result = try VideoDeleter.delete(filenames: [name], knownFilenames: [name], config: config(relations: [name]), configURL: configURL)

        XCTAssertEqual(result.deletedCount, 0)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertTrue(exists(name))
        XCTAssertNotNil(result.updatedConfig.videoRelations[name], "Decisions survive a failed delete")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: videos.path)
        XCTAssertEqual(try readCache().keys.sorted(), [name], "Cached metadata survives a failed delete")
    }

    // MARK: Fixture

    private var configURL: URL { root.appendingPathComponent("pvorg.json") }

    private func config(relations: [String]) -> AppConfig {
        AppConfig(
            videosPath: videos.path,
            galleriesPath: root.appendingPathComponent("galleries").path,
            tags: [],
            videoRelations: Dictionary(uniqueKeysWithValues: relations.map {
                ($0, VideoRelation(galleries: [], excludedGalleries: ["G1"], tags: [], excludedTags: []))
            })
        )
    }

    private func makeVideo(_ name: String, contactSheet: Bool) throws {
        try Data().write(to: videos.appendingPathComponent(name))
        if contactSheet {
            try Data().write(to: videos.appendingPathComponent("img/\(name).jpg"))
        }
    }

    private func writeCache(_ names: [String]) throws {
        let entries = Dictionary(uniqueKeysWithValues: names.map {
            ($0, MetadataCacheEntry(duration: 6, width: 640, height: 360, fps: 24, fileSize: 1))
        })
        try JSONEncoder().encode(entries).write(to: videos.appendingPathComponent("cache.json"))
    }

    private func readCache() throws -> [String: MetadataCacheEntry] {
        try JSONDecoder().decode([String: MetadataCacheEntry].self, from: Data(contentsOf: videos.appendingPathComponent("cache.json")))
    }

    private func exists(_ relative: String) -> Bool {
        FileManager.default.fileExists(atPath: videos.appendingPathComponent(relative).path)
    }
}
