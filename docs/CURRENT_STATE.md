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
- 测试：37 个用例全绿（单元 35 + 集成 2）；集成测试打真实服务端（`GOTIFY_E2E=1 scripts/test.sh`）。
- **设置窗口**（方案 2：Settings scene + TabView 顶部标签，ADR-009）：
  - 服务器标签：地址/Token 草稿编辑 + 「测试连接」（复用 currentUser，错误分类文案）+ 「保存并连接」显式提交（仅身份变化触发重连）。
  - 通知标签：启用/声音开关即时生效（AppConfig 新增 notificationsEnabled/soundEnabled）。
  - AppConfig 支持 save（目录创建、原子写后重设 600、prettyPrinted）与缺字段容错解码；路径可注入，磁盘往返/权限/兼容均有测试。
  - 入口：面板 gearshape 菜单「设置…」；LSUIElement 下打开前手动 activate + makeKeyAndOrderFront 双保险。
- `scripts/test.sh`：解决纯 CLT 环境 Testing.framework 不在默认搜索路径的问题。
- `scripts/e2e-ui-check.sh`：半自动端到端验证（起服务端→发消息→AX 开面板→截图）。
- **开源准备（2026-08-09）**：MIT LICENSE（© zuijiaosy）、README 重写为标准开源格式（徽章/截图/安装/配置/贡献指南）、功能截图入库 `docs/screenshots/`（面板列表、设置-服务器、设置-通知）。

- Codex 多轮对抗审查 6 轮共 17 条发现，全部核实为真并修复（含连接恢复、通知恰好一次语义、并发竞态、测试隔离等）。

## In Progress

- 设置窗口手工验收剩余项（截图已确认：窗口可打开前置、TabView 为顶部工具栏标签样式、连接状态正常，见 `docs/screenshots/`）：
  1. 服务器标签：错 token 测试连接显示「Token 无效（401）」；逐键输入不触发重连。
  2. 保存后 `cat` config.json 新字段写入、`ls -l` 权限 `-rw-------`（单测已覆盖，实盘顺手确认即可）。
  3. 通知标签：关总开关发消息无横幅；开通知关声音有横幅无声音。

## Not Implemented

- 系统睡眠/唤醒专门处理（当前靠重连退避兜底）、网络切换主动探测。
- 登录时启动、已读状态、消息删除。
- CI 与发布流程。

## Known Issues

- 端口 8080 被本机 nginx/OrbStack 占用，服务端固定用 18080。
- Token 明文存 config.json（权限 600，ADR-008 已知取舍）。
- ad-hoc 签名每次构建变化，通知授权在个别系统版本可能重复弹出；异常时换 CFBundleIdentifier 重试。
- 面板宽度两档硬切无动画（NSPanel resize 与 SwiftUI 动画不同步，属有意取舍）。

## Next

1. 用户授权终端权限后跑 `scripts/e2e-ui-check.sh` 完成 UI 截图验收；按上面清单手工验收设置窗口。
2. 后续迭代：设置窗口「通用」标签（开机自启，SMAppService，需实测 ad-hoc 签名下行为）、睡眠/唤醒处理。
