import SwiftUI

@main
struct GotifyMacApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            PanelView(model: model)
        } label: {
            // 在 label 内读取可观察属性才能建立依赖，图标才会随未读状态刷新
            Image(systemName: model.hasUnread ? "bell.badge" : "bell")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}
