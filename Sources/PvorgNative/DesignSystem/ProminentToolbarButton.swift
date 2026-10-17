import SwiftUI

/// The one emphasized action in a toolbar (Save). `.borderedProminent` renders
/// as a plain button inside macOS 26+ glass toolbars, so use the glass equivalent there.
struct ProminentToolbarButton: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}
