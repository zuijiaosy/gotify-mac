import SwiftUI

/// 通知标签：开关类设置即时生效（macOS 惯例，无保存按钮）。
struct NotificationSettingsTab: View {
    let model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("启用通知", isOn: binding(\.notificationsEnabled))
                Toggle("通知声音", isOn: binding(\.soundEnabled))
                    .disabled(!model.config.notificationsEnabled)
            }
            if !model.notifier.statusHint.isEmpty {
                Section {
                    Label(model.notifier.statusHint, systemImage: "bell.slash")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
    }

    /// get 读 model.config，set 走唯一写入口 saveConfig（即时落盘生效）
    private func binding(_ keyPath: WritableKeyPath<AppConfig, Bool>) -> Binding<Bool> {
        Binding(
            get: { model.config[keyPath: keyPath] },
            set: { newValue in
                var config = model.config
                config[keyPath: keyPath] = newValue
                model.saveConfig(config)
            }
        )
    }
}
