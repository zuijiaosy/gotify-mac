import SwiftUI

/// 设置窗口根视图：macOS 经典顶部工具栏标签样式（Settings scene 内的
/// TabView 默认渲染）。LSUIElement 应用的窗口不会自动前置，onAppear 里
/// 手动 activate + makeKey 兜底（入口按钮处已 activate 过一次，双保险）。
struct SettingsView: View {
    let model: AppModel

    var body: some View {
        TabView {
            ServerSettingsTab(model: model)
                .tabItem { Label("服务器", systemImage: "server.rack") }
        }
        .frame(width: 440)
        .onAppear { activateSettingsWindow() }
    }

    private func activateSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // Settings 窗口此刻可能尚未进 NSApp.windows，推迟一拍再找；
        // identifier 匹配不到时（系统改名）优雅降级为仅 activate
        DispatchQueue.main.async {
            NSApp.windows
                .first { $0.identifier?.rawValue.contains("Settings") == true }?
                .makeKeyAndOrderFront(nil)
        }
    }
}
