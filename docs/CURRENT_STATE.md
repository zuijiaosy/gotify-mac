# Current State

Updated: 2026-08-09

## Completed

- 项目文档、协作规则、ADR-001~008。
- SwiftPM 工程 + 打包脚本（ad-hoc 签名 .app）+ `start.sh` 一键启动。
- 本地 Gotify 服务端（docker，18080 端口），健康与消息收发验证通过。
- **MVP 功能全部落地**：
  - REST 消息/应用加载（GotifyClient）。
  - 菜单栏面板 UI：单栏简洁列表 ↔ 点击展开双栏详情（用户选定方案 1+5），优先级四档色点。
  - WebSocket 实时接收（ping 确认握手、指数退避重连、重连后补拉去重）。
  - 系统通知（前台横幅、仅新消息、非 .app 环境安全降级）。
- 测试：25 个用例全绿（单元 23 + 集成 2）；集成测试打真实服务端（`GOTIFY_E2E=1 scripts/test.sh`）。
- `scripts/test.sh`：解决纯 CLT 环境 Testing.framework 不在默认搜索路径的问题。
- `scripts/e2e-ui-check.sh`：半自动端到端验证（起服务端→发消息→AX 开面板→截图）。

- Codex 多轮对抗审查 6 轮共 17 条发现，全部核实为真并修复（含连接恢复、通知恰好一次语义、并发竞态、测试隔离等）。

## In Progress

- UI 截图人工验收：AppleScript 点击与 screencapture 需要用户为终端授权"辅助功能"与"屏幕录制"后重跑 e2e 脚本。

## Not Implemented

- 应用内配置编辑界面（当前手工编辑 config.json）。
- 系统睡眠/唤醒专门处理（当前靠重连退避兜底）、网络切换主动探测。
- 登录时启动、已读状态、消息删除。
- CI 与发布流程。

## Known Issues

- 端口 8080 被本机 nginx/OrbStack 占用，服务端固定用 18080。
- Token 明文存 config.json（权限 600，ADR-008 已知取舍）。
- ad-hoc 签名每次构建变化，通知授权在个别系统版本可能重复弹出；异常时换 CFBundleIdentifier 重试。
- 面板宽度两档硬切无动画（NSPanel resize 与 SwiftUI 动画不同步，属有意取舍）。

## Next

1. 用户授权终端权限后跑 `scripts/e2e-ui-check.sh` 完成 UI 截图验收。
2. 后续迭代：应用内设置界面、登录自启动、睡眠/唤醒处理。
