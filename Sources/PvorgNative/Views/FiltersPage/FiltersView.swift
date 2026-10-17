import SwiftUI

struct FiltersView: View {
    @Environment(AppState.self) private var appState

    @State private var query = ""
    @State private var showsPreview = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                section(
                    title: "Galleries",
                    explanation: "Videos are paired only with the galleries you include.",
                    mode: .include,
                    values: appState.allGalleryNames,
                    label: { $0 },
                    selection: \.selectedGalleries,
                    emptyMessage: "No gallery folders were found."
                )
                section(
                    title: "Studios",
                    explanation: "Only videos from the studios you include are shown.",
                    mode: .include,
                    values: appState.allStudios,
                    label: DisplayName.humanize,
                    selection: \.selectedStudios,
                    emptyMessage: "No videos were found."
                )
                section(
                    title: "Tags",
                    explanation: "Only videos marked Yes for every selected tag in Tag Mapping are shown.",
                    mode: .require,
                    values: appState.allTags,
                    label: { $0 },
                    selection: \.selectedTags,
                    emptyMessage: "No tags are defined in pvorg.json."
                )
                section(
                    title: "Cast",
                    explanation: "Only videos featuring everyone selected are shown.",
                    mode: .require,
                    values: appState.allCast,
                    label: DisplayName.humanize,
                    selection: \.selectedCast,
                    emptyMessage: "No cast names were found in video filenames."
                )
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 960, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Filters")
        .navigationSubtitle(appState.combinations.count.counted("combination"))
        .searchable(text: $query, placement: .toolbar, prompt: "Filter Names")
        .toolbar {
            ToolbarItem {
                Button("Reset Filters", systemImage: "arrow.counterclockwise") {
                    appState.resetFilters()
                }
                .help("Include every gallery and studio and clear required tags and cast")
                .disabled(appState.filtersAreDefault)
            }
            ToolbarItem {
                Button {
                    showsPreview.toggle()
                } label: {
                    Label("Preview", systemImage: "sidebar.trailing")
                }
                .help(showsPreview ? "Hide Preview" : "Show Preview")
            }
        }
        .inspector(isPresented: $showsPreview) {
            CombinationPreviewView()
                .inspectorColumnWidth(min: 260, ideal: 300, max: 400)
        }
    }

    private func section(
        title: String,
        explanation: String,
        mode: FilterSectionView.Mode,
        values: [String],
        label: (String) -> String,
        selection keyPath: ReferenceWritableKeyPath<AppState, Set<String>>,
        emptyMessage: String
    ) -> FilterSectionView {
        let items = values
            .map { FilterSectionView.Item(value: $0, label: label($0)) }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let visible = trimmedQuery.isEmpty ? items : items.filter { $0.label.localizedStandardContains(trimmedQuery) }

        return FilterSectionView(
            title: title,
            explanation: explanation,
            mode: mode,
            allItems: items,
            visibleItems: visible,
            selection: appState[keyPath: keyPath],
            emptyMessage: emptyMessage
        ) { newSelection in
            appState[keyPath: keyPath] = newSelection
            appState.regenerateCombinations()
        }
    }
}

/// The inspector beside the filters: how many combinations the filters yield and a sample of them.
private struct CombinationPreviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppNavigation.self) private var navigation

    private let sampleSize = 10

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(appState.combinations.count.formatted())
                        .font(.system(.largeTitle, design: .rounded).weight(.semibold).monospacedDigit())
                        .contentTransition(.numericText())
                    Text(breakdown)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, Spacing.xs)

                Button {
                    navigation.page = .viewer
                } label: {
                    Label("Open Viewer", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(appState.combinations.isEmpty)
                .padding(.bottom, Spacing.xs)
            } header: {
                Text("Combinations")
            }

            Section {
                if appState.combinations.isEmpty {
                    Text("Nothing matches the current filters.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(upNext, id: \.combination.id) { index, combination in
                        SampleRow(combination: combination, tgpURL: appState.tgpURL(for: combination.video.filename)) {
                            appState.showCombination(at: index)
                            navigation.page = .viewer
                        }
                    }
                }
            } header: {
                Text("Up Next")
            } footer: {
                if appState.combinations.count > sampleSize {
                    Text("Order is shuffled whenever the filters change.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    /// The combinations the viewer will show next, starting at its current position.
    private var upNext: [(index: Int, combination: Combination)] {
        let count = appState.combinations.count
        guard count > 0 else { return [] }
        return (0..<min(sampleSize, count)).map { offset in
            let index = (appState.combinationIndex + offset) % count
            return (index, appState.combinations[index])
        }
    }

    private var breakdown: String {
        let videos = Set(appState.combinations.map(\.video.filename)).count
        let galleries = Set(appState.combinations.map(\.gallery.name)).count
        return "\(videos.counted("video")) · \(galleries.counted("gallery", "galleries"))"
    }
}

private struct SampleRow: View {
    let combination: Combination
    let tgpURL: URL?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm + 2) {
                AsyncThumbnail(url: tgpURL)
                    .frame(width: 64, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(DisplayName.title(for: combination.video))
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(combination.gallery.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Show in Viewer")
        .accessibilityLabel("\(DisplayName.title(for: combination.video)) with \(combination.gallery.name)")
        .accessibilityHint("Opens this combination in the viewer")
    }
}
