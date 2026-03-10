import AppKit
import SwiftUI

struct MappingTableView: View {
    let fetchPage: (_ page: Int, _ pageSize: Int, _ hideDecided: Bool) -> MappingPageData
    let saveChanges: (_ changes: [String: [String: TriState]]) throws -> Void

    @State private var data = MappingPageData.empty(pageSize: 20)
    @State private var page = 1
    @State private var hideDecided = true
    @State private var localChanges: [String: [String: TriState]] = [:]
    @State private var feedback: (text: String, color: Color)?

    private let pageSize = 20

    private var hasChanges: Bool { !localChanges.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(Color.border)

            if data.columns.isEmpty {
                Text("No columns to map.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if data.videos.isEmpty {
                Text(hideDecided ? "All videos are fully decided. Uncheck the filter to see all." : "No videos found.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                tableContent
            }

            Divider().overlay(Color.border)
            PaginationView(
                page: data.page,
                totalPages: max(1, Int(ceil(Double(data.total) / Double(pageSize)))),
                onPrevious: {
                    page = max(1, page - 1)
                    reloadPage()
                },
                onNext: {
                    page += 1
                    reloadPage()
                }
            )
            .padding(10)
            .background(Color.bgSecondary)
        }
        .background(Color.bgPrimary)
        .onAppear {
            reloadPage(resetChanges: true)
        }
        .onChange(of: hideDecided) { _, _ in
            page = 1
            reloadPage(resetChanges: true)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Toggle("Hide fully decided", isOn: $hideDecided)
                .toggleStyle(.checkbox)

            Spacer()

            if hasChanges {
                Text("\(localChanges.count) unsaved change(s)")
                    .font(.caption)
                    .foregroundStyle(Color.stateChanged)
            }

            Button("Save") {
                do {
                    try saveChanges(localChanges)
                    localChanges.removeAll()
                    feedback = ("Saved", .stateYes)
                    reloadPage()
                } catch {
                    feedback = ("Save failed: \(error.localizedDescription)", .stateNo)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!hasChanges)

            if let feedback {
                Text(feedback.text)
                    .font(.caption)
                    .foregroundStyle(feedback.color)
            }

            Text("\(data.total) videos")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.bgSecondary)
    }

    private var tableContent: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                headerRow
                ForEach(data.videos) { row in
                    divider
                    bodyRow(row)
                }
            }
            .padding(8)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text("TGP")
                .frame(width: 80)
                .font(.caption.bold())
            Text("Video")
                .frame(width: 220, alignment: .leading)
                .font(.caption.bold())

            ForEach(data.columns, id: \.self) { column in
                Text(column)
                    .frame(width: 80)
                    .font(.caption.bold())
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
    }

    private func bodyRow(_ row: MappingVideoRow) -> some View {
        HStack(spacing: 8) {
            Group {
                if let url = row.tgpURL, let image = NSImage(contentsOf: url) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().fill(Color.tagBg)
                }
            }
            .frame(width: 72, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .hoverPreview(imageURL: row.tgpURL)

            Text(row.title.isEmpty ? row.filename : row.title)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 220, alignment: .leading)
                .help(row.filename)

            ForEach(data.columns, id: \.self) { column in
                let state = stateFor(row: row, column: column)
                TriStateButtonView(
                    state: state,
                    isModified: isModified(row: row, column: column),
                    onTap: {
                        recordChange(for: row.filename, column: column, newState: state.next, original: row.map[column] ?? .undecided)
                    }
                )
                .frame(width: 80)
            }
        }
        .padding(.vertical, 6)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.border)
            .frame(height: 1)
    }

    private func stateFor(row: MappingVideoRow, column: String) -> TriState {
        localChanges[row.filename]?[column] ?? row.map[column] ?? .undecided
    }

    private func isModified(row: MappingVideoRow, column: String) -> Bool {
        localChanges[row.filename]?[column] != nil
    }

    private func recordChange(for filename: String, column: String, newState: TriState, original: TriState) {
        var entry = localChanges[filename] ?? [:]
        if newState == original {
            entry.removeValue(forKey: column)
        } else {
            entry[column] = newState
        }

        if entry.isEmpty {
            localChanges.removeValue(forKey: filename)
        } else {
            localChanges[filename] = entry
        }
    }

    private func reloadPage(resetChanges: Bool = false) {
        data = fetchPage(page, pageSize, hideDecided)
        page = data.page
        if resetChanges {
            localChanges.removeAll()
        }
    }
}
