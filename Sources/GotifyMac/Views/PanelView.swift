import SwiftUI

/// 面板根视图：单栏列表(360) ↔ 双栏列表+详情(240+400)，宽度两档硬切不做动画
/// （NSPanel resize 与 SwiftUI 动画不同步，会闪烁）。
struct PanelView: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings

    // 基于 selectedMessage 而非 ID：选中的消息被仓库淘汰后自动收回单栏
    private var expanded: Bool { model.selectedMessage != nil }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HStack(spacing: 0) {
                messageList
                    .frame(width: expanded ? 240 : 360)
                if expanded {
                    Divider()
                    MessageDetailView(model: model)
                        .frame(width: 400)
                }
            }
        }
        .frame(height: 480)
        .background(PanelWindowSizeEnforcer())
        .onDisappear {
            // 面板关闭后下次打开回到单栏
            model.selectedMessageID = nil
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Text("最近消息")
                .font(.headline)
            Spacer()
            Text(model.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Button {
                model.markAllRead()
            } label: {
                Image(systemName: "checkmark.circle")
            }
            .buttonStyle(.borderless)
            .disabled(!model.hasUnread)
            .help("全部标为已读")
            Menu {
                Button("设置…") {
                    // LSUIElement 应用无 Dock 图标，设置窗口不会自动前置，
                    // 打开前必须先把应用激活到前台
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
                Button("重新检查连接") {
                    Task { await model.refresh() }
                }
                Divider()
                Button("退出 Gotify Mac") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var messageList: some View {
        if model.store.messages.isEmpty {
            VStack {
                Spacer()
                Text(emptyHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(model.store.messages) { message in
                        MessageRowView(
                            message: message,
                            appName: model.appName(for: message.appid),
                            isSelected: model.selectedMessageID == message.id,
                            isUnread: model.isUnread(message),
                            compact: expanded
                        )
                        .onTapGesture {
                            if model.selectedMessageID == message.id {
                                model.selectedMessageID = nil
                            } else {
                                model.selectedMessageID = message.id
                            }
                        }
                    }
                }
                .padding(6)
            }
        }
    }

    private var emptyHint: String {
        switch model.state {
        case .checking: "正在连接…"
        case .connected: "暂无消息"
        case .unconfigured(let hint), .reconnecting(let hint), .failed(let hint): hint
        }
    }
}

/// 兜底：MenuBarExtra .window 的宿主窗口在某些真实交互路径下（如展开详情后点击面板
/// 外部关闭）不跟随内容收窄，重开时残留 641pt 宽的空白窗口，内容 360pt 居中其中，
/// 四周露出一圈"鬼影"。作为面板内容的 background，本视图尺寸恒等于内容尺寸；
/// 布局时发现窗口 frame 与内容不一致，就把窗口对齐回内容大小（保持顶边与水平中心）。
/// 正常 resize 路径下尺寸一致，此处为空操作。
private struct PanelWindowSizeEnforcer: NSViewRepresentable {
    func makeNSView(context: Context) -> EnforcerView { EnforcerView() }
    func updateNSView(_ nsView: EnforcerView, context: Context) {}

    final class EnforcerView: NSView {
        override func layout() {
            super.layout()
            enforce()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            enforce()
        }

        private func enforce() {
            // 异步执行：等本轮布局落定，避免与 AppKit 自身的窗口调整互相打架
            DispatchQueue.main.async { [weak self] in
                guard let self, let window = self.window else { return }
                let target = self.bounds.size
                guard target.width > 0, target.height > 0,
                      window.frame.size != target else { return }
                let frame = window.frame
                window.setFrame(
                    NSRect(
                        x: frame.midX - target.width / 2,
                        y: frame.maxY - target.height,
                        width: target.width,
                        height: target.height
                    ),
                    display: true
                )
                window.invalidateShadow()
            }
        }
    }
}
