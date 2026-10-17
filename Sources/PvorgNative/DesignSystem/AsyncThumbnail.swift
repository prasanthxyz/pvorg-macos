import AppKit
import SwiftUI

/// An image loaded through `ImagePipeline`. Shows a quiet placeholder while
/// decoding and a symbol if the file is missing or unreadable.
struct AsyncThumbnail: View {
    let url: URL?
    var maxPixelSize: Int
    var contentMode: ContentMode
    var placeholder: Color

    private struct Loaded {
        let url: URL
        let image: NSImage?
    }

    @State private var loaded: Loaded?

    init(url: URL?, maxPixelSize: Int = ImageSize.thumbnail, contentMode: ContentMode = .fill, placeholder: Color = .thumbnailPlaceholder) {
        self.url = url
        self.maxPixelSize = maxPixelSize
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    var body: some View {
        ZStack {
            if let image = displayedImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                placeholder
                if isMissing {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .animation(.easeOut(duration: 0.18), value: displayedImage != nil)
        .task(id: url) {
            guard let url else { return }
            // Hold our own reference even on a cache hit, so eviction can't blank a visible image.
            if let cached = ImagePipeline.shared.cachedImage(for: url, maxPixelSize: maxPixelSize) {
                loaded = Loaded(url: url, image: cached)
                return
            }
            let image = await ImagePipeline.shared.image(for: url, maxPixelSize: maxPixelSize)
            guard !Task.isCancelled else { return }
            loaded = Loaded(url: url, image: image)
        }
    }

    /// Reads the cache synchronously so recreated views never flash the placeholder.
    private var displayedImage: NSImage? {
        guard let url else { return nil }
        if let cached = ImagePipeline.shared.cachedImage(for: url, maxPixelSize: maxPixelSize) {
            return cached
        }
        return loaded?.url == url ? loaded?.image : nil
    }

    private var isMissing: Bool {
        guard let url else { return true }
        return loaded?.url == url && loaded?.image == nil
    }
}
