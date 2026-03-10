import SwiftUI

struct TriStateButtonView: View {
    let state: TriState
    let isModified: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(state.symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(state.foregroundColor)
                .frame(width: 32, height: 24)
                .background(state.backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isModified ? Color.stateChanged : Color.clear, lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
    }
}
