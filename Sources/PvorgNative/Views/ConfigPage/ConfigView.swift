import SwiftUI

struct ConfigView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ChipSelectorView(
                        label: "Galleries",
                        items: appState.allGalleryNames,
                        selected: binding(\.selectedGalleries),
                        onSelectionChanged: { appState.regenerateCombinations() },
                        contextMenuProvider: { name in
                            AnyView(galleryContextMenu(name: name))
                        }
                    )

                    ChipSelectorView(
                        label: "Tags",
                        items: appState.allTags,
                        selected: binding(\.selectedTags),
                        onSelectionChanged: { appState.regenerateCombinations() }
                    )

                    ChipSelectorView(
                        label: "Studios",
                        items: appState.allStudios,
                        selected: binding(\.selectedStudios),
                        onSelectionChanged: { appState.regenerateCombinations() }
                    )

                    ChipSelectorView(
                        label: "Cast",
                        items: appState.allCast,
                        selected: binding(\.selectedCast),
                        onSelectionChanged: { appState.regenerateCombinations() }
                    )
                }
                .padding(20)
            }

            Divider().overlay(Color.border)

            VStack(alignment: .leading, spacing: 10) {
                Text("Sample Combinations (\(appState.combinations.count) total)")
                    .font(.headline)

                if appState.combinations.isEmpty {
                    Text("No combinations")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(Array(appState.combinations.prefix(10))) { combo in
                                HStack(spacing: 8) {
                                    Text(combo.video.filename)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Text(combo.gallery.name)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.tagBg)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
            .frame(width: 340)
            .padding(16)
        }
        .background(Color.bgPrimary)
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<AppState, Set<String>>) -> Binding<Set<String>> {
        Binding(
            get: { appState[keyPath: keyPath] },
            set: { appState[keyPath: keyPath] = $0 }
        )
    }

    @ViewBuilder
    private func galleryContextMenu(name: String) -> some View {
        if appState.selectedGalleries.contains(name) {
            Button("Select all except \(name)") {
                appState.selectedGalleries = Set(appState.allGalleryNames).subtracting([name])
                appState.regenerateCombinations()
            }
        } else {
            Button("Select only \(name)") {
                appState.selectedGalleries = [name]
                appState.regenerateCombinations()
            }
        }
    }
}
