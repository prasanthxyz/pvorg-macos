import Foundation
import Observation

/// Search and selection for the Library grid.
@Observable
@MainActor
final class LibraryModel {
    var query = ""
    var selection: Set<String> = []
    /// Filenames awaiting confirmation in the delete dialog.
    var pendingDeletion: [String] = []

    func visibleVideos(in appState: AppState) -> [Video] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appState.sortedVideos }
        return appState.sortedVideos.filter { $0.matches(query) }
    }

    func toggle(_ filename: String) {
        if selection.contains(filename) {
            selection.remove(filename)
        } else {
            selection.insert(filename)
        }
    }

    /// Drops selected filenames that no longer exist after a reload or delete.
    func prune(keeping filenames: Set<String>) {
        selection.formIntersection(filenames)
    }
}
