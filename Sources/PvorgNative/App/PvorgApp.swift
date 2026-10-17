import AppKit
import SwiftUI

@main
struct PvorgApp: App {
    @State private var appState = AppState()
    @State private var navigation = AppNavigation()
    @State private var viewer = ViewerModel()
    @State private var library = LibraryModel()
    @State private var mappings = MappingStore()
    @State private var keyboard = KeyboardContext()
    @State private var toasts = ToastCenter()

    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .dark

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(navigation)
                .environment(viewer)
                .environment(library)
                .environment(mappings)
                .environment(keyboard)
                .environment(toasts)
                .onAppear {
                    applyAppearance()
                    keyboard.commands = CommandContext(appState: appState, navigation: navigation, viewer: viewer)
                }
                .onChange(of: appearance) { _, _ in applyAppearance() }
                .task {
                    appState.start()
                }
        }
        .defaultSize(width: 1280, height: 820)
        .windowToolbarStyle(.unified)
        .commands {
            AppCommands(
                appState: appState,
                navigation: navigation,
                viewer: viewer,
                mappings: mappings,
                toasts: toasts
            )
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }

    /// Applied app-wide so sheets, alerts, menus and the hover panel all agree.
    private func applyAppearance() {
        NSApp.appearance = appearance.nsAppearance
    }
}
