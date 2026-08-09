import Foundation
import Testing
@testable import GotifyMac

/// 打真实本地 Gotify 服务端的集成测试，默认跳过。
/// 运行：先 docker compose -f deploy/gotify/docker-compose.yml up -d，
/// 再 GOTIFY_E2E=1 scripts/test.sh
@Suite(
    .enabled(if: ProcessInfo.processInfo.environment["GOTIFY_E2E"] == "1"),
    .serialized
)
struct IntegrationTests {
    static let base = URL(string: "http://127.0.0.1:18080")!

    struct IntegrationError: Error, CustomStringConvertible {
        let description: String
        init(_ text: String) { description = text }
    }

    struct TempResources {
        let clientID: Int
        let clientToken: String
        let appID: Int
        let appToken: String
    }

    struct CreatedEntity: Decodable {
        let id: Int
        let token: String
    }

    // MARK: - admin API（仅测试内使用，本地默认账号）

    func adminRequest(_ method: String, _ path: String, body: [String: String]? = nil) async throws -> Data {
        var request = URLRequest(url: Self.base.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue(
            "Basic " + Data("admin:admin".utf8).base64EncodedString(),
            forHTTPHeaderField: "Authorization"
        )
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw IntegrationError("\(method) \(path) 返回 \(code)")
        }
        return data
    }

    func createResources() async throws -> TempResources {
        let suffix = UUID().uuidString.prefix(8)
        let client = try JSONDecoder().decode(
            CreatedEntity.self,
            from: try await adminRequest("POST", "client", body: ["name": "e2e-client-\(suffix)"])
        )
        let app = try JSONDecoder().decode(
            CreatedEntity.self,
            from: try await adminRequest("POST", "application", body: ["name": "e2e-app-\(suffix)"])
        )
        return TempResources(
            clientID: client.id, clientToken: client.token,
            appID: app.id, appToken: app.token
        )
    }

    func destroy(_ resources: TempResources) async {
        _ = try? await adminRequest("DELETE", "client/\(resources.clientID)")
        _ = try? await adminRequest("DELETE", "application/\(resources.appID)")
    }

    func sendMessage(
        title: String, body: String, priority: Int, appToken: String,
        extras: [String: Any]? = nil
    ) async throws {
        var request = URLRequest(url: Self.base.appendingPathComponent("message"))
        request.httpMethod = "POST"
        request.setValue(appToken, forHTTPHeaderField: "X-Gotify-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = [
            "title": title, "message": body, "priority": priority,
        ]
        if let extras { payload["extras"] = extras }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw IntegrationError("发送消息失败")
        }
    }

    // MARK: - 用例

    @Test func REST发送与拉取一致() async throws {
        let resources = try await createResources()
        do {
            let marker = "rest-e2e-\(UUID().uuidString.prefix(8))"
            try await sendMessage(title: marker, body: "REST 一致性验证", priority: 5, appToken: resources.appToken)

            let client = GotifyClient(baseURL: Self.base, token: resources.clientToken)
            let page = try await client.messages(limit: 20)
            let found = page.messages.first { $0.title == marker }
            #expect(found != nil)
            #expect(found?.message == "REST 一致性验证")
            #expect(found?.displayPriority == 5)
            #expect(found?.appid == resources.appID)

            let apps = try await client.applications()
            #expect(apps.contains { $0.id == resources.appID })
        } catch {
            await destroy(resources)
            throw error
        }
        await destroy(resources)
    }

    /// 业务项目推送 markdown 通知的真实链路：extras 声明 → 拉取后识别 → 摘要剥符号
    @Test func markdown通知端到端识别与渲染() async throws {
        let resources = try await createResources()
        do {
            let marker = "md-e2e-\(UUID().uuidString.prefix(8))"
            let body = "**用户**: test@example.com\n- 金额: ¥199\n- 订单号: P2025"
            try await sendMessage(
                title: marker, body: body, priority: 5, appToken: resources.appToken,
                extras: ["client::display": ["contentType": "text/markdown"]]
            )

            let client = GotifyClient(baseURL: Self.base, token: resources.clientToken)
            let page = try await client.messages(limit: 20)
            let found = try #require(page.messages.first { $0.title == marker })
            #expect(found.contentType == .markdown)
            #expect(found.previewText == "用户: test@example.com\n金额: ¥199\n订单号: P2025")
            let rendered = String(MarkdownRenderer.attributedBody(found.message).characters)
            #expect(rendered == "用户: test@example.com\n•  金额: ¥199\n•  订单号: P2025")
        } catch {
            await destroy(resources)
            throw error
        }
        await destroy(resources)
    }

    @Test func WebSocket收到实时消息() async throws {
        let resources = try await createResources()
        do {
            let marker = "stream-e2e-\(UUID().uuidString.prefix(8))"
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await event in GotifyStream.events(baseURL: Self.base, token: resources.clientToken) {
                        switch event {
                        case .connected:
                            try await self.sendMessage(
                                title: marker, body: "流式验证", priority: 2,
                                appToken: resources.appToken
                            )
                        case .message(let message):
                            if message.title == marker {
                                #expect(message.message == "流式验证")
                                return
                            }
                        case .disconnected:
                            break
                        }
                    }
                    throw IntegrationError("流意外结束")
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(10))
                    throw IntegrationError("10 秒内未从 WebSocket 收到消息")
                }
                try await group.next()
                group.cancelAll()
            }
        } catch {
            await destroy(resources)
            throw error
        }
        await destroy(resources)
    }
}
