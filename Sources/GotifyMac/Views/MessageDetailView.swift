import SwiftUI

/// 右侧详情栏：应用图标/名、时间、优先级徽章、全文、复制与返回
struct MessageDetailView: View {
    let model: AppModel

    var body: some View {
        if let message = model.selectedMessage {
            VStack(alignment: .leading, spacing: 0) {
                header(message)
                Divider()
                ScrollView {
                    bodyText(message)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                Divider()
                footer(message)
            }
        } else {
            Text("选择一条消息查看详情")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// markdown 消息渲染样式，其余原样显示
    private func bodyText(_ message: GotifyMessage) -> Text {
        switch message.contentType {
        case .markdown: Text(MarkdownRenderer.attributedBody(message.message))
        case .plain: Text(message.message)
        }
    }

    private func header(_ message: GotifyMessage) -> some View {
        HStack(spacing: 8) {
            AsyncImage(url: model.appImageURL(for: message.appid)) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "app.badge")
                    .foregroundStyle(.secondary)
            }
            .frame(width: 28, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 1) {
                Text(message.displayTitle)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(model.appName(for: message.appid))
                    Text(message.date.formatted(.dateTime.month().day().hour().minute().second()))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            priorityBadge(message.displayPriority)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func priorityBadge(_ priority: Int) -> some View {
        Text("P\(priority)")
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(PriorityTier(priority: priority).color, in: Capsule())
    }

    private func footer(_ message: GotifyMessage) -> some View {
        HStack {
            Button {
                model.selectedMessageID = nil
            } label: {
                Label("返回", systemImage: "chevron.left")
            }
            Spacer()
            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(message.message, forType: .string)
            } label: {
                Label("复制内容", systemImage: "doc.on.doc")
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
