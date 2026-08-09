import SwiftUI

/// 服务器标签：本地草稿 + 显式提交。逐键保存会触发重连风暴和半截
/// URL 的连接尝试，所以只在 onSubmit / 「保存并连接」时落盘。
struct ServerSettingsTab: View {
    let model: AppModel

    private enum TestState: Equatable {
        case idle
        case testing
        case done(AppModel.ConnectionTest)
    }

    @State private var draftURL = ""
    @State private var draftToken = ""
    @State private var testState: TestState = .idle

    var body: some View {
        Form {
            Section {
                TextField("服务器地址", text: $draftURL, prompt: Text("http://127.0.0.1:18080"))
                    .autocorrectionDisabled()
                    .onSubmit(apply)
                SecureField("Client Token", text: $draftToken)
                    .onSubmit(apply)
                Text("在 Gotify Web 界面创建并复制 Client 类型的 Token")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Button("测试连接") { runTest() }
                        .disabled(testState == .testing)
                    Button("保存并连接") { apply() }
                        .keyboardShortcut(.defaultAction)
                    Spacer()
                    testResultLabel
                }
                LabeledContent("当前状态", value: model.statusText)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            draftURL = model.config.serverURL
            draftToken = model.config.clientToken
        }
    }

    @ViewBuilder
    private var testResultLabel: some View {
        switch testState {
        case .idle:
            EmptyView()
        case .testing:
            ProgressView()
                .controlSize(.small)
        case .done(.success(let user)):
            Label("连接成功：\(user)", systemImage: "checkmark.circle")
                .foregroundStyle(.green)
                .font(.caption)
        case .done(.failure(let hint)):
            Label(hint, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .font(.caption)
        }
    }

    /// 用草稿值测试，不落盘
    private func runTest() {
        testState = .testing
        let url = draftURL
        let token = draftToken
        Task {
            testState = .done(await model.testConnection(serverURL: url, token: token))
        }
    }

    private func apply() {
        var config = model.config
        config.serverURL = draftURL
        config.clientToken = draftToken
        model.saveConfig(config)
    }
}
