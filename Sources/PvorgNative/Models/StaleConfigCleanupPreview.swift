import Foundation

struct StaleConfigCleanupPreview: Identifiable {
    let id = UUID()
    let videosPath: String
    let videoFileCount: Int
    let totalRelationCount: Int
    let staleEntries: [String]

    var staleEntryCount: Int {
        staleEntries.count
    }

    var isHighRisk: Bool {
        videoFileCount == 0 && totalRelationCount > 0
    }
}
