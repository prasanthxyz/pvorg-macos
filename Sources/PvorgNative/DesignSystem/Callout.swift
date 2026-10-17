import SwiftUI

/// An inline notice that sits within a page (skipped files, risky cleanups).
struct Callout<Actions: View>: View {
    enum Tone {
        case warning
        case critical

        var tint: Color {
            switch self {
            case .warning: .orange
            case .critical: .red
            }
        }

        var systemImage: String {
            switch self {
            case .warning: "exclamationmark.triangle.fill"
            case .critical: "exclamationmark.octagon.fill"
            }
        }
    }

    let tone: Tone
    let title: String
    let message: String
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm + 2) {
            Image(systemName: tone.systemImage)
                .foregroundStyle(tone.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            actions
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 2)
        .background(tone.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .strokeBorder(tone.tint.opacity(0.25), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
    }
}

extension Callout where Actions == EmptyView {
    init(tone: Tone, title: String, message: String) {
        self.init(tone: tone, title: title, message: message) { EmptyView() }
    }
}
