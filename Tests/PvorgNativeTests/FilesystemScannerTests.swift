import Foundation
import XCTest
@testable import PvorgNative

final class FilesystemScannerTests: XCTestCase {
    func testScanVideosTreatsUnknownVideosAsAllGalleriesAndAllTags() throws {
        let fixture = try Fixture()
        let filename = "studio-actor-title.mp4"
        fixture.createVideo(named: filename)

        let config = AppConfig(
            videosPath: fixture.videosURL.path,
            galleriesPath: fixture.galleriesURL.path,
            tags: ["tag-a", "tag-b"],
            videoRelations: [:]
        )

        let result = try FilesystemScanner.scanVideos(config: config, galleryNames: ["gal-a", "gal-b"])

        XCTAssertEqual(result.videos.count, 1)
        XCTAssertEqual(result.videos[0].relatedGalleries, ["gal-a", "gal-b"])
        XCTAssertEqual(result.videos[0].tags, ["tag-a", "tag-b"])
    }

    func testScanVideosHonorsExplicitExcludedMappings() throws {
        let fixture = try Fixture()
        let filename = "studio-actor-title.mp4"
        fixture.createVideo(named: filename)

        let config = AppConfig(
            videosPath: fixture.videosURL.path,
            galleriesPath: fixture.galleriesURL.path,
            tags: ["tag-a", "tag-b"],
            videoRelations: [
                filename: VideoRelation(
                    galleries: [],
                    excludedGalleries: ["gal-b"],
                    tags: [],
                    excludedTags: ["tag-b"]
                )
            ]
        )

        let result = try FilesystemScanner.scanVideos(config: config, galleryNames: ["gal-a", "gal-b"])

        XCTAssertEqual(result.videos.count, 1)
        XCTAssertEqual(result.videos[0].relatedGalleries, ["gal-a"])
        XCTAssertEqual(result.videos[0].tags, ["tag-a"])
    }

    func testScanVideosKeepsAllMappingsWhenManualRelationHasNoExclusions() throws {
        let fixture = try Fixture()
        let filename = "studio-actor-title.mp4"
        fixture.createVideo(named: filename)

        let config = AppConfig(
            videosPath: fixture.videosURL.path,
            galleriesPath: fixture.galleriesURL.path,
            tags: ["tag-a", "tag-b"],
            videoRelations: [
                filename: VideoRelation(
                    galleries: [],
                    excludedGalleries: [],
                    tags: [],
                    excludedTags: []
                )
            ]
        )

        let result = try FilesystemScanner.scanVideos(config: config, galleryNames: ["gal-a", "gal-b"])

        XCTAssertEqual(result.videos.count, 1)
        XCTAssertEqual(result.videos[0].relatedGalleries, ["gal-a", "gal-b"])
        XCTAssertEqual(result.videos[0].tags, ["tag-a", "tag-b"])
    }
}

private final class Fixture {
    let rootURL: URL
    let videosURL: URL
    let galleriesURL: URL

    init() throws {
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        videosURL = rootURL.appendingPathComponent("VID", isDirectory: true)
        galleriesURL = rootURL.appendingPathComponent("GAL", isDirectory: true)
        try FileManager.default.createDirectory(at: videosURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: galleriesURL, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: rootURL)
    }

    func createVideo(named filename: String) {
        FileManager.default.createFile(atPath: videosURL.appendingPathComponent(filename).path, contents: Data(), attributes: nil)
    }
}
