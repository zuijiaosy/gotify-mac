import SwiftUI

/// 列表行：左侧独立未读轨道对齐标题，顶部元信息行承接优先级色点、应用名与相对/绝对时间，
/// 保持所有行在已读/未读状态下的文字左边缘严格对齐。
struct MessageRowView: View {
    let message: GotifyMessage
    let appName: String
    let isSelected: Bool
    let isUnread: Bool
    /// 双栏模式下列表变窄，行距收紧
    let compact: Bool
    /// 计算"x 分钟前"的基准时刻，由面板按分钟推进
    let now: Date

    @State private var isHovered = false

    private var tier: PriorityTier {
        PriorityTier(priority: message.displayPriority)
    }

    /// 列表不展示正文摘要（正文通常很长，完整内容在详情里看）；
    /// 无标题消息改用正文首段折叠成一行作标题，避免整行只剩「（无标题）」
    private var listTitle: String {
        guard message.title?.isEmpty ?? true else { return message.displayTitle }
        let preview = message.previewText
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return preview.isEmpty ? message.displayTitle : preview
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2.5) {
            // 第一行：优先级色点 + 应用名 + 时间（右对齐，等宽数字）
            HStack(spacing: 4.5) {
                Circle()
                    .fill(tier.dotColor)
                    .frame(width: tier == .critical ? 6.5 : 5.5, height: tier == .critical ? 6.5 : 5.5)
                Text(appName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PanelTheme.inkSecondary)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(Self.timeLabel(message.date, now: now))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(PanelTheme.inkTertiary)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            .padding(.leading, 12)

            // 第二行：独立未读蓝点轨道 + 标题（光学居中对齐）
            HStack(alignment: .center, spacing: 6) {
                Circle()
                    .fill(isUnread ? Color.accentColor : Color.clear)
                    .frame(width: 6, height: 6)
                Text(listTitle)
                    .font(.system(size: 13, weight: isUnread ? .semibold : .medium))
                    .foregroundStyle(isUnread ? PanelTheme.inkPrimary : PanelTheme.inkReadTitle)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, compact ? 8 : 10)
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .background(
            rowBackground,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? PanelTheme.rowSelectedBorder : Color.clear, lineWidth: 0.75)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var rowBackground: Color {
        if isSelected { return PanelTheme.rowSelectedFill }
        if isHovered { return PanelTheme.rowHover }
        return .clear
    }

    /// 相对时间 + 绝对时间；24 小时以上只留绝对时间（窄栏 240pt 放不下两段，
    /// 且此时绝对日期本身已足够说明"多久以前"）
    static func timeLabel(_ date: Date, now: Date) -> String {
        guard let relative = relativeText(date, now: now) else { return timeText(date) }
        return "\(relative) · \(timeText(date))"
    }

    /// 相对时间，分钟粒度；未来时间（服务器时钟偏差）按"刚刚"处理，超 24 小时返回 nil
    static func relativeText(_ date: Date, now: Date) -> String? {
        let minutes = Int(now.timeIntervalSince(date) / 60)
        if minutes < 1 { return "刚刚" }
        if minutes < 60 { return "\(minutes) 分钟前" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) 小时前" }
        return nil
    }

    static func timeText(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.month().day().hour().minute())
    }
}
