import Foundation
import SwiftUI

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

    var symbol: String {
        switch self {
        case .yes: "✓"
        case .no: "✗"
        case .undecided: "—"
        }
    }

    var foregroundColor: Color {
        switch self {
        case .yes: .white
        case .no: .white
        case .undecided: .textSecondary
        }
    }

    var backgroundColor: Color {
        switch self {
        case .yes: .stateYes
        case .no: .stateNo
        case .undecided: .tagBg
        }
    }
}
