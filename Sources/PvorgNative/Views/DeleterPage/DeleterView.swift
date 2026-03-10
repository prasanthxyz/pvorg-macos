import SwiftUI

struct DeleterView: View {
    @Environment(AppState.self) private var appState

    @State private var page = 1
    @State private var selected: Set<String> = []
    @State private var showConfirm = false
    @State private var feedback: (text: String, color: Color)?

    private let pageSize = 24
    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 12)]

    private var sortedVideos: [Video] {
        appState.videos.sorted { $0.filename < $1.filename }
    }

    private var totalPages: Int {
        max(1, Int(ceil(Double(sortedVideos.count) / Double(pageSize))))
    }

    private var pageVideos: [Video] {
        let clampedPage = min(max(page, 1), totalPages)
        let start = (clampedPage - 1) * pageSize
        let end = min(start + pageSize, sortedVideos.count)
        guard start < end else { return [] }
        return Array(sortedVideos[start..<end])
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(Color.border)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(pageVideos) { video in
                        VideoCardView(
                            video: video,
                            tgpURL: appState.tgpURL(for: video.filename),
                            isSelected: selected.contains(video.filename),
                            onTap: { toggle(video.filename) }
                        )
                    }
                }
                .padding(16)
            }

            Divider().overlay(Color.border)
            PaginationView(
                page: min(max(page, 1), totalPages),
                totalPages: totalPages,
                onPrevious: { page = max(1, page - 1) },
                onNext: { page = min(totalPages, page + 1) }
            )
            .padding(10)
            .background(Color.bgSecondary)
        }
        .background(Color.bgPrimary)
        .confirmationDialog(
            "Delete \(selected.count) video(s)? This cannot be undone.",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                performDelete()
            }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: sortedVideos.count) { _, _ in
            page = min(page, totalPages)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button("Select All") {
                selected = Set(pageVideos.map(\.filename))
            }
            .buttonStyle(.bordered)

            Button("Deselect All") {
                selected.removeAll()
            }
            .buttonStyle(.bordered)

            Spacer()

            if selected.count > 0 {
                Button("Delete Selected (\(selected.count))", role: .destructive) {
                    showConfirm = true
                }
                .buttonStyle(.borderedProminent)
            }

            if let feedback {
                Text(feedback.text)
                    .font(.caption)
                    .foregroundStyle(feedback.color)
            }

            Text("\(sortedVideos.count) videos")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.bgSecondary)
    }

    private func toggle(_ filename: String) {
        if selected.contains(filename) {
            selected.remove(filename)
        } else {
            selected.insert(filename)
        }
    }

    private func performDelete() {
        do {
            let result = try appState.deleteVideos(Array(selected))
            selected.removeAll()
            page = 1
            if result.errors.isEmpty {
                feedback = ("Deleted \(result.deletedCount) video(s).", .stateYes)
            } else {
                feedback = ("Deleted \(result.deletedCount). \(result.errors.count) error(s).", .stateNo)
            }
        } catch {
            feedback = ("Delete failed: \(error.localizedDescription)", .stateNo)
        }
    }
}
