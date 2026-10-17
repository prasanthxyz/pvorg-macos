import SwiftUI

/// A toggleable token. State is carried by the leading symbol as well as the
/// tint, so it never relies on color alone, and both states share one width
/// so toggling never reflows the surrounding layout.
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs + 1) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.callout)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.6))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.callout)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.leading, Spacing.sm - 1)
            .padding(.trailing, Spacing.sm + 2)
            .padding(.vertical, Spacing.xs + 1)
            .background(background, in: RoundedRectangle(cornerRadius: Radius.small + 1, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Radius.small + 1, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var background: Color {
        if isSelected {
            return Color.accentColor.opacity(isHovering ? 0.24 : 0.17)
        }
        return isHovering ? .subtleFillHover : .subtleFill
    }
}
