import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Binding var currentPage: Page

    var body: some View {
        Group {
            if let error = appState.fatalError {
                FatalErrorView(message: error)
            } else if !appState.isReady {
                LoadingView()
            } else {
                MainView(currentPage: $currentPage)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }
}

struct LoadingView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 16) {
            Text(appState.progressText)
                .font(.headline)

            ProgressView()
                .controlSize(.large)

            Text("\(appState.videos.count) videos, \(appState.galleries.count) galleries")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FatalErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Text("Startup Error")
                .font(.title2)
                .foregroundStyle(.red)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MainView: View {
    @Binding var currentPage: Page

    var body: some View {
        VStack(spacing: 0) {
            NavBar(currentPage: $currentPage)
            Divider().overlay(Color.border)

            Group {
                switch currentPage {
                case .viewer:
                    ViewerView()
                case .config:
                    ConfigView()
                case .deleter:
                    DeleterView()
                case .mapper:
                    GalleryMapperView()
                case .tagMapper:
                    TagMapperView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
