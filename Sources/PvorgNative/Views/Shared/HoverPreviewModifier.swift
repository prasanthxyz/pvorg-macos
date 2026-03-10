import AppKit
import SwiftUI

struct HoverPreviewModifier: ViewModifier {
    let imageURL: URL?

    func body(content: Content) -> some View {
        content
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    Task { @MainActor in
                        guard let imageURL else {
                            HoverPreviewWindow.shared.hide()
                            return
                        }
                        HoverPreviewWindow.shared.show(imageURL: imageURL)
                    }
                case .ended:
                    Task { @MainActor in
                        HoverPreviewWindow.shared.hide()
                    }
                }
            }
            .onDisappear {
                Task { @MainActor in
                    HoverPreviewWindow.shared.hide()
                }
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

    private let previewSize = NSSize(width: 920, height: 518)
    private let panel: NSPanel
    private let containerView: NSView
    private let imageView: NSImageView
    private let imageCache = NSCache<NSString, NSImage>()

    private init() {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: previewSize),
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
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        containerView = NSView(frame: NSRect(origin: .zero, size: previewSize))
        containerView.wantsLayer = true
        containerView.layer?.masksToBounds = true
        containerView.layer?.cornerRadius = 10
        containerView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.96).cgColor
        containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.35).cgColor
        containerView.layer?.borderWidth = 1

        let imageFrame = containerView.bounds.insetBy(dx: 12, dy: 12)
        imageView = NSImageView(frame: imageFrame)
        imageView.autoresizingMask = [.width, .height]
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(imageView)

        panel.contentView = containerView
    }

    func show(imageURL: URL) {
        let key = imageURL.path as NSString
        let image: NSImage
        if let cached = imageCache.object(forKey: key) {
            image = cached
        } else {
            guard let loaded = NSImage(contentsOf: imageURL) else {
                hide()
                return
            }
            imageCache.setObject(loaded, forKey: key)
            image = loaded
        }

        imageView.image = image
        positionNearMouse()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func positionNearMouse() {
        let mouse = NSEvent.mouseLocation
        let screen = screen(containing: mouse) ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        let visible = screen.visibleFrame
        let width = previewSize.width
        let height = previewSize.height

        var x = mouse.x + 24
        var y = mouse.y - height - 18

        if x + width > visible.maxX - 8 {
            x = mouse.x - width - 24
        }
        if x < visible.minX + 8 {
            x = visible.minX + 8
        }
        if y < visible.minY + 8 {
            y = mouse.y + 24
        }
        if y + height > visible.maxY - 8 {
            y = visible.maxY - height - 8
        }

        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    private func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }
}
