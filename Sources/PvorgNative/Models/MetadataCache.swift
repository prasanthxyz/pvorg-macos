import Foundation

actor MetadataCache {
    private let cacheURL: URL
    private var entries: [String: MetadataCacheEntry] = [:]

    init(cacheURL: URL) {
        self.cacheURL = cacheURL
    }

    func load() {
        guard let data = try? Data(contentsOf: cacheURL) else {
            entries = [:]
            return
        }
        do {
            entries = try JSONDecoder().decode([String: MetadataCacheEntry].self, from: data)
        } catch {
            entries = [:]
        }
    }

    func has(_ filename: String) -> Bool {
        entries[filename] != nil
    }

    func get(_ filename: String) -> MetadataCacheEntry? {
        entries[filename]
    }

    func set(_ filename: String, value: MetadataCacheEntry) {
        entries[filename] = value
    }

    func remove(_ filename: String) {
        entries.removeValue(forKey: filename)
    }

    func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)
        try cacheURL.deletingLastPathComponent().createDirectoryIfNeeded()
        try data.write(to: cacheURL, options: .atomic)
    }
}
