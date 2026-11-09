import SwiftUI

struct ViewerView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppNavigation.self) private var navigation
    @Environment(ViewerModel.self) private var viewer
    @Environment(MappingStore.self) private var mappings
    @Environment(ToastCenter.self) private var toasts
    @Environment(KeyboardContext.self) private var keyboard

    private var commands: CommandContext {
        CommandContext(appState: appState, navigation: navigation, viewer: viewer, mappings: mappings, toasts: toasts, keyboard: keyboard)
    }

    var body: some View {
        Group {
            if let combination = appState.currentCombination {
                stage(for: combination)
            } else {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.stage)
            }
        }
        // The stage is always dark, so everything on it renders with dark-appearance colors.
        .environment(\.colorScheme, .dark)
        .navigationTitle(title)
        .navigationSubtitle(subtitle)
        .toolbar { toolbarContent }
        .onChange(of: appState.currentCombination?.id) { _, _ in
            viewer.reset()
            prefetchNext()
        }
        .onAppear(perform: prefetchNext)
        .onDisappear {
            viewer.reset()
        }
    }

    // MARK: Stage

    private func stage(for combination: Combination) -> some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ZStack {
                    switch viewer.mode {
                    case .contactSheet:
                        contactSheet(for: combination)
                    case .video:
                        VideoPlayerView(playerState: viewer.player) {
                            viewer.show(.contactSheet, for: combination)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Rectangle()
                    .fill(Color.stageHairline)
                    .frame(width: 1)

                GallerySlideshowView(gallery: combination.gallery)
                    .frame(width: (geo.size.width * 0.25).rounded())
            }
        }
        .background(Color.stage)
        .contextMenu { stageMenu(for: combination) }
    }

    @ViewBuilder
    private func stageMenu(for combination: Combination) -> some View {
        Button("Exclude “\(combination.gallery.name)” from This Video", systemImage: "hand.thumbsdown") {
            commands.excludeCurrentPairing()
        }
        Divider()
        Button("Reveal Video in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([combination.video.fileURL])
        }
        if let firstImage = combination.gallery.imageFiles.first {
            Button("Reveal Gallery in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([firstImage.deletingLastPathComponent()])
            }
        }
    }

    @ViewBuilder
    private func contactSheet(for combination: Combination) -> some View {
        let url = appState.tgpURL(for: combination.video.filename)
        if let url, FileManager.default.fileExists(atPath: url.path) {
            AsyncThumbnail(url: url, maxPixelSize: ImageSize.full, contentMode: .fit, placeholder: .clear)
                .id(url)
                .padding(Spacing.lg)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    viewer.show(.video, for: combination)
                }
                .accessibilityLabel("Contact sheet for \(DisplayName.title(for: combination.video))")
                .accessibilityHint("Double-click to play the video")
        } else {
            ContentUnavailableView {
                Label("No Contact Sheet", systemImage: "square.grid.3x3")
            } description: {
                Text("A preview couldn’t be generated for this video. Reloading the library tries again.")
            } actions: {
                Button("Play Video") {
                    viewer.show(.video, for: combination)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Button {
                commands.excludeCurrentPairing()
            } label: {
                Label("Exclude Pairing", systemImage: "hand.thumbsdown")
            }
            .help(excludeHelp)
            .disabled(appState.currentCombination == nil)
        }

        ToolbarItem {
            Picker("Display", selection: modeBinding) {
                Label("Contact Sheet", systemImage: "square.grid.3x3")
                    .tag(ViewerModel.Mode.contactSheet)
                Label("Video", systemImage: "play.rectangle")
                    .tag(ViewerModel.Mode.video)
            }
            .pickerStyle(.segmented)
            .labelStyle(.iconOnly)
            .help("Switch between the contact sheet and the video (P)")
            .disabled(appState.currentCombination == nil)
        }

        ToolbarItem {
            ControlGroup {
                Button {
                    appState.previousCombination()
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .help("Previous combination (B)")

                Button {
                    appState.nextCombination()
                } label: {
                    Label("Next", systemImage: "chevron.right")
                }
                .help("Next combination (N)")
            } label: {
                Label("Navigate", systemImage: "chevron.left.chevron.right")
            }
            .disabled(appState.combinations.count < 2)
        }

        ToolbarItem {
            Text(positionText)
                .opacity(appState.combinations.isEmpty ? 0 : 1)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .padding(.horizontal, Spacing.xs)
                .accessibilityLabel(positionAccessibilityText)
        }
    }

    private var modeBinding: Binding<ViewerModel.Mode> {
        Binding(
            get: { viewer.mode },
            set: { viewer.show($0, for: appState.currentCombination) }
        )
    }

    // MARK: Text

    private var title: String {
        guard let combination = appState.currentCombination else { return "Viewer" }
        return DisplayName.title(for: combination.video)
    }

    private var subtitle: String {
        guard let combination = appState.currentCombination else { return "" }
        return DisplayName.credits(studio: combination.video.studio, actors: combination.video.actors)
    }

    private var excludeHelp: String {
        guard let combination = appState.currentCombination else { return "Exclude this pairing" }
        return "Never pair “\(combination.gallery.name)” with this video (⌫). Undo with ⌘Z."
    }

    private var positionText: String {
        guard !appState.combinations.isEmpty else { return "0 of 0" }
        return "\((appState.combinationIndex + 1).formatted()) of \(appState.combinations.count.formatted())"
    }

    private var positionAccessibilityText: String {
        "Combination \(positionText)"
    }

    // MARK: Empty states

    @ViewBuilder
    private var emptyState: some View {
        if appState.videos.isEmpty {
            ContentUnavailableView {
                Label("No Videos", systemImage: "film.stack")
            } description: {
                Text("PP Video Organizer didn’t find any videos in \(abbreviated(appState.config?.videosPath)).")
            } actions: {
                Button("Reload Library") { reloadLibrary(appState) }
            }
        } else if appState.galleries.isEmpty {
            ContentUnavailableView {
                Label("No Galleries", systemImage: "photo.on.rectangle.angled")
            } description: {
                Text("Add folders of images to \(abbreviated(appState.config?.galleriesPath)), then reload the library.")
            } actions: {
                Button("Reload Library") { reloadLibrary(appState) }
            }
        } else if !appState.filtersAreDefault {
            ContentUnavailableView {
                Label("No Matching Combinations", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text(appState.selectedTags.isEmpty
                    ? "Your filters exclude every video and gallery pairing."
                    : "Your filters exclude every video and gallery pairing. Required tags only match videos marked Yes for them in Tag Mapping.")
            } actions: {
                Button("Edit Filters") { navigation.page = .filters }
                    .buttonStyle(.borderedProminent)
                Button("Reset Filters") { appState.resetFilters() }
            }
        } else {
            ContentUnavailableView {
                Label("No Combinations", systemImage: "rectangle.on.rectangle.slash")
            } description: {
                Text("Every video is excluded from every gallery. Include some galleries in Gallery Mapping.")
            } actions: {
                Button("Open Gallery Mapping") { navigation.page = .galleryMapping }
            }
        }
    }

    private func abbreviated(_ path: String?) -> String {
        guard let path else { return "the videos folder" }
        return (path as NSString).abbreviatingWithTildeInPath
    }

    private func prefetchNext() {
        guard appState.combinations.count > 1 else { return }
        let next = appState.combinations[(appState.combinationIndex + 1) % appState.combinations.count]
        ImagePipeline.shared.prefetch(appState.tgpURL(for: next.video.filename), maxPixelSize: ImageSize.full)
    }
}

/// Re-runs the startup pipeline after clearing decoded images, since previews may be regenerated.
@MainActor
func reloadLibrary(_ appState: AppState) {
    ImagePipeline.shared.removeAll()
    appState.reload()
}
