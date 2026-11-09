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
    case excludePairing

    static let all: [PlainKeyCommand] = [
        .go(.viewer), .go(.filters), .toggleMode, .previous, .next, .playPause, .skipBack, .skipForward, .excludePairing,
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
        case .excludePairing: .delete
        }
    }

    var characters: String {
        switch self {
        case .skipBack: String(UnicodeScalar(NSLeftArrowFunctionKey)!)
        case .skipForward: String(UnicodeScalar(NSRightArrowFunctionKey)!)
        // The Delete (backspace) key arrives as DEL, not KeyEquivalent.delete's BS.
        case .excludePairing: "\u{7f}"
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
    let mappings: MappingStore
    let toasts: ToastCenter
    let keyboard: KeyboardContext

    var isViewerActive: Bool {
        appState.isReady && navigation.page == .viewer && appState.currentCombination != nil
    }

    func isAvailable(_ command: PlainKeyCommand) -> Bool {
        switch command {
        case .go:
            appState.isReady
        case .toggleMode, .previous, .next, .excludePairing:
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
        case .excludePairing: excludeCurrentPairing()
        }
    }

    // MARK: Excluding pairings

    private struct Pairing {
        let filename: String
        let galleryName: String
        let videoTitle: String
    }

    private var undoManager: UndoManager? {
        keyboard.mainWindow?.undoManager
    }

    /// Marks the current gallery as "No" for the current video and moves on.
    /// No confirmation: it's undoable (toast, ⌘Z) and editable in Gallery Mapping.
    func excludeCurrentPairing() {
        guard isViewerActive, let combination = appState.currentCombination else { return }
        let pairing = Pairing(
            filename: combination.video.filename,
            galleryName: combination.gallery.name,
            videoTitle: DisplayName.title(for: combination.video)
        )
        exclude(pairing)
    }

    static let undoActionName = "Exclude Pairing"

    @discardableResult
    private func exclude(_ pairing: Pairing) -> Bool {
        do {
            let exclusion = try appState.excludePairing(filename: pairing.filename, galleryName: pairing.galleryName)
            // The viewer decision supersedes an unsaved edit of the same cell.
            mappings.galleries.discardPendingChange(filename: pairing.filename, column: pairing.galleryName)
            undoManager?.registerUndo(withTarget: appState) { _ in
                MainActor.assumeIsolated { self.restore(exclusion, pairing) }
            }
            undoManager?.setActionName(Self.undoActionName)
            toasts.show(
                "Excluded “\(pairing.galleryName)” from “\(pairing.videoTitle)”",
                systemImage: "hand.thumbsdown.fill",
                actionTitle: "Undo"
            ) { [undoManager] in
                guard undoManager?.undoActionName == Self.undoActionName else { return }
                undoManager?.undo()
            }
            return true
        } catch {
            appState.appNotice = AppNotice(title: "Couldn’t Exclude Pairing", message: error.localizedDescription)
            return false
        }
    }

    private func restore(_ exclusion: PairingExclusion, _ pairing: Pairing) {
        do {
            try appState.restorePairing(exclusion)
            // Replaces the Exclude toast, so its Undo can't linger after undoing another way.
            toasts.show("Restored “\(pairing.galleryName)” for “\(pairing.videoTitle)”", systemImage: "arrow.uturn.backward")
            undoManager?.registerUndo(withTarget: appState) { _ in
                MainActor.assumeIsolated { _ = self.exclude(pairing) }
            }
            undoManager?.setActionName(Self.undoActionName)
        } catch {
            appState.appNotice = AppNotice(title: "Couldn’t Undo", message: error.localizedDescription)
        }
    }
}
