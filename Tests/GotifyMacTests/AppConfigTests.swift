import Foundation
import Testing
@testable import GotifyMac

@Suite struct AppConfigTests {
    /// 每条测试用独立临时目录，互不干扰也不触碰真实配置
    private func makeTempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("GotifyMacTests-\(UUID().uuidString)")
            .appendingPathComponent("config.json")
    }

    private func cleanUp(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    private func permissions(of url: URL) throws -> Int {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs[.posixPermissions] as? NSNumber)?.intValue ?? -1
    }

    @Test func 保存后重新加载得到相同配置() throws {
        let url = makeTempURL()
        defer { cleanUp(url) }
        let config = AppConfig(
            serverURL: "http://example.test:8080",
            clientToken: "tok-abc",
            notificationsEnabled: false,
            soundEnabled: false
        )
        try AppConfig.save(config, to: url)
        let loaded = AppConfig.load(from: url)
        #expect(loaded.serverURL == config.serverURL)
        #expect(loaded.clientToken == config.clientToken)
        #expect(loaded.notificationsEnabled == false)
        #expect(loaded.soundEnabled == false)
    }

    @Test func 保存自动创建缺失的中间目录() throws {
        let url = makeTempURL()
        defer { cleanUp(url) }
        #expect(!FileManager.default.fileExists(atPath: url.path))
        try AppConfig.save(.default, to: url)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func 保存后文件权限为600() throws {
        let url = makeTempURL()
        defer { cleanUp(url) }
        try AppConfig.save(.default, to: url)
        #expect(try permissions(of: url) == 0o600)
    }

    @Test func 覆盖已有文件后权限仍为600() throws {
        // .atomic 写入是临时文件 rename，会丢原权限位，锁定 save 内重设的行为
        let url = makeTempURL()
        defer { cleanUp(url) }
        try AppConfig.save(.default, to: url)
        var updated = AppConfig.default
        updated.clientToken = "tok-new"
        try AppConfig.save(updated, to: url)
        #expect(try permissions(of: url) == 0o600)
        #expect(AppConfig.load(from: url).clientToken == "tok-new")
    }

    @Test func 老版本配置缺新字段时解码回默认值() throws {
        // 手写只含旧字段的 JSON：serverURL/token 不得丢，新字段回默认 true
        let url = makeTempURL()
        defer { cleanUp(url) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let legacy = #"{"serverURL":"http://legacy.test:9999","clientToken":"tok-legacy"}"#
        try Data(legacy.utf8).write(to: url)
        let loaded = AppConfig.load(from: url)
        #expect(loaded.serverURL == "http://legacy.test:9999")
        #expect(loaded.clientToken == "tok-legacy")
        #expect(loaded.notificationsEnabled == true)
        #expect(loaded.soundEnabled == true)
    }

    @Test func 配置文件损坏时load回落默认() throws {
        let url = makeTempURL()
        defer { cleanUp(url) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        let loaded = AppConfig.load(from: url)
        #expect(loaded.serverURL == AppConfig.default.serverURL)
        #expect(loaded.clientToken.isEmpty)
    }

    @Test func 文件不存在时load回落默认() {
        let loaded = AppConfig.load(from: makeTempURL())
        #expect(loaded.serverURL == AppConfig.default.serverURL)
    }
}

@Suite struct TestConnectionTests {
    @MainActor
    private func makeModel() -> AppModel {
        AppModel(autoStart: false)
    }

    @MainActor @Test func 测试连接成功返回用户名() async {
        let model = makeModel()
        let fetcher = FakeFetcher(json: #"{"name":"admin"}"#)
        let result = await model.testConnection(
            serverURL: "http://127.0.0.1:18080", token: "tok", fetcher: fetcher)
        #expect(result == .success(user: "admin"))
    }

    @MainActor @Test func 测试连接401返回Token无效文案() async {
        let model = makeModel()
        let fetcher = FakeFetcher(json: "{}", status: 401)
        let result = await model.testConnection(
            serverURL: "http://127.0.0.1:18080", token: "bad", fetcher: fetcher)
        #expect(result == .failure("Token 无效（401）"))
    }

    @MainActor @Test func 测试连接5xx返回状态码文案() async {
        let model = makeModel()
        let fetcher = FakeFetcher(json: "{}", status: 502)
        let result = await model.testConnection(
            serverURL: "http://127.0.0.1:18080", token: "tok", fetcher: fetcher)
        #expect(result == .failure("连接失败：HTTP 502"))
    }

    @MainActor @Test func 地址无scheme时不发请求直接判定无效() async {
        let model = makeModel()
        let fetcher = FakeFetcher(responses: [])
        let result = await model.testConnection(
            serverURL: "not a url", token: "tok", fetcher: fetcher)
        #expect(result == .failure("服务器地址无效"))
        #expect(fetcher.requests.isEmpty)
    }

    @MainActor @Test func Token为空时不发请求() async {
        let model = makeModel()
        let fetcher = FakeFetcher(responses: [])
        let result = await model.testConnection(
            serverURL: "http://127.0.0.1:18080", token: "", fetcher: fetcher)
        #expect(result == .failure("Token 为空"))
        #expect(fetcher.requests.isEmpty)
    }
}
