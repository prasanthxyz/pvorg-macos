import Foundation

struct FilenameValidator {
    struct ParsedFilename {
        let studio: String
        let actors: [String]
        let title: String
    }

    static func validate(_ filename: String) -> (isValid: Bool, reasons: [String]) {
        var reasons: [String] = []
        if filename != filename.lowercased() {
            reasons.append("Contains uppercase characters")
        }
        if filename.contains(" ") {
            reasons.append("Contains spaces")
        }
        let stem = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        let parts = stem.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        if parts.count < 3 {
            reasons.append("Fewer than 3 dash-separated parts (need studio-actor-title)")
        }
        return (reasons.isEmpty, reasons)
    }

    static func parse(_ filename: String) -> ParsedFilename {
        let stem = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        let parts = stem.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 3 else {
            return ParsedFilename(studio: parts.first ?? "unknown", actors: [], title: stem)
        }
        return ParsedFilename(studio: parts[0], actors: Array(parts[1..<(parts.count - 1)]), title: parts[parts.count - 1])
    }
}
