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

    func testGalleryMappingPageSortsByDisplayedNameBeforePagination() {
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

        let page = appState.galleryMappingPage(page: 1, pageSize: 10, hideDecided: false)

        XCTAssertEqual(page.videos.map(\.filename), [
            "beta-actor-title.mp4",
            "delta-actor-title.mp4",
            "zeta-actor-title.mp4",
            "charlie-actor-title.mp4",
        ])
    }

    func testTagMappingPageSortsByDisplayedNameBeforePagination() {
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

        let page = appState.tagMappingPage(page: 1, pageSize: 10, hideDecided: false)

        XCTAssertEqual(page.videos.map(\.filename), [
            "beta-actor-title.mp4",
            "delta-actor-title.mp4",
            "zeta-actor-title.mp4",
            "charlie-actor-title.mp4",
        ])
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
