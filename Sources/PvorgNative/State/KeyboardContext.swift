import AppKit
import Observation
import SwiftUI

/// Dispatches the app's single-key shortcuts (`PlainKeyCommand`: V, C, P, B, N,
/// Space, arrows, digits) against live state, and keeps them from swallowing
/// typing: while text is being edited, or while a sheet or Settings has focus,
/// those keys go straight to the focused control. Either way menus never see
/// these keys, so their possibly stale key equivalents can't misfire.
/// `isEditingText` also lets views withdraw their own shortcuts (⌘A, ⌘⌫).
@Observable
@MainActor
final class KeyboardContext {
    /// The main window's first responder is a text field's editor.
    private(set) var isEditingText = false

    /// Where plain-key commands are performed; set once the app's models exist.
    @ObservationIgnored var commands: CommandContext?

    @ObservationIgnored weak var mainWindow: NSWindow? {
        didSet {
            guard mainWindow !== oldValue else { return }
            responderObservation = mainWindow?.observe(\.firstResponder, options: [.initial, .new]) { [weak self] window, _ in
                MainActor.assumeIsolated {
                    self?.isEditingText = window.firstResponder is NSText
                }
            }
        }
    }

    @ObservationIgnored private var responderObservation: NSKeyValueObservation?
    @ObservationIgnored private var monitor: Any?

    init() {
        // Local monitors run on the main thread before the event is dispatched.
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            nonisolated(unsafe) let event = event
            let delivered = MainActor.assumeIsolated {
                self?.deliverToFocusedControl(event) ?? false
            }
            return delivered ? nil : event
        }
    }

    /// Handles a plain shortcut key: performs its command when it applies,
    /// otherwise delivers it to the focused control. Returns whether the key
    /// was one of the app's plain shortcut keys (and so has been handled).
    private func deliverToFocusedControl(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
              let characters = event.charactersIgnoringModifiers?.lowercased(),
              let command = PlainKeyCommand(characters: characters),
              let window = event.window ?? NSApp.keyWindow else {
            return false
        }
        let isTyping = window.firstResponder is NSText
        if !isTyping, window === mainWindow, let commands, commands.isAvailable(command) {
            commands.perform(command)
            return true
        }
        // NSWindow.sendEvent delivers keyDown to the first responder without
        // consulting menu key equivalents.
        window.sendEvent(event)
        return true
    }
}

extension View {
    /// A shortcut that is withdrawn while `enabled` is false, so the key reaches
    /// whatever else wants it (a list, a text field).
    func plainKeyShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = [], enabled: Bool) -> some View {
        keyboardShortcut(enabled ? KeyboardShortcut(key, modifiers: modifiers) : nil)
    }
}

/// Reports the hosting `NSWindow` once the view is installed in one.
struct WindowReader: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        ReaderView(onWindow: onWindow)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ReaderView: NSView {
        let onWindow: (NSWindow) -> Void

        init(onWindow: @escaping (NSWindow) -> Void) {
            self.onWindow = onWindow
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { onWindow(window) }
        }
    }
}
