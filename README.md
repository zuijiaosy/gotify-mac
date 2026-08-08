# Gotify Mac

Gotify Mac 是一个面向 macOS 的 Gotify 原生客户端项目。

当前仓库已有一个最小可运行的菜单栏应用骨架（SwiftPM 工程，无 Xcode 工程），业务功能尚未实现。仓库中的实现与文档将作为项目现状的唯一事实来源；历史聊天只用于解释需求背景和设计原因。

## 项目目标

- 使用 Swift 与 SwiftUI 构建原生 macOS 客户端。
- 通过 Gotify REST API 获取应用与消息。
- 通过 Gotify WebSocket stream 接收实时消息。
- 使用 macOS 系统通知展示新消息。
- 服务器地址与 Client Token 存放在仓库之外的本地配置文件 `~/Library/Application Support/GotifyMac/config.json`，不写入源码或 Git。

这些目标尚不代表已经实现。实际进度以 [`docs/CURRENT_STATE.md`](docs/CURRENT_STATE.md) 为准。

## 项目文档

- [`AGENTS.md`](AGENTS.md)：Coding Agent 的工作与文档同步规则。
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)：当前有效架构和已确认的系统边界。
- [`docs/DECISIONS.md`](docs/DECISIONS.md)：已经接受的关键设计决策及原因。
- [`docs/CURRENT_STATE.md`](docs/CURRENT_STATE.md)：当前完成情况、问题与下一步。

## 构建与运行

要求 macOS 14+ 与 Swift 6 工具链（Command Line Tools 即可，无需 Xcode.app）。

```bash
./start.sh
```

等价于：退出正在运行的旧实例，然后 `scripts/build-app.sh` 构建并 `open "build/Gotify Mac.app"` 启动。

## 本地 Gotify 服务端

```bash
docker compose -f deploy/gotify/docker-compose.yml up -d
```

服务地址 `http://127.0.0.1:18080`（8080 被本机其他服务占用），Web 管理界面默认账号 `admin/admin`。数据保存在 `deploy/gotify/data/`（已 gitignore，内含 Token，不得提交）。

## 当前阶段

菜单栏应用已能读取本地配置并显示与本地 Gotify 服务端的连接状态，下一步是实现 REST API 消息加载和 WebSocket 实时接收。开始编码前，请先阅读上述项目文档。

## 安全约定

- 不提交 Gotify Server 地址、Client Token、签名证书或其他凭据。
- 本地配置文件和 Xcode 用户状态必须保持在 Git 之外。
- 日志、错误信息和测试夹具不得包含真实 Token 或个人消息内容。

