import Foundation
import Observation

/// 系统通知封装（ADR-016）。macOS 26/27 对 ad-hoc 签名的应用封锁了
/// UNUserNotificationCenter 的直接授权，改用 osascript display notification
/// 通过 ScriptingAdditions 发横幅，无需额外权限即可工作。
/// 裸二进制（swift run / 测试进程）没有 .app bundle，投递前做 bundle 检查。
@MainActor
@Observable
final class NotificationService {
    private(set) var available = false
    private(set) var statusHint = ""

    func setUp() async {
        guard Bundle.main.bundleIdentifier != nil,
              Bundle.main.bundlePath.hasSuffix(".app") else {
            statusHint = "非 .app 运行，通知不可用"
            return
        }
        available = true
    }

    /// 调用方保证只对真正新增的消息调用（MessageStore.insert 返回 true）。
    /// 内容与主界面列表行一致：应用名 + 标题 + 正文摘要，不含详情。
    func post(_ message: GotifyMessage, appName: String, sound: Bool = true) {
        guard available else { return }
        let title = "\(appName): \(message.displayTitle)"
        let body = message.previewText
        // AppleScript 用双引号界定字符串，转义内部的反斜杠和双引号
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\")
             .replacingOccurrences(of: "\"", with: "\\\"")
        }
        let soundClause = sound ? " sound name \"default\"" : ""
        let script = "display notification \"\(esc(body))\" with title \"\(esc(title))\"\(soundClause)"
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments  = ["-e", script]
        task.standardOutput = FileHandle.nullDevice
        task.standardError  = FileHandle.nullDevice
        try? task.run()
    }
}
