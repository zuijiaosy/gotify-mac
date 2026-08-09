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
