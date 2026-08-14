import Foundation
import Testing
@testable import GotifyMac

@MainActor
@Suite struct MessageRowViewTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func text(minutesAgo: Double) -> String? {
        MessageRowView.relativeText(now.addingTimeInterval(-minutesAgo * 60), now: now)
    }

    @Test func 一分钟内显示刚刚() {
        #expect(text(minutesAgo: 0) == "刚刚")
        #expect(text(minutesAgo: 0.9) == "刚刚")
    }

    @Test func 小时内按分钟() {
        #expect(text(minutesAgo: 1) == "1 分钟前")
        #expect(text(minutesAgo: 59) == "59 分钟前")
    }

    @Test func 一天内按小时() {
        #expect(text(minutesAgo: 60) == "1 小时前")
        #expect(text(minutesAgo: 23 * 60 + 59) == "23 小时前")
    }

    @Test func 超过一天不给相对时间() {
        #expect(text(minutesAgo: 24 * 60) == nil)
        #expect(text(minutesAgo: 3 * 24 * 60 + 5) == nil)
    }

    @Test func 组合标签在超一天时只剩绝对时间() {
        let recent = now.addingTimeInterval(-5 * 60)
        #expect(MessageRowView.timeLabel(recent, now: now)
            == "5 分钟前 · \(MessageRowView.timeText(recent))")
        let old = now.addingTimeInterval(-3 * 24 * 3600)
        #expect(MessageRowView.timeLabel(old, now: now) == MessageRowView.timeText(old))
    }

    @Test func 服务器时钟超前时不出现负数() {
        #expect(text(minutesAgo: -10) == "刚刚")
    }
}
