import Foundation

enum ConfigService {
    static var configURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("pvorg.json")
    }

    static func loadConfig(from url: URL = configURL) throws -> AppConfig {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AppConfig.self, from: data)
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
