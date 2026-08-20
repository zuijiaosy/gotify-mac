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

    @Test func websocket地址转换() {
        let http = GotifyStream.websocketURL(baseURL: URL(string: "http://127.0.0.1:18080")!)
        #expect(http?.absoluteString == "ws://127.0.0.1:18080/stream")
        let https = GotifyStream.websocketURL(baseURL: URL(string: "https://gotify.example.com")!)
        #expect(https?.absoluteString == "wss://gotify.example.com/stream")
        let subpath = GotifyStream.websocketURL(baseURL: URL(string: "https://example.com/gotify/")!)
        #expect(subpath?.absoluteString == "wss://example.com/gotify/stream")
    }
}
