import SwiftUI

struct StaleConfigCleanupSheet: View {
    let preview: StaleConfigCleanupPreview
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            header

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Spacing.lg, verticalSpacing: Spacing.sm) {
                summaryRow("Videos folder", (preview.videosPath as NSString).abbreviatingWithTildeInPath, selectable: true)
                summaryRow("Videos on disk", preview.videoFileCount.formatted())
                summaryRow("Entries in pvorg.json", preview.totalRelationCount.formatted())
                summaryRow("Stale entries", preview.staleEntryCount.formatted())
            }
            .font(.callout)

            if preview.isHighRisk {
                Callout(
                    tone: .critical,
                    title: "No videos are visible in the videos folder",
                    message: "If a drive is disconnected or the folder is temporarily unavailable, removing these entries permanently deletes your mapping decisions."
                )
            }

            if !preview.staleEntries.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Entries to Remove")
                        .font(.headline)
                    List(preview.staleEntries, id: \.self) { entry in
                        Text(entry)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                            .help(entry)
                    }
                    .listStyle(.bordered(alternatesRowBackgrounds: true))
                    .frame(minHeight: 120, idealHeight: min(CGFloat(preview.staleEntries.count) * 24 + 8, 260), maxHeight: 260)
                }
            }

            HStack {
                Spacer()
                if preview.staleEntries.isEmpty {
                    Button("Done", action: onCancel)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Cancel", action: onCancel)
                        .keyboardShortcut(.cancelAction)
                    Button("Remove \(preview.staleEntryCount.counted("Entry", "Entries"))", role: .destructive, action: onConfirm)
                        // Never the default button when the cleanup could wipe real data.
                        .keyboardShortcut(preview.isHighRisk ? nil : .defaultAction)
                }
            }
        }
        .padding(Spacing.xl)
        .frame(width: 560)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: preview.staleEntries.isEmpty ? "checkmark.circle" : "doc.badge.gearshape")
                .font(.system(size: 30))
                .foregroundStyle(preview.staleEntries.isEmpty ? Color.decisionYes : Color.accentColor)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(preview.staleEntries.isEmpty ? "No Stale Entries" : "Clean Up Stale Entries")
                    .font(.title3.weight(.semibold))
                Text(preview.staleEntries.isEmpty
                    ? "Every entry in pvorg.json matches a video in your videos folder."
                    : "These pvorg.json entries refer to videos that are no longer in your videos folder. Removing them doesn’t touch any files.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func summaryRow(_ label: String, _ value: String, selectable: Bool = false) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            Group {
                if selectable {
                    Text(value).textSelection(.enabled)
                } else {
                    Text(value).monospacedDigit()
                }
            }
            .lineLimit(1)
            .truncationMode(.middle)
        }
    }
}
