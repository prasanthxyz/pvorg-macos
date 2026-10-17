import AppKit
import SwiftUI

/// Shows a large floating contact sheet near the pointer while hovering a
/// thumbnail. Like tooltips, the first preview waits briefly so sweeping the
/// pointer across a grid doesn't flash panels; once one is showing, moving to
/// a neighbor swaps instantly.
struct HoverPreviewModifier: ViewModifier {
    let imageURL: URL?

    func body(content: Content) -> some View {
        content
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    if let imageURL {
                        HoverPreviewWindow.shared.hover(imageURL)
                    } else {
                        HoverPreviewWindow.shared.hide()
                    }
                case .ended:
                    HoverPreviewWindow.shared.hide()
                }
            }
            .onDisappear {
                HoverPreviewWindow.shared.hide()
            }
    }
}

extension View {
    func hoverPreview(imageURL: URL?) -> some View {
        modifier(HoverPreviewModifier(imageURL: imageURL))
    }
}

@MainActor
private final class HoverPreviewWindow {
    static let shared = HoverPreviewWindow()

    private let maxSize = NSSize(width: 920, height: 518)
    private let inset: CGFloat = 6
    private let initialDelay: Duration = .milliseconds(220)
    /// After hiding, a new hover within this window shows immediately.
    private let warmInterval: TimeInterval = 0.4

    private let panel: NSPanel
    private let imageView: NSImageView
    private var hoveredURL: URL?
    private var showTask: Task<Void, Never>?
    private var lastHidden = Date.distantPast

    private init() {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: maxSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .popUpMenu
        panel.isFloatingPanel = true
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: maxSize))
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = Radius.large
        background.layer?.cornerCurve = .continuous
        background.layer?.masksToBounds = true
        background.layer?.borderColor = NSColor.white.withAlphaComponent(0.14).cgColor
        background.layer?.borderWidth = 1

        imageView = NSImageView(frame: background.bounds.insetBy(dx: inset, dy: inset))
        imageView.autoresizingMask = [.width, .height]
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = Radius.medium
        imageView.layer?.cornerCurve = .continuous
        imageView.layer?.masksToBounds = true
        background.addSubview(imageView)

        panel.contentView = background
    }

    func hover(_ url: URL) {
        if panel.isVisible, hoveredURL == url {
            positionNearMouse()
            return
        }
        hoveredURL = url
        showTask?.cancel()

        let isWarm = panel.isVisible || Date().timeIntervalSince(lastHidden) < warmInterval
        showTask = Task { [weak self, initialDelay] in
            if !isWarm {
                try? await Task.sleep(for: initialDelay)
            }
            guard let self, !Task.isCancelled, self.hoveredURL == url else { return }
            guard let image = await ImagePipeline.shared.image(for: url, maxPixelSize: ImageSize.large) else {
                self.hide()
                return
            }
            guard !Task.isCancelled, self.hoveredURL == url else { return }
            self.imageView.image = image
            self.positionNearMouse(fitting: image.size)
            self.panel.orderFrontRegardless()
        }
    }

    func hide() {
        showTask?.cancel()
        showTask = nil
        hoveredURL = nil
        if panel.isVisible {
            lastHidden = Date()
        }
        panel.orderOut(nil)
    }

    private func positionNearMouse(fitting imageSize: NSSize? = nil) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame

        var size = panel.frame.size
        if let imageSize, imageSize.width > 0, imageSize.height > 0 {
            // Size the panel to the image's aspect ratio, capped to the max size and the screen.
            let limit = NSSize(width: min(maxSize.width, visible.width * 0.6), height: min(maxSize.height, visible.height * 0.7))
            let scale = min(limit.width / imageSize.width, limit.height / imageSize.height)
            size = NSSize(width: (imageSize.width * scale).rounded() + inset * 2, height: (imageSize.height * scale).rounded() + inset * 2)
        }

        var x = mouse.x + 24
        var y = mouse.y - size.height - 18
        if x + size.width > visible.maxX - 8 { x = mouse.x - size.width - 24 }
        if x < visible.minX + 8 { x = visible.minX + 8 }
        if y < visible.minY + 8 { y = mouse.y + 24 }
        if y + size.height > visible.maxY - 8 { y = visible.maxY - size.height - 8 }

        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}
