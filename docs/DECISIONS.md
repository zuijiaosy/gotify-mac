# Decisions

Updated: 2026-08-08

本文件记录已经接受的长期决策。每项决策保留状态和原因；如果以后改变方向，新增替代决策并将旧决策标为 `Superseded`，不要删除历史。

## ADR-001：使用 Gotify 作为消息服务

- Status: Accepted
- Date: 2026-08-08

### Decision

macOS 客户端连接现有 Gotify Server，通过其 REST API 获取消息，并通过 WebSocket stream 接收实时消息。

### Rationale

- 项目目标就是补充 Gotify 的 macOS 原生客户端体验。
- Gotify Server 已负责消息接收与持久化，Mac 端无需自建消息后端。
- Android 端可继续使用 Gotify 生态中的现有客户端。

### Consequences

- 客户端行为受 Gotify API 和鉴权模型约束。
- 第一版应优先验证兼容的 Gotify Server/API 版本，再实现扩展能力。

## ADR-002：远端消息以 Gotify Server 为权威来源

- Status: Accepted
- Date: 2026-08-08

### Decision

消息内容的权威副本保存在 Gotify Server。Mac 客户端只保留满足体验和离线展示需要的有限缓存，不把本地存储当作完整消息档案。

### Rationale

- 避免客户端复制完整服务端存储职责。
- 降低初版的数据迁移、恢复和一致性复杂度。
- 客户端可以通过服务端重新获取消息。

### Consequences

- 本地缓存被清理时不应影响服务端消息。
- 缓存容量和离线体验仍需在实现前单独确认。

## ADR-003：第一版不实现跨设备已读状态同步

- Status: Accepted
- Date: 2026-08-08

### Decision

如果第一版需要已读状态，该状态只在 Mac 本地保存，不承诺与 Android 或其他客户端同步。

### Rationale

- 当前目标聚焦于消息接收、展示和通知。
- 跨设备已读同步需要额外的服务端模型或协议约定，不属于初始范围。

### Consequences

- 同一条消息在不同设备上的已读状态可能不同。
- 将来若引入同步能力，需要新增 ADR，明确服务端模型、冲突处理和迁移方案。

## ADR-004：Client Token 存储在 macOS Keychain

- Status: Superseded by ADR-008
- Date: 2026-08-08

### Decision

Gotify Client Token 必须存储在 macOS Keychain，不写入源码、普通偏好文件或可提交配置。

### Rationale

- Token 属于敏感凭据。
- Keychain 是 macOS 上适合保存应用凭据的系统能力。

### Consequences

- 设置、更新和删除 Token 都要处理 Keychain 错误。
- 日志和诊断信息必须对凭据进行完整屏蔽。

## ADR-005：优先采用 Swift、SwiftUI 与 Apple 原生框架

- Status: Accepted
- Date: 2026-08-08

### Decision

客户端以 Swift 和 SwiftUI 实现，并优先使用 Apple 原生网络、通知、安全存储和生命周期 API。新增第三方生产依赖前需说明必要性并获得确认。

### Rationale

- 保持应用原生体验并减少依赖面。
- 降低长期维护、供应链和版本兼容成本。

### Consequences

- 初期实现可能需要为系统 API 编写少量适配层。
- 最低 macOS 版本将直接影响可使用的 SwiftUI 和系统 API，必须在创建工程前确认。

## ADR-006：最低支持 macOS 14 Sonoma

- Status: Accepted
- Date: 2026-08-08

### Decision

第一版最低支持 macOS 14（`LSMinimumSystemVersion` 与 SwiftPM platforms 均设为 14.0）。

### Rationale

- 覆盖近三代系统，同时可以使用 MenuBarExtra、`@Observable` 等现代 SwiftUI API。
- 是兼容性与 API 现代性的平衡点。

### Consequences

- 不能使用仅 macOS 15+ 可用的 API；如确有需要，须用 `if #available` 做条件降级或新增 ADR 提升最低版本。

## ADR-007：工程形式采用 SwiftPM + 打包脚本，不依赖 Xcode 工程

- Status: Accepted
- Date: 2026-08-08

### Decision

代码以 Swift Package（`Package.swift` + `Sources/`）组织，`swift build` 构建，`scripts/build-app.sh` 将产物组装为 `.app` bundle（复制 `Support/Info.plist`、ad-hoc 签名）。当前不创建 `.xcodeproj`。

### Rationale

