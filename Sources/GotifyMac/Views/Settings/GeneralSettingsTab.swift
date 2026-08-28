import ServiceManagement
import SwiftUI

/// 通用标签：登录时启动 + 版本号。开关即时生效（ADR-009：只有服务器地址与
/// Token 走草稿 + 显式提交）；状态不落盘，每次出现时重新问系统（ADR-014）。
struct GeneralSettingsTab: View {
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
            Section {
                LabeledContent("版本", value: Self.versionText)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: syncFromSystem)
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
