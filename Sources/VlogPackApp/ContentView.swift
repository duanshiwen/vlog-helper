import SwiftUI
import VlogPackCore

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.hasOpenProject {
                WorkspaceView()
            } else {
                LaunchView()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}
