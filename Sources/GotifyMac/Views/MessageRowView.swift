import SwiftUI

/// 列表行：优先级色点 + 应用名 + 时间（相对+绝对） + 标题 + 摘要
struct MessageRowView: View {
    let message: GotifyMessage
    let appName: String
    let isSelected: Bool
    let isUnread: Bool
    /// 双栏模式下列表变窄，隐藏摘要
    let compact: Bool
    /// 计算"x 分钟前"的基准时刻，由面板按分钟推进
    let now: Date

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(PriorityTier(priority: message.displayPriority).color)
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(appName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(Self.timeLabel(message.date, now: now))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
                HStack(spacing: 4) {
                    if isUnread {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                    }
                    Text(message.displayTitle)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                if !compact {
                    Text(message.previewText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            isSelected ? Color.accentColor.opacity(0.15) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
        .contentShape(Rectangle())
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
