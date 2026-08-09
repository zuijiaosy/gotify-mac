import Foundation
import Testing
@testable import GotifyMac

@Suite struct MarkdownRenderingTests {
    /// 业务侧管理员通知的典型形态
    static let sample = """
    **用户**: zuijiaosy@gmail.com
    - 金额: ¥199
    - 订单号: P2025080912
    """

    // MARK: - attributedBody

    @Test func 保留换行() {
        let rendered = MarkdownRenderer.attributedBody(Self.sample)
        let text = String(rendered.characters)
        #expect(text.filter { $0 == "\n" }.count == 2)
    }

    @Test func 列表前缀转为圆点() {
        let rendered = MarkdownRenderer.attributedBody(Self.sample)
        let text = String(rendered.characters)
        #expect(text.contains("•  金额: ¥199"))
        #expect(!text.contains("- 金额"))
    }

    @Test func 加粗标记被解析且不残留星号() {
        let rendered = MarkdownRenderer.attributedBody("**用户**: a@b.com")
        #expect(!String(rendered.characters).contains("*"))
        let bolded = rendered.runs.contains { $0.inlinePresentationIntent == .stronglyEmphasized }
        #expect(bolded)
    }

    @Test func 井号标题剥前缀并整行加粗() {
        let rendered = MarkdownRenderer.attributedBody("## 库存预警")
        let text = String(rendered.characters)
        #expect(text == "库存预警")
        #expect(rendered.runs.allSatisfy { $0.inlinePresentationIntent == .stronglyEmphasized })
    }

    @Test func 未闭合标记回退原文不崩溃() {
        let rendered = MarkdownRenderer.attributedBody("金额 ** 未闭合")
        #expect(String(rendered.characters).contains("未闭合"))
    }

    @Test func 纯文本原样输出() {
        let plain = "服务器磁盘使用率达到 85%"
        #expect(String(MarkdownRenderer.attributedBody(plain).characters) == plain)
    }

    @Test func 空行保留为段落间距() {
        let rendered = MarkdownRenderer.attributedBody("第一段\n\n第二段")
        #expect(String(rendered.characters) == "第一段\n\n第二段")
    }

    // MARK: - plainPreview

    @Test func 剥掉加粗与列表标记() {
        let preview = MarkdownRenderer.plainPreview(Self.sample)
        #expect(preview == "用户: zuijiaosy@gmail.com\n金额: ¥199\n订单号: P2025080912")
    }

    @Test func 链接只保留文字() {
        #expect(MarkdownRenderer.plainPreview("详情见[后台](https://a.com/x)") == "详情见后台")
    }

    @Test func 行内代码剥反引号() {
        #expect(MarkdownRenderer.plainPreview("订单 `P2025` 已支付") == "订单 P2025 已支付")
    }

    @Test(arguments: ["user_id: 42", "a*b*c 与 2*3", "snake_case_name", "3 * 4 = 12"])
    func 不误伤裸下划线与星号(input: String) {
        #expect(MarkdownRenderer.plainPreview(input) == input)
    }

    @Test(arguments: [("*斜体*", "斜体"), ("_斜体_", "斜体"), ("金额 *偏低* 请注意", "金额 偏低 请注意")])
    func 剥掉单标记斜体(input: String, expected: String) {
        #expect(MarkdownRenderer.plainPreview(input) == expected)
    }

    /// 详情页能渲染的行内语法，摘要里就不该残留标记
    @Test func 摘要不残留任何成对标记() {
        let raw = "**加粗** 与 *斜体* 与 `代码` 与 [链接](https://a.com)"
        #expect(MarkdownRenderer.plainPreview(raw) == "加粗 与 斜体 与 代码 与 链接")
    }

    // MARK: - previewText 门控

    @Test func 纯文本消息previewText与原文完全一致() {
        let raw = "**这不是 markdown**\n- 原样显示"
        let message = GotifyMessage(id: 1, appid: 1, title: "t", message: raw,
                                    priority: 0, date: .now)
        #expect(message.previewText == raw)
    }

    @Test func markdown消息previewText剥符号() {
        let extras = MessageExtras(clientDisplay: .init(contentType: "text/markdown"))
        let message = GotifyMessage(id: 1, appid: 1, title: "t", message: "**金额**: ¥199",
                                    priority: 0, date: .now, extras: extras)
        #expect(message.previewText == "金额: ¥199")
    }
}
