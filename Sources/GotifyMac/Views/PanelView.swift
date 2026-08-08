import SwiftUI

/// 面板根视图：单栏列表(360) ↔ 双栏列表+详情(240+400)，宽度两档硬切不做动画
/// （NSPanel resize 与 SwiftUI 动画不同步，会闪烁）。
struct PanelView: View {
    let model: AppModel

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
            if !model.notifier.statusHint.isEmpty {
                Image(systemName: "bell.slash")
                    .foregroundStyle(.orange)
                    .help(model.notifier.statusHint)
            }
            Menu {
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
