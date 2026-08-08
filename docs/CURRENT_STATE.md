# Current State

Updated: 2026-08-08

## Completed

- 初始化本地 Git 仓库，默认分支为 `main`。
- 建立项目说明与 Coding Agent 协作规则。
- 建立架构、决策和当前状态三类项目记忆文档。
- 确认最低支持 macOS 14（ADR-006）；工程形式 SwiftPM + 打包脚本（ADR-007）。
- 创建最小 SwiftPM 菜单栏应用骨架，`scripts/build-app.sh` 打包、`start.sh` 一键启动。
- 本地 Gotify 服务端：`deploy/gotify/docker-compose.yml`（2.7.3，端口 18080），已启动并通过 health/version/消息收发验证。
- 决定配置与 Token 存本地配置文件而非 Keychain（ADR-008，取代 ADR-004）。
- 实现配置读取（`AppConfig`）与连接状态检查（`AppModel` 调 `GET /current/user`），菜单显示服务器地址和连接结果。
- 已在服务端创建 Client（"Gotify Mac"）和测试 Application，Token 写入本地 config.json 并验证有效。

## In Progress

- （无）

## Not Implemented

- Gotify Server 配置编辑界面（当前只能手工编辑 config.json）。
- REST API 客户端封装与应用/消息加载。
- WebSocket stream 与重连策略。
- 消息状态、排序、去重和本地缓存。
- 消息列表 UI（当前菜单只有连接状态）。
- macOS 通知权限与通知展示。
- 系统睡眠/唤醒和网络切换恢复。
- 登录时启动。
- 自动化测试（尚无测试 target）、CI 和发布流程。

## Known Issues

- 端口 8080 被本机 nginx/OrbStack 占用，因此服务端使用 18080。
- Token 明文存于 config.json（权限 600），安全性弱于 Keychain（ADR-008 已知取舍）。
- App 仅 ad-hoc 签名，只适合本机自用。
- 连接检查是临时最小实现，后续应并入 Networking 模块。

## Next

1. 实现 REST API 客户端（获取应用与消息列表），并建立第一个测试 target。
2. 在菜单中展示消息列表。
3. 实现 WebSocket stream 接收实时消息与系统通知。
4. 在每个里程碑完成后同步更新本文件和相关架构/决策文档。
