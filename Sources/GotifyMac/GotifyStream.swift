import Foundation
import os

enum StreamEvent: Sendable {
    /// 收到首帧（视为连接成功），上层应做 REST 补拉
    case connected
    case message(GotifyMessage)
    /// 已断开并进入退避等待
    case disconnected(reason: String)
}

/// Gotify WebSocket /stream 封装：迭代返回的流即启动连接，
/// 取消迭代方所在的 Task 即断开。重连状态全部是内部 Task 的局部变量。
enum GotifyStream {
    static func events(
        baseURL: URL,
        token: String,
        session: URLSession = .shared
    ) -> AsyncStream<StreamEvent> {
        AsyncStream { continuation in
            let task = Task {
                var attempt = 0
                while !Task.isCancelled {
                    guard let wsURL = websocketURL(baseURL: baseURL) else {
                        continuation.yield(.disconnected(reason: "服务器地址无效"))
                        break
                    }
                    var request = URLRequest(url: wsURL)
                    request.setValue(token, forHTTPHeaderField: "X-Gotify-Key")
                    let wsTask = session.webSocketTask(with: request)
                    wsTask.resume()

                    do {
                        // 服务端连上后不会主动发帧，用 ping/pong 确认握手成功
                        try await withTaskCancellationHandler {
                            try await ping(wsTask)
                        } onCancel: {
                            wsTask.cancel(with: .goingAway, reason: nil)
                        }
                        attempt = 0
                        continuation.yield(.connected)
                        while !Task.isCancelled {
                            // onCancel 里取消 wsTask，让挂起中的 receive 立即抛错退出
                            let frame = try await withTaskCancellationHandler {
                                try await wsTask.receive()
                            } onCancel: {
                                wsTask.cancel(with: .goingAway, reason: nil)
                            }
                            if let message = decode(frame) {
                                continuation.yield(.message(message))
                            }
                        }
                        wsTask.cancel(with: .goingAway, reason: nil)
                    } catch {
                        wsTask.cancel(with: .goingAway, reason: nil)
                        if Task.isCancelled { break }
                        continuation.yield(.disconnected(reason: "连接中断，稍后重连"))
                        do {
                            try await Task.sleep(for: backoffDelay(attempt: attempt))
                        } catch {
                            break  // sleep 被取消
                        }
                        attempt += 1
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// http(s)://host → ws(s)://host/stream
    static func websocketURL(baseURL: URL) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = components.path.hasSuffix("/")
            ? components.path + "stream"
            : components.path + "/stream"
        return components.url
    }

    /// 指数退避：1s 起步翻倍，封顶 60s，±20% 抖动
    static func backoffDelay(attempt: Int, jitter: Double = Double.random(in: 0.8...1.2)) -> Duration {
        let base = min(pow(2.0, Double(min(attempt, 6))), 60.0)
        return .seconds(base * jitter)
    }

    private static func ping(_ task: URLSessionWebSocketTask) async throws {
        try await ping(send: task.sendPing)
    }

    /// sendPing 的 pongReceiveHandler 在「连接失败叠加任务取消」时会被 Foundation
    /// 回调两次，continuation 只允许 resume 一次，多余的回调必须丢弃（否则崩溃）
    static func ping(
        send: (@escaping @Sendable (Error?) -> Void) -> Void
    ) async throws {
        let resumed = OSAllocatedUnfairLock(initialState: false)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            send { error in
                let isFirst = resumed.withLock { done in
                    if done { return false }
                    done = true
                    return true
                }
                guard isFirst else { return }
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            }
        }
    }

    private static func decode(_ frame: URLSessionWebSocketTask.Message) -> GotifyMessage? {
        let data: Data
        switch frame {
        case .string(let text):
            data = Data(text.utf8)
        case .data(let raw):
            data = raw
        @unknown default:
            return nil
        }
        return try? JSONDecoder.gotify.decode(GotifyMessage.self, from: data)
    }
}
