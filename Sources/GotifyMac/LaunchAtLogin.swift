import Foundation
import ServiceManagement

/// 登录时启动（ADR-014）。开关状态不落 config.json：`SMAppService` 是系统
/// 真值——用户可以直接在「系统设置 → 通用 → 登录项」里关掉，本地再存一份
/// 布尔必然出现两边不一致。这里只做薄封装，读写都直接问系统。
enum LaunchAtLogin {
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    static var isEnabled: Bool { status == .enabled }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// 注册/注销失败的中文提示。ad-hoc 签名（ADR-013）下系统有可能拒绝登录项
    /// 注册，所以不吞错误——把系统原文一并带出来，用户才有得排查。
    static func failureHint(enabling: Bool, error: Error) -> String {
        let action = enabling ? "开启" : "关闭"
        let ns = error as NSError
        guard ns.domain == "SMAppServiceErrorDomain" else {
            return "\(action)失败：\(ns.localizedDescription)"
        }
        return "\(action)失败：\(ns.localizedDescription)"
            + "（若应用不在「应用程序」文件夹，移过去后重试）"
    }

    /// 注册成功但系统仍要用户点头时的提示；nil = 无需提示
    static func approvalHint(status: SMAppService.Status) -> String? {
        status == .requiresApproval
            ? "已注册，还需在「系统设置 → 通用 → 登录项」中允许后才会生效"
            : nil
    }
}
