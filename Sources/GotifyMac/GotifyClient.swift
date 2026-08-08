import Foundation

/// 可注入的最小抓取协议，测试用 fake 实现替代真实网络
protocol HTTPDataFetching: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataFetching {}

enum GotifyClientError: Error, Equatable {
    case unauthorized
    case http(Int)
    case invalidResponse
}

struct CurrentUser: Codable, Sendable {
    let name: String
}

/// Gotify REST API 封装
struct GotifyClient: Sendable {
    let baseURL: URL
    let token: String
    var fetcher: any HTTPDataFetching = URLSession.shared

    func currentUser() async throws -> CurrentUser {
        try await get(path: "current/user")
    }

    func applications() async throws -> [GotifyApplication] {
        try await get(path: "application")
    }

    func messages(limit: Int = 100, since: Int? = nil) async throws -> PagedMessages {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let since {
            query.append(URLQueryItem(name: "since", value: String(since)))
        }
        return try await get(path: "message", query: query)
    }

    /// 重连补拉：Gotify 的 since 语义是"返回 id 小于 since 的消息"（往旧翻页），
    /// 所以从最新页往回翻，直到覆盖已知的 afterID 或翻满 maxPages 页。
    func messagesNewer(than afterID: Int, maxPages: Int = 3) async throws -> [GotifyMessage] {
        var collected: [GotifyMessage] = []
        var since: Int? = nil
        for _ in 0..<maxPages {
            let page = try await messages(limit: 100, since: since)
            collected.append(contentsOf: page.messages)
            if page.messages.contains(where: { $0.id <= afterID }) { break }
            guard let nextSince = page.paging.since, page.messages.count >= page.paging.limit else { break }
            since = nextSince
        }
        return collected.filter { $0.id > afterID }
    }

    func makeRequest(path: String, query: [URLQueryItem] = []) -> URLRequest {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        if !query.isEmpty {
            components.queryItems = query
        }
        var request = URLRequest(url: components.url!)
        request.setValue(token, forHTTPHeaderField: "X-Gotify-Key")
        request.timeoutInterval = 10
        return request
    }

    /// 应用图标地址（image 是相对路径，如 "static/defaultapp.png"）
    func imageURL(for app: GotifyApplication) -> URL? {
        guard !app.image.isEmpty else { return nil }
        return URL(string: app.image, relativeTo: baseURL.appendingPathComponent(""))
            ?? baseURL.appendingPathComponent(app.image)
    }

    private func get<T: Decodable>(path: String, query: [URLQueryItem] = []) async throws -> T {
        let (data, response) = try await fetcher.data(for: makeRequest(path: path, query: query))
        guard let http = response as? HTTPURLResponse else {
            throw GotifyClientError.invalidResponse
        }
        switch http.statusCode {
        case 200:
            do {
                return try JSONDecoder.gotify.decode(T.self, from: data)
            } catch {
                throw GotifyClientError.invalidResponse
            }
        case 401, 403:
            throw GotifyClientError.unauthorized
        default:
            throw GotifyClientError.http(http.statusCode)
        }
    }
}
