import AppKit
import SwiftUI

/// The app's unmodified-key shortcuts, carried over from the original app.
///
/// SwiftUI refreshes command menus lazily, so a menu's key equivalents can lag
/// behind the app's state (Space would still see "Play" disabled right after P
/// started the video). These keys are therefore dispatched by
/// `KeyboardContext` against live state; menus show the same shortcuts and call
/// the same actions, but never handle these keys themselves.
enum PlainKeyCommand: Hashable {
    case go(Page)
    case toggleMode
    case previous
    case next
    case playPause
    case skipBack
    case skipForward
    case jump(tenths: Int)

    static let all: [PlainKeyCommand] = [
        .go(.viewer), .go(.filters), .toggleMode, .previous, .next, .playPause, .skipBack, .skipForward,
    ] + (0..<10).map { .jump(tenths: $0) }

    private static let byCharacters: [String: PlainKeyCommand] = Dictionary(uniqueKeysWithValues: all.map { ($0.characters, $0) })

    /// Matches a key press by `charactersIgnoringModifiers` (lowercased).
    init?(characters: String) {
        guard let command = Self.byCharacters[characters] else { return nil }
        self = command
    }

    var key: KeyEquivalent {
        switch self {
        case .go(.viewer): "v"
        case .go(.filters): "c"
        case .go: " " // Only Viewer and Filters have plain keys; see `all`.
        case .toggleMode: "p"
        case .previous: "b"
        case .next: "n"
        case .playPause: .space
        case .skipBack: .leftArrow
        case .skipForward: .rightArrow
        case .jump(let tenths): KeyEquivalent(Character(String(tenths)))
        }
    }

    var characters: String {
        switch self {
        case .skipBack: String(UnicodeScalar(NSLeftArrowFunctionKey)!)
        case .skipForward: String(UnicodeScalar(NSRightArrowFunctionKey)!)
        default: String(key.character)
        }
    }

    static var allCharacters: Set<String> { Set(byCharacters.keys) }
}

/// The state plain-key commands read and act on.
@MainActor
struct CommandContext {
    let appState: AppState
    let navigation: AppNavigation
    let viewer: ViewerModel

    var isViewerActive: Bool {
        appState.isReady && navigation.page == .viewer && appState.currentCombination != nil
    }

    func isAvailable(_ command: PlainKeyCommand) -> Bool {
        switch command {
        case .go:
            appState.isReady
        case .toggleMode, .previous, .next:
            isViewerActive
        case .playPause, .skipBack, .skipForward, .jump:
            isViewerActive && viewer.canControlPlayback
        }
    }

    func perform(_ command: PlainKeyCommand) {
        guard isAvailable(command) else { return }
        switch command {
        case .go(let page): navigation.page = page
        case .toggleMode: viewer.toggleMode(for: appState.currentCombination)
        case .previous: appState.previousCombination()
        case .next: appState.nextCombination()
        case .playPause: viewer.player.togglePlayPause()
        case .skipBack: viewer.player.seekRelative(-10)
        case .skipForward: viewer.player.seekRelative(10)
        case .jump(let tenths): viewer.player.seekToPercent(Double(tenths) / 10)
        }
    }

}
