import SwiftUI
import VlogPackCore

@main
struct VlogPackApp: App {
    @State private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(appState)
        }
        #endif
    }
}
