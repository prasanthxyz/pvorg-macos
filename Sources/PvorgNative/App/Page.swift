import Observation
import SwiftUI

enum Page: String, CaseIterable, Identifiable {
    case viewer
    case filters
    case library
    case galleryMapping
    case tagMapping

    enum Group: String, CaseIterable {
        case browse = "Browse"
        case organize = "Organize"
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .viewer: "Viewer"
        case .filters: "Filters"
        case .library: "Library"
        case .galleryMapping: "Gallery Mapping"
        case .tagMapping: "Tag Mapping"
        }
    }

    var systemImage: String {
        switch self {
        case .viewer: "play.rectangle"
        case .filters: "line.3.horizontal.decrease.circle"
        case .library: "square.grid.2x2"
        case .galleryMapping: "photo.on.rectangle.angled"
        case .tagMapping: "tag"
        }
    }

    var group: Group {
        switch self {
        case .viewer, .filters: .browse
        case .library, .galleryMapping, .tagMapping: .organize
        }
    }

    /// Single-key shortcut carried over from the original navigation bar.
    var shortcut: KeyEquivalent? {
        switch self {
        case .viewer: "v"
        case .filters: "c"
        default: nil
        }
    }

    var mappingKind: MappingKind? {
        switch self {
        case .galleryMapping: .galleries
        case .tagMapping: .tags
        default: nil
        }
    }
}

@Observable
@MainActor
final class AppNavigation {
    var page: Page = .viewer
}
