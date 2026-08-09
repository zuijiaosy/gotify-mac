import Foundation
import Observation

/// 应用协调者：连接状态、消息仓库、应用列表、面板选中态。
@MainActor
@Observable
final class AppModel {
    enum ConnectionState: Equatable {
        case checking
        case unconfigured(String)
        case connected(user: String)
        case reconnecting(String)
        case failed(String)
    }

    private(set) var state: ConnectionState = .checking
    private(set) var serverURL = AppConfig.default.serverURL
    /// 磁盘配置的内存镜像，设置界面读它；写只能走 saveConfig
    private(set) var config = AppConfig.default
    private(set) var store = MessageStore()
    private(set) var apps: [Int: GotifyApplication] = [:]
    /// nil = 单栏列表；非 nil = 双栏并选中该消息
    var selectedMessageID: Int?

    private var client: GotifyClient?
    private var streamTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    /// 连续瞬时连接失败次数，成功后清零，驱动自动重试的退避
    private var connectAttempt = 0
    private var userName = ""
    /// 每次 refresh 递增；跨 await 后与之比较，过期的调用丢弃结果不再写状态
    private var refreshGeneration = 0
    /// 上次连接的 serverURL|token；变化时旧服务器的消息/应用/选中态全部作废
    private var lastIdentity: String?
    /// 空仓库补拉合并进来的消息 id：按历史消息处理不通知，但其中随后出现
    /// 缓冲流事件的（说明是补拉期间刚到达的新消息）须补发通知恰好一次
    private var pendingStreamNotifyIDs: Set<Int> = []
    /// 通知基线：id 大于基线的补拉消息都是新消息，要通知。
    /// nil = 初始加载失败、基线未知（此时退化为 pendingStreamNotifyIDs 补偿）
    private var notifyBaseline: Int?
    let notifier = NotificationService()

    var statusText: String {
        switch state {
        case .checking: "检查中…"
        case .unconfigured(let hint): hint
        case .connected(let user): "已连接：\(user)"
        case .reconnecting(let hint): hint
        case .failed(let hint): hint
        }
    }

    var selectedMessage: GotifyMessage? {
        guard let id = selectedMessageID else { return nil }
        return store.messages.first { $0.id == id }
    }

    /// autoStart: false 供测试使用，避免测试进程读取真实配置、访问真实服务器
    init(autoStart: Bool = true) {
        if autoStart {
            Task {
                await notifier.setUp()
                await refresh()
            }
        }
    }

    /// 重读配置、验证连接、加载应用与消息、重启实时流
    func refresh() async {
        refreshGeneration += 1
        let generation = refreshGeneration
        streamTask?.cancel()
        streamTask = nil
        retryTask?.cancel()
        retryTask = nil
        state = .checking
        let config = AppConfig.load()
        self.config = config
        serverURL = config.serverURL

        let identity = "\(config.serverURL)|\(config.clientToken)"
        if identity != lastIdentity {
            store = MessageStore()
            apps = [:]
            selectedMessageID = nil
            pendingStreamNotifyIDs = []
            notifyBaseline = nil
            lastIdentity = identity
        }

        guard !config.clientToken.isEmpty else {
            client = nil
            state = .unconfigured("未配置：请在 config.json 中填入 clientToken")
            return
        }
        guard let base = config.url else {
            client = nil
            state = .unconfigured("服务器地址无效")
            return
        }
        let client = GotifyClient(baseURL: base, token: config.clientToken)
        self.client = client
        do {
            let user = try await client.currentUser()
            guard generation == refreshGeneration else { return }
            connectAttempt = 0
            userName = user.name
            state = .connected(user: user.name)
            // 同一身份重复 refresh 时保留旧基线：流取消间隙到达的消息也要通知
            let priorBaseline = notifyBaseline
            let fresh = await loadInitial(client: client, generation: generation)
            guard generation == refreshGeneration else { return }
            if let fresh {
                if let priorBaseline {
                    for message in fresh.filter({ $0.id > priorBaseline })
                        .sorted(by: { $0.id < $1.id }) {
                        notifyIfEnabled(message)
                    }
                }
                // 加载成功即知道服务器此刻的消息上界（空历史时为 0），
                // 之后补拉到的 id 大于它的都是新消息
                notifyBaseline = store.maxKnownID
            } else {
                notifyBaseline = nil
                // 实时流连上后会补拉最新消息，此提示随 .connected 事件自动恢复
                state = .reconnecting("消息加载失败，等待实时流补拉")
            }
            startStream(client: client, generation: generation)
        } catch GotifyClientError.unauthorized {
            guard generation == refreshGeneration else { return }
            state = .failed("Token 无效（401）")
        } catch GotifyClientError.http(let code) {
            guard generation == refreshGeneration else { return }
            if code >= 500 {
                state = .failed("连接失败：HTTP \(code)，稍后自动重试")
                scheduleRetry(generation: generation)
            } else {
                state = .failed("连接失败：HTTP \(code)")
            }
        } catch {
            guard generation == refreshGeneration else { return }
            state = .failed("无法连接服务器，稍后自动重试")
            scheduleRetry(generation: generation)
        }
    }

