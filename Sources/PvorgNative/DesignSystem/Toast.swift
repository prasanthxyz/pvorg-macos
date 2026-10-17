import SwiftUI

/// Transient confirmation for completed actions ("Deleted 3 videos"). Errors
/// use alerts instead, because they need acknowledgement.
@Observable
@MainActor
final class ToastCenter {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let systemImage: String
        var actionTitle: String?
        var action: (@MainActor () -> Void)?

        static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
    }

    private(set) var current: Toast?
    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    /// Shows a confirmation. With an action (e.g. Undo) it stays up longer so there's time to use it.
    func show(_ message: String, systemImage: String = "checkmark.circle.fill", actionTitle: String? = nil, action: (@MainActor () -> Void)? = nil) {
        let toast = Toast(message: message, systemImage: systemImage, actionTitle: actionTitle, action: action)
        current = toast
        AccessibilityNotification.Announcement(message).post()

        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(action == nil ? 2.6 : 6))
            guard !Task.isCancelled, self?.current == toast else { return }
            self?.current = nil
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }
}

struct ToastOverlay: View {
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let toast = toasts.current {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: toast.systemImage)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    Text(toast.message)
                        .font(.callout.weight(.medium))
                        .lineLimit(2)
                    if let title = toast.actionTitle, let action = toast.action {
                        Button(title) {
                            action()
                            toasts.dismiss()
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Color.accentColor)
                        .fontWeight(.semibold)
                        .padding(.leading, Spacing.xs)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm + 2)
                .modifier(FloatingSurface(cornerRadius: Radius.large))
                .id(toast.id)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.2), value: toasts.current)
        .padding(.bottom, Spacing.xl)
        .allowsHitTesting(toasts.current?.action != nil)
    }
}

/// Background for small floating surfaces (toasts, hover cards): glass on
/// macOS 26 and later, a material with a hairline and soft shadow before that.
struct FloatingSurface: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.hairline, lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        }
    }
}
