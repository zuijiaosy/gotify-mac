import ServiceManagement
import SwiftUI

/// 通用设置即时生效；登录启动状态由系统管理，快捷键写入配置。
struct GeneralSettingsTab: View {
    let model: AppModel
    let shortcuts: GlobalShortcuts
    @State private var launchAtLogin = false
    @State private var hint: String?

    var body: some View {
        Form {
            Section("启动与通知") {
                Toggle(isOn: $launchAtLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("登录时启动 Gotify Mac")
                        Text("菜单栏应用没有 Dock 图标，开启后将在登录时静默启动")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: launchAtLogin) { _, enabled in apply(enabled) }

                if let hint {
                    Label(hint, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }

                Toggle(isOn: notificationsBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("新消息弹出系统通知")
                        Text("通知显示应用名、标题和摘要，首次弹出时系统会询问授权")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                ForEach(ShortcutAction.allCases, id: \.rawValue) { action in
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent(action.title) {
                            ShortcutRecorderControl(
                                binding: shortcuts.bindings[action],
                                isRecording: shortcuts.recording == action,
                                onRecord: { shortcuts.beginRecording(action) },
                                onClear: { shortcuts.update(action, to: nil) }
                            )
                        }
                        if let error = shortcuts.errors[action] {
                            Label(error, systemImage: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            } header: {
                Text("全局快捷键")
            } footer: {
                Text("点击录入含 ⌘、⌃ 或 ⌥ 的组合键，按 Esc 取消；仅在应用运行时生效。")
            }

            Section {
                LabeledContent("版本") {
                    Text(Self.versionText)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: syncFromSystem)
        .onDisappear { shortcuts.cancelRecording() }
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { model.config.notificationsEnabled },
            set: { enabled in
                var new = model.config
                new.notificationsEnabled = enabled
                model.saveConfig(new)
            }
        )
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

/// 原生风格的全局快捷键录入控件：键帽样式展示当前绑定，录入时以主题色高亮提示
private struct ShortcutRecorderControl: View {
    let binding: KeyboardShortcutBinding?
    let isRecording: Bool
    let onRecord: () -> Void
    let onClear: () -> Void

    @State private var isHovered = false
    @State private var isClearHovered = false

    private var canClear: Bool {
        binding != nil || isRecording
    }

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onRecord) {
                HStack(spacing: 4) {
                    if isRecording {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                        Text("按下组合键…")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    } else if let binding {
                        Text(Self.spacedDisplayName(binding.displayName))
                            .font(.system(size: 12.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                            .tracking(0.5)
                    } else {
                        Text("点击录入")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 118, height: 24)
                .background(recorderBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(recorderBorder, lineWidth: isRecording ? 1.5 : 0.75)
                )
                .shadow(color: isRecording ? Color.clear : Color.black.opacity(0.04), radius: 1, y: 0.5)
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .help("录入快捷键，按 Escape 取消")

            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(clearIconColor)
            }
            .buttonStyle(.borderless)
            .disabled(!canClear)
            .onHover { isClearHovered = $0 }
            .help("清除快捷键")
        }
    }

    private var recorderBackground: Color {
        if isRecording { return Color.accentColor.opacity(0.11) }
        if isHovered { return Color.primary.opacity(0.05) }
        return Color(nsColor: .controlBackgroundColor)
    }

    private var recorderBorder: Color {
        if isRecording { return Color.accentColor }
        if isHovered { return Color.primary.opacity(0.24) }
        return Color.primary.opacity(0.14)
    }

    private var clearIconColor: Color {
        guard canClear else { return Color.secondary.opacity(0.28) }
        return isClearHovered ? Color.primary.opacity(0.70) : Color.secondary.opacity(0.65)
    }

    /// 在修饰键符号间插入窄空格（如 "⌃⌥G" → "⌃ ⌥ G"），提升键帽可读性
    private static func spacedDisplayName(_ raw: String) -> String {
        var result = ""
        for (index, ch) in raw.enumerated() {
            if index > 0 {
                let prev = raw[raw.index(raw.startIndex, offsetBy: index - 1)]
                if "⌃⌥⇧⌘".contains(prev) {
                    result.append(" ")
                }
            }
            result.append(ch)
        }
        return result
    }
}
