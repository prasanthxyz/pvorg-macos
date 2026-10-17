import Foundation
import XCTest
@testable import PvorgNative

final class FilesystemScannerTests: XCTestCase {
    func testScanVideosTreatsUnknownVideosAsAllGalleriesAndNoTags() throws {
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
        XCTAssertEqual(result.videos[0].tags, [], "Tags are opt-in: an untouched video has none")
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
        XCTAssertEqual(result.videos[0].tags, [], "Undecided tag-a doesn't count; excluded tag-b doesn't either")
    }

    func testScanVideosKeepsAllGalleriesButNoTagsWhenRelationIsUndecided() throws {
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
        XCTAssertEqual(result.videos[0].tags, [], "Creating an entry (e.g. by saving a gallery decision) must not change tags")
    }

    func testScanVideosUsesOnlyTagsExplicitlyMarkedYes() throws {
        let fixture = try Fixture()
        let filename = "studio-actor-title.mp4"
        fixture.createVideo(named: filename)

        let config = AppConfig(
            videosPath: fixture.videosURL.path,
            galleriesPath: fixture.galleriesURL.path,
            tags: ["tag-a", "tag-b", "tag-c"],
            videoRelations: [
                filename: VideoRelation(
                    galleries: [],
                    excludedGalleries: [],
                    tags: ["tag-a", "tag-c"],
                    excludedTags: ["tag-b"]
                )
            ]
        )

        let result = try FilesystemScanner.scanVideos(config: config, galleryNames: ["gal-a"])

        XCTAssertEqual(result.videos[0].tags, ["tag-a", "tag-c"])
    }
}

/// End to end: files on disk → scanner → combination engine, for the filter
/// rules users see in Filters.
final class CombinationFilterTests: XCTestCase {
    private let tagged = "acme-jane-both_tags.mp4"
    private let partlyTagged = "acme-jane-one_tag.mp4"
    private let untouched = "acme-jane-untouched.mp4"
    private let excludedTag = "acme-jane-excluded_tag.mp4"
    private let galleries = ["gal-a", "gal-b"]

    func testNoRequiredTagsShowsEveryVideoRegardlessOfTagging() throws {
        let videos = try scan()

        let shown = videosShown(videos, requiring: [])

        XCTAssertEqual(shown, [tagged, partlyTagged, untouched, excludedTag].sorted())
    }

    func testRequiredTagsMatchOnlyVideosMarkedYesForAllOfThem() throws {
        let videos = try scan()

        XCTAssertEqual(videosShown(videos, requiring: ["tag-a"]), [tagged, partlyTagged].sorted(), "Undecided and excluded videos don't match")
        XCTAssertEqual(videosShown(videos, requiring: ["tag-a", "tag-b"]), [tagged], "Every selected tag must be yes")
        XCTAssertEqual(videosShown(videos, requiring: ["tag-b"]), [tagged])
    }

    func testGalleryFilterPairsWithAnySelectedGalleryTheVideoIsntExcludedFrom() throws {
        let videos = try scan(excludingGallery: "gal-b", from: untouched)
        let galleryModels = galleries.map { Gallery(name: $0, imageFiles: []) }

        let all = CombinationEngine.generate(
            videos: videos,
            galleries: galleryModels,
            selectedGalleries: Set(galleries),
            selectedStudios: ["acme"],
            selectedTags: [],
            selectedCast: []
        )
        XCTAssertEqual(all.count, 4 * 2 - 1, "Every video with each gallery, minus the excluded pairing")
        XCTAssertFalse(all.contains { $0.video.filename == untouched && $0.gallery.name == "gal-b" })

        let onlyA = CombinationEngine.generate(
            videos: videos,
            galleries: galleryModels,
            selectedGalleries: ["gal-a"],
            selectedStudios: ["acme"],
            selectedTags: [],
            selectedCast: []
        )
        XCTAssertEqual(onlyA.count, 4)
        XCTAssertTrue(onlyA.allSatisfy { $0.gallery.name == "gal-a" })
    }

    // MARK: Fixture

    private func scan(excludingGallery gallery: String? = nil, from video: String? = nil) throws -> [Video] {
        let fixture = try Fixture()
        for name in [tagged, partlyTagged, untouched, excludedTag] {
            fixture.createVideo(named: name)
        }
        var relations: [String: VideoRelation] = [
            tagged: VideoRelation(galleries: [], excludedGalleries: [], tags: ["tag-a", "tag-b"], excludedTags: []),
            partlyTagged: VideoRelation(galleries: [], excludedGalleries: [], tags: ["tag-a"], excludedTags: ["tag-b"]),
            excludedTag: VideoRelation(galleries: [], excludedGalleries: [], tags: [], excludedTags: ["tag-a", "tag-b"]),
        ]
        if let gallery, let video {
            relations[video] = VideoRelation(galleries: [], excludedGalleries: [gallery], tags: [], excludedTags: [])
        }
        let config = AppConfig(
            videosPath: fixture.videosURL.path,
            galleriesPath: fixture.galleriesURL.path,
            tags: ["tag-a", "tag-b"],
            videoRelations: relations
        )
        return try FilesystemScanner.scanVideos(config: config, galleryNames: galleries).videos
    }

    private func videosShown(_ videos: [Video], requiring tags: Set<String>) -> [String] {
        let combinations = CombinationEngine.generate(
            videos: videos,
            galleries: galleries.map { Gallery(name: $0, imageFiles: []) },
            selectedGalleries: Set(galleries),
            selectedStudios: ["acme"],
            selectedTags: tags,
            selectedCast: []
        )
        return Set(combinations.map(\.video.filename)).sorted()
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
