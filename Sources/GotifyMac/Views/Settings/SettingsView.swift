import SwiftUI

/// 设置窗口由 MenuBarController 持有和前置，内容继续使用 SwiftUI TabView。
struct SettingsView: View {
    let model: AppModel
    let shortcuts: GlobalShortcuts

    var body: some View {
        TabView {
            ServerSettingsTab(model: model)
                .tabItem { Label("服务器", systemImage: "server.rack") }
            GeneralSettingsTab(shortcuts: shortcuts)
                .tabItem { Label("通用", systemImage: "gearshape") }
        }
        .frame(width: 440)
        .frame(height: 420)
    }
}
