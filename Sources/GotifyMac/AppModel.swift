import Foundation
import Observation

/// 应用状态：当前只负责检查服务器连接和 Token 有效性。
@MainActor
@Observable
final class AppModel {
    private(set) var serverURL = AppConfig.default.serverURL
    private(set) var statusText = "检查中…"

    init() {
        Task { await refresh() }
    }

    func refresh() async {
        statusText = "检查中…"
        let config = AppConfig.load()
        serverURL = config.serverURL
        guard !config.clientToken.isEmpty else {
            statusText = "未配置：请在 config.json 中填入 clientToken"
            return
        }
        guard let base = config.url else {
            statusText = "服务器地址无效"
            return
        }
        var request = URLRequest(url: base.appendingPathComponent("current/user"))
        request.setValue(config.clientToken, forHTTPHeaderField: "X-Gotify-Key")
        request.timeoutInterval = 5
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                statusText = "连接失败：无效响应"
                return
            }
            switch http.statusCode {
            case 200:
                let name = (try? JSONDecoder().decode(CurrentUser.self, from: data))?.name ?? "未知用户"
                statusText = "已连接：\(name)"
            case 401:
                statusText = "Token 无效（401）"
            default:
                statusText = "连接失败：HTTP \(http.statusCode)"
            }
        } catch {
            statusText = "无法连接服务器"
        }
    }
}

private struct CurrentUser: Decodable {
    let name: String
}
