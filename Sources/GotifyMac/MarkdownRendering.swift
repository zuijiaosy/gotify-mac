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
    /// 详情页正文：渲染为带样式的 AttributedString
    static func attributedBody(_ text: String) -> AttributedString {
        var result = AttributedString()
        for (index, line) in text.components(separatedBy: "\n").enumerated() {
            if index > 0 { result.append(AttributedString("\n")) }
            result.append(attributedLine(line))
        }
        return result
    }

    /// 列表预览与系统通知横幅：剥掉标记的纯文本（这两处无法渲染样式）
    static func plainPreview(_ text: String) -> String {
        text.components(separatedBy: "\n")
            .map(strippedLine)
            .joined(separator: "\n")
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
                return (indent + rest.trimmingCharacters(in: .whitespaces), true)
            }
        }

        // 无序列表：- / * / + 后跟空格
        if let marker = body.first, "-*+".contains(marker), body.dropFirst().first == " " {
            return (indent + "•  " + body.dropFirst(2), false)
        }

        return (line, false)
    }

    private static func inlineParsed(_ text: String) -> AttributedString {
        guard !text.isEmpty else { return AttributedString() }
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        // 未闭合标记等异常输入回退为原始文本，不能丢内容
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    // MARK: - 剥符号

    /// 只匹配成对标记，不做裸 * / _ 的全局删除，避免误伤 snake_case、乘号等
    private static let inlinePatterns: [(pattern: String, template: String)] = [
        (#"\[([^\]]+)\]\([^)]*\)"#, "$1"),  // 链接只留文字
        (#"\*\*(.+?)\*\*"#, "$1"),
        (#"__(.+?)__"#, "$1"),
        (#"`(.+?)`"#, "$1"),
    ]

    /// 预编译，避免每行渲染都重建正则
    private static let inlineRegexes: [(NSRegularExpression, String)] =
        inlinePatterns.compactMap { spec in
            guard let regex = try? NSRegularExpression(pattern: spec.pattern) else { return nil }
            return (regex, spec.template)
        }

    private static func strippedLine(_ line: String) -> String {
        let indent = line.prefix { $0 == " " || $0 == "\t" }
        var body = String(line.dropFirst(indent.count))

        let hashes = body.prefix { $0 == "#" }
        if (1...6).contains(hashes.count), body.dropFirst(hashes.count).first == " " {
            body = body.dropFirst(hashes.count).trimmingCharacters(in: .whitespaces)
        } else if let marker = body.first, "-*+".contains(marker), body.dropFirst().first == " " {
            body = String(body.dropFirst(2))
        }

        for (regex, template) in inlineRegexes {
            body = regex.stringByReplacingMatches(
                in: body,
                range: NSRange(body.startIndex..., in: body),
                withTemplate: template
            )
        }
        return indent + body
    }
}

extension GotifyMessage {
    /// 列表行与通知横幅共用的正文摘要。纯文本消息原样返回，行为与改造前完全一致。
    var previewText: String {
        contentType == .markdown ? MarkdownRenderer.plainPreview(message) : message
    }
}
