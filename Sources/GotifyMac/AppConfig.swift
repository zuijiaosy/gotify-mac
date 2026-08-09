import Foundation

/// 本地配置文件（ADR-008/ADR-009）：~/Library/Application Support/GotifyMac/config.json
/// 保存服务器地址、Client Token 与通知偏好；文件在仓库之外，不会被提交。
struct AppConfig: Codable {
    var serverURL: String
    var clientToken: String
    var notificationsEnabled: Bool
    var soundEnabled: Bool

    static let fileURL: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("GotifyMac/config.json")

    static let `default` = AppConfig(serverURL: "http://127.0.0.1:18080", clientToken: "")

    init(
        serverURL: String,
        clientToken: String,
        notificationsEnabled: Bool = true,
        soundEnabled: Bool = true
    ) {
        self.serverURL = serverURL
        self.clientToken = clientToken
        self.notificationsEnabled = notificationsEnabled
        self.soundEnabled = soundEnabled
    }

    /// 老版本 config.json 缺新字段时逐字段回默认，绝不能整体解码失败
    /// 回落 default——那会让用户已配置的 serverURL/token 看起来"丢失"。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        serverURL = try c.decodeIfPresent(String.self, forKey: .serverURL)
            ?? Self.default.serverURL
        clientToken = try c.decodeIfPresent(String.self, forKey: .clientToken) ?? ""
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
    }

    static func load(from url: URL = fileURL) -> AppConfig {
        guard let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data)
        else { return .default }
        return config
    }

    static func save(_ config: AppConfig, to url: URL = fileURL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        // 保持文件可手工编辑（ADR-008 的使用方式仍然有效）
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: url, options: .atomic)
        // .atomic 是写临时文件再 rename，会丢掉原文件权限位，
        // 必须写后重设 600（Token 明文存盘，ADR-008 要求）
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    var url: URL? { URL(string: serverURL) }
}
