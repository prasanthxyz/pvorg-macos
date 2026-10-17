import Foundation

enum TriState: String, Codable {
    case yes
    case no
    case undecided

    var next: TriState {
        switch self {
        case .undecided: .yes
        case .yes: .no
        case .no: .undecided
        }
    }

    var title: String {
        switch self {
        case .yes: "Yes"
        case .no: "No"
        case .undecided: "Undecided"
        }
    }
}
