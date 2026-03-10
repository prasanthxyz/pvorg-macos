import SwiftUI

struct TagMapperView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        MappingTableView(
            fetchPage: { page, pageSize, hideDecided in
                appState.tagMappingPage(page: page, pageSize: pageSize, hideDecided: hideDecided)
            },
            saveChanges: { changes in
                try appState.saveTagMappings(changes)
            }
        )
    }
}
