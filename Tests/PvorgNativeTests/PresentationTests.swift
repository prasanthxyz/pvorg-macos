import Foundation
import XCTest
@testable import PvorgNative

@MainActor
final class PresentationTests: XCTestCase {
    func testHumanizeTurnsFilenameTokensIntoReadableNames() {
        XCTAssertEqual(DisplayName.humanize("jane_doe"), "Jane Doe")
        XCTAssertEqual(DisplayName.humanize("acme"), "Acme")
        XCTAssertEqual(DisplayName.humanize("4k__clip"), "4k Clip")
        XCTAssertEqual(DisplayName.humanize(""), "")
    }

    func testCreditsJoinStudioAndCast() {
        XCTAssertEqual(DisplayName.credits(studio: "acme", actors: ["jane_doe"]), "Acme · Jane Doe")
        XCTAssertEqual(DisplayName.credits(studio: "acme", actors: []), "Acme")
    }

    func testTimecodes() {
        XCTAssertEqual(TimecodeFormat.string(from: 0), "0:00")
        XCTAssertEqual(TimecodeFormat.string(from: 7.9), "0:07")
        XCTAssertEqual(TimecodeFormat.string(from: 754), "12:34")
        XCTAssertEqual(TimecodeFormat.string(from: 3723), "1:02:03")
        XCTAssertEqual(TimecodeFormat.string(from: .nan), "0:00")
    }

    func testCountedPluralizes() {
        XCTAssertEqual(1.counted("video"), "1 video")
        XCTAssertEqual(3.counted("video"), "3 videos")
        XCTAssertEqual(2.counted("gallery", "galleries"), "2 galleries")
    }

    func testVideoSearchMatchesTitleStudioCastAndFilename() {
        let video = Video(
            filename: "acme-jane_doe-harbor_lights.mp4",
            studio: "acme",
            actors: ["jane_doe"],
            title: "harbor_lights",
            fileURL: URL(fileURLWithPath: "/tmp/x.mp4"),
            relatedGalleries: [],
            tags: []
        )
        XCTAssertTrue(video.matches("harbor lights"))
        XCTAssertTrue(video.matches("ACME"))
        XCTAssertTrue(video.matches("jane doe"))
        XCTAssertTrue(video.matches("harbor_l"))
        XCTAssertFalse(video.matches("globex"))
    }

    func testResetFiltersRestoresDefaults() {
        let appState = AppState()
        appState.config = AppConfig(videosPath: "/tmp/v", galleriesPath: "/tmp/g", tags: ["t"], videoRelations: [:])
        appState.galleries = [Gallery(name: "G", imageFiles: [])]
        appState.videos = [
            Video(filename: "s-a-t.mp4", studio: "s", actors: ["a"], title: "t", fileURL: URL(fileURLWithPath: "/tmp/s-a-t.mp4"), relatedGalleries: ["G"], tags: ["t"]),
        ]
        appState.resetFilters()
        XCTAssertTrue(appState.filtersAreDefault)
        XCTAssertEqual(appState.combinations.count, 1)

        appState.selectedTags = ["t"]
        XCTAssertFalse(appState.filtersAreDefault)
        appState.resetFilters()
        XCTAssertTrue(appState.filtersAreDefault)
    }

    func testInvalidConfigReportsTheProblem() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        try Data(#"{"videosPath": "/tmp", "tags": [], "videoRelations": {}}"#.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try ConfigService.loadConfig(from: url)) { error in
            XCTAssertTrue(error.localizedDescription.contains("galleriesPath"), error.localizedDescription)
        }
    }
}
