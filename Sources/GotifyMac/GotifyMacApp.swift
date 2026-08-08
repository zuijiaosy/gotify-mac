import SwiftUI

@main
struct GotifyMacApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Gotify Mac", systemImage: "bell") {
            MenuContentView(model: model)
        }
    }
}

struct MenuContentView: View {
    let model: AppModel

    var body: some View {
        Text("服务器：\(model.serverURL)")
        Text(model.statusText)
        Button("重新检查连接") {
            Task { await model.refresh() }
        }
        Divider()
        Button("退出 Gotify Mac") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
