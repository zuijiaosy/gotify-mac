import Foundation
import Testing
@testable import GotifyMac

@MainActor
final class FakeHotKeyRegistrar: HotKeyRegistering {
    var onPress: ((ShortcutAction) -> Void)?
    var active: [ShortcutAction: KeyboardShortcutBinding] = [:]
    var rejected: KeyboardShortcutBinding?

    func register(_ binding: KeyboardShortcutBinding, for action: ShortcutAction) throws {
        if binding == rejected || active.values.contains(binding) {
            throw ShortcutError.registration(-9878)
        }
        active[action] = binding
    }

    func unregister(_ action: ShortcutAction) { active[action] = nil }
    func stop() { active = [:] }
}

@Suite struct ShortcutConfigTests {
    @Test func missingFieldsUseDefaults() throws {
        let config = try JSONDecoder().decode(AppConfig.self, from: Data("{}".utf8))
        #expect(config.togglePanelShortcut == .togglePanel)
        #expect(config.markAllReadShortcut == .markAllRead)
    }

    @Test func clearedBindingsStayCleared() throws {
        var config = AppConfig.default
        config.togglePanelShortcut = nil
        config.markAllReadShortcut = nil
        let loaded = try JSONDecoder().decode(AppConfig.self, from: JSONEncoder().encode(config))
        #expect(loaded.togglePanelShortcut == nil)
        #expect(loaded.markAllReadShortcut == nil)
    }

    @Test func malformedBindingDoesNotDiscardOtherConfig() throws {
        let json = #"{"serverURL":"https://example.test","togglePanelShortcut":{"keyCode":"invalid"}}"#
        let config = try JSONDecoder().decode(AppConfig.self, from: Data(json.utf8))
        #expect(config.serverURL == "https://example.test")
        #expect(config.togglePanelShortcut == nil)
        #expect(config.markAllReadShortcut == .markAllRead)
    }

    @Test func validationRejectsBareAndUnsupportedKeys() {
        #expect(!KeyboardShortcutBinding(keyCode: 5, modifiers: 0).isValid)
        #expect(!KeyboardShortcutBinding(keyCode: 5, modifiers: 512).isValid)
        #expect(!KeyboardShortcutBinding(keyCode: 999, modifiers: KeyboardShortcutBinding.togglePanel.modifiers).isValid)
        #expect(KeyboardShortcutBinding.togglePanel.isValid)
    }
}

@MainActor @Suite struct GlobalShortcutsTests {
    private let custom = KeyboardShortcutBinding(keyCode: 0, modifiers: KeyboardShortcutBinding.togglePanel.modifiers)

    @Test func startsBothBindingsAndDispatchesActions() {
        let registrar = FakeHotKeyRegistrar()
        var actions: [ShortcutAction] = []
        let shortcuts = GlobalShortcuts(registrar: registrar, save: { _ in }, perform: { actions.append($0) })
        shortcuts.start(config: .default)
        #expect(registrar.active.count == 2)
        registrar.onPress?(.togglePanel)
        registrar.onPress?(.markAllRead)
        #expect(actions == [.togglePanel, .markAllRead])
        shortcuts.stop()
        #expect(registrar.active.isEmpty)
    }

    @Test func duplicateIsRejectedWithoutSaving() {
        let registrar = FakeHotKeyRegistrar()
        var saves = 0
        let shortcuts = GlobalShortcuts(registrar: registrar, save: { _ in saves += 1 }, perform: { _ in })
        shortcuts.start(config: .default)
        shortcuts.update(.togglePanel, to: .markAllRead)
        #expect(saves == 0)
        #expect(registrar.active[.togglePanel] == .togglePanel)
        #expect(shortcuts.errors[.togglePanel] != nil)
    }

    @Test func registrationFailureRestoresPreviousBinding() {
        let registrar = FakeHotKeyRegistrar()
        registrar.rejected = custom
        var saves = 0
        let shortcuts = GlobalShortcuts(registrar: registrar, save: { _ in saves += 1 }, perform: { _ in })
        shortcuts.start(config: .default)
        shortcuts.update(.togglePanel, to: custom)
        #expect(saves == 0)
        #expect(shortcuts.bindings[.togglePanel] == .togglePanel)
        #expect(registrar.active[.togglePanel] == .togglePanel)
        #expect(registrar.active[.markAllRead] == .markAllRead)
    }

    @Test func saveFailureRestoresPreviousBinding() {
        let registrar = FakeHotKeyRegistrar()
        let shortcuts = GlobalShortcuts(registrar: registrar, save: { _ in throw CocoaError(.fileWriteNoPermission) }, perform: { _ in })
        shortcuts.start(config: .default)
        shortcuts.update(.togglePanel, to: custom)
        #expect(shortcuts.bindings[.togglePanel] == .togglePanel)
        #expect(registrar.active[.togglePanel] == .togglePanel)
        #expect(shortcuts.errors[.togglePanel]?.contains("保存失败") == true)
    }

    @Test func changingAndClearingSaveAndUpdateRegistration() {
        let registrar = FakeHotKeyRegistrar()
        var saved: [ShortcutAction: KeyboardShortcutBinding] = [:]
        let shortcuts = GlobalShortcuts(registrar: registrar, save: { saved = $0 }, perform: { _ in })
        shortcuts.start(config: .default)
        shortcuts.update(.togglePanel, to: custom)
        #expect(saved[.togglePanel] == custom)
        #expect(registrar.active[.togglePanel] == custom)
        shortcuts.update(.togglePanel, to: nil)
        #expect(saved[.togglePanel] == nil)
        #expect(registrar.active[.togglePanel] == nil)
        #expect(registrar.active[.markAllRead] == .markAllRead)
    }

    @Test func startupFailureOnlyDisablesAffectedAction() {
        let registrar = FakeHotKeyRegistrar()
        registrar.rejected = .togglePanel
        let shortcuts = GlobalShortcuts(registrar: registrar, save: { _ in }, perform: { _ in })
        shortcuts.start(config: .default)
        #expect(registrar.active[.togglePanel] == nil)
        #expect(shortcuts.errors[.togglePanel] != nil)
        #expect(registrar.active[.markAllRead] == .markAllRead)
    }

    @Test func emptyStoreDoesNotResetPersistedReadWatermark() {
        var config = AppConfig.default
        config.lastReadMessageID = 42
        let model = AppModel(autoStart: false, initialConfig: config)
        model.markAllRead()
        #expect(model.config.lastReadMessageID == 42)
    }

    @Test func markAllReadPersistsCurrentMaximum() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("config.json")
        var store = MessageStore()
        _ = store.insert(GotifyMessage(id: 12, appid: 1, title: "Test", message: "Test", priority: 1, date: Date()))
        let model = AppModel(autoStart: false, initialStore: store, configURL: url)
        #expect(model.hasUnread)
        model.markAllRead()
        #expect(!model.hasUnread)
        #expect(AppConfig.load(from: url).lastReadMessageID == 12)
    }

    @Test func savingShortcutsPreservesConfigWithoutReconnecting() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("config.json")
        var config = AppConfig.default
        config.serverURL = "https://example.test"
        config.lastReadMessageID = 42
        let model = AppModel(autoStart: false, initialConfig: config, configURL: url)
        try model.saveShortcuts([.togglePanel: custom])
        let loaded = AppConfig.load(from: url)
        #expect(loaded.serverURL == config.serverURL)
        #expect(loaded.lastReadMessageID == 42)
        #expect(loaded.togglePanelShortcut == custom)
        #expect(loaded.markAllReadShortcut == nil)
        #expect(model.isRefreshing == false)
    }
}