- 开发机只安装了 Command Line Tools，没有 Xcode.app，SwiftPM 是当前环境立即可用的构建方式。
- 工程配置以纯文本（Package.swift、Info.plist、脚本）表达，diff 友好。

### Consequences

- 无法使用 SwiftUI 预览、Xcode 调试器和 Interface Builder。
- App 仅 ad-hoc 签名，只适合本机自用；若将来需要分发、公证或上架，需安装 Xcode 并新增 ADR 引入标准工程与正式签名。

## ADR-008：配置与 Client Token 存储在本地配置文件

- Status: Accepted（用户明确要求，替代 ADR-004）
- Date: 2026-08-08

### Decision

服务器地址和 Client Token 统一保存在 `~/Library/Application Support/GotifyMac/config.json`（权限 600），不使用 Keychain。该文件位于仓库之外，永远不提交 Git。

### Rationale

- 用户明确要求配置放在本地配置文件而非 Keychain，简化本地开发和手工编辑。
- 应用当前定位为本机自用，配置文件在用户目录下且已收紧权限。

### Consequences

- Token 以明文形式存在磁盘上，安全性弱于 Keychain；日志和错误信息仍必须屏蔽 Token。
- 若将来面向分发或多用户场景，应新增 ADR 重新评估凭据存储方案。


## ADR-009：应用内配置写入策略

- Status: Accepted
- Date: 2026-08-09

### Decision

设置窗口落地后，config.json 由应用写入（此前仅手工编辑）。写入策略：JSON 保持 prettyPrinted + sortedKeys（保留手工编辑的可行性）；原子写（临时文件 rename）后必须重设权限 600（rename 会丢原权限位）；解码采用逐字段容错——老版本文件缺新字段时回默认值，绝不整体解码失败回落 default（否则已配置的 serverURL/token 会"丢失"）。应用内写入唯一入口为 `AppModel.saveConfig`，仅服务器地址或 Token 变化才触发重连。

### Consequences

- 未来给 AppConfig 加字段必须提供默认值并走 decodeIfPresent，保证旧文件兼容。
- 手工编辑 config.json 仍然有效，但应用一旦保存设置会重写整个文件（未知字段会被丢弃）。

## ADR-010：Markdown 正文按行拆分渲染，摘要与详情分离

- Status: Accepted
- Date: 2026-08-09

### Decision

支持发送方通过 `extras.client::display.contentType = text/markdown` 声明正文为 Markdown。渲染不直接用 `AttributedString(markdown:)` 的 `.full` 模式，改为「按行拆分 → 块级标记自己转换 → 每行用 `.inlineOnlyPreservingWhitespace` 交系统解析行内语法」。列表行与系统通知横幅无法渲染富文本，改用剥掉标记的纯文本摘要。

### Rationale

实测 `.full` 模式会丢弃全部换行，且列表结构只落在 SwiftUI `Text` 不渲染的 `PresentationIntent` 上，多行通知会被挤成一行；`.inlineOnlyPreservingWhitespace` 保留换行且能解析行内语法，但 `- `、`# ` 这类块级标记保持字面量，因此块级部分自己处理。

剥标记只匹配成对标记，单标记斜体额外要求外侧非字母数字（近似 CommonMark flanking 规则），避免误伤 `user_id`、`2*3` 这类内容。

### Consequences

- 支持范围：加粗、斜体、行内代码、链接、无序列表、ATX 标题。表格、围栏代码块、嵌套列表、图片、HTML 按字面量显示。
- 详情页与摘要走两条路径，新增行内语法支持时两边都要改，否则详情能渲染而摘要残留标记。
- 零第三方依赖，全部基于 Foundation。

## ADR-011：本地已读状态用单一水位线，存 config.json

- Status: Accepted
- Date: 2026-08-09

### Decision

已读状态不逐条记录，只持久化一个 `lastReadMessageID` 水位线（AppConfig 新字段）：id 大于水位线的消息视为未读；「全部已读」把水位线推到当前最大消息 id。仅本地生效（符合 ADR-003），不新开状态文件，复用 config.json 的读写机制（ADR-009 的容错解码与 600 权限）。serverURL|token 身份变化时水位线归零并落盘——旧服务器的消息 id 对新服务器无意义。

### Rationale

- 用户的使用方式是"看完点一下全部已读，下次知道从哪条开始看"，水位线正好是这个心智模型；Gotify 消息 id 单调递增使其成立。
- 逐条已读集合需要随 200 条裁剪同步清理、体积无上界，复杂度不匹配需求。
- 水位线语义上更接近用户偏好而非缓存数据，放 config.json 可复用现成持久化路径，代价是配置文件里多一个应用维护的字段。

