import Foundation

/// 消息仓库：按 id 降序、去重、只保留最近 maxCount 条。纯逻辑，无网络无 UI。
struct MessageStore: Sendable {
    private(set) var messages: [GotifyMessage] = []
    var maxCount = 200

    private var knownIDs: Set<Int> = []

    /// 批量合并（初次加载/重连补拉），返回真正新增的消息（供通知判断）
    mutating func merge(_ incoming: [GotifyMessage]) -> [GotifyMessage] {
        var fresh: [GotifyMessage] = []
        for message in incoming where !knownIDs.contains(message.id) {
            knownIDs.insert(message.id)
            fresh.append(message)
        }
        guard !fresh.isEmpty else { return [] }
        messages.append(contentsOf: fresh)
        messages.sort { $0.id > $1.id }
        trim()
        return fresh
    }

    /// WebSocket 单条插入；返回 false 表示 id 已存在（去重）
    mutating func insert(_ message: GotifyMessage) -> Bool {
        guard !knownIDs.contains(message.id) else { return false }
        if let index = messages.firstIndex(where: { $0.id < message.id }) {
            messages.insert(message, at: index)
        } else {
            messages.append(message)
        }
        knownIDs.insert(message.id)
        trim()
        return true
    }

    var maxKnownID: Int { messages.first?.id ?? 0 }

    private mutating func trim() {
        if messages.count > maxCount {
            messages.removeLast(messages.count - maxCount)
        }
        knownIDs = Set(messages.map(\.id))
    }
}
