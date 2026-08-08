import Testing
@testable import GotifyMac

@Suite struct SmokeTests {
    @Test func 默认配置可加载() {
        let config = AppConfig.default
        #expect(config.serverURL == "http://127.0.0.1:18080")
        #expect(config.url != nil)
    }

    @MainActor @Test func AppModel可在主线程实例化() {
        // autoStart: false —— 测试进程不得读取真实配置或访问真实服务器
        let model = AppModel(autoStart: false)
        #expect(model.serverURL == AppConfig.default.serverURL)
    }
}
