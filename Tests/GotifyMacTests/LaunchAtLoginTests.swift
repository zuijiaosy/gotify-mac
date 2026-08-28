import Foundation
import ServiceManagement
import Testing
@testable import GotifyMac

// SMAppService 本身不进单测——真跑会真往系统登录项里写。这里只测纯逻辑映射。
@Suite struct LaunchAtLoginTests {
    @Test func 系统域错误提示带上应用程序文件夹指引() {
        let error = NSError(
            domain: "SMAppServiceErrorDomain", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Operation not permitted"])
        let hint = LaunchAtLogin.failureHint(enabling: true, error: error)
        #expect(hint.contains("开启失败"))
        #expect(hint.contains("Operation not permitted"))
        #expect(hint.contains("应用程序"))
    }

    @Test func 非系统域错误只带系统原文() {
        let error = NSError(
            domain: NSCocoaErrorDomain, code: 4099,
            userInfo: [NSLocalizedDescriptionKey: "连接中断"])
        let hint = LaunchAtLogin.failureHint(enabling: false, error: error)
        #expect(hint.contains("关闭失败"))
        #expect(hint.contains("连接中断"))
        #expect(!hint.contains("应用程序"))
    }

    @Test func 仅待批准状态给出批准提示() {
        #expect(LaunchAtLogin.approvalHint(status: .requiresApproval) != nil)
        #expect(LaunchAtLogin.approvalHint(status: .enabled) == nil)
        #expect(LaunchAtLogin.approvalHint(status: .notRegistered) == nil)
        #expect(LaunchAtLogin.approvalHint(status: .notFound) == nil)
    }
}
