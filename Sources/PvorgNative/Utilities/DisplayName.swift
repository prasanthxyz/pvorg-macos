import Foundation

/// Presentation helpers for names derived from filenames. Filenames are
/// lowercase with underscores ("jane_doe"); the UI shows "Jane Doe". Raw values
/// remain the identifiers everywhere else (selection sets, config, sorting keys).
enum DisplayName {
    static func humanize(_ token: String) -> String {
        let words = token
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ", omittingEmptySubsequences: true)
        guard !words.isEmpty else { return token }
        return words
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    static func title<T: VideoDisplaySortable>(for item: T) -> String {
        let trimmed = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? item.filename : humanize(trimmed)
    }

    static func cast(_ actors: [String]) -> String {
        ListFormatter.localizedString(byJoining: actors.map(humanize))
    }

    /// "Acme · Jane Doe and John Roe"
    static func credits(studio: String, actors: [String]) -> String {
        let parts = [humanize(studio), cast(actors)].filter { !$0.isEmpty }
        return parts.joined(separator: " · ")
    }
}

enum TimecodeFormat {
    /// "0:07", "12:34", "1:02:03"
    static func string(from seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

extension Int {
    /// "1 video" / "3 videos"
    func counted(_ singular: String, _ plural: String? = nil) -> String {
        "\(formatted()) \(self == 1 ? singular : (plural ?? singular + "s"))"
    }
}
