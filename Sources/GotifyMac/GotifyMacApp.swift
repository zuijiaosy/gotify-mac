import SwiftUI

@main
struct GotifyMacApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Gotify Mac", systemImage: "bell") {
            PanelView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
