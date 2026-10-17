import AppKit
import SwiftUI

struct LibraryView: View {
    @Environment(AppState.self) private var appState
    @Environment(LibraryModel.self) private var library
    @Environment(ToastCenter.self) private var toasts
    @Environment(KeyboardContext.self) private var keyboard

    @State private var showsSkippedFiles = false

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: Spacing.lg, alignment: .top)]

    var body: some View {
        @Bindable var library = library
        let visible = library.visibleVideos(in: appState)

        content(visible: visible)
            .navigationTitle("Library")
            .navigationSubtitle(subtitle(visibleCount: visible.count))
            .searchable(text: $library.query, placement: .toolbar, prompt: "Search Videos")
            .toolbar { toolbarContent(visible: visible) }
            .confirmationDialog(
                deletionTitle,
                isPresented: Binding(
                    get: { !library.pendingDeletion.isEmpty },
                    set: { if !$0 { library.pendingDeletion = [] } }
                ),
                titleVisibility: .visible
            ) {
                Button(deletionTitle.replacingOccurrences(of: "?", with: ""), role: .destructive) {
                    performDelete(library.pendingDeletion)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(deletionMessage)
            }
            .onAppear(perform: pruneSelection)
            .onChange(of: appState.libraryRevision) { _, _ in pruneSelection() }
            // What you see is what you delete: refining the search drops hidden videos from the selection.
            .onChange(of: library.query) { _, _ in pruneSelection() }
    }

    @ViewBuilder
    private func content(visible: [Video]) -> some View {
        if appState.videos.isEmpty {
            ContentUnavailableView {
                Label("No Videos", systemImage: "film.stack")
            } description: {
                if appState.skippedFiles.isEmpty {
                    Text("Add videos named studio-cast-title to \(abbreviated(appState.config?.videosPath)), then reload the library.")
                } else {
                    Text("\(appState.skippedFiles.count.counted("file was", "files were")) skipped because the names don’t follow the studio-cast-title format.")
                }
            } actions: {
                Button("Reload Library") { reloadLibrary(appState) }
                if !appState.skippedFiles.isEmpty {
                    showSkippedFilesButton("Show Skipped Files")
                }
            }
        } else if visible.isEmpty {
            ContentUnavailableView.search(text: library.query)
        } else {
            ScrollView {
                // The notice lives inside the scroll view: a fixed view above it at the
                // top of a split-view detail column misplaces the sidebar on macOS 26+.
                if !appState.skippedFiles.isEmpty {
                    skippedFilesBanner
                }
                LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.xl) {
                    ForEach(visible) { video in
                        VideoCardView(
                            video: video,
                            tgpURL: appState.tgpURL(for: video.filename),
                            isSelected: library.selection.contains(video.filename),
                            onToggle: {
                                withAnimation(.snappy(duration: 0.18)) {
                                    library.toggle(video.filename)
                                }
                            }
                        )
                        .contextMenu { contextMenu(for: video) }
                    }
                }
                .padding(Spacing.xl)
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private func toolbarContent(visible: [Video]) -> some ToolbarContent {
        let visibleNames = Set(visible.map(\.filename))
        let allVisibleSelected = !visibleNames.isEmpty && visibleNames.isSubset(of: library.selection)

        ToolbarItem {
            Button("Select All", systemImage: "checkmark.circle") {
                library.selection.formUnion(visibleNames)
            }
            .plainKeyShortcut("a", modifiers: .command, enabled: !keyboard.isEditingText)
            .help(library.query.isEmpty ? "Select every video (⌘A)" : "Select every matching video (⌘A)")
            .disabled(visible.isEmpty || allVisibleSelected)
        }

        ToolbarItem {
            Button("Deselect All", systemImage: "xmark.circle") {
                library.selection.removeAll()
            }
            .plainKeyShortcut(.escape, enabled: !keyboard.isEditingText)
            .help("Deselect all videos (Esc)")
            .disabled(library.selection.isEmpty)
        }

        ToolbarItem {
            Button(role: .destructive) {
                library.pendingDeletion = library.selection.sorted()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .plainKeyShortcut(.delete, modifiers: .command, enabled: !keyboard.isEditingText)
            .help("Delete the selected videos (⌘⌫)")
            .disabled(library.selection.isEmpty)
        }
    }

    @ViewBuilder
    private func contextMenu(for video: Video) -> some View {
        let isSelected = library.selection.contains(video.filename)
        Button(isSelected ? "Deselect" : "Select") {
            library.toggle(video.filename)
        }
        Button("Reveal in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([video.fileURL])
        }
        Divider()
        if isSelected && library.selection.count > 1 {
            Button("Delete \(library.selection.count.counted("Video"))…", role: .destructive) {
                library.pendingDeletion = library.selection.sorted()
            }
        } else {
            Button("Delete “\(DisplayName.title(for: video))”…", role: .destructive) {
                library.pendingDeletion = [video.filename]
            }
        }
    }

    // MARK: Skipped files

    private var skippedFilesBanner: some View {
        Callout(
            tone: .warning,
            title: "\(appState.skippedFiles.count.counted("file")) skipped",
            message: "Names must be lowercase, without spaces, in the form studio-cast-title."
        ) {
            showSkippedFilesButton("Show Files")
                .controlSize(.small)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.lg)
    }

    private func showSkippedFilesButton(_ title: String) -> some View {
        Button(title) { showsSkippedFiles = true }
            .popover(isPresented: $showsSkippedFiles, arrowEdge: .bottom) {
                SkippedFilesList(files: appState.skippedFiles)
            }
    }

    // MARK: Actions

    private func performDelete(_ filenames: [String]) {
        library.pendingDeletion = []
        do {
            let result = try appState.deleteVideos(filenames)
            library.selection.subtract(filenames)
            if result.errors.isEmpty {
                toasts.show("Deleted \(result.deletedCount.counted("video"))", systemImage: "trash")
            } else {
                appState.appNotice = AppNotice(
                    title: "Some Videos Couldn’t Be Deleted",
                    message: "Deleted \(result.deletedCount.counted("video")).\n\n" + result.errors.joined(separator: "\n")
                )
            }
        } catch {
            appState.appNotice = AppNotice(title: "Delete Failed", message: error.localizedDescription)
        }
    }

    // MARK: Text

    private var deletionTitle: String {
        let count = library.pendingDeletion.count
        if count == 1, let video = appState.videos.first(where: { $0.filename == library.pendingDeletion[0] }) {
            return "Delete “\(DisplayName.title(for: video))”?"
        }
        return "Delete \(count.counted("Video"))?"
    }

    private var deletionMessage: String {
        let consequence = "The video files, their contact sheets, mapping decisions and cached metadata will be permanently removed. This can’t be undone."
        let names = library.pendingDeletion.compactMap { filename in
            appState.videos.first { $0.filename == filename }.map(DisplayName.title(for:))
        }
        guard names.count > 1, names.count <= 6 else { return consequence }
        return ListFormatter.localizedString(byJoining: names) + ".\n\n" + consequence
    }

    private func pruneSelection() {
        library.prune(keeping: Set(library.visibleVideos(in: appState).map(\.filename)))
    }

    private func subtitle(visibleCount: Int) -> String {
        if !library.selection.isEmpty {
            return "\(library.selection.count.formatted()) of \(appState.videos.count.counted("video")) selected"
        }
        if !library.query.trimmingCharacters(in: .whitespaces).isEmpty {
            return "\(visibleCount.formatted()) of \(appState.videos.count.counted("video"))"
        }
        return appState.videos.count.counted("video")
    }

    private func abbreviated(_ path: String?) -> String {
        guard let path else { return "the videos folder" }
        return (path as NSString).abbreviatingWithTildeInPath
    }
}

private struct SkippedFilesList: View {
    let files: [SkippedFile]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Skipped Files")
                .font(.headline)
                .padding([.horizontal, .top], Spacing.lg)
                .padding(.bottom, Spacing.sm)
            List(files) { file in
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(file.filename)
                        .font(.callout.weight(.medium))
                        .textSelection(.enabled)
                    Text(file.reasons.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, Spacing.xxs)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 380, height: min(80 + CGFloat(files.count) * 44, 360))
    }
}
