# Architecture

Updated: 2026-08-09

## 当前实现

MVP 已实现（详见 ADR-006/007/008）：

- **Configuration**：`AppConfig.swift` 读写 `~/Library/Application Support/GotifyMac/config.json`（ADR-008/009）：服务器地址、Client Token、通知偏好；缺字段容错解码、原子写后重设权限 600；load/save 路径可注入以便测试。写入唯一入口是 `AppModel.saveConfig`，View 不直接落盘。
- **Networking**：`GotifyClient.swift`（REST：current/user、application、message 分页与补拉，`HTTPDataFetching` 协议注入可测）；`GotifyStream.swift`（WebSocket /stream，AsyncStream 封装，ping 确认握手，指数退避重连 1s→60s ±20% 抖动，取消即断开）。
- **Message Store**：`MessageStore.swift`，纯逻辑 struct，按 id 去重/降序/保留最近 200 条（不落盘，符合 ADR-002），`merge` 返回真正新增项供通知判断。
- **Markdown 渲染**：`MarkdownRendering.swift`（ADR-010）。`GotifyMessage.extras` 解析 Gotify 约定键 `client::display.contentType`，声明 `text/markdown` 时详情页用 `MarkdownRenderer.attributedBody` 渲染样式，列表行与通知横幅用 `plainPreview` 剥标记后的纯文本（这两处无法渲染富文本）。未声明 contentType 的消息行为与改造前完全一致。extras 解码两级 `init(from:)` 均不抛错，畸形 extras 降级为 nil——`GotifyStream.decode` 用 `try?` 解码，抛错会导致实时消息被静默丢弃。
- **Notification Service**：`NotificationService.swift`，UNUserNotificationCenter 封装；非 .app 环境（swift run/测试进程）自动降级不触碰 UN API；`willPresent` 保证前台横幅；仅对 `insert` 成功的新消息通知。注意：本机 ad-hoc 签名下授权必被系统拒绝，服务静默降级，UI 入口已移除（ADR-012），提醒依赖未读圆点。
- **协调者**：`AppModel.swift`（@MainActor @Observable），连接状态机（checking/unconfigured/connected/reconnecting/failed）、初始 REST 加载、流生命周期、重连后 `messagesNewer` 补拉、面板选中态、已读水位线（ADR-011：`markAllRead` 推进 `config.lastReadMessageID`，身份变化时归零）。
- **UI**：`Views/PanelView.swift`（MenuBarExtra `.window` 样式，单栏 360 ↔ 双栏 240+400 两档定宽硬切）、`MessageRowView.swift`（优先级色点 ≥8 红/4-7 橙/1-3 蓝/0 灰）、`MessageDetailView.swift`（详情/复制/返回）、`Views/Settings/`（Settings scene + TabView 顶部标签式设置窗口：服务器标签草稿+显式提交+测试连接；LSUIElement 下打开设置前手动 activate 前置窗口）。
- **测试**：`Tests/GotifyMacTests/` 单元测试 + `GOTIFY_E2E=1` 门控集成测试（打真实 docker 服务端）；`scripts/test.sh` 包装 CLT 环境所需的 Testing.framework 路径；`scripts/e2e-ui-check.sh` 半自动 UI 截图验证。
- 打包 `scripts/build-app.sh` / 一键启动 `start.sh`；本地服务端 `deploy/gotify/docker-compose.yml`（2.7.3，端口 18080）。

尚未实现：系统睡眠/唤醒专门处理（当前依赖重连退避兜底）、登录自启动。

本文件以下内容是第一版的**目标架构基线**，用于约束后续实现；代码落地后，必须根据真实实现更新，并将已经实现与尚未实现的部分分开描述。

## 目标系统边界

```text
Gotify Server
    │
    ├── REST API ──────── 获取应用和消息
    │
    └── WebSocket stream ─ 接收实时消息
               │
               ▼
          Gotify Mac
          ├── Configuration
          ├── Networking
          ├── Message Store
          ├── Notification Service
          └── SwiftUI Menu Bar UI
```

Gotify Server 是远端消息内容的权威来源。macOS 客户端负责连接、展示、通知和有限的本地状态，不承担服务端职责。

## 目标模块职责

### Configuration

- 管理服务器地址和偏好。
- 服务器地址与 Client Token 保存在本地配置文件 `~/Library/Application Support/GotifyMac/config.json`（ADR-008，仓库之外）。
- 向网络层提供经过校验的连接配置。

### Networking

- 封装 Gotify REST API。
- 管理 WebSocket stream 的连接、断开与重连。
- 将传输模型转换为应用内模型，并向上层暴露明确错误。

### Message Store

- 合并历史消息与实时消息。
- 负责排序、去重和内存/本地缓存边界。
- 对 UI 暴露可观察状态；不直接承担网络连接生命周期。

### Notification Service

- 请求并检查 macOS 通知权限。
- 根据消息和应用状态决定是否展示系统通知。
- 避免因重连或重复消息产生重复通知。

### SwiftUI Menu Bar UI

- 提供菜单栏入口、消息列表、连接状态和设置界面。
- 只通过明确的状态与服务接口协作，不直接拼接网络请求或读取 Token。

## 目标数据流

1. 用户配置服务器地址和 Client Token。
2. 客户端通过 REST API 加载初始应用与消息。
3. 客户端建立 WebSocket stream 接收后续消息。
4. Message Store 合并并去重消息，然后更新 SwiftUI。
5. Notification Service 对符合条件的新消息发出系统通知。

## 尚待决策

- 具体模块拆分粒度（单 target 内分目录，还是拆分多个 SwiftPM target）。
- 本地缓存技术、容量与淘汰策略。
- WebSocket 在网络切换、系统睡眠和唤醒后的恢复策略。
- 菜单栏应用是否同时提供常规窗口和 Dock 行为。

