import Foundation
import XCTest
@testable import PvorgNative

@MainActor
final class VideoDisplaySortTests: XCTestCase {
    func testSharedSortUsesDisplayedTitleAndFallsBackToFilename() {
        let videos = [
            makeVideo(filename: "charlie-actor-title.mp4", title: ""),
            makeVideo(filename: "zeta-actor-title.mp4", title: "Bravo"),
            makeVideo(filename: "delta-actor-title.mp4", title: "alpha"),
            makeVideo(filename: "beta-actor-title.mp4", title: "Alpha"),
        ]

        let sorted = VideoDisplaySort.sorted(videos)

        XCTAssertEqual(sorted.map(\.filename), [
            "beta-actor-title.mp4",
            "delta-actor-title.mp4",
            "zeta-actor-title.mp4",
            "charlie-actor-title.mp4",
        ])
    }

    func testSortMatchesHumanizedDisplayNames() {
        let videos = [
            makeVideo(filename: "a-x-zebra.mp4", title: "zebra"),
            makeVideo(filename: "b-x-a_long_road.mp4", title: "a_long_road"),
            makeVideo(filename: "c-x-another.mp4", title: "another"),
        ]

        XCTAssertEqual(VideoDisplaySort.sorted(videos).map(\.title), ["a_long_road", "another", "zebra"])
        XCTAssertEqual(VideoDisplaySort.sorted(videos).map { VideoDisplaySort.displayName(for: $0) }, ["A Long Road", "Another", "Zebra"])
    }

    func testGalleryMappingRowsSortByDisplayedName() {
        let appState = makeAppState()

        let rows = appState.mappingRows(.galleries, hideDecided: false)

        XCTAssertEqual(rows.map(\.filename), [
            "beta-actor-title.mp4",
            "delta-actor-title.mp4",
            "zeta-actor-title.mp4",
            "charlie-actor-title.mp4",
        ])
    }

    func testTagMappingRowsSortByDisplayedName() {
        let appState = makeAppState()

        let rows = appState.mappingRows(.tags, hideDecided: false)

        XCTAssertEqual(rows.map(\.filename), [
            "beta-actor-title.mp4",
            "delta-actor-title.mp4",
            "zeta-actor-title.mp4",
            "charlie-actor-title.mp4",
        ])
    }

    private func makeAppState() -> AppState {
        let appState = AppState()
        appState.config = AppConfig(
            videosPath: "/tmp/videos",
            galleriesPath: "/tmp/galleries",
            tags: ["tag-a"],
            videoRelations: [:]
        )
        appState.galleries = [Gallery(name: "Gallery A", imageFiles: [])]
        appState.videos = [
            makeVideo(filename: "charlie-actor-title.mp4", title: ""),
            makeVideo(filename: "zeta-actor-title.mp4", title: "Bravo"),
            makeVideo(filename: "delta-actor-title.mp4", title: "alpha"),
            makeVideo(filename: "beta-actor-title.mp4", title: "Alpha"),
        ]
        return appState
    }

    private func makeVideo(filename: String, title: String) -> Video {
        Video(
            filename: filename,
            studio: "studio",
            actors: ["actor"],
            title: title,
            fileURL: URL(fileURLWithPath: "/tmp/\(filename)"),
            relatedGalleries: ["Gallery A"],
            tags: ["tag-a"]
        )
    }
}
