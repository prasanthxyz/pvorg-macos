import Foundation

protocol VideoDisplaySortable {
    var filename: String { get }
    var title: String { get }
}

enum VideoDisplaySort {
    static func displayName<T: VideoDisplaySortable>(for item: T) -> String {
        let trimmedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? item.filename : trimmedTitle
    }

    static func sorted<T: VideoDisplaySortable>(_ items: [T]) -> [T] {
        items.sorted { lhs, rhs in
            areInIncreasingOrder(lhs, rhs)
        }
    }

    private static func areInIncreasingOrder<T: VideoDisplaySortable>(_ lhs: T, _ rhs: T) -> Bool {
        let displayComparison = displayName(for: lhs).localizedCaseInsensitiveCompare(displayName(for: rhs))
        if displayComparison != .orderedSame {
            return displayComparison == .orderedAscending
        }

        let filenameComparison = lhs.filename.localizedCaseInsensitiveCompare(rhs.filename)
        if filenameComparison != .orderedSame {
            return filenameComparison == .orderedAscending
        }

        return lhs.filename < rhs.filename
    }
}