    /// 设置界面的唯一写入口：落盘立即生效；仅服务器地址或 Token 变化才重连
    /// （开关类改动不能走 refresh，它会整体撕掉现有 WebSocket 流）。
    func saveConfig(_ new: AppConfig) {
        let reconnect = new.serverURL != config.serverURL
            || new.clientToken != config.clientToken
        config = new
        try? AppConfig.save(new)
        if reconnect { Task { await refresh() } }
    }

    enum ConnectionTest: Equatable {
        case success(user: String)
        case failure(String)
    }

    /// 用设置表单的草稿值测试连接，不触碰 self.client / self.state
    func testConnection(
        serverURL: String,
        token: String,
        fetcher: any HTTPDataFetching = URLSession.shared
    ) async -> ConnectionTest {
        guard !token.isEmpty else { return .failure("Token 为空") }
        guard let base = URL(string: serverURL), base.scheme != nil else {
            return .failure("服务器地址无效")
        }
        let client = GotifyClient(baseURL: base, token: token, fetcher: fetcher)
        do {
            return .success(user: try await client.currentUser().name)
        } catch GotifyClientError.unauthorized {
            return .failure("Token 无效（401）")
        } catch GotifyClientError.http(let code) {
            return .failure("连接失败：HTTP \(code)")
        } catch {
            return .failure("无法连接服务器")
        }
    }

    /// 瞬时失败（网络错误/5xx）后按指数退避自动重试；
    /// 鉴权和配置类错误不重试，等用户修正后手动刷新
    private func scheduleRetry(generation: Int) {
        let attempt = connectAttempt
        connectAttempt += 1
        retryTask?.cancel()
        retryTask = Task {
            try? await Task.sleep(for: GotifyStream.backoffDelay(attempt: attempt))
            guard !Task.isCancelled, generation == refreshGeneration else { return }
            // 先置空再进 refresh：refresh 开头会取消 retryTask，
            // 不置空的话取消的就是正在执行自己的这个任务，导致重试必然失败
            retryTask = nil
            await refresh()
        }
    }

