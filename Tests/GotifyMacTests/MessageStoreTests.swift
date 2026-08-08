import Foundation
import Testing
@testable import GotifyMac

@Suite struct MessageStoreTests {
    func msg(_ id: Int) -> GotifyMessage {
        GotifyMessage(id: id, appid: 1, title: "t\(id)", message: "m\(id)",
                      priority: 0, date: Date(timeIntervalSince1970: Double(id)))
    }

    @Test func 乱序合并后按id降序() {
        var store = MessageStore()
        _ = store.merge([msg(3), msg(1), msg(5), msg(2)])
        #expect(store.messages.map(\.id) == [5, 3, 2, 1])
    }

    @Test func 合并去重且只返回新增() {
        var store = MessageStore()
        _ = store.merge([msg(1), msg(2)])
        let added = store.merge([msg(2), msg(3), msg(3)])
        #expect(added.map(\.id) == [3])
        #expect(store.messages.map(\.id) == [3, 2, 1])
    }

    @Test func 插入保持降序且重复返回false() {
        var store = MessageStore()
        _ = store.merge([msg(10), msg(5)])
        #expect(store.insert(msg(7)) == true)
        #expect(store.messages.map(\.id) == [10, 7, 5])
        #expect(store.insert(msg(7)) == false)
        #expect(store.messages.count == 3)
        #expect(store.insert(msg(20)) == true)
        #expect(store.messages.first?.id == 20)
    }

    @Test func 超出上限裁剪最旧() {
        var store = MessageStore()
        store.maxCount = 5
        _ = store.merge((1...7).map(msg))
        #expect(store.messages.map(\.id) == [7, 6, 5, 4, 3])
        // 被裁掉的旧 id 可以重新插入（不在 knownIDs 中），但会立即被再次裁剪
        #expect(store.insert(msg(1)) == true)
        #expect(store.messages.map(\.id) == [7, 6, 5, 4, 3])
    }

    @Test func maxKnownID取最新() {
        var store = MessageStore()
        #expect(store.maxKnownID == 0)
        _ = store.merge([msg(4), msg(9)])
        #expect(store.maxKnownID == 9)
    }
}
