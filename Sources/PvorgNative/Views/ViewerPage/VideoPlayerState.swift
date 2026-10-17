import AppKit
import AVFoundation
import Observation

@Observable
@MainActor
final class VideoPlayerState {
    enum Status: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    private(set) var player: AVPlayer?
    private(set) var url: URL?
    private(set) var status: Status = .idle
    private(set) var duration: Double = 0
    private(set) var currentTime: Double = 0
    private(set) var isPlaying: Bool = false
    /// While the user drags the scrubber, the scrubber owns `currentTime`.
    private(set) var isScrubbing = false

    /// AVAssetImageGenerator serves concurrent async requests; the box lets one cross isolation.
    private struct FrameGenerator: @unchecked Sendable {
        let generator: AVAssetImageGenerator
    }

    @ObservationIgnored private var imageGenerator: FrameGenerator?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private let thumbnailCache: NSCache<NSNumber, NSImage> = {
        let cache = NSCache<NSNumber, NSImage>()
        cache.countLimit = 120
        return cache
    }()

    func load(url: URL) {
        stopAndClear()
        self.url = url
        status = .loading

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        self.player = player

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 0)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(seconds: 1, preferredTimescale: 600)
        imageGenerator = FrameGenerator(generator: generator)

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                if !self.isScrubbing, time.seconds.isFinite {
                    self.currentTime = time.seconds
                }
                self.isPlaying = self.player?.timeControlStatus != .paused
            }
        }

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            let failed = item.status == .failed
            let failure = item.error?.localizedDescription
            let ready = item.status == .readyToPlay
            // AVFoundation doesn't promise main-thread KVO delivery.
            Task { @MainActor [weak self] in
                guard let self, self.url == url else { return }
                if failed {
                    self.fail(failure)
                } else if ready, self.status == .loading {
                    self.status = .ready
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.isPlaying = false }
        }

        Task {
            do {
                let (playable, loadedDuration) = try await asset.load(.isPlayable, .duration)
                guard self.url == url else { return }
                duration = loadedDuration.seconds.isFinite ? loadedDuration.seconds : 0
                if !playable {
                    fail(nil)
                }
            } catch {
                guard self.url == url else { return }
                fail(error.localizedDescription)
            }
        }
    }

    func play() {
        guard let player else { return }
        if case .failed = status { return }
        if duration > 0, currentTime >= duration - 0.25 {
            seek(to: 0)
        }
        player.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
        isScrubbing = false
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func seek(to seconds: Double) {
        guard duration > 0 else { return }
        let clamped = max(0, min(duration, seconds))
        player?.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = clamped
    }

    func seekToPercent(_ percent: Double) {
        seek(to: percent * duration)
    }

    func seekRelative(_ delta: Double) {
        seek(to: currentTime + delta)
    }

    /// Live scrubbing: approximate seeks while dragging, an exact one on release.
    func scrub(to seconds: Double, finished: Bool) {
        guard duration > 0 else { return }
        let clamped = max(0, min(duration, seconds))
        if finished {
            isScrubbing = false
            seek(to: clamped)
        } else {
            isScrubbing = true
            currentTime = clamped
            let tolerance = CMTime(seconds: 0.3, preferredTimescale: 600)
            player?.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: tolerance, toleranceAfter: tolerance)
        }
    }

    /// A frame near `time`, generated off the main thread and cached per second.
    func thumbnail(at time: Double) async -> NSImage? {
        guard let generator = imageGenerator, duration > 0 else { return nil }
        let second = Int(max(0, min(duration, time)).rounded(.down))
        if let cached = thumbnailCache.object(forKey: NSNumber(value: second)) {
            return cached
        }
        let requested = url
        do {
            let image = try await generator.generator.image(at: CMTime(seconds: Double(second), preferredTimescale: 600)).image
            guard url == requested else { return nil }
            let thumbnail = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            thumbnailCache.setObject(thumbnail, forKey: NSNumber(value: second))
            return thumbnail
        } catch {
            return nil
        }
    }

    func stopAndClear() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        statusObservation = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil

        imageGenerator?.generator.cancelAllCGImageGeneration()
        player?.pause()
        player = nil
        url = nil
        imageGenerator = nil
        thumbnailCache.removeAllObjects()
        status = .idle
        duration = 0
        currentTime = 0
        isPlaying = false
        isScrubbing = false
    }

    private func fail(_ reason: String?) {
        guard status != .idle else { return }
        if case .failed = status { return }
        player?.pause()
        isPlaying = false
        if let reason {
            Log.app.error("Playback failed for \(self.url?.lastPathComponent ?? "", privacy: .public): \(reason, privacy: .public)")
        }
        status = .failed(Self.failureMessage(for: url, reason: reason))
    }

    /// AVFoundation's own errors ("Cannot Open") don't explain anything, so lead with the likely cause.
    private static func failureMessage(for url: URL?, reason: String?) -> String {
        let ext = url?.pathExtension.lowercased() ?? ""
        if ["mkv", "avi", "wmv", "webm", "flv"].contains(ext) {
            return "macOS can’t play .\(ext) files. Open it in an app that supports this format, or re-encode it to MP4."
        }
        if let reason, !reason.isEmpty, reason != "Cannot Open" {
            return "The video couldn’t be opened. \(reason)"
        }
        return "The video couldn’t be opened. The file may be damaged or use an unsupported codec."
    }
}
