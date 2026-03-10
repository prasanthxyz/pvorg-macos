import SwiftUI

struct GalleryMapperView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        MappingTableView(
            fetchPage: { page, pageSize, hideDecided in
                appState.galleryMappingPage(page: page, pageSize: pageSize, hideDecided: hideDecided)
            },
            saveChanges: { changes in
                try appState.saveGalleryMappings(changes)
            }
        )
    }
}