### Consequences

- 无法表达"跳着读"（新消息已读、旧消息未读），若将来需要逐条已读须新增 ADR。
- 手工编辑 config.json 时该字段会被应用改写（点全部已读或换服务器时）。

## ADR-012：放弃系统通知横幅，以菜单栏未读圆点为唯一提醒

- Status: Accepted（替代同日拟定的 "Apple Development 证书签名" 方案）
- Date: 2026-08-09

### Decision

不再追求让 `UNUserNotificationCenter` 系统通知横幅可用：构建保持 ad-hoc 签名，不引入任何证书。新消息的提醒方式为菜单栏图标的未读圆点/角标（ADR-011 的已读水位线机制）。通知相关 UI 入口全部移除（面板工具栏的 `bell.slash` 警示图标、设置窗口「通知」标签）；`NotificationService` 与 `notificationsEnabled`/`soundEnabled` 配置字段保留：在授权可用的环境（如他人用有效证书自行构建）仍会发横幅，本机授权失败时静默降级。

### Rationale

macOS 26 上完整排查结论：

1. ad-hoc 与 openssl 自签名证书（即使加入用户信任列表）请求授权被系统直接拒绝（"Notifications are not allowed for this application"）。
2. 换用免费 Apple ID 的 Apple Development 证书（Apple 根证书链）后，授权弹窗可以出现——但系统把"拒绝"记录绑定在**应用路径**上且不出现在 系统设置→通知 中，一旦横幅被划掉或误点，该路径便永久无法再弹窗，只能换全新路径+全新 bundle ID 重来。
3. 上述流程对一个个人自用工具过于脆弱繁琐（装 12GB Xcode、证书年检、路径/ID 不能复用），用户裁定收益不值得，未读圆点已满足提醒需求。

### Consequences

- 本机不会有系统通知横幅与提示音；提醒完全依赖菜单栏未读圆点。
- 通知开关不再有 UI，只能手工编辑 config.json 的 `notificationsEnabled`/`soundEnabled`（仅对授权可用的环境有意义）。
- 无需 Xcode、无需任何证书，回到纯 CLT + SwiftPM 工作流（ADR-007 完整保持）。
- 若将来 macOS 放宽限制或用户改用有效证书，功能无需改代码即可恢复。
- 排查过程中生成的钥匙串项（Apple Development 证书、WWDR G3 中间证书）无害保留。

## ADR-013：发布走 GitHub Actions 打 DMG，ad-hoc 签名不公证

- Status: Accepted
- Date: 2026-08-09

### Decision

推送 `v*` 标签触发 `.github/workflows/release.yml`：在 macos-15 runner 上跑单元测试 → `scripts/build-app.sh`（`APP_ARCHS="arm64 x86_64"` 出通用二进制，`APP_VERSION` 取自标签、`APP_BUILD` 取 run number）→ `scripts/make-dmg.sh` 打成含 `/Applications` 快捷方式的 DMG → `gh release create` 上传到 Releases。签名仍是 ad-hoc，不做 Developer ID 签名与公证。

DMG 打包逻辑放在 `scripts/make-dmg.sh` 而不是写进 workflow，本地可复现同样的产物；CI 只做编排。

### Rationale

- 用户需要在 Releases 页直接下载安装包，源码构建对普通用户门槛过高。
- 公证需要 99 美元/年的 Apple Developer Program 会员，对个人自用工具不成立；ad-hoc 签名的取舍已在 ADR-012 定过，这里延续。
- runner 是 Apple Silicon，默认只出 arm64；显式双架构才能覆盖 Intel Mac。多架构构建走 xcbuild 需要完整 Xcode，CI 有、本机（纯 CLT，ADR-007）没有，因此架构做成可选环境变量而不是写死。
- 用 `gh` CLI 而不是第三方 action 发布，减少供应链面。

### Consequences

- 用户下载的 DMG 会被 Gatekeeper 拦截，必须右键「打开」或 `xattr -dr com.apple.quarantine`；Release 说明与 README 都写明该步骤。
- 版本号唯一来源是 git 标签，`Support/Info.plist` 里的 `0.1.0` 只作为本地构建的缺省值。
- 本机无法验证通用二进制构建（缺 Xcode），该路径只在 CI 上生效，首次发版需确认 `lipo -info` 输出两个架构（workflow 内已加该检查步骤）。
- 没有自动更新机制，用户需自行回到 Releases 页下载新版本。
