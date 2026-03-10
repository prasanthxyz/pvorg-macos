import AppKit
import SwiftUI

struct VideoCardView: View {
    let video: Video
    let tgpURL: URL?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Group {
                    if let tgpURL, let image = NSImage(contentsOf: tgpURL) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(16 / 9, contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color.tagBg)
                            .overlay {
                                Text("No TGP")
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(height: 120)
                .clipped()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.red)
                    .padding(8)
            }

            Text(video.title.isEmpty ? video.filename : video.title)
                .lineLimit(1)
                .truncationMode(.tail)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(video.filename)
        }
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.stateNo : Color.border, lineWidth: isSelected ? 2 : 1)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .hoverPreview(imageURL: tgpURL)
    }
}
