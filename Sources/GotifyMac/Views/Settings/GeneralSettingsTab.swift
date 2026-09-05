import ServiceManagement
import SwiftUI

/// 通用设置即时生效；登录启动状态由系统管理，快捷键写入配置。
struct GeneralSettingsTab: View {
    let shortcuts: GlobalShortcuts
    @State private var launchAtLogin = false
    @State private var hint: String?

    var body: some View {
        Form {
            Section {
                Toggle("登录时启动 Gotify Mac", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in apply(enabled) }
                if let hint {
                    Label(hint, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
                Text("菜单栏应用没有 Dock 图标，开启后会在登录时静默启动到菜单栏")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("全局快捷键") {
                ForEach(ShortcutAction.allCases, id: \.rawValue) { action in
                    LabeledContent(action.title) {
                        HStack {
                            Button {
                                shortcuts.beginRecording(action)
                            } label: {
                                Text(shortcuts.recording == action ? "请按组合键…" :
                                     shortcuts.bindings[action]?.displayName ?? "未设置")
                                    .frame(width: 115)
                            }
                            .help("录入快捷键，Escape 取消")
                            Button {
                                shortcuts.update(action, to: nil)
                            } label: {
                                Image(systemName: "xmark.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("清除快捷键")
                            .disabled(shortcuts.bindings[action] == nil && shortcuts.recording != action)
                        }
                    }
                    if let error = shortcuts.errors[action] {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            Section {
                LabeledContent("版本", value: Self.versionText)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: syncFromSystem)
        .onDisappear { shortcuts.cancelRecording() }
    }

    /// 系统才是真值：用户可能在系统设置里改过，每次出现都重新读
    private func syncFromSystem() {
        launchAtLogin = LaunchAtLogin.isEnabled
        hint = LaunchAtLogin.approvalHint(status: LaunchAtLogin.status)
    }

    private func apply(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            hint = LaunchAtLogin.approvalHint(status: LaunchAtLogin.status)
        } catch {
            hint = LaunchAtLogin.failureHint(enabling: enabled, error: error)
            // 系统没答应，开关不能停在用户以为成功的位置
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }

    /// 非 .app 环境（swift run）读不到 bundle 版本，降级为开发构建
    private static var versionText: String {
        let info = Bundle.main.infoDictionary
        guard let short = info?["CFBundleShortVersionString"] as? String else {
            return "开发构建"
        }
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(short) (\($0))" } ?? short
    }
}
