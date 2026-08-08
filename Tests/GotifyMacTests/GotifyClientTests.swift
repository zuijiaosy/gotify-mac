import Foundation
import Testing
@testable import GotifyMac

/// fake fetcher：记录请求并按脚本返回响应
final class FakeFetcher: HTTPDataFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [URLRequest] = []
    private var responses: [(Data, Int)]

    var requests: [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return _requests
    }

    init(responses: [(Data, Int)]) {
        self.responses = responses
    }

    convenience init(json: String, status: Int = 200) {
        self.init(responses: [(Data(json.utf8), status)])
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let (data, status): (Data, Int) = lock.withLock {
            _requests.append(request)
            return responses.isEmpty ? (Data(), 500) : responses.removeFirst()
        }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil
        )!
        return (data, response)
    }
}

@Suite struct GotifyClientTests {
    let base = URL(string: "http://127.0.0.1:18080")!

    func makeClient(_ fetcher: FakeFetcher) -> GotifyClient {
        GotifyClient(baseURL: base, token: "test-token", fetcher: fetcher)
    }

    @Test func 请求构造带token与query() {
        let client = makeClient(FakeFetcher(responses: []))
        let request = client.makeRequest(
            path: "message",
            query: [URLQueryItem(name: "limit", value: "100"), URLQueryItem(name: "since", value: "42")]
        )
        #expect(request.url?.absoluteString == "http://127.0.0.1:18080/message?limit=100&since=42")
        #expect(request.value(forHTTPHeaderField: "X-Gotify-Key") == "test-token")
    }

    @Test func 状态401映射为unauthorized() async {
        let client = makeClient(FakeFetcher(json: "{}", status: 401))
        await #expect(throws: GotifyClientError.unauthorized) {
            _ = try await client.currentUser()
        }
    }

    @Test func 状态500映射为http错误() async {
        let client = makeClient(FakeFetcher(json: "{}", status: 500))
        await #expect(throws: GotifyClientError.http(500)) {
            _ = try await client.currentUser()
        }
    }

    @Test func 解码失败映射为invalidResponse() async {
        let client = makeClient(FakeFetcher(json: "not json", status: 200))
        await #expect(throws: GotifyClientError.invalidResponse) {
            _ = try await client.currentUser()
        }
    }

    @Test func 补拉在覆盖已知id后停止() async throws {
        // 第一页含 id 6..4（覆盖 afterID=5），不应请求第二页
        let page1 = """
        {"paging":{"size":3,"limit":100,"since":4},"messages":[
            {"id":6,"appid":1,"message":"a","date":"2026-08-08T10:00:06Z"},
            {"id":5,"appid":1,"message":"b","date":"2026-08-08T10:00:05Z"},
            {"id":4,"appid":1,"message":"c","date":"2026-08-08T10:00:04Z"}]}
        """
        let fetcher = FakeFetcher(json: page1)
        let client = makeClient(fetcher)
        let newer = try await client.messagesNewer(than: 5)
        #expect(fetcher.requests.count == 1)
        #expect(newer.map(\.id) == [6])
    }

    @Test func 补拉翻页直到页尽() async throws {
        // 两页，第二页不满 limit → 停止；afterID=0 全部返回
        let page1 = """
        {"paging":{"size":2,"limit":2,"since":8},"messages":[
            {"id":10,"appid":1,"message":"a","date":"2026-08-08T10:00:10Z"},
            {"id":9,"appid":1,"message":"b","date":"2026-08-08T10:00:09Z"}]}
        """
        let page2 = """
        {"paging":{"size":1,"limit":2,"since":null},"messages":[
            {"id":8,"appid":1,"message":"c","date":"2026-08-08T10:00:08Z"}]}
        """
        let fetcher = FakeFetcher(responses: [(Data(page1.utf8), 200), (Data(page2.utf8), 200)])
        let client = makeClient(fetcher)
        let newer = try await client.messagesNewer(than: 0)
        #expect(fetcher.requests.count == 2)
        #expect(newer.map(\.id) == [10, 9, 8])
        // 第二页请求应带 since=8
        #expect(fetcher.requests[1].url?.query()?.contains("since=8") == true)
    }
}
