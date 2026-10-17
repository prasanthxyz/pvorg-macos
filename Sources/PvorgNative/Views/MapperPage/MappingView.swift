import AppKit
import SwiftUI

/// The tri-state matrix shared by Gallery Mapping and Tag Mapping: one row per
/// video, one column per gallery or tag.
struct MappingView: View {
    let kind: MappingKind

    @Environment(AppState.self) private var appState
    @Environment(MappingStore.self) private var mappings
    @Environment(ToastCenter.self) private var toasts

    private var session: MappingSession { mappings.session(kind) }

    var body: some View {
        @Bindable var session = session

        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !session.columns.isEmpty && !appState.videos.isEmpty {
                    statusBar
                }
            }
            .navigationTitle(kind.title)
            .navigationSubtitle(subtitle)
            .searchable(text: $session.query, placement: .toolbar, prompt: "Search Videos")
            .toolbar { toolbarContent }
            .confirmationDialog(
                "Discard \(session.changeCount.counted("Unsaved Change"))?",
                isPresented: $session.confirmsRevert,
                titleVisibility: .visible
            ) {
                Button("Discard Changes", role: .destructive) { session.revert() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Cells go back to their saved decisions.")
            }
            .onAppear { session.refresh(from: appState) }
            .onChange(of: appState.libraryRevision) { _, _ in session.refresh(from: appState) }
            .onChange(of: session.query) { _, _ in session.refresh(from: appState) }
            .onChange(of: session.showsDecidedVideos) { _, _ in session.refresh(from: appState) }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if session.columns.isEmpty {
            switch kind {
            case .galleries:
                ContentUnavailableView {
                    Label("No Galleries", systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text("Add folders of images to \(abbreviated(appState.config?.galleriesPath)), then reload the library.")
                }
            case .tags:
                ContentUnavailableView {
                    Label("No Tags", systemImage: "tag")
                } description: {
                    Text("Add tag names to the “tags” list in pvorg.json, then reload the library.")
                }
            }
        } else if appState.videos.isEmpty {
            ContentUnavailableView {
                Label("No Videos", systemImage: "film.stack")
            } description: {
                Text("There’s nothing to map yet.")
            }
        } else if session.rows.isEmpty {
            if !session.query.trimmingCharacters(in: .whitespaces).isEmpty {
                ContentUnavailableView.search(text: session.query)
            } else {
                ContentUnavailableView {
                    Label("All Caught Up", systemImage: "checkmark.circle")
                } description: {
                    Text("Every video has a decision for every \(kind.columnNoun).")
                } actions: {
                    Button("Show All Videos") { session.showsDecidedVideos = true }
                }
            }
        } else {
            matrix
        }
    }

    private var matrix: some View {
        GeometryReader { geo in
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(Array(session.rows.enumerated()), id: \.element.id) { index, row in
                            MappingRowView(row: row, index: index, session: session)
                        }
                    } header: {
                        MappingHeaderView(session: session)
                    }
                }
                .padding(.bottom, Spacing.lg)
                // With few columns, header and row stripes still span the whole page.
                .frame(minWidth: geo.size.width, alignment: .leading)
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: Spacing.lg) {
            HStack(spacing: Spacing.md) {
                legendItem(.undecided)
                legendItem(.yes)
                legendItem(.no)
            }
            Text("Click a cell to cycle")
                .foregroundStyle(.tertiary)

            Spacer(minLength: Spacing.lg)

            if session.hasChanges {
                Label(session.changeCount.counted("unsaved change"), systemImage: "circle.fill")
                    .labelStyle(StatusDotLabelStyle())
                    .foregroundStyle(Color.pendingChange)
            }
            Text("\(session.rows.count.formatted()) of \(appState.videos.count.counted("video")) shown")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .font(.caption)
        .padding(.horizontal, Spacing.lg)
        .frame(height: 30)
        .background(.bar)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.hairline).frame(height: 0.5)
        }
    }

    private func legendItem(_ state: TriState) -> some View {
        HStack(spacing: Spacing.xs + 1) {
            TriStateBadge(state: state, size: CGSize(width: 18, height: 14))
            Text(state.title)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        @Bindable var session = session

        ToolbarItem {
            Picker("Show", selection: $session.showsDecidedVideos) {
                Text("Undecided").tag(false)
                Text("All").tag(true)
            }
            .pickerStyle(.segmented)
            .help("Show only videos that still need a decision, or every video")
        }
        ToolbarItem {
            Button("Revert", systemImage: "arrow.uturn.backward") {
                session.confirmsRevert = true
            }
            .help("Discard unsaved changes")
            .disabled(!session.hasChanges)
        }
        ToolbarItem {
            Button("Save") {
                save()
            }
            .modifier(ProminentToolbarButton())
            .help("Save changes to pvorg.json (⌘S)")
            .disabled(!session.hasChanges)
        }
    }

    // MARK: Actions & text

    private func save() {
        do {
            let saved = try session.save(to: appState)
            toasts.show("Saved \(saved.counted("change"))")
        } catch {
            appState.appNotice = AppNotice(title: "Couldn’t Save Changes", message: error.localizedDescription)
        }
    }

    private var subtitle: String {
        if session.hasChanges {
            return session.changeCount.counted("unsaved change")
        }
        if session.undecidedVideoCount == 0 {
            return "All videos decided"
        }
        return "\(session.undecidedVideoCount.counted("video")) need decisions"
    }

    private func abbreviated(_ path: String?) -> String {
        guard let path else { return "the galleries folder" }
        return (path as NSString).abbreviatingWithTildeInPath
    }
}

