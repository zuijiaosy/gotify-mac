import Foundation

/// 本地配置文件（ADR-008）：~/Library/Application Support/GotifyMac/config.json
/// 保存服务器地址和 Client Token；文件在仓库之外，不会被提交。
struct AppConfig: Codable {
    var serverURL: String
    var clientToken: String

    static let fileURL: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("GotifyMac/config.json")

    static let `default` = AppConfig(serverURL: "http://127.0.0.1:18080", clientToken: "")

    static func load() -> AppConfig {
        guard let data = try? Data(contentsOf: fileURL),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data)
        else { return .default }
        return config
    }

    var url: URL? { URL(string: serverURL) }
}
