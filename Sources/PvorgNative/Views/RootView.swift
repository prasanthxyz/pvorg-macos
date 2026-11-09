import AppKit
import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(KeyboardContext.self) private var keyboard
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        Group {
            if let error = appState.fatalError {
                StartupErrorView(message: error)
            } else if !appState.isReady {
                StartupProgressView(progress: appState.startupProgress)
            } else {
                MainSplitView()
            }
        }
        .frame(minWidth: 960, minHeight: 600)
        .background(WindowReader { keyboard.mainWindow = $0 })
        .overlay(alignment: .bottom) {
            ToastOverlay()
        }
        .sheet(
            item: Binding(
                get: { appState.staleCleanupPreview },
                set: { appState.staleCleanupPreview = $0 }
            )
        ) { preview in
            StaleConfigCleanupSheet(
                preview: preview,
                onCancel: { appState.dismissStaleConfigCleanupPreview() },
                onConfirm: confirmCleanup
            )
        }
        .alert(
            appState.appNotice?.title ?? "",
            isPresented: Binding(
                get: { appState.appNotice != nil },
                set: { if !$0 { appState.appNotice = nil } }
            ),
            presenting: appState.appNotice
        ) { _ in
            Button("OK") {}
        } message: { notice in
            Text(notice.message)
        }
    }

    private func confirmCleanup() {
        do {
            let removed = try appState.confirmStaleConfigCleanup()
            toasts.show("Removed \(removed.counted("stale entry", "stale entries"))")
        } catch {
            appState.dismissStaleConfigCleanupPreview()
            appState.appNotice = AppNotice(title: "Cleanup Failed", message: error.localizedDescription)
        }
    }
}

private struct MainSplitView: View {
    @Environment(AppNavigation.self) private var navigation
    /// The sidebar's hidden state, remembered across launches (SPEC §4.1). The
    /// toolbar button and View › Hide Sidebar (⌃⌘S) come from the system.
    @AppStorage("sidebarHidden") private var sidebarHidden = false

    private var columnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { sidebarHidden ? .detailOnly : .all },
            set: { sidebarHidden = $0 == .detailOnly }
        )
    }

    var body: some View {
        NavigationSplitView(columnVisibility: columnVisibility) {
            Sidebar()
        } detail: {
            switch navigation.page {
            case .viewer:
                ViewerView()
            case .filters:
                FiltersView()
            case .library:
                LibraryView()
            case .galleryMapping:
                MappingView(kind: .galleries)
                    .id(MappingKind.galleries)
            case .tagMapping:
                MappingView(kind: .tags)
                    .id(MappingKind.tags)
            }
        }
    }
}

struct StartupProgressView: View {
    let progress: StartupProgress

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "movieclapper")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.sm) {
                Text(progress.title)
                    .font(.title2.weight(.semibold))
                    .contentTransition(.opacity)

                Group {
                    if let fraction = progress.fraction {
                        ProgressView(value: fraction)
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                    }
                }
                .frame(width: 280)
                .padding(.top, Spacing.xs)

                // Reserve the line so the layout doesn't jump as details come and go.
                Text(progress.detail ?? " ")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 420)
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("PP Video Organizer")
        .accessibilityElement(children: .combine)
    }
}

struct StartupErrorView: View {
    @Environment(AppState.self) private var appState
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("Couldn’t Load Your Library", systemImage: "exclamationmark.triangle")
        } description: {
            VStack(spacing: Spacing.md) {
                Text(message)
                Text("PP Video Organizer reads its configuration from \(configPath).")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        } actions: {
            Button("Try Again") {
                reloadLibrary(appState)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)

            if FileManager.default.fileExists(atPath: ConfigService.configURL.path) {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([ConfigService.configURL])
                }
            }
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("PP Video Organizer")
    }

    private var configPath: String {
        (ConfigService.configURL.path as NSString).abbreviatingWithTildeInPath
    }
}
