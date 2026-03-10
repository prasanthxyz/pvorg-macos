import AppKit
import SwiftUI

struct GallerySlideshowView: View {
    let images: [URL]

    @State private var shuffledImages: [URL] = []
    @State private var currentIndex = 0

    var body: some View {
        Group {
            if shuffledImages.isEmpty {
                Text("No images")
                    .foregroundStyle(.secondary)
            } else if let image = NSImage(contentsOf: shuffledImages[currentIndex]) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .id(shuffledImages[currentIndex].path)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: currentIndex)
            } else {
                Text("Image load failed")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            reshuffle()
        }
        .onChange(of: images) { _, _ in
            reshuffle()
        }
        .task(id: shuffledImages.map(\.path).joined(separator: "|")) {
            guard shuffledImages.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if Task.isCancelled { return }
                currentIndex = (currentIndex + 1) % shuffledImages.count
            }
        }
    }

    private func reshuffle() {
        shuffledImages = images.shuffled()
        currentIndex = 0
    }
}
