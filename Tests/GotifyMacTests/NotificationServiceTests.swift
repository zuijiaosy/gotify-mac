import Foundation
import Testing
@testable import GotifyMac

@Suite struct NotificationServiceTests {
    /// 测试进程没有 .app bundle：setUp 不得崩溃，且 available 必须为 false
    @MainActor @Test func 无bundle环境安全降级() async {
        let service = NotificationService()
        await service.setUp()
        #expect(service.available == false)
        #expect(!service.statusHint.isEmpty)
        // available=false 时 post 应为静默 no-op（不崩溃）
        let message = GotifyMessage(
            id: 1, appid: 1, title: "t", message: "m", priority: 0, date: .now
        )
        service.post(message, appName: "测试")
    }
}
