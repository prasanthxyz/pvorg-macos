import SwiftUI

struct VideoCardView: View {
    let video: Video
    let tgpURL: URL?
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                thumbnail
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(DisplayName.title(for: video))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(DisplayName.credits(studio: video.studio, actors: video.actors))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, Spacing.xxs)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(video.filename)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(DisplayName.title(for: video)), \(DisplayName.credits(studio: video.studio, actors: video.actors))")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isSelected ? "Removes from the selection" : "Adds to the selection")
    }

    private var thumbnail: some View {
        AsyncThumbnail(url: tgpURL, maxPixelSize: ImageSize.card)
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.white.opacity(isHovering ? 0.18 : 0.06), lineWidth: isSelected ? 3 : 1)
            }
            .overlay(alignment: .topTrailing) {
                selectionBadge
                    .padding(Spacing.sm)
            }
            .hoverPreview(imageURL: tgpURL)
    }

    @ViewBuilder
    private var selectionBadge: some View {
        if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.accentColor)
                .shadow(color: .black.opacity(0.35), radius: 2)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else if isHovering {
            Image(systemName: "circle")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.5), radius: 2)
                .transition(.opacity)
        }
    }
}
