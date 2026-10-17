import SwiftUI

/// Menu bar commands. The single-key shortcuts shown here (V, C, P, B, N,
/// Space, arrows, digits) are dispatched by `KeyboardContext`; see
/// `PlainKeyCommand` for why menus don't handle those keys themselves.
struct AppCommands: Commands {
    let appState: AppState
    let navigation: AppNavigation
    let viewer: ViewerModel
    let mappings: MappingStore
    let keyboard: KeyboardContext
    let toasts: ToastCenter

    private var context: CommandContext {
        CommandContext(appState: appState, navigation: navigation, viewer: viewer, mappings: mappings, toasts: toasts, keyboard: keyboard)
    }

    var body: some Commands {
        SidebarCommands()

        // Single library, single window.
        CommandGroup(replacing: .newItem) {}

        CommandGroup(after: .newItem) {
            Button("Reload Library") {
                reloadLibrary(appState)
            }
            .keyboardShortcut("r")
            .disabled(!appState.isReady && appState.fatalError == nil)

            Button("Clean Up Stale Entries…") {
                appState.showStaleConfigCleanupPreview()
            }
            .disabled(!appState.isReady || appState.config == nil)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save Mapping Changes") {
                saveActiveMapping()
            }
            .keyboardShortcut("s")
            .disabled(activeMapping?.hasChanges != true)

            Button("Revert Mapping Changes…") {
                activeMapping?.confirmsRevert = true
            }
            .disabled(activeMapping?.hasChanges != true)
        }

        CommandMenu("Go") {
            ForEach(Page.allCases) { page in
                if page.shortcut != nil {
                    commandButton(page.title, .go(page))
                } else {
                    Button(page.title) {
                        navigation.page = page
                    }
                    .disabled(!appState.isReady)
                }
            }
        }

        CommandMenu("Viewer") {
            commandButton(viewer.mode == .video ? "Show Contact Sheet" : "Play Video", .toggleMode)
            commandButton("Previous Combination", .previous)
            commandButton("Next Combination", .next)
            commandButton(excludeTitle, .excludePairing)

            Divider()

            commandButton(viewer.player.isPlaying ? "Pause" : "Play", .playPause)
            commandButton("Skip Back 10 Seconds", .skipBack)
            commandButton("Skip Forward 10 Seconds", .skipForward)

            Menu("Jump To") {
                ForEach(0..<10) { tenths in
                    commandButton("\(tenths * 10)%", .jump(tenths: tenths))
                }
            }
            .disabled(!context.isAvailable(.jump(tenths: 0)))
        }
    }

    private func commandButton(_ title: String, _ command: PlainKeyCommand) -> some View {
        Button(title) {
            context.perform(command)
        }
        .keyboardShortcut(command.key, modifiers: [])
        .disabled(!context.isAvailable(command))
    }

    private var excludeTitle: String {
        guard let gallery = appState.currentCombination?.gallery.name else { return "Exclude Pairing" }
        return "Exclude “\(gallery)” from This Video"
    }

    private var activeMapping: MappingSession? {
        guard appState.isReady, let kind = navigation.page.mappingKind else { return nil }
        return mappings.session(kind)
    }

    private func saveActiveMapping() {
        guard let session = activeMapping else { return }
        do {
            let saved = try session.save(to: appState)
            toasts.show("Saved \(saved.counted("change"))")
        } catch {
            appState.appNotice = AppNotice(title: "Couldn’t Save Changes", message: error.localizedDescription)
        }
    }
}
