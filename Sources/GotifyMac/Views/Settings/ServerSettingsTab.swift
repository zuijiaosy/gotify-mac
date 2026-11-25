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
    @State private var isTokenVisible = false
    @State private var testState: TestState = .idle

    private var hasUnsavedChanges: Bool {
        draftURL != model.config.serverURL || draftToken != model.config.clientToken
    }

    var body: some View {
        Form {
            Section {
                TextField("服务器地址", text: $draftURL, prompt: Text("https://gotify.example.com"))
                    .autocorrectionDisabled()
                    .onSubmit(apply)

                LabeledContent("Client Token") {
                    HStack(spacing: 6) {
                        ZStack(alignment: .trailing) {
                            if draftToken.isEmpty {
                                Text("粘贴 Client Token")
                                    .foregroundStyle(.tertiary)
                                    .allowsHitTesting(false)
                            }
                            Group {
                                if isTokenVisible {
                                    TextField("", text: $draftToken)
                                        .autocorrectionDisabled()
                                        .onSubmit(apply)
                                } else {
                                    SecureField("", text: $draftToken)
                                        .onSubmit(apply)
                                }
                            }
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                        }

                        Button {
                            isTokenVisible.toggle()
                        } label: {
                            Image(systemName: isTokenVisible ? "eye.slash" : "eye")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(width: 18, height: 18)
                        }
                        .buttonStyle(.borderless)
                        .help(isTokenVisible ? "隐藏 Token" : "显示 Token")
                    }
                }
            } header: {
                Text("服务器连接")
            } footer: {
                Text("在 Gotify Web 界面的 CLIENTS 页面创建并复制 Client Token（非 App Token）。配置仅保存在本机，文件权限为 600。")
            }

            Section {
                LabeledContent("当前状态") {
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(PanelTheme.statusColor(for: model.state).opacity(0.22))
                                .frame(width: 10, height: 10)
                            Circle()
                                .fill(PanelTheme.statusColor(for: model.state))
                                .frame(width: 6, height: 6)
                        }
                        Text(model.statusText)
                            .foregroundStyle(statusTextColor)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        runTest()
                    } label: {
                        HStack(spacing: 5) {
                            if testState == .testing {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(testState == .testing ? "测试中…" : "测试连接")
                        }
                    }
                    .disabled(testState == .testing)

                    Spacer()

                    if hasUnsavedChanges {
                        Text("未保存")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button("保存并连接") { apply() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }

                if case .done(let result) = testState {
                    testResultRow(result)
                }
            } header: {
                Text("状态与操作")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            draftURL = model.config.serverURL
            draftToken = model.config.clientToken
        }
        .onChange(of: draftURL) { _, _ in
            if case .done = testState { testState = .idle }
        }
        .onChange(of: draftToken) { _, _ in
            if case .done = testState { testState = .idle }
        }
    }

    private var statusTextColor: Color {
        switch model.state {
        case .failed: .red
        case .reconnecting: .orange
        case .connected, .checking, .unconfigured: .secondary
        }
    }

    @ViewBuilder
    private func testResultRow(_ result: AppModel.ConnectionTest) -> some View {
        switch result {
        case .success(let user):
            Label("连接成功，当前用户：\(user)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .failure(let hint):
            Label(hint, systemImage: "exclamationmark.triangle.fill")
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
