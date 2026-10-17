import SwiftUI

struct Sidebar: View {
    @Environment(AppState.self) private var appState
    @Environment(AppNavigation.self) private var navigation
    @Environment(MappingStore.self) private var mappings

    var body: some View {
        List(selection: selection) {
            ForEach(Page.Group.allCases, id: \.self) { group in
                Section(group.rawValue) {
                    ForEach(Page.allCases.filter { $0.group == group }) { page in
                        row(for: page)
                    }
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 280)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            librarySummary
        }
    }

    @ViewBuilder
    private func row(for page: Page) -> some View {
        let label = Label(page.title, systemImage: page.systemImage)
            .tag(page)
            .help(page.shortcut.map { "\(page.title) (\(String($0.character).uppercased()))" } ?? page.title)

        if let kind = page.mappingKind, mappings.session(kind).changeCount > 0 {
            label
                .badge(mappings.session(kind).changeCount)
                .accessibilityValue("\(mappings.session(kind).changeCount.counted("unsaved change"))")
        } else {
            label
        }
    }

    private var selection: Binding<Page?> {
        Binding(
            get: { navigation.page },
            set: { if let page = $0 { navigation.page = page } }
        )
    }

    private var librarySummary: some View {
        HStack(spacing: Spacing.xs + 2) {
            Image(systemName: "film.stack")
                .foregroundStyle(.tertiary)
            Text("\(appState.videos.count.counted("video")) · \(appState.galleries.count.counted("gallery", "galleries"))")
                .lineLimit(1)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .accessibilityElement(children: .combine)
    }
}
