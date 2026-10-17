import AppKit
import SwiftUI

/// Playback controls under the video: skip, play/pause, elapsed time, scrubber, duration.
struct TransportBar: View {
    @Bindable var player: VideoPlayerState

    var body: some View {
        HStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.xs) {
                TransportButton(systemImage: "gobackward.10", label: "Skip Back 10 Seconds") {
                    player.seekRelative(-10)
                }
                TransportButton(systemImage: player.isPlaying ? "pause.fill" : "play.fill", label: player.isPlaying ? "Pause" : "Play", prominent: true) {
                    player.togglePlayPause()
                }
                TransportButton(systemImage: "goforward.10", label: "Skip Forward 10 Seconds") {
                    player.seekRelative(10)
                }
            }

            Text(TimecodeFormat.string(from: player.currentTime))
                .timecodeStyle()

            Scrubber(player: player)

            Text(TimecodeFormat.string(from: player.duration))
                .timecodeStyle()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .disabled(player.status != .ready)
    }
}

private struct TransportButton: View {
    let systemImage: String
    let label: String
    var prominent = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(prominent ? .title3 : .body)
                .fontWeight(.medium)
                .foregroundStyle(Color.stagePrimary)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(isHovering ? 0.12 : 0), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

private extension Text {
    func timecodeStyle() -> some View {
        font(.caption.monospacedDigit())
            .foregroundStyle(Color.stageSecondary)
            .frame(minWidth: 40)
    }
}

/// A track that previews the frame under the pointer and seeks live while dragging.
private struct Scrubber: View {
    let player: VideoPlayerState

    @State private var hoverLocation: CGFloat?
    @State private var hoverThumbnail: NSImage?
    @State private var thumbnailTask: Task<Void, Never>?
    @State private var isDragging = false

    private let previewWidth: CGFloat = 224

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let progress = player.duration > 0 ? min(max(player.currentTime / player.duration, 0), 1) : 0
            let isActive = hoverLocation != nil || isDragging
            let trackHeight: CGFloat = isActive ? 6 : 4

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                Capsule()
                    .fill(Color.stagePrimary)
                    .frame(width: max(trackHeight, width * progress))
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .shadow(color: .black.opacity(0.4), radius: 2)
                    .offset(x: width * progress - 6)
                    .opacity(isActive ? 1 : 0)
            }
            .frame(height: trackHeight)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.12), value: isActive)
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoverLocation = location.x
                    requestThumbnail(at: time(at: location.x, width: width))
                case .ended:
                    hoverLocation = nil
                    thumbnailTask?.cancel()
                    hoverThumbnail = nil
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        hoverLocation = value.location.x
                        player.scrub(to: time(at: value.location.x, width: width), finished: false)
                        requestThumbnail(at: time(at: value.location.x, width: width))
                    }
                    .onEnded { value in
                        isDragging = false
                        player.scrub(to: time(at: value.location.x, width: width), finished: true)
                    }
            )
            .overlay(alignment: .bottomLeading) {
                if let hoverLocation, player.duration > 0 {
                    preview(at: hoverLocation, width: width)
                }
            }
        }
        .frame(height: 20)
        .onDisappear {
            // A drag interrupted by the view going away never reports its end.
            if isDragging {
                isDragging = false
                player.scrub(to: player.currentTime, finished: true)
            }
            thumbnailTask?.cancel()
        }
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue("\(TimecodeFormat.string(from: player.currentTime)) of \(TimecodeFormat.string(from: player.duration))")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: player.seekRelative(10)
            case .decrement: player.seekRelative(-10)
            @unknown default: break
            }
        }
    }

    private func preview(at x: CGFloat, width: CGFloat) -> some View {
        let clampedX = min(max(x - previewWidth / 2, 0), max(width - previewWidth, 0))
        return VStack(spacing: Spacing.xs) {
            ZStack {
                Color.stageRaised
                if let hoverThumbnail {
                    Image(nsImage: hoverThumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
            .frame(width: previewWidth, height: previewWidth * 9 / 16)
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            }

            Text(TimecodeFormat.string(from: time(at: x, width: width)))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(Color.stagePrimary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xxs)
                .background(Color.black.opacity(0.7), in: Capsule())
        }
        .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
        .offset(x: clampedX, y: -Spacing.xl)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func time(at x: CGFloat, width: CGFloat) -> Double {
        Double(min(max(x / width, 0), 1)) * player.duration
    }

    private func requestThumbnail(at time: Double) {
        thumbnailTask?.cancel()
        thumbnailTask = Task {
            // Coalesce rapid pointer movement into one frame request.
            try? await Task.sleep(for: .milliseconds(40))
            guard !Task.isCancelled else { return }
            let image = await player.thumbnail(at: time)
            guard !Task.isCancelled, let image else { return }
            hoverThumbnail = image
        }
    }
}
