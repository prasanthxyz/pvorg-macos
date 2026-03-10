import AppKit
import SwiftUI

struct HoverPreviewModifier: ViewModifier {
    let imageURL: URL?
    @State private var isHovering = false
    @State private var hoverLocation: CGPoint = .zero

    func body(content: Content) -> some View {
        content
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    isHovering = true
                    hoverLocation = location
                case .ended:
                    isHovering = false
                }
            }
            .overlay(alignment: .topLeading) {
                if isHovering,
                   let imageURL,
                   let image = NSImage(contentsOf: imageURL) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 500)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 8)
                        .offset(x: hoverLocation.x + 20, y: hoverLocation.y - 160)
                        .allowsHitTesting(false)
                        .zIndex(1000)
                }
            }
    }
}

extension View {
    func hoverPreview(imageURL: URL?) -> some View {
        modifier(HoverPreviewModifier(imageURL: imageURL))
    }
}
