# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概况

Gotify Mac 是一个面向 macOS 的 Gotify 原生客户端（Swift + SwiftUI 菜单栏应用）。

工程形式是 **SwiftPM + 打包脚本，没有 Xcode 工程**（开发机只有 Command Line Tools，见 ADR-007）。最低支持 macOS 14（ADR-006）。目前已有菜单栏骨架、本地配置读取和连接状态检查；REST 封装、WebSocket、消息列表、通知均未实现——实际进度以 `docs/CURRENT_STATE.md` 为准，不要根据架构文档假设模块已存在。

## 常用命令

```bash
./start.sh                   # 一键：退出旧实例 → 构建 release → 启动 .app
swift build                  # 仅构建（debug）
scripts/build-app.sh         # 构建 release 并组装 build/Gotify Mac.app（ad-hoc 签名）
open "build/Gotify Mac.app"  # 运行菜单栏应用

# 本地 Gotify 服务端（Docker，http://127.0.0.1:18080，管理界面账号 admin/admin）
docker compose -f deploy/gotify/docker-compose.yml up -d
docker compose -f deploy/gotify/docker-compose.yml down
```

尚无测试 target；添加后用 `swift test` 运行，并更新本节。

本机 8080 端口被 nginx/OrbStack 占用，所以服务端映射到 18080，不要改回 8080。

## 必读文档（开始工作前按顺序阅读）

1. `AGENTS.md` — 完整的 agent 工作规则与文档同步规则，**必须遵守**。
2. `docs/ARCHITECTURE.md` — 目标架构基线（注意：其中描述的模块均未实现）。
3. `docs/DECISIONS.md` — 已接受的 ADR。
4. `docs/CURRENT_STATE.md` — 当前进度、已知问题与下一步，是项目进度的唯一事实来源。

代码与文档不一致时以代码为准，并在结果中说明差异。

## 关键决策约束（详见 docs/DECISIONS.md）

- 客户端连接现有 Gotify Server：REST API 拉取应用/消息，WebSocket stream 接收实时消息；服务端是消息的权威来源，本地只做有限缓存。
- 服务器地址与 Client Token 存本地配置文件 `~/Library/Application Support/GotifyMac/config.json`（ADR-008，用户明确要求不用 Keychain）；Token 绝不写入源码、日志或 Git。
- 优先使用 Swift/SwiftUI 与 Apple 原生框架；新增第三方生产依赖前必须先征得用户确认。
- 第一版不做跨设备已读同步。

## 代码布局

- `Package.swift` — executable target `GotifyMac`，platforms 定为 `.macOS(.v14)`。
- `Sources/GotifyMac/` — 应用代码：`GotifyMacApp.swift`（`MenuBarExtra` 入口）、`AppConfig.swift`（config.json 读取）、`AppModel.swift`（连接状态检查）。
- `Support/Info.plist` — bundle 配置（`LSUIElement=true` 隐藏 Dock 图标）。
- `scripts/build-app.sh` — 组装 `.app` 的打包脚本。
- `deploy/gotify/` — 本地 Gotify 服务端 docker-compose；`data/` 子目录含数据库（内含 Token），已 gitignore，不得提交。

## 目标模块边界（尚未实现）

Configuration/Keychain → Networking（REST + WebSocket 生命周期）→ Message Store（合并/排序/去重，暴露可观察状态）→ Notification Service（系统通知，防重连重复通知）→ SwiftUI Menu Bar UI。UI 只通过状态与服务接口协作，不直接发请求或读 Token。

## 文档同步规则（摘要，完整规则见 AGENTS.md）

- 架构/模块边界变化 → 更新 `docs/ARCHITECTURE.md`，区分"已实现"与"计划"。
- 新增或替换关键决策 → 在 `docs/DECISIONS.md` 追加 ADR；旧决策标 `Superseded`，不删除历史。
- 完成有意义的任务 → 更新 `docs/CURRENT_STATE.md`（日期、完成项、进行中、已知问题、下一步）。
- 纯格式/注释改动不要求更新 CURRENT_STATE。

## 安全约定

- 不提交 Gotify Server 地址、Client Token、签名证书等凭据。
- 日志、错误信息、测试夹具不得包含真实 Token 或真实消息内容。
- 除非用户明确要求，不要 commit 或 push。

## 待决策事项（实现前需与用户确认）

- 模块拆分粒度（单 target 分目录 vs 多 SwiftPM target）。
- 本地缓存技术与容量策略。
- WebSocket 在睡眠/唤醒、网络切换后的恢复策略。
