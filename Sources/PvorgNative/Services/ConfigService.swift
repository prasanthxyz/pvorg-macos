import Foundation

enum ConfigService {
    /// `~/pvorg.json`. `PVORG_CONFIG` overrides it so the app can be run
    /// against a test library without touching the real one.
    static var configURL: URL {
        if let override = ProcessInfo.processInfo.environment["PVORG_CONFIG"], !override.isEmpty {
            return URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("pvorg.json")
    }

    static func loadConfig(from url: URL = configURL) throws -> AppConfig {
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode(AppConfig.self, from: data)
        } catch let error as DecodingError {
            throw NSError(domain: "ConfigService", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "\(url.lastPathComponent) isn’t valid: \(describe(error))",
            ])
        }
    }

    private static func describe(_ error: DecodingError) -> String {
        func path(_ context: DecodingError.Context) -> String {
            let keys = context.codingPath.map { $0.intValue.map { "[\($0)]" } ?? $0.stringValue }
            return keys.isEmpty ? "" : " (at “\(keys.joined(separator: "."))”)"
        }
        switch error {
        case .keyNotFound(let key, let context):
            return "the required key “\(key.stringValue)” is missing\(path(context))."
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context):
            return context.debugDescription.trimmingCharacters(in: CharacterSet(charactersIn: ".")) + path(context) + "."
        @unknown default:
            return error.localizedDescription
        }
    }

    static func saveConfig(_ config: AppConfig, to url: URL = configURL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)

        guard var jsonString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "ConfigService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode config as UTF-8"])
        }

        if !jsonString.hasSuffix("\n") {
            jsonString += "\n"
        }

        guard let outData = jsonString.data(using: .utf8) else {
            throw NSError(domain: "ConfigService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to convert JSON string to Data"])
        }

        try outData.write(to: url, options: .atomic)
    }

    static func normalizeRelations(_ config: inout AppConfig) -> Int {
        var changed = 0

        for (filename, relation) in config.videoRelations {
            var relation = relation
            var localChanged = false

            if relation.tags == nil {
                relation.tags = []
                localChanged = true
            }
            if relation.galleries == nil {
                relation.galleries = []
                localChanged = true
            }
            if relation.excludedTags == nil {
                relation.excludedTags = []
                localChanged = true
            }
            if relation.excludedGalleries == nil {
                relation.excludedGalleries = []
                localChanged = true
            }

            if localChanged {
                config.videoRelations[filename] = relation
                changed += 1
            }
        }

        return changed
    }
}
