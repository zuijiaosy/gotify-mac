import Foundation
import Observation
import UserNotifications

/// 系统通知封装。裸二进制（swift run / 测试进程）没有 .app bundle，
/// 直接调 UNUserNotificationCenter 会崩溃，setUp 里必须先做 bundle 检查。
@MainActor
@Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private(set) var available = false
    /// 非空表示通知不可用及原因，面板工具栏展示
    private(set) var statusHint = ""

    func setUp() async {
        guard Bundle.main.bundleIdentifier != nil,
              Bundle.main.bundlePath.hasSuffix(".app") else {
            statusHint = "非 .app 运行，通知不可用"
            return
        }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        do {
            available = try await center.requestAuthorization(options: [.alert, .sound])
            if !available {
                statusHint = "通知被拒绝，请在 系统设置→通知 中开启"
            }
        } catch {
            statusHint = "通知授权失败：\(error.localizedDescription)"
        }
    }

    /// 调用方保证只对真正新增的消息调用（MessageStore.insert 返回 true）
    func post(_ message: GotifyMessage, appName: String, sound: Bool = true) {
        guard available else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(appName): \(message.displayTitle)"
        content.body = message.message
        content.sound = sound ? .default : nil
        let request = UNNotificationRequest(
            identifier: "gotify-message-\(message.id)",  // 同 id 不重复通知的兜底
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// 应用在前台时也展示横幅（默认会被系统静默吞掉）
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
