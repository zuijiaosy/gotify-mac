# Current State

Updated: 2026-08-10

## Completed

- 项目文档、协作规则、ADR-001~008。
- SwiftPM 工程 + 打包脚本（ad-hoc 签名 .app）+ `start.sh` 一键启动。
- 本地 Gotify 服务端（docker，18080 端口），健康与消息收发验证通过。
- **MVP 功能全部落地**：
  - REST 消息/应用加载（GotifyClient）。
  - 菜单栏面板 UI：单栏简洁列表 ↔ 点击展开双栏详情（用户选定方案 1+5），优先级四档色点。
  - WebSocket 实时接收（ping 确认握手、指数退避重连、重连后补拉去重）。
  - 系统通知（前台横幅、仅新消息、非 .app 环境安全降级）。（2026-08-09 已移除 UI 入口，ADR-012）
- 测试：37 个用例全绿（单元 35 + 集成 2）；集成测试打真实服务端（`GOTIFY_E2E=1 scripts/test.sh`）。
- **设置窗口**（方案 2：Settings scene + TabView 顶部标签，ADR-009）：
  - 服务器标签：地址/Token 草稿编辑 + 「测试连接」（复用 currentUser，错误分类文案）+ 「保存并连接」显式提交（仅身份变化触发重连）。
  - 通知标签：启用/声音开关即时生效（AppConfig 新增 notificationsEnabled/soundEnabled）。（2026-08-09 标签已随 ADR-012 移除，配置字段保留）
  - AppConfig 支持 save（目录创建、原子写后重设 600、prettyPrinted）与缺字段容错解码；路径可注入，磁盘往返/权限/兼容均有测试。
  - 入口：面板 gearshape 菜单「设置…」；LSUIElement 下打开前手动 activate + makeKeyAndOrderFront 双保险。
- `scripts/test.sh`：解决纯 CLT 环境 Testing.framework 不在默认搜索路径的问题。
- `scripts/e2e-ui-check.sh`：半自动端到端验证（起服务端→发消息→AX 开面板→截图）。
- **开源准备（2026-08-09）**：MIT LICENSE（© zuijiaosy）、README 重写为标准开源格式（徽章/截图/安装/配置/贡献指南）、功能截图入库 `docs/screenshots/`（面板列表、设置-服务器、设置-通知）。

- Codex 多轮对抗审查 6 轮共 17 条发现，全部核实为真并修复（含连接恢复、通知恰好一次语义、并发竞态、测试隔离等）。

- **发布流程（2026-08-09，ADR-013）**：`scripts/make-dmg.sh` 把 `.app` 打成含 `/Applications` 快捷方式的 DMG；`build-app.sh` 新增 `APP_VERSION`/`APP_BUILD`/`APP_ARCHS` 环境变量；`.github/workflows/release.yml` 在推 `v*` 标签时跑测试 → 出 arm64+x86_64 通用二进制 → 打 DMG → `gh release create` 上传到 Releases。签名仍为 ad-hoc、不公证，用户首次打开需手动放行。**v0.2.0 已发布（2026-08-09）**：workflow 一次跑通，`lipo` 确认 x86_64+arm64 双架构，DMG 下载挂载验证通过。

- **全部已读（2026-08-09，ADR-011）**：面板右上角 `checkmark.circle` 按钮把已读水位线 `lastReadMessageID` 推到当前最大消息 id 并落盘 config.json；未读消息标题前显示 accent 色小蓝点，菜单栏铃铛在有未读时变为 `bell.badge`；换服务器身份时水位线归零。测试 67 个用例全绿（新增水位线读写往返与旧配置兼容 2 个）。
- **Markdown 正文渲染（2026-08-09，ADR-010）**：解析 `extras.client::display.contentType`，详情页渲染加粗/斜体/行内代码/链接/无序列表/ATX 标题，列表行与通知横幅显示剥标记后的纯文本；畸形 extras 降级为纯文本且不影响整条消息解码。测试 58 个用例全绿（新增 21 个，含畸形 extras 参数化与 markdown 端到端）。动因：codexzh / cczh / auto-gpt-plus 三个项目把管理员通知从邮件迁到 Gotify，正文改用 Markdown。

- **面板"鬼影"窗口修复（2026-08-10）**：用户实测出现窗口停在 641pt（双栏宽）而内容 360pt 居中、四周露出一圈空白鬼影的状态（截图几何比例 1.78 与 641/360 精确吻合）。程序化探针验证了 6 条状态切换路径（离屏/可见/竞态的展开与收窄、关闭重开）窗口 resize 均正常，未能复现精确触发点——嫌疑最大的是"展开详情后点击面板外部关闭"这条需要真实鼠标事件的路径（本机 agent shell 无辅助功能权限，无法模拟）。修复采用自愈兜底：`PanelView` 的 background 挂 `PanelWindowSizeEnforcer`（NSViewRepresentable），布局时发现窗口 frame 与内容尺寸不一致即缩回内容大小（保持顶边与水平中心）并 `invalidateShadow()`；正常路径下尺寸一致为空操作，探针复测确认对 6 条正常路径零影响。67 测试全绿。**待用户按原路径实测确认鬼影不再出现。**无回归单测：需要真实 WindowServer 交互，超出单元测试能力。

## In Progress

- 设置窗口手工验收剩余项（截图已确认：窗口可打开前置、TabView 为顶部工具栏标签样式、连接状态正常，见 `docs/screenshots/`）：
  1. 服务器标签：错 token 测试连接显示「Token 无效（401）」；逐键输入不触发重连。
  2. 保存后 `cat` config.json 新字段写入、`ls -l` 权限 `-rw-------`（单测已覆盖，实盘顺手确认即可）。

## Not Implemented

- 系统睡眠/唤醒专门处理（当前靠重连退避兜底）、网络切换主动探测。
- 登录时启动、消息删除、逐条已读（当前只有全部已读水位线，ADR-011）。
- PR/push 的持续集成（当前只有打标签触发的发布 workflow）、应用内自动更新、公证。

## Known Issues

- 端口 8080 被本机 nginx/OrbStack 占用，服务端固定用 18080。
- Token 明文存 config.json（权限 600，ADR-008 已知取舍）。
- macOS 26 实测系统通知授权对 ad-hoc / 自签名 / Apple Development 证书均难以稳定通过（拒绝记录绑定应用路径且无法在系统设置中重置），已决策放弃系统通知横幅并移除其 UI 入口（工具栏警示图标、设置「通知」标签），以菜单栏未读圆点为唯一提醒（ADR-012）。
- 面板宽度两档硬切无动画（NSPanel resize 与 SwiftUI 动画不同步，属有意取舍）。
- 通用二进制构建（`APP_ARCHS="arm64 x86_64"`）走 xcbuild，本机纯 CLT 环境不可用，只能在 CI 上验证（v0.2.0 发版已确认双架构正常）。

## Next

1. 用户授权终端权限后跑 `scripts/e2e-ui-check.sh` 完成 UI 截图验收；按上面清单手工验收设置窗口。
2. 在真实 Mac 上手工验证 v0.2.0 DMG 的 Gatekeeper 放行步骤（右键打开 / xattr）与安装体验。
3. 后续迭代：设置窗口「通用」标签（开机自启，SMAppService，需实测 ad-hoc 签名下行为）、睡眠/唤醒处理。
