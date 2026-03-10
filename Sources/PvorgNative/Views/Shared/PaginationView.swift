import SwiftUI

struct PaginationView: View {
    let page: Int
    let totalPages: Int
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("Prev", action: onPrevious)
                .disabled(page <= 1)

            Text("Page \(page) / \(max(totalPages, 1))")
                .font(.caption)

            Button("Next", action: onNext)
                .disabled(page >= totalPages)
        }
        .buttonStyle(.bordered)
    }
}