// MARK: - Matrix pieces

private enum MatrixMetrics {
    static let labelWidth: CGFloat = 300
    static let columnWidth: CGFloat = 84
    static let rowHeight: CGFloat = 52
    static let headerHeight: CGFloat = 44
}

private struct MappingHeaderView: View {
    let session: MappingSession

    var body: some View {
        HStack(spacing: 0) {
            Text("Video")
                .padding(.leading, Spacing.lg)
                .frame(width: MatrixMetrics.labelWidth, alignment: .leading)

            ForEach(session.columns, id: \.self) { column in
                Menu {
                    Section("Set all shown videos to") {
                        ForEach([TriState.yes, .no, .undecided], id: \.self) { state in
                            Button(state.title, systemImage: state.systemImage) {
                                session.set(state, column: column)
                            }
                        }
                    }
                } label: {
                    Text(column)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .frame(width: MatrixMetrics.columnWidth - Spacing.xs, height: MatrixMetrics.headerHeight)
                .frame(width: MatrixMetrics.columnWidth)
                .help("\(column) – click to set every shown video at once")
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: MatrixMetrics.headerHeight, maxHeight: MatrixMetrics.headerHeight, alignment: .leading)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.hairline).frame(height: 0.5)
        }
    }
}

private struct MappingRowView: View {
    let row: MappingVideoRow
    let index: Int
    let session: MappingSession

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {
            label
                .frame(width: MatrixMetrics.labelWidth, alignment: .leading)

            ForEach(session.columns, id: \.self) { column in
                TriStateCell(
                    state: session.state(for: row, column: column),
                    isModified: session.isModified(row, column: column),
                    accessibilityName: "\(DisplayName.title(for: row)), \(column)"
                ) {
                    session.cycle(row, column: column)
                }
                .frame(width: MatrixMetrics.columnWidth, height: MatrixMetrics.rowHeight)
            }
        }
        .frame(maxWidth: .infinity, minHeight: MatrixMetrics.rowHeight, maxHeight: MatrixMetrics.rowHeight, alignment: .leading)
        .background(rowBackground)
        .onHover { isHovering = $0 }
    }

    private var label: some View {
        HStack(spacing: Spacing.sm + 2) {
            AsyncThumbnail(url: row.tgpURL)
                .frame(width: 64, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                .hoverPreview(imageURL: row.tgpURL)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(DisplayName.title(for: row))
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(DisplayName.credits(studio: row.studio, actors: row.actors))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .help(row.filename)
        .contentShape(Rectangle())
        .contextMenu {
            Section("Set every column to") {
                ForEach([TriState.yes, .no, .undecided], id: \.self) { state in
                    Button(state.title, systemImage: state.systemImage) {
                        session.set(state, row: row)
                    }
                }
            }
            Divider()
            if let videoURL = videoURL {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([videoURL])
                }
            }
        }
    }

    private var videoURL: URL? {
        // Contact sheets live in <videos>/img/<filename>.jpg.
        row.tgpURL?.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(row.filename)
    }

    private var rowBackground: Color {
        if isHovering { return Color.accentColor.opacity(0.07) }
        return index.isMultiple(of: 2) ? .clear : Color.primary.opacity(0.03)
    }
}

private struct StatusDotLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.xs + 1) {
            configuration.icon.font(.system(size: 6))
            configuration.title
        }
    }
}
