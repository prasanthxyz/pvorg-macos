import AppKit
import SwiftUI

/// Spacing scale on a 4pt grid. Every padding and stack spacing in the app comes from here.
enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

/// Corner radii. Small for dense controls, medium for thumbnails and chips, large for floating surfaces.
enum Radius {
    static let small: CGFloat = 5
    static let medium: CGFloat = 8
    static let large: CGFloat = 12
}

extension Color {
    // Chrome follows the system appearance.
    static let subtleFill = Color.primary.opacity(0.06)
    static let subtleFillHover = Color.primary.opacity(0.1)
    static let hairline = Color(nsColor: .separatorColor)
    static let thumbnailPlaceholder = Color.primary.opacity(0.08)

    // The media stage stays dark in both appearances so contact sheets,
    // galleries and video read true and the chrome recedes.
    static let stage = Color(white: 0.06)
    static let stageRaised = Color(white: 0.12)
    static let stageHairline = Color.white.opacity(0.08)
    static let stagePrimary = Color.white.opacity(0.94)
    static let stageSecondary = Color.white.opacity(0.62)

    // Mapping decision states. Tuned so the glyph keeps 3:1 contrast against
    // its tinted cell in both appearances (system green/red are too light on white).
    static let decisionYes = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.27, green: 0.80, blue: 0.45, alpha: 1)
            : NSColor(srgbRed: 0.10, green: 0.53, blue: 0.25, alpha: 1)
    })
    static let decisionNo = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 1.00, green: 0.42, blue: 0.40, alpha: 1)
            : NSColor(srgbRed: 0.80, green: 0.13, blue: 0.13, alpha: 1)
    })
    static let pendingChange = Color.orange
}

private extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua]) != nil
    }
}

/// The user's appearance preference. The original app was dark-only, so dark stays the default.
enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}
