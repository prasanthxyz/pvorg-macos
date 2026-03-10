import AppKit
import AVFoundation
import Observation

@Observable
@MainActor
final class VideoPlayerState {
    var player: AVPlayer?
    var asset: AVAsset?
    var imageGenerator: AVAssetImageGenerator?
    var duration: Double = 0
    var currentTime: Double = 0
    var isPlaying: Bool = false

    private var timeObserver: Any?

    func load(url: URL) {
        stopAndClear()

        let asset = AVAsset(url: url)
        self.asset = asset

        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        self.player = player

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 0)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(seconds: 1, preferredTimescale: 600)
        self.imageGenerator = generator

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.currentTime = time.seconds
            }
        }

        Task {
            do {
                let loadedDuration = try await asset.load(.duration)
                self.duration = loadedDuration.seconds
            } catch {
                self.duration = 0
            }
        }
    }

    func play() {
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func seek(to seconds: Double) {
        guard duration > 0 else { return }
        let clamped = max(0, min(duration, seconds))
        let target = CMTime(seconds: clamped, preferredTimescale: 600)
        player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = clamped
    }

    func seekToPercent(_ percent: Double) {
        seek(to: percent * duration)
    }

    func seekRelative(_ delta: Double) {
        seek(to: currentTime + delta)
    }

    func thumbnail(at time: Double) async -> NSImage? {
        guard let generator = imageGenerator else { return nil }
        let clamped = max(0, min(duration, time))
        let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)

        do {
            var actualTime = CMTime.zero
            let cgImage = try generator.copyCGImage(at: cmTime, actualTime: &actualTime)
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } catch {
            return nil
        }
    }

    func stopAndClear() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil

        player?.pause()
        player = nil
        asset = nil
        imageGenerator = nil
        duration = 0
        currentTime = 0
        isPlaying = false
    }

}
