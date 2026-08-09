import SwiftUI

/// 正文渲染方式，由 extras 的 client::display.contentType 决定
enum MessageContentType: Sendable, Equatable {
    case plain, markdown
}

/// Gotify 消息（GET /message 与 WebSocket /stream 共用同一 JSON 结构）
struct GotifyMessage: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let appid: Int
    let title: String?
    let message: String
    let priority: Int?
    let date: Date
    let extras: MessageExtras?

    init(id: Int, appid: Int, title: String?, message: String,
         priority: Int?, date: Date, extras: MessageExtras? = nil) {
        self.id = id
        self.appid = appid
        self.title = title
        self.message = message
        self.priority = priority
        self.date = date
        self.extras = extras
    }

    var displayTitle: String {
        let t = title ?? ""
        return t.isEmpty ? "（无标题）" : t
    }

    var displayPriority: Int { priority ?? 0 }

    /// 未声明或声明为其它类型时一律按纯文本处理，保证旧消息行为不变
    var contentType: MessageContentType {
        let raw = extras?.clientDisplay?.contentType?
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        return raw == "text/markdown" ? .markdown : .plain
    }
}

/// 消息扩展字段。extras 是任意嵌套 JSON，这里只定向解析约定键 client::display，
/// 其余内容忽略。两级 init(from:) 都不抛错：extras 畸形时降级为 nil，绝不能让
/// 整条消息解码失败——GotifyStream.decode 用 try? 解码，抛错会导致实时消息被静默丢弃。
struct MessageExtras: Codable, Hashable, Sendable {
    let clientDisplay: ClientDisplay?

    struct ClientDisplay: Codable, Hashable, Sendable {
        let contentType: String?

        init(contentType: String?) {
            self.contentType = contentType
        }

        init(from decoder: Decoder) {
            guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
                contentType = nil
                return
            }
            contentType = try? container.decodeIfPresent(String.self, forKey: .contentType)
        }
    }

    enum CodingKeys: String, CodingKey {
        case clientDisplay = "client::display"
    }

    init(clientDisplay: ClientDisplay?) {
        self.clientDisplay = clientDisplay
    }

    init(from decoder: Decoder) {
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            clientDisplay = nil
            return
        }
        clientDisplay = try? container.decodeIfPresent(ClientDisplay.self, forKey: .clientDisplay)
    }
}

/// Gotify 应用（GET /application）
struct GotifyApplication: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let description: String
    let image: String
}

struct PagedMessages: Codable, Sendable {
    let messages: [GotifyMessage]
    let paging: Paging
}

struct Paging: Codable, Sendable {
    let size: Int
    let limit: Int
    let since: Int?
    let next: String?
}

/// 优先级分档：>=8 红、4-7 橙、1-3 蓝、0 灰
enum PriorityTier: Sendable {
    case critical, high, normal, low

    init(priority: Int) {
        switch priority {
        case 8...: self = .critical
        case 4...7: self = .high
        case 1...3: self = .normal
        default: self = .low
        }
    }

    var color: Color {
        switch self {
        case .critical: .red
        case .high: .orange
        case .normal: .blue
        case .low: .gray
        }
    }
}

/// Gotify 日期是 RFC3339，可能带也可能不带小数秒，两个 formatter 依次尝试。
/// ISO8601DateFormatter 线程安全，nonisolated(unsafe) 仅为跳过 Sendable 检查。
private enum GotifyDate {
    nonisolated(unsafe) static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ raw: String) -> Date? {
        fractional.date(from: raw) ?? plain.date(from: raw)
    }
}

extension JSONDecoder {
    static let gotify: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = GotifyDate.parse(raw) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "无法解析日期: \(raw)"
                ))
            }
            return date
        }
        return decoder
    }()
}
