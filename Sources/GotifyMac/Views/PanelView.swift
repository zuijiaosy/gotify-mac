import SwiftUI

/// 面板根视图：单栏列表(360) ↔ 双栏列表+详情(240+400)，由 popover 控制两档宽度。
struct PanelView: View {
    let model: AppModel
    let showSettings: () -> Void
    let resize: (Bool) -> Void

    /// 列表相对时间的基准时刻，每分钟推进一次
    @State private var now = Date()
    private let minuteTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

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
        .onChange(of: expanded) { _, value in resize(value) }
        .onReceive(minuteTicker) { now = $0 }
        .onAppear {
            // 面板视图跨次打开会复用，重开时先把基准时刻拉回当下
            now = Date()
        }
        .onDisappear {
            // 面板关闭后下次打开回到单栏
            model.selectedMessageID = nil
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Text("最近消息")
                .font(.headline)
            statusIndicator
            Spacer(minLength: 8)
            Button {
                model.markAllRead()
            } label: {
                Label("全部已读", systemImage: "checkmark.circle")
            }
            .buttonStyle(.bordered)
            .disabled(!model.hasUnread)
            .fixedSize()
            .help("全部标为已读")
            Menu {
                Button("设置…") {
                    showSettings()
                }
                Button("重新检查连接") {
                    Task { await model.refresh() }
                }
                .disabled(model.isRefreshing)
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

    /// 连接状态：彩色圆点 + 短文案（不再展示用户名）
    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(model.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .help(model.statusText)
    }

    private var statusColor: Color {
        switch model.state {
        case .connected: .green
        case .checking, .reconnecting: .orange
        case .failed: .red
        case .unconfigured: .secondary
        }
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
                            compact: expanded,
                            now: now
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
