import Foundation
import Observation

/// Unsaved edits and view options for one mapping matrix. Lives for the whole
/// app session, so switching pages or filters never discards pending work.
@Observable
@MainActor
final class MappingSession {
    let kind: MappingKind

    /// filename → column → new state, only for cells that differ from what is saved.
    private(set) var pendingChanges: [String: [String: TriState]] = [:]
    var showsDecidedVideos = false
    var query = ""
    /// Drives the discard confirmation, so the toolbar and File menu share one dialog.
    var confirmsRevert = false

    /// Rows for the current options; refreshed explicitly so cell edits don't recompute them.
    private(set) var rows: [MappingVideoRow] = []
    private(set) var columns: [String] = []
    /// Videos still missing a decision for at least one column, ignoring the search.
    private(set) var undecidedVideoCount = 0

    init(kind: MappingKind) {
        self.kind = kind
    }

    var changeCount: Int {
        pendingChanges.values.reduce(0) { $0 + $1.count }
    }

    var hasChanges: Bool { !pendingChanges.isEmpty }

    func refresh(from appState: AppState) {
        columns = appState.mappingColumns(kind)
        rows = appState.mappingRows(kind, hideDecided: !showsDecidedVideos, query: query)
        undecidedVideoCount = (!showsDecidedVideos && query.isEmpty)
            ? rows.count
            : appState.mappingRows(kind, hideDecided: true).count
        let known = Set(appState.videos.map(\.filename))
        let knownColumns = Set(columns)
        pendingChanges = pendingChanges.reduce(into: [:]) { result, entry in
            guard known.contains(entry.key) else { return }
            let kept = entry.value.filter { knownColumns.contains($0.key) }
            if !kept.isEmpty { result[entry.key] = kept }
        }
    }

    func state(for row: MappingVideoRow, column: String) -> TriState {
        pendingChanges[row.filename]?[column] ?? row.map[column] ?? .undecided
    }

    func isModified(_ row: MappingVideoRow, column: String) -> Bool {
        pendingChanges[row.filename]?[column] != nil
    }

    func cycle(_ row: MappingVideoRow, column: String) {
        set(state(for: row, column: column).next, for: row, column: column)
    }

    func set(_ state: TriState, for row: MappingVideoRow, column: String) {
        let saved = row.map[column] ?? .undecided
        var entry = pendingChanges[row.filename] ?? [:]
        if state == saved {
            entry.removeValue(forKey: column)
        } else {
            entry[column] = state
        }
        pendingChanges[row.filename] = entry.isEmpty ? nil : entry
    }

    /// Applies `state` to one column for every row currently shown.
    func set(_ state: TriState, column: String) {
        for row in rows {
            set(state, for: row, column: column)
        }
    }

    /// Applies `state` to every column of one row.
    func set(_ state: TriState, row: MappingVideoRow) {
        for column in columns {
            set(state, for: row, column: column)
        }
    }

    func revert() {
        pendingChanges.removeAll()
    }

    /// Writes pending changes to pvorg.json and returns how many cells were saved.
    @discardableResult
    func save(to appState: AppState) throws -> Int {
        let count = changeCount
        guard count > 0 else { return 0 }
        try appState.saveMappings(kind, changes: pendingChanges)
        pendingChanges.removeAll()
        refresh(from: appState)
        return count
    }
}

@Observable
@MainActor
final class MappingStore {
    let galleries = MappingSession(kind: .galleries)
    let tags = MappingSession(kind: .tags)

    func session(_ kind: MappingKind) -> MappingSession {
        switch kind {
        case .galleries: galleries
        case .tags: tags
        }
    }
}
