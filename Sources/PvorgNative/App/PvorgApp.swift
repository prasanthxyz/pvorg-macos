import SwiftUI

@main
struct PvorgApp: App {
    @State private var appState = AppState()
    @State private var currentPage: Page = .viewer

    var body: some Scene {
        WindowGroup {
            ContentView(currentPage: $currentPage)
                .environment(appState)
                .preferredColorScheme(.dark)
                .task {
                    appState.start()
                }
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandMenu("Navigate") {
                Button("Viewer") {
                    currentPage = .viewer
                }
                .keyboardShortcut("v", modifiers: [])

                Button("Config") {
                    currentPage = .config
                }
                .keyboardShortcut("c", modifiers: [])
            }

            CommandMenu("Viewer") {
                Button("Toggle TGP/Video") {
                    NotificationCenter.default.post(name: ViewerNotifications.toggleMode, object: nil)
                }
                .keyboardShortcut("p", modifiers: [])

                Button("Previous Combination") {
                    NotificationCenter.default.post(name: ViewerNotifications.previous, object: nil)
                }
                .keyboardShortcut("b", modifiers: [])

                Button("Next Combination") {
                    NotificationCenter.default.post(name: ViewerNotifications.next, object: nil)
                }
                .keyboardShortcut("n", modifiers: [])

                Button("Play/Pause") {
                    NotificationCenter.default.post(name: ViewerNotifications.playPause, object: nil)
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("Seek -10s") {
                    NotificationCenter.default.post(name: ViewerNotifications.seekRelative, object: -10.0)
                }
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button("Seek +10s") {
                    NotificationCenter.default.post(name: ViewerNotifications.seekRelative, object: 10.0)
                }
                .keyboardShortcut(.rightArrow, modifiers: [])

                Divider()

                Button("Seek 0%") {
                    NotificationCenter.default.post(name: ViewerNotifications.seekPercent, object: 0.0)
                }
                .keyboardShortcut("0", modifiers: [])

                Button("Seek 10%") {
                    NotificationCenter.default.post(name: ViewerNotifications.seekPercent, object: 0.1)
                }
                .keyboardShortcut("1", modifiers: [])

                Button("Seek 20%") {
                    NotificationCenter.default.post(name: ViewerNotifications.seekPercent, object: 0.2)
                }
                .keyboardShortcut("2", modifiers: [])

                Button("Seek 30%") {
                    NotificationCenter.default.post(name: ViewerNotifications.seekPercent, object: 0.3)
                }
                .keyboardShortcut("3", modifiers: [])

                Button("Seek 40%") {
                    NotificationCenter.default.post(name: ViewerNotifications.seekPercent, object: 0.4)
                }
                .keyboardShortcut("4", modifiers: [])

                Button("Seek 50%") {
                    NotificationCenter.default.post(name: ViewerNotifications.seekPercent, object: 0.5)
                }
                .keyboardShortcut("5", modifiers: [])

                Button("Seek 60%") {
                    NotificationCenter.default.post(name: ViewerNotifications.seekPercent, object: 0.6)
                }
                .keyboardShortcut("6", modifiers: [])

                Button("Seek 70%") {
                    NotificationCenter.default.post(name: ViewerNotifications.seekPercent, object: 0.7)
                }
                .keyboardShortcut("7", modifiers: [])

                Button("Seek 80%") {
                    NotificationCenter.default.post(name: ViewerNotifications.seekPercent, object: 0.8)
                }
                .keyboardShortcut("8", modifiers: [])

                Button("Seek 90%") {
                    NotificationCenter.default.post(name: ViewerNotifications.seekPercent, object: 0.9)
                }
                .keyboardShortcut("9", modifiers: [])
            }
        }
    }
}
