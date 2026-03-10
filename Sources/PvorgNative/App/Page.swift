import Foundation

enum Page: String, CaseIterable {
    case viewer = "Home"
    case config = "Config"
    case deleter = "Deleter"
    case mapper = "Mapper"
    case tagMapper = "Tag Mapper"

    var label: String {
        switch self {
        case .viewer: "Home (V)"
        case .config: "Config (C)"
        case .deleter: "Deleter"
        case .mapper: "Mapper"
        case .tagMapper: "Tag Mapper"
        }
    }
}
