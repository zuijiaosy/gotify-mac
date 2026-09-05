import Foundation

/// 本地配置文件（ADR-008/ADR-009）：~/Library/Application Support/GotifyMac/config.json
/// 保存服务器地址、Client Token 与通知偏好；文件在仓库之外，不会被提交。
struct AppConfig: Codable {
    var serverURL: String
    var clientToken: String
    var notificationsEnabled: Bool
    var soundEnabled: Bool
    /// 已读水位线：id 大于它的消息视为未读；0 = 从未标记过已读（ADR-011）
    var lastReadMessageID: Int
    var togglePanelShortcut: KeyboardShortcutBinding? = .togglePanel
    var markAllReadShortcut: KeyboardShortcutBinding? = .markAllRead

    static let fileURL: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("GotifyMac/config.json")

    static let `default` = AppConfig(serverURL: "http://127.0.0.1:18080", clientToken: "")

    init(
        serverURL: String,
        clientToken: String,
        notificationsEnabled: Bool = true,
        soundEnabled: Bool = true,
        lastReadMessageID: Int = 0
    ) {
        self.serverURL = serverURL
        self.clientToken = clientToken
        self.notificationsEnabled = notificationsEnabled
        self.soundEnabled = soundEnabled
        self.lastReadMessageID = lastReadMessageID
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
        lastReadMessageID = try c.decodeIfPresent(Int.self, forKey: .lastReadMessageID) ?? 0
        togglePanelShortcut = Self.decodeShortcut(c, key: .togglePanelShortcut, fallback: .togglePanel)
        markAllReadShortcut = Self.decodeShortcut(c, key: .markAllReadShortcut, fallback: .markAllRead)
    }

    private static func decodeShortcut(
        _ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys,
        fallback: KeyboardShortcutBinding
    ) -> KeyboardShortcutBinding? {
        guard container.contains(key) else { return fallback }
        guard let value = try? container.decode(KeyboardShortcutBinding.self, forKey: key),
              value.isValid else { return nil }
        return value
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(serverURL, forKey: .serverURL)
        try c.encode(clientToken, forKey: .clientToken)
        try c.encode(notificationsEnabled, forKey: .notificationsEnabled)
        try c.encode(soundEnabled, forKey: .soundEnabled)
        try c.encode(lastReadMessageID, forKey: .lastReadMessageID)
        // Explicit null distinguishes a cleared shortcut from an older config.
        try c.encode(togglePanelShortcut, forKey: .togglePanelShortcut)
        try c.encode(markAllReadShortcut, forKey: .markAllReadShortcut)
    }

    private enum CodingKeys: String, CodingKey {
        case serverURL, clientToken, notificationsEnabled, soundEnabled, lastReadMessageID
        case togglePanelShortcut, markAllReadShortcut
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
