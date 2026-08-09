import Foundation

/// Markdown 正文渲染与纯文本摘要。
///
/// 渲染策略是「行级块前缀自己处理 + 行内语法交给系统解析」：
/// `AttributedString(markdown:)` 的 `.full` 模式会丢掉全部换行，且列表结构只落在
/// SwiftUI Text 不渲染的 PresentationIntent 上，直接用会把多行通知挤成一行；
/// `.inlineOnlyPreservingWhitespace` 保留换行、能解析行内语法，但 `- ` `# `
/// 这类块级标记保持字面量。故按行拆开，块级标记自己转换，行内交给系统。
///
/// 支持：加粗、斜体、行内代码、链接、无序列表、ATX 标题。
/// 不支持（按字面量显示）：表格、围栏代码块、嵌套列表、图片、HTML。
enum MarkdownRenderer {
    /// 列表项在详情页显示为圆点；摘要里再去掉
    private static let bulletPrefix = "•  "

    /// 详情页正文：渲染为带样式的 AttributedString
    static func attributedBody(_ text: String) -> AttributedString {
        var result = AttributedString()
        var inFence = false
        for (index, line) in text.components(separatedBy: "\n").enumerated() {
            if index > 0 { result.append(AttributedString("\n")) }
            if isFenceDelimiter(line) {
                inFence.toggle()
                result.append(AttributedString(line))
                continue
            }
            result.append(inFence ? AttributedString(line) : attributedLine(line))
        }
        return result
    }

    /// 列表预览与系统通知横幅：剥掉标记的纯文本（这两处无法渲染样式）。
    ///
    /// 直接取详情渲染结果的字符，与详情页共用同一条解析路径。此前摘要另走一套正则，
    /// 结果两边对行内代码里的标记、转义符、intraword 强调等理解不一致——
    /// 详情渲染了而摘要残留标记。共用解析器后这类分歧不可能再出现。
    static func plainPreview(_ text: String) -> String {
        String(attributedBody(text).characters)
            .components(separatedBy: "\n")
            .map(strippedBullet)
            .joined(separator: "\n")
    }

    /// 圆点是给详情页看的视觉标记，纯文本摘要里不需要
    private static func strippedBullet(_ line: String) -> String {
        let indent = line.prefix { $0 == " " || $0 == "\t" }
        let body = line.dropFirst(indent.count)
        guard body.hasPrefix(bulletPrefix) else { return line }
        return String(indent) + String(body.dropFirst(bulletPrefix.count))
    }

    /// 围栏代码块内一律按字面量处理：块级标记不转换、行内语法不解析，
    /// 否则代码里的 `- ` `# ` 会被当成列表和标题，源码字符被吃掉。
    private static func isFenceDelimiter(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~")
    }

    // MARK: - 渲染

    private static func attributedLine(_ line: String) -> AttributedString {
        let block = blockPrefix(line)
        var attributed = inlineParsed(block.content)
        if block.isHeading {
            attributed.inlinePresentationIntent = .stronglyEmphasized
        }
        return attributed
    }

    /// 把块级标记转成可直接显示的形式：列表项换成圆点，标题剥掉井号并标记加粗
    private static func blockPrefix(_ line: String) -> (content: String, isHeading: Bool) {
        let indent = line.prefix { $0 == " " || $0 == "\t" }
        let body = line.dropFirst(indent.count)

        // ATX 标题：1~6 个 # 后跟空格
        let hashes = body.prefix { $0 == "#" }
        if (1...6).contains(hashes.count) {
            let rest = body.dropFirst(hashes.count)
            if rest.first == " " {
                return (indent + stripAtxClosing(rest.trimmingCharacters(in: .whitespaces)), true)
            }
        }

        // 无序列表：- / * / + 后跟空格
        if let marker = body.first, "-*+".contains(marker), body.dropFirst().first == " " {
            return (indent + bulletPrefix + body.dropFirst(2), false)
        }

        return (line, false)
    }

    /// ATX 标题的闭合井号是可选语法（`## 标题 ##`），需与开头井号一并去掉，
    /// 否则详情、列表和横幅都会残留结尾的 `##`
    private static func stripAtxClosing(_ text: String) -> String {
        let trailing = text.reversed().prefix { $0 == "#" }
        guard !trailing.isEmpty else { return text }
        let head = text.dropLast(trailing.count)
        // 闭合井号前必须有空格，避免把 "C#" 这类内容误伤
        guard head.last == " " else { return text }
        return String(head).trimmingCharacters(in: .whitespaces)
    }

    private static func inlineParsed(_ text: String) -> AttributedString {
        guard !text.isEmpty else { return AttributedString() }
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        // 未闭合标记等异常输入回退为原始文本，不能丢内容
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

extension GotifyMessage {
    /// 列表行与通知横幅共用的正文摘要。纯文本消息原样返回，行为与改造前完全一致。
    var previewText: String {
        contentType == .markdown ? MarkdownRenderer.plainPreview(message) : message
    }
}
