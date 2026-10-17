import AppKit
import ImageIO

/// Decodes images off the main thread at the size they are displayed and keeps
/// them in a memory-bounded cache, so grids scroll smoothly and re-renders never
/// touch the disk.
@MainActor
final class ImagePipeline {
    static let shared = ImagePipeline()

    private struct DecodedImage: @unchecked Sendable {
        let cgImage: CGImage
    }

    private let cache = NSCache<NSString, NSImage>()
    private var inFlight: [NSString: Task<DecodedImage?, Never>] = [:]
    /// Bumped by `removeAll()` so decodes started before a reload don't refill the cache.
    private var generation = 0

    private init() {
        cache.totalCostLimit = 768 * 1024 * 1024
    }

    func cachedImage(for url: URL, maxPixelSize: Int) -> NSImage? {
        cache.object(forKey: Self.key(url, maxPixelSize))
    }

    func image(for url: URL, maxPixelSize: Int) async -> NSImage? {
        let key = Self.key(url, maxPixelSize)
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let task: Task<DecodedImage?, Never>
        if let existing = inFlight[key] {
            task = existing
        } else {
            task = Task.detached(priority: .userInitiated) {
                Self.decode(url: url, maxPixelSize: maxPixelSize)
            }
            inFlight[key] = task
        }
        let startedGeneration = generation

        let decoded = await task.value
        if inFlight[key] == task {
            inFlight[key] = nil
        }

        guard let decoded, startedGeneration == generation else { return nil }
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let image = NSImage(cgImage: decoded.cgImage, size: NSSize(width: decoded.cgImage.width, height: decoded.cgImage.height))
        cache.setObject(image, forKey: key, cost: decoded.cgImage.bytesPerRow * decoded.cgImage.height)
        return image
    }

    func prefetch(_ url: URL?, maxPixelSize: Int) {
        guard let url, cachedImage(for: url, maxPixelSize: maxPixelSize) == nil else { return }
        Task { _ = await image(for: url, maxPixelSize: maxPixelSize) }
    }

    func removeAll() {
        cache.removeAllObjects()
        inFlight.removeAll()
        generation += 1
    }

    private static func key(_ url: URL, _ maxPixelSize: Int) -> NSString {
        "\(maxPixelSize)|\(url.path)" as NSString
    }

    nonisolated private static func decode(url: URL, maxPixelSize: Int) -> DecodedImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return DecodedImage(cgImage: image)
    }
}

/// Standard decode sizes. Keeping these few buckets lets screens share cache entries.
enum ImageSize {
    /// Small list thumbnails (mapping rows, previews).
    static let thumbnail = 320
    /// Library cards.
    static let card = 720
    /// Slideshow and hover preview.
    static let large = 1920
    /// Full-resolution contact sheets in the viewer.
    static let full = 4096
}
