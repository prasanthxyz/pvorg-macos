import SwiftUI

extension TriState {
    var systemImage: String {
        switch self {
        case .yes: "checkmark"
        case .no: "xmark"
        case .undecided: "minus"
        }
    }

    var tint: Color {
        switch self {
        case .yes: .decisionYes
        case .no: .decisionNo
        case .undecided: .secondary
        }
    }

    var fill: Color {
        switch self {
        case .yes: Color.decisionYes.opacity(0.18)
        case .no: Color.decisionNo.opacity(0.16)
        case .undecided: Color.subtleFill
        }
    }
}

/// The glyph used in cells and in the legend.
struct TriStateBadge: View {
    let state: TriState
    var isModified = false
    var size = CGSize(width: 30, height: 22)

    var body: some View {
        Image(systemName: state.systemImage)
            .font(.system(size: size.height * 0.5, weight: .bold))
            .foregroundStyle(state.tint)
            .frame(width: size.width, height: size.height)
            .background(state.fill, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            .overlay {
                if isModified {
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .strokeBorder(Color.pendingChange, lineWidth: 1.5)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isModified {
                    Circle()
                        .fill(Color.pendingChange)
                        .frame(width: 6, height: 6)
                        .offset(x: 2, y: -2)
                }
            }
    }
}

/// One matrix cell. The whole cell is the hit target; clicking cycles
/// undecided → yes → no → undecided.
struct TriStateCell: View {
    let state: TriState
    let isModified: Bool
    let accessibilityName: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            TriStateBadge(state: state, isModified: isModified)
                .scaleEffect(isHovering ? 1.08 : 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.1), value: isHovering)
        .help("\(state.title) – click to change")
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(isModified ? "\(state.title), unsaved" : state.title)
        .accessibilityHint("Cycles between undecided, yes and no")
    }
}
