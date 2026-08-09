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

    @Test(arguments: [
        ("## 库存预警 ##", "库存预警"),
        ("# 标题 #", "标题"),
        ("## 语言 C#", "语言 C#"),  // 闭合井号前需有空格，不误伤 C#
    ])
    func ATX闭合井号一并剥除(input: String, expected: String) {
        #expect(String(MarkdownRenderer.attributedBody(input).characters) == expected)
        #expect(MarkdownRenderer.plainPreview(input) == expected)
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

    /// URL 里带括号（维基百科式链接）时不能在第一个右括号截断
    @Test func 链接地址含括号不残留字符() {
        #expect(MarkdownRenderer.plainPreview("见[文档](https://a.com/a_(b))") == "见文档")
    }

    @Test func 行内代码剥反引号() {
        #expect(MarkdownRenderer.plainPreview("订单 `P2025` 已支付") == "订单 P2025 已支付")
    }

    @Test(arguments: ["user_id: 42", "snake_case_name", "3 * 4 = 12", "2*3 = 6"])
    func 不误伤裸下划线与星号(input: String) {
        #expect(MarkdownRenderer.plainPreview(input) == input)
    }

    /// 摘要与详情共用解析器，CommonMark 允许 `*` 的词内强调，两边结果必须一致
    @Test(arguments: ["a*b*c", "**加粗**", "`**代码内不加粗**`", #"\*转义\*"#])
    func 摘要与详情文本始终一致(input: String) {
        let detail = String(MarkdownRenderer.attributedBody(input).characters)
        #expect(MarkdownRenderer.plainPreview(input) == detail)
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

    // MARK: - 围栏代码块

    static let fenced = """
    执行以下命令:
    ```
    - rm file
    # 注释
    **不是加粗**
    ```
    完成
    """

    @Test func 围栏内不转换块级标记() {
        let rendered = String(MarkdownRenderer.attributedBody(Self.fenced).characters)
        #expect(rendered.contains("- rm file"))
        #expect(rendered.contains("# 注释"))
        #expect(!rendered.contains("•  rm file"))
    }

    @Test func 围栏内不解析行内语法() {
        let rendered = String(MarkdownRenderer.attributedBody(Self.fenced).characters)
        #expect(rendered.contains("**不是加粗**"))
    }

    @Test func 围栏内摘要不剥标记() {
        let preview = MarkdownRenderer.plainPreview(Self.fenced)
        #expect(preview.contains("- rm file"))
        #expect(preview.contains("**不是加粗**"))
    }

    @Test func 围栏结束后恢复正常渲染() {
        let preview = MarkdownRenderer.plainPreview("```\n- 原样\n```\n- 列表项")
        #expect(preview.contains("- 原样"))
        #expect(preview.hasSuffix("列表项"))
        #expect(!preview.hasSuffix("- 列表项"))
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
