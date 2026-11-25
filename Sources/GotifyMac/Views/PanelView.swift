import SwiftUI

/// 面板根视图：单栏列表(360) ↔ 双栏列表+详情(240+1+400=641)，由 popover 控制两档宽度。
struct PanelView: View {
    let model: AppModel
    let showSettings: () -> Void
    let resize: (Bool) -> Void

    /// 列表相对时间的基准时刻，每分钟推进一次
    @State private var now = Date()
    @State private var isGearHovered = false
    private let minuteTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // 基于 selectedMessage 而非 ID：选中的消息被仓库淘汰后自动收回单栏
    private var expanded: Bool { model.selectedMessage != nil }

    private var unreadCount: Int {
        model.store.messages.reduce(0) { $0 + (model.isUnread($1) ? 1 : 0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Rectangle()
                .fill(PanelTheme.hairline)
                .frame(height: 1)
            HStack(spacing: 0) {
                messageList
                    .id(model.panelPresentationID)
                    .frame(width: expanded ? 240 : 360)
                    .background(PanelTheme.canvas)
                if expanded {
                    Rectangle()
                        .fill(PanelTheme.hairline)
                        .frame(width: 1)
                    MessageDetailView(model: model)
                        .frame(width: 400)
                }
            }
        }
        .frame(height: 480)
        .background(PanelTheme.canvas)
        .environment(\.colorScheme, .light)
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
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("最近消息")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(PanelTheme.inkPrimary)
                    .fixedSize()
                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 5.5)
                        .frame(minWidth: 18, minHeight: 16)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                        .fixedSize()
                }
            }
            statusIndicator
            Spacer(minLength: 6)
            Button {
                model.markAllRead()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 11, weight: .medium))
                    Text("全部已读")
                }
            }
            .buttonStyle(PanelToolbarButtonStyle())
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
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(isGearHovered ? PanelTheme.inkPrimary : PanelTheme.inkSecondary)
                    .frame(width: 24, height: 24)
                    .background(
                        isGearHovered ? Color.black.opacity(0.06) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            // 面板打开时齿轮会成为首个焦点，去掉系统蓝色焦点框
            .focusEffectDisabled()
            .fixedSize()
            .onHover { isGearHovered = $0 }
            .help("设置与更多操作")
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .frame(height: 42)
        .background(PanelTheme.chromeBackground)
    }

    /// 连接状态：语义圆点 + 短文案，异常态用柔色文字提醒
    private var statusIndicator: some View {
        HStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.22))
                    .frame(width: 10, height: 10)
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
            }
            Text(model.statusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(statusTextColor)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(statusPillBackground, in: Capsule())
        .help(model.statusText)
    }

    private var statusColor: Color {
        PanelTheme.statusColor(for: model.state)
    }

    private var statusTextColor: Color {
        switch model.state {
        case .failed: Color(red: 0.74, green: 0.16, blue: 0.16)
        case .reconnecting: Color(red: 0.70, green: 0.38, blue: 0.04)
        case .connected, .checking, .unconfigured: PanelTheme.inkSecondary
        }
    }

    private var statusPillBackground: Color {
        switch model.state {
        case .failed: statusColor.opacity(0.10)
        case .reconnecting: statusColor.opacity(0.10)
        case .connected, .checking, .unconfigured: Color.black.opacity(0.038)
        }
    }

    @ViewBuilder
    private var messageList: some View {
        if model.store.messages.isEmpty {
            emptyStateView
        } else {
            let messages = model.store.messages
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        let isSelected = model.selectedMessageID == message.id
                        let nextSelected = index + 1 < messages.count
                            && model.selectedMessageID == messages[index + 1].id

                        MessageRowView(
                            message: message,
                            appName: model.appName(for: message.appid),
                            isSelected: isSelected,
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

                        if index + 1 < messages.count {
                            Rectangle()
                                .fill(isSelected || nextSelected ? Color.clear : PanelTheme.rowHairline)
                                .frame(height: 0.5)
                                .padding(.leading, 20)
                                .padding(.trailing, 10)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
            .background(PanelTheme.canvas)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Spacer()
            ZStack {
                Circle()
                    .fill(emptyIconBackground)
                    .frame(width: 44, height: 44)
                if case .checking = model.state {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: emptySymbolName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(emptySymbolColor)
                }
            }
            VStack(spacing: 4) {
                Text(emptyTitle)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(PanelTheme.inkPrimary)
                Text(emptySubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(PanelTheme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(maxWidth: 240)
            }
            emptyActionButton
                .padding(.top, 2)
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PanelTheme.canvas)
    }

    private var emptySymbolName: String {
        switch model.state {
        case .checking: "arrow.triangle.2.circlepath"
        case .connected: "tray"
        case .unconfigured: "server.rack"
        case .reconnecting: "arrow.triangle.2.circlepath"
        case .failed: "wifi.exclamationmark"
        }
    }

    private var emptySymbolColor: Color {
        switch model.state {
        case .connected, .unconfigured: PanelTheme.inkSecondary
        case .checking, .reconnecting, .failed: statusColor
        }
    }

    private var emptyIconBackground: Color {
        switch model.state {
        case .failed, .reconnecting: statusColor.opacity(0.11)
        case .checking, .connected, .unconfigured: PanelTheme.subtleSurface
        }
    }

    private var emptyTitle: String {
        switch model.state {
        case .checking: "正在连接服务器…"
        case .connected: "暂无消息"
        case .unconfigured: "尚未配置服务器"
        case .reconnecting: "正在重新连接"
        case .failed: "连接失败"
        }
    }

    private var emptySubtitle: String {
        switch model.state {
        case .checking: "正在同步应用列表与最近消息"
        case .connected: "新推送到达后会实时显示在这里"
        case .unconfigured(let hint), .reconnecting(let hint), .failed(let hint): hint
        }
    }

    @ViewBuilder
    private var emptyActionButton: some View {
        switch model.state {
        case .unconfigured:
            Button("打开设置…") {
                showSettings()
            }
            .buttonStyle(PanelToolbarButtonStyle())
        case .failed, .reconnecting:
            Button("重新检查连接") {
                Task { await model.refresh() }
            }
            .buttonStyle(PanelToolbarButtonStyle())
            .disabled(model.isRefreshing)
        case .checking, .connected:
            EmptyView()
        }
    }
}
