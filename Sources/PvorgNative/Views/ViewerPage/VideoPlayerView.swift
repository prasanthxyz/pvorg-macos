import SwiftUI

struct VideoPlayerView: View {
    @Bindable var playerState: VideoPlayerState

    var body: some View {
        VStack(spacing: 10) {
            if let player = playerState.player {
                NativeVideoPlayerView(player: player)
                    .background(.black)
                    .onTapGesture {
                        playerState.togglePlayPause()
                    }
            } else {
                ZStack {
                    Rectangle().fill(.black)
                    Text("No video loaded")
                        .foregroundStyle(.secondary)
                }
            }

            SeekBarView(
                duration: playerState.duration,
                currentTime: playerState.currentTime,
                onSeek: { playerState.seek(to: $0) },
                thumbnailProvider: { time in
                    await playerState.thumbnail(at: time)
                }
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
