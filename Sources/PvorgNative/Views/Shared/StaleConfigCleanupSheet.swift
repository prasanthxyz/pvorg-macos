import SwiftUI

struct StaleConfigCleanupSheet: View {
    let preview: StaleConfigCleanupPreview
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Clean Stale Config Entries")
                .font(.title2)
                .bold()

            VStack(alignment: .leading, spacing: 8) {
                detailRow(label: "Videos path", value: preview.videosPath)
                detailRow(label: "Video files on disk", value: "\(preview.videoFileCount)")
                detailRow(label: "Config entries", value: "\(preview.totalRelationCount)")
                detailRow(label: "Stale entries", value: "\(preview.staleEntryCount)")
            }

            if preview.isHighRisk {
                Text("Warning: zero video files are currently visible on disk while pvorg.json still contains mappings. If a device is unmounted or a path is temporarily unavailable, confirming this cleanup will permanently delete manual mapping decisions.")
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if preview.staleEntries.isEmpty {
                Text("No stale entries were found.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Entries that would be removed")
                    .font(.headline)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(preview.staleEntries, id: \.self) { entry in
                            Text(entry)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.tagBg)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .frame(minHeight: 180, maxHeight: 320)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                if preview.staleEntryCount > 0 {
                    Button("Remove \(preview.staleEntryCount) Stale Entr\(preview.staleEntryCount == 1 ? "y" : "ies")", role: .destructive, action: onConfirm)
                }
            }
        }
        .padding(20)
        .frame(width: 680)
        .background(Color.bgPrimary)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