    /// 返回本次合并进仓库的新消息；nil 表示消息列表加载失败。
    /// 过期调用的结果直接丢弃（返回空数组，调用方随即因 generation 校验退出）
    private func loadInitial(client: GotifyClient, generation: Int) async -> [GotifyMessage]? {
        async let appsResult = client.applications()
        async let messagesResult = client.messages(limit: 100)
        let appList = try? await appsResult
        let page = try? await messagesResult
        guard generation == refreshGeneration else { return [] }
        if let appList {
            apps = Dictionary(appList.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        }
        guard let page else { return nil }
        return store.merge(page.messages)
    }

    /// 消费实时流：新消息插入仓库；连接/重连成功后 REST 补拉遗漏的消息
    private func startStream(client: GotifyClient, generation: Int) {
        streamTask?.cancel()
        streamTask = Task {
            for await event in GotifyStream.events(baseURL: client.baseURL, token: client.token) {
                guard generation == refreshGeneration else { return }
                switch event {
                case .connected:
                    state = .connected(user: userName)
                    let maxID = store.maxKnownID
                    // 空仓库（初始加载失败或确实无消息）时直接拉最新页，
                    // 否则从最新页回翻补拉断线期间遗漏的消息；瞬时失败重试
                    var backfill: [GotifyMessage]?
                    for attempt in 0..<3 {
                        backfill = if maxID > 0 {
                            try? await client.messagesNewer(than: maxID)
                        } else {
                            (try? await client.messages(limit: 100))?.messages
                        }
                        guard generation == refreshGeneration else { return }
                        if backfill != nil { break }
                        try? await Task.sleep(for: .seconds(2 * (attempt + 1)))
                        guard generation == refreshGeneration else { return }
                    }
                    // 初始加载时应用列表若失败，借补拉时机恢复
                    if apps.isEmpty {
                        await reloadApps(client: client, generation: generation)
                        guard generation == refreshGeneration else { return }
                    }
                    guard let backfill else {
                        // 实时流仍在，仅补拉失败：提示手动刷新，不中断连接
                        state = .reconnecting("消息补拉失败，请点「重新检查连接」")
                        continue
                    }
                    let fresh = store.merge(backfill)
                    // 补拉中出现未知 appid（如断线期间新建的应用）先重拉元数据，
                    // 列表行和通知才有正确的应用名
                    if fresh.contains(where: { apps[$0.appid] == nil }) {
                        await reloadApps(client: client, generation: generation)
                        guard generation == refreshGeneration else { return }
                    }
                    if let baseline = notifyBaseline {
                        // 基线已知（初始加载成功过，空历史时为 0）：
                        // id 大于基线的都是新消息，补发通知；与缓冲流事件互斥恰好一次
                        for message in fresh.filter({ $0.id > baseline }).sorted(by: { $0.id < $1.id }) {
                            notifyIfEnabled(message)
                        }
                    } else {
                        // 基线未知（初始加载失败）：补拉内容新旧莫辨，不直接通知；
                        // 其中随后出现缓冲流事件的由 .message 分支补发
                        pendingStreamNotifyIDs = Set(fresh.map(\.id))
                    }
                    notifyBaseline = store.maxKnownID
                case .message(let message):
                    let isNew = store.insert(message)
                    let compensate = !isNew && pendingStreamNotifyIDs.remove(message.id) != nil
                    if isNew || compensate {
                        // 未知 appid（如新建的应用）先重拉应用列表，通知才有正确名称
                        if apps[message.appid] == nil {
                            await reloadApps(client: client, generation: generation)
                            guard generation == refreshGeneration else { return }
                        }
                        notifyIfEnabled(message)
                    }
                case .disconnected(let reason):
                    state = .reconnecting(reason)
                }
            }
        }
    }

    private func reloadApps(client: GotifyClient, generation: Int) async {
        guard let list = try? await client.applications(),
              generation == refreshGeneration else { return }
        apps = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
    }

    /// 所有新消息通知的统一出口：用户级开关与声音偏好在此生效
    private func notifyIfEnabled(_ message: GotifyMessage) {
        guard config.notificationsEnabled else { return }
        notifier.post(
            message,
            appName: appName(for: message.appid),
            sound: config.soundEnabled
        )
    }

    func appName(for appid: Int) -> String {
        apps[appid]?.name ?? "应用 \(appid)"
    }

    func appImageURL(for appid: Int) -> URL? {
        guard let app = apps[appid], let client else { return nil }
        return client.imageURL(for: app)
    }
}
