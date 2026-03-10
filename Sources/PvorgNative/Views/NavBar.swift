import SwiftUI

struct NavBar: View {
    @Binding var currentPage: Page

    var body: some View {
        HStack(spacing: 8) {
            Text("pvorg")
                .font(.headline)
                .foregroundStyle(Color.accentTheme)

            ForEach(Page.allCases, id: \.self) { page in
                Button {
                    currentPage = page
                } label: {
                    Text(page.label)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(currentPage == page ? Color.accentTheme : Color.clear)
                        .foregroundStyle(currentPage == page ? .white : .secondary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.bgSecondary)
    }
}
