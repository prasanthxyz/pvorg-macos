import SwiftUI

struct ChipSelectorView: View {
    let label: String
    let items: [String]
    @Binding var selected: Set<String>
    var onSelectionChanged: () -> Void
    var contextMenuProvider: ((String) -> AnyView)? = nil

    private let columns: [GridItem] = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.headline)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Button {
                        if selected.contains(item) {
                            selected.remove(item)
                        } else {
                            selected.insert(item)
                        }
                        onSelectionChanged()
                    } label: {
                        Text(item)
                            .lineLimit(1)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(selected.contains(item) ? Color.accentTheme : Color.tagBg)
                            .foregroundStyle(selected.contains(item) ? .white : .secondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .ifLet(contextMenuProvider) { view, provider in
                        view.contextMenu {
                            provider(item)
                        }
                    }
                }
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func ifLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}
