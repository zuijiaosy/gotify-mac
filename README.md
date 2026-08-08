# Gotify Mac

Gotify Mac 是一个面向 macOS 的 Gotify 原生客户端项目。

MVP 已实现（SwiftPM 工程，无 Xcode 工程）：菜单栏面板展示消息列表与详情、REST 加载、WebSocket 实时接收与断线重连补拉、系统通知。仓库中的实现与文档是项目现状的唯一事实来源；历史聊天只用于解释需求背景和设计原因。

## 功能

- Swift + SwiftUI 原生菜单栏应用（`MenuBarExtra` window 面板，单栏列表 ↔ 双栏详情）。
- 通过 Gotify REST API 加载应用与消息，优先级四档色点（≥8 红、4-7 橙、1-3 蓝、0 灰）。
- 通过 Gotify WebSocket stream 实时接收消息，断线指数退避重连并补拉遗漏消息。
- 新消息弹 macOS 系统通知（应用在前台也弹横幅）。
- 服务器地址与 Client Token 存放在仓库之外的本地配置文件 `~/Library/Application Support/GotifyMac/config.json`，不写入源码或 Git。

实际进度以 [`docs/CURRENT_STATE.md`](docs/CURRENT_STATE.md) 为准。

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

## 测试

```bash
scripts/test.sh                # 单元测试（CLT 环境必须用此脚本，不要直接 swift test）
GOTIFY_E2E=1 scripts/test.sh   # 含打真实本地服务端的集成测试
scripts/e2e-ui-check.sh        # 半自动端到端 UI 验证（需终端有辅助功能+屏幕录制权限）
```

## 当前阶段

MVP 完成。后续迭代方向：应用内设置界面、登录自启动、睡眠/唤醒处理。开始编码前，请先阅读上述项目文档。

## 安全约定

- 不提交 Gotify Server 地址、Client Token、签名证书或其他凭据。
- 本地配置文件和 Xcode 用户状态必须保持在 Git 之外。
- 日志、错误信息和测试夹具不得包含真实 Token 或个人消息内容。

