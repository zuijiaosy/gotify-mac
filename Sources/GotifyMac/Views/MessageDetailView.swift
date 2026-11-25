import SwiftUI

/// 右侧详情栏：应用图标/名、完整时间、柔色优先级徽章、舒适排版的正文区、带反馈的复制与返回栏
struct MessageDetailView: View {
    let model: AppModel
    @State private var copiedMessageID: Int?
    @State private var copyResetTask: Task<Void, Never>?

    var body: some View {
        if let message = model.selectedMessage {
            VStack(alignment: .leading, spacing: 0) {
                header(message)
                Rectangle()
                    .fill(PanelTheme.hairline)
                    .frame(height: 1)
                ScrollView {
                    bodyContent(message)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
                .background(PanelTheme.canvas)
                Rectangle()
                    .fill(PanelTheme.hairline)
                    .frame(height: 1)
                footer(message)
            }
            .background(PanelTheme.canvas)
            .onChange(of: message.id) { _, _ in
                copyResetTask?.cancel()
                copiedMessageID = nil
            }
            .onDisappear {
                copyResetTask?.cancel()
                copiedMessageID = nil
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 22))
                    .foregroundStyle(PanelTheme.inkTertiary)
                Text("选择一条消息查看详情")
                    .font(.system(size: 12.5))
                    .foregroundStyle(PanelTheme.inkSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PanelTheme.canvas)
        }
    }

    /// markdown 消息渲染样式，其余原样显示
    @ViewBuilder
    private func bodyContent(_ message: GotifyMessage) -> some View {
        if message.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text("（无正文内容）")
                .font(.system(size: 13))
                .foregroundStyle(PanelTheme.inkTertiary)
        } else {
            bodyText(message)
                .font(.system(size: 13.5))
                .foregroundStyle(PanelTheme.inkPrimary)
                .lineSpacing(4.5)
                .tint(.accentColor)
                .textSelection(.enabled)
        }
    }

    private func bodyText(_ message: GotifyMessage) -> Text {
        switch message.contentType {
        case .markdown: Text(MarkdownRenderer.attributedBody(message.message))
        case .plain: Text(message.message)
        }
    }

    private func header(_ message: GotifyMessage) -> some View {
        let tier = PriorityTier(priority: message.displayPriority)
        return HStack(alignment: .top, spacing: 10) {
            appIcon(for: message, tier: tier)

            VStack(alignment: .leading, spacing: 3) {
                Text(message.displayTitle)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(PanelTheme.inkPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 5) {
                    Text(model.appName(for: message.appid))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(PanelTheme.inkSecondary)
                        .lineLimit(1)
                    Text("·")
                        .font(.system(size: 11.5))
                        .foregroundStyle(PanelTheme.inkTertiary)
                    Text(message.date.formatted(.dateTime.month().day().hour().minute().second()))
                        .font(.system(size: 11.5).monospacedDigit())
                        .foregroundStyle(PanelTheme.inkTertiary)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
            }

            Spacer(minLength: 8)
            priorityBadge(message.displayPriority, tier: tier)
                .padding(.top, 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(PanelTheme.chromeBackground)
    }

    private func appIcon(for message: GotifyMessage, tier: PriorityTier) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white)
            AsyncImage(url: model.appImageURL(for: message.appid)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(4)
                default:
                    Image(systemName: "bell.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(tier.dotColor.opacity(0.85))
                }
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(PanelTheme.hairline, lineWidth: 0.75)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
    }

    private func priorityBadge(_ priority: Int, tier: PriorityTier) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(tier.dotColor)
                .frame(width: 6, height: 6)
            Text("P\(priority)")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(tier.badgeForeground)
        }
        .padding(.horizontal, 7.5)
        .padding(.vertical, 3)
        .background(tier.badgeBackground, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(tier.badgeBorder, lineWidth: 0.75)
        )
        .fixedSize()
        .help("消息优先级 \(priority)")
    }

    private func footer(_ message: GotifyMessage) -> some View {
        let isCopied = copiedMessageID == message.id
        return HStack {
            Button {
                model.selectedMessageID = nil
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("返回")
                }
            }
            .buttonStyle(PanelSubtleButtonStyle())

            Spacer()

            Button {
                copyMessage(message)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11.5, weight: .medium))
                    Text(isCopied ? "已复制" : "复制内容")
                }
            }
            .buttonStyle(PanelSubtleButtonStyle(
                foreground: isCopied ? Color(red: 0.13, green: 0.62, blue: 0.32) : PanelTheme.inkSecondary,
                hoverForeground: isCopied ? Color(red: 0.13, green: 0.62, blue: 0.32) : PanelTheme.inkPrimary
            ))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(PanelTheme.chromeBackground)
    }

    private func copyMessage(_ message: GotifyMessage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(message.message, forType: .string)
        copiedMessageID = message.id
        copyResetTask?.cancel()
        copyResetTask = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            copiedMessageID = nil
        }
    }
}
