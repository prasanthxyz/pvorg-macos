import AppKit
import Foundation
import XCTest
@testable import PvorgNative

@MainActor
final class KeyboardCommandTests: XCTestCase {
    func testEveryPlainKeyIsUniqueAndRoundTrips() {
        XCTAssertEqual(PlainKeyCommand.allCharacters.count, PlainKeyCommand.all.count)
        for command in PlainKeyCommand.all {
            XCTAssertEqual(PlainKeyCommand(characters: command.characters), command)
        }
    }

    func testKeysMatchTheOriginalShortcuts() {
        XCTAssertEqual(PlainKeyCommand(characters: "v"), .go(.viewer))
        XCTAssertEqual(PlainKeyCommand(characters: "c"), .go(.filters))
        XCTAssertEqual(PlainKeyCommand(characters: "p"), .toggleMode)
        XCTAssertEqual(PlainKeyCommand(characters: "b"), .previous)
        XCTAssertEqual(PlainKeyCommand(characters: "n"), .next)
        XCTAssertEqual(PlainKeyCommand(characters: " "), .playPause)
        XCTAssertEqual(PlainKeyCommand(characters: String(UnicodeScalar(NSLeftArrowFunctionKey)!)), .skipBack)
        XCTAssertEqual(PlainKeyCommand(characters: String(UnicodeScalar(NSRightArrowFunctionKey)!)), .skipForward)
        XCTAssertEqual(PlainKeyCommand(characters: "7"), .jump(tenths: 7))
        XCTAssertNil(PlainKeyCommand(characters: "x"))
    }

    func testViewerCommandsOnlyApplyInTheViewer() {
        let context = makeContext()
        XCTAssertFalse(context.isAvailable(.go(.viewer)), "Nothing applies before the library is ready")

        context.appState.isReady = true
        context.navigation.page = .library
        XCTAssertTrue(context.isAvailable(.go(.viewer)))
        XCTAssertFalse(context.isAvailable(.next))

        context.navigation.page = .viewer
        XCTAssertTrue(context.isAvailable(.next))
        XCTAssertTrue(context.isAvailable(.toggleMode))
        XCTAssertFalse(context.isAvailable(.playPause), "Playback keys need a playing video")

        let first = context.appState.combinationIndex
        context.perform(.next)
        XCTAssertEqual(context.appState.combinationIndex, (first + 1) % context.appState.combinations.count)
        context.navigation.page = .library
        context.perform(.next)
        XCTAssertEqual(context.appState.combinationIndex, (first + 1) % context.appState.combinations.count, "Ignored outside the viewer")
    }

    func testLibrarySearchMatchesAndSelectionPruning() {
        let context = makeContext()
        let library = LibraryModel()
        library.selection = Set(context.appState.videos.map(\.filename))

        library.query = "acme"
        let shown = library.visibleVideos(in: context.appState)
        XCTAssertEqual(shown.map(\.studio), ["acme"])

        library.prune(keeping: Set(shown.map(\.filename)))
        XCTAssertEqual(library.selection, Set(shown.map(\.filename)))
    }

    private func makeContext() -> CommandContext {
        let appState = AppState()
        appState.config = AppConfig(videosPath: "/tmp/v", galleriesPath: "/tmp/g", tags: [], videoRelations: [:])
        appState.galleries = [Gallery(name: "G1", imageFiles: []), Gallery(name: "G2", imageFiles: [])]
        appState.videos = [
            Video(filename: "acme-jane-one.mp4", studio: "acme", actors: ["jane"], title: "one", fileURL: URL(fileURLWithPath: "/tmp/1.mp4"), relatedGalleries: ["G1", "G2"], tags: []),
            Video(filename: "globex-sam-two.mp4", studio: "globex", actors: ["sam"], title: "two", fileURL: URL(fileURLWithPath: "/tmp/2.mp4"), relatedGalleries: ["G1", "G2"], tags: []),
        ]
        appState.resetFilters()
        return CommandContext(appState: appState, navigation: AppNavigation(), viewer: ViewerModel())
    }
}
