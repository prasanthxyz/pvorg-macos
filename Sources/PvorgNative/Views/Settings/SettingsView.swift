import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .dark

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("The viewer always uses a dark stage so images and video look their best.")
                    .foregroundStyle(.secondary)
            }

            Section("Library") {
                pathRow("Configuration", url: ConfigService.configURL)
                if let config = appState.config {
                    pathRow("Videos", url: URL(fileURLWithPath: config.videosPath, isDirectory: true))
                    pathRow("Galleries", url: URL(fileURLWithPath: config.galleriesPath, isDirectory: true))
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func pathRow(_ title: String, url: URL) -> some View {
        LabeledContent(title) {
            HStack(spacing: Spacing.sm) {
                Text((url.path as NSString).abbreviatingWithTildeInPath)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(url.path)
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Show in Finder")
                .accessibilityLabel("Show \(title) in Finder")
                .disabled(!FileManager.default.fileExists(atPath: url.path))
            }
        }
    }
}
