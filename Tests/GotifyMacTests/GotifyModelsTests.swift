import Foundation
import Testing
@testable import GotifyMac

@Suite struct GotifyModelsTests {
    /// 真实服务端响应（Gotify 2.7.3）截取的 fixture
    static let pagedJSON = """
    {
        "paging": {"next": "http://127.0.0.1:18080/message?limit=2&since=3", "size": 2, "since": 3, "limit": 2},
        "messages": [
            {"id": 4, "appid": 1, "message": "每日备份任务执行成功", "title": "定时任务", "priority": 5, "date": "2026-08-08T20:58:09.418750118+08:00"},
            {"id": 3, "appid": 1, "message": "服务器磁盘使用率达到 85%", "title": "磁盘告警", "priority": 8, "date": "2026-08-08T20:58:09+08:00"}
        ]
    }
    """

    @Test func 解码真实分页响应() throws {
        let page = try JSONDecoder.gotify.decode(PagedMessages.self, from: Data(Self.pagedJSON.utf8))
        #expect(page.messages.count == 2)
        #expect(page.paging.since == 3)
        #expect(page.messages[0].id == 4)
        #expect(page.messages[0].title == "定时任务")
        #expect(page.messages[1].priority == 8)
    }

    @Test func 日期带与不带小数秒都能解析() throws {
        let page = try JSONDecoder.gotify.decode(PagedMessages.self, from: Data(Self.pagedJSON.utf8))
        let withFraction = page.messages[0].date
        let noFraction = page.messages[1].date
        // 两条消息时间相同（忽略小数秒），差应小于 1 秒
        #expect(abs(withFraction.timeIntervalSince(noFraction)) < 1.0)
    }

    @Test func 无效日期抛错() {
        let bad = #"{"id":1,"appid":1,"message":"x","date":"not-a-date"}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder.gotify.decode(GotifyMessage.self, from: Data(bad.utf8))
        }
    }

    @Test func 缺省字段容错() throws {
        // title 和 priority 缺失时应能解码
        let minimal = #"{"id":7,"appid":2,"message":"内容","date":"2026-08-08T10:00:00Z"}"#
        let message = try JSONDecoder.gotify.decode(GotifyMessage.self, from: Data(minimal.utf8))
        #expect(message.title == nil)
        #expect(message.displayTitle == "（无标题）")
        #expect(message.displayPriority == 0)
    }

    @Test(arguments: [
        (0, PriorityTier.low), (1, PriorityTier.normal), (3, PriorityTier.normal),
        (4, PriorityTier.high), (7, PriorityTier.high), (8, PriorityTier.critical),
        (10, PriorityTier.critical), (-1, PriorityTier.low),
    ])
    func 优先级分档边界(priority: Int, expected: PriorityTier) {
        #expect(PriorityTier(priority: priority) == expected)
    }

    @Test func 解码应用列表() throws {
        let json = #"[{"id":1,"token":"A9K","name":"测试应用","description":"本地联调用","internal":false,"image":"static/defaultapp.png","defaultPriority":0}]"#
        let apps = try JSONDecoder.gotify.decode([GotifyApplication].self, from: Data(json.utf8))
        #expect(apps.first?.name == "测试应用")
        #expect(apps.first?.image == "static/defaultapp.png")
    }
}

extension PriorityTier: Equatable {}
