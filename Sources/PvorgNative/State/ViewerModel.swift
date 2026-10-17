import Foundation
import Observation

/// Viewer presentation state shared by the viewer page and the Viewer menu.
@Observable
@MainActor
final class ViewerModel {
    enum Mode: Hashable {
        case contactSheet
        case video
    }

    var mode: Mode = .contactSheet
    let player = VideoPlayerState()

    func show(_ mode: Mode, for combination: Combination?) {
        guard let combination, mode != self.mode else { return }
        self.mode = mode
        switch mode {
        case .video:
            // Returning to the same video resumes where it was paused.
            if player.url != combination.video.fileURL {
                player.load(url: combination.video.fileURL)
            }
            player.play()
        case .contactSheet:
            player.pause()
        }
    }

    func toggleMode(for combination: Combination?) {
        show(mode == .video ? .contactSheet : .video, for: combination)
    }

    var canControlPlayback: Bool {
        mode == .video && player.status == .ready
    }

    /// Called when the combination changes or the viewer goes away.
    func reset() {
        player.stopAndClear()
        mode = .contactSheet
    }
}
