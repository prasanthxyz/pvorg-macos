import AppKit
import SwiftUI

struct ViewerView: View {
    @Environment(AppState.self) private var appState

    @State private var showTGP = true
    @State private var playerState = VideoPlayerState()

    var body: some View {
        Group {
            if let combination = appState.currentCombination {
                VStack(spacing: 0) {
                    header(combination: combination)
                    Divider().overlay(Color.border)

                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            ZStack {
                                if showTGP {
                                    if let tgpURL = appState.tgpURL(for: combination.video.filename),
                                       let image = NSImage(contentsOf: tgpURL) {
                                        Image(nsImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    } else {
                                        Text("TGP not found")
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    VideoPlayerView(playerState: playerState)
                                }
                            }
                            .frame(width: geo.size.width * 0.75, height: geo.size.height)

                            Divider().overlay(Color.border)

                            GallerySlideshowView(images: combination.gallery.imageFiles)
                                .frame(width: geo.size.width * 0.25, height: geo.size.height)
                        }
                    }
                }
                .onChange(of: appState.combinationIndex) { _, _ in
                    playerState.stopAndClear()
                    showTGP = true
                }
                .onReceive(NotificationCenter.default.publisher(for: ViewerNotifications.toggleMode)) { _ in
                    toggleMode()
                }
                .onReceive(NotificationCenter.default.publisher(for: ViewerNotifications.previous)) { _ in
                    appState.previousCombination()
                }
                .onReceive(NotificationCenter.default.publisher(for: ViewerNotifications.next)) { _ in
                    appState.nextCombination()
                }
                .onReceive(NotificationCenter.default.publisher(for: ViewerNotifications.playPause)) { _ in
                    guard !showTGP else { return }
                    playerState.togglePlayPause()
                }
                .onReceive(NotificationCenter.default.publisher(for: ViewerNotifications.seekRelative)) { note in
                    guard !showTGP else { return }
                    guard let delta = note.object as? Double else { return }
                    playerState.seekRelative(delta)
                }
                .onReceive(NotificationCenter.default.publisher(for: ViewerNotifications.seekPercent)) { note in
                    guard !showTGP else { return }
                    guard let pct = note.object as? Double else { return }
                    playerState.seekToPercent(pct)
                }
            } else {
                Text("No combinations found.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.bgPrimary)
    }

    @ViewBuilder
    private func header(combination: Combination) -> some View {
        HStack(spacing: 10) {
            Text(combination.video.filename)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(showTGP ? "VID" : "TGP") {
                toggleMode()
            }
            .buttonStyle(.borderedProminent)

            Button("Prev") {
                appState.previousCombination()
            }
            .buttonStyle(.bordered)

            Button("Next") {
                appState.nextCombination()
            }
            .buttonStyle(.bordered)

            Text(combination.gallery.name)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text("\(appState.combinationIndex + 1)/\(max(appState.combinations.count, 1))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.bgSecondary)
    }

    private func toggleMode() {
        guard let combination = appState.currentCombination else { return }

        if showTGP {
            showTGP = false
            playerState.load(url: combination.video.fileURL)
            playerState.play()
        } else {
            showTGP = true
            playerState.pause()
        }
    }
}
