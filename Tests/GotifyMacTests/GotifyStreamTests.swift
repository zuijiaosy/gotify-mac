import Foundation
import Testing
@testable import GotifyMac

@Suite struct GotifyStreamTests {
    @Test func 退避指数增长且封顶60秒() {
        // jitter 固定为 1 便于断言
        #expect(GotifyStream.backoffDelay(attempt: 0, jitter: 1) == .seconds(1))
        #expect(GotifyStream.backoffDelay(attempt: 1, jitter: 1) == .seconds(2))
        #expect(GotifyStream.backoffDelay(attempt: 2, jitter: 1) == .seconds(4))
        #expect(GotifyStream.backoffDelay(attempt: 5, jitter: 1) == .seconds(32))
        #expect(GotifyStream.backoffDelay(attempt: 6, jitter: 1) == .seconds(60))
        #expect(GotifyStream.backoffDelay(attempt: 100, jitter: 1) == .seconds(60))
    }

    @Test func 退避带抖动上下界() {
        let delay = GotifyStream.backoffDelay(attempt: 3)
        #expect(delay >= .seconds(8 * 0.8))
        #expect(delay <= .seconds(8 * 1.2))
    }

    // 回归：断联时点「重新连接」会取消挂起中的 sendPing，Foundation 会把
    // pongReceiveHandler 回调两次，旧实现二次 resume continuation 直接崩溃（SIGTRAP）
    @Test func ping回调被调用两次不崩溃() async throws {
        try await GotifyStream.ping { handler in
            handler(nil)
            handler(URLError(.cancelled))
        }
    }

    @Test func ping回调两次时以首次错误为准() async {
        await #expect(throws: URLError.self) {
            try await GotifyStream.ping { handler in
                handler(URLError(.networkConnectionLost))
                handler(nil)
            }
        }
    }

    // ping 的反面：Foundation 也可能一次都不回调（wsTask 已终态时），
    // 没有超时兜底的话 continuation 永不 resume，整条流永久挂起且 cancel 唤不醒
    @Test func ping零回调时超时抛出() async {
        await #expect(throws: URLError.self) {
            try await GotifyStream.ping(timeout: .milliseconds(20)) { _ in }
        }
    }

    @Test func ping正常返回时不受超时影响() async throws {
        try await GotifyStream.ping(timeout: .seconds(30)) { handler in handler(nil) }
    }

    // 回归：receive 与 sendPing 同构——取消 wsTask 时 Foundation 同样可能把
    // 完成回调调两次，二次 resume continuation 会 SIGTRAP
    @Test func receive回调被调用两次不崩溃() async throws {
        let frame = try await GotifyStream.receive { handler in
            handler(.success(.string("first")))
            handler(.failure(URLError(.cancelled)))
        }
        // Message 不是 Equatable，取出负载再断言
        guard case .string(let text) = frame else {
            Issue.record("期望 .string 帧")
            return
        }
        #expect(text == "first")
    }

    @Test func receive回调两次时以首次错误为准() async {
        await #expect(throws: URLError.self) {
            _ = try await GotifyStream.receive { handler in
                handler(.failure(URLError(.networkConnectionLost)))
                handler(.success(.string("late")))
            }
        }
    }

    @Test func websocket地址转换() {
        let http = GotifyStream.websocketURL(baseURL: URL(string: "http://127.0.0.1:18080")!)
        #expect(http?.absoluteString == "ws://127.0.0.1:18080/stream")
        let https = GotifyStream.websocketURL(baseURL: URL(string: "https://gotify.example.com")!)
        #expect(https?.absoluteString == "wss://gotify.example.com/stream")
        let subpath = GotifyStream.websocketURL(baseURL: URL(string: "https://example.com/gotify/")!)
        #expect(subpath?.absoluteString == "wss://example.com/gotify/stream")
    }
}
