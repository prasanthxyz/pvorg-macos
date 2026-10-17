import AppKit
import SwiftUI

struct VideoPlayerView: View {
    @Bindable var playerState: VideoPlayerState
    let onShowContactSheet: () -> Void

    var body: some View {
        if case .failed(let message) = playerState.status {
            failure(message)
        } else {
            player
        }
    }

    private var player: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black
                if let player = playerState.player {
                    NativeVideoPlayerView(player: player)
                        .onTapGesture {
                            playerState.togglePlayPause()
                        }
                        .accessibilityLabel("Video")
                        .accessibilityHint("Click to play or pause")
                }
                if playerState.status == .loading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            TransportBar(player: playerState)
                .background(Color.stage)
        }
    }

    private func failure(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Can’t Play This Video", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            if let url = playerState.url {
                Button("Open in Default App") {
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
            }
            Button("Show Contact Sheet", action: onShowContactSheet)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.stage)
    }
}
