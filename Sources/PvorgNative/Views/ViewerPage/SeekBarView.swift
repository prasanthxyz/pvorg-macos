import AppKit
import SwiftUI

struct SeekBarView: View {
    let duration: Double
    let currentTime: Double
    let onSeek: (Double) -> Void
    let thumbnailProvider: @MainActor (Double) async -> NSImage?

    @State private var isHovering = false
    @State private var hoverX: CGFloat = 0
    @State private var hoverThumbnail: NSImage?
    @State private var thumbnailTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            let progress = duration > 0 ? currentTime / duration : 0

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(white: 0.2))

                Rectangle()
                    .fill(Color.accentTheme)
                    .frame(width: width * progress)
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    isHovering = true
                    hoverX = location.x
                    let hoverTime = (location.x / width).clamped(to: 0...1) * duration
                    generateThumbnail(at: hoverTime)
                case .ended:
                    isHovering = false
                    thumbnailTask?.cancel()
                    hoverThumbnail = nil
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let pct = (value.location.x / width).clamped(to: 0...1)
                        onSeek(pct * duration)
                    }
            )
            .overlay(alignment: .topLeading) {
                if isHovering, let thumbnail = hoverThumbnail {
                    let clampedX = min(max(hoverX - 80, 0), width - 160)
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(.white, lineWidth: 2)
                        )
                        .shadow(radius: 4)
                        .offset(x: clampedX, y: -100)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(height: 8)
    }

    private func generateThumbnail(at time: Double) {
        thumbnailTask?.cancel()
        thumbnailTask = Task { @MainActor in
            hoverThumbnail = await thumbnailProvider(time)
        }
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
