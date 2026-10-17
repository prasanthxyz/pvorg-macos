import SwiftUI

/// The gallery half of a combination: its images in a random order, advancing
/// every two seconds with a short crossfade.
struct GallerySlideshowView: View {
    let gallery: Gallery

    @State private var order: [URL] = []
    @State private var index = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let interval: Duration = .seconds(2)

    var body: some View {
        ZStack {
            Color.stage

            if order.isEmpty {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title)
                    Text("No Images")
                        .font(.headline)
                    Text("This gallery folder is empty.")
                        .font(.callout)
                }
                .foregroundStyle(Color.stageSecondary)
                .multilineTextAlignment(.center)
                .padding(Spacing.lg)
            } else {
                AsyncThumbnail(url: order[index], maxPixelSize: ImageSize.large, contentMode: .fit, placeholder: .stage)
                    .id(order[index])
                    .transition(.opacity)
                    .accessibilityLabel("Image \(index + 1) of \(order.count) from \(gallery.name)")
            }
        }
        .overlay(alignment: .bottom) {
            caption
        }
        .clipped()
        .task(id: gallery) {
            order = gallery.imageFiles.shuffled()
            index = 0
            guard !order.isEmpty else { return }
            ImagePipeline.shared.prefetch(order[0], maxPixelSize: ImageSize.large)
            guard order.count > 1 else { return }

            while !Task.isCancelled {
                let next = (index + 1) % order.count
                // Decode the next image before switching so the fade never shows a blank frame.
                async let decoded = ImagePipeline.shared.image(for: order[next], maxPixelSize: ImageSize.large)
                try? await Task.sleep(for: interval)
                _ = await decoded
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                    index = next
                }
            }
        }
    }

    private var caption: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text(gallery.name)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.stagePrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: Spacing.xs)
            if !order.isEmpty {
                Text("\(index + 1) of \(order.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.stageSecondary)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.xl)
        .padding(.bottom, Spacing.sm + 2)
        .background {
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
        }
        .accessibilityElement(children: .combine)
    }
}
