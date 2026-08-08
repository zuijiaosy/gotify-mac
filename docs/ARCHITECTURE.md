# Architecture

Updated: 2026-08-08

## 当前实现

已实现的部分（详见 ADR-006/ADR-007）：

- SwiftPM 工程骨架：`Package.swift`（executable target `GotifyMac`，最低 macOS 14）。
- 菜单栏应用入口：`Sources/GotifyMac/GotifyMacApp.swift`，使用 SwiftUI `MenuBarExtra`，显示服务器地址、连接状态、重新检查和退出。
- 配置读取 `AppConfig.swift`：从 `~/Library/Application Support/GotifyMac/config.json` 读取服务器地址与 Client Token（ADR-008），默认服务器 `http://127.0.0.1:18080`。
- 连接检查 `AppModel.swift`：用 Client Token 调用 `GET /current/user` 验证服务器可达与 Token 有效，结果显示在菜单中。
- 打包脚本 `scripts/build-app.sh`：`swift build` 后组装 `build/Gotify Mac.app`（复制 `Support/Info.plist`，ad-hoc 签名，`LSUIElement` 隐藏 Dock 图标）。
- 本地开发服务端：`deploy/gotify/docker-compose.yml`（Gotify 2.7.3，宿主端口 18080，数据卷 `deploy/gotify/data/` 已被 gitignore）。

Networking（REST 封装与 WebSocket）、Message Store、Notification Service、配置编辑界面均未实现；当前连接检查是临时的最小实现，后续应并入 Networking 模块。

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

