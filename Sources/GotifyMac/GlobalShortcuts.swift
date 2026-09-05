import AppKit
import Carbon
import Observation

enum ShortcutAction: UInt32, CaseIterable {
    case togglePanel = 1
    case markAllRead = 2

    var title: String {
        switch self {
        case .togglePanel: "显示/隐藏主界面"
        case .markAllRead: "全部已读"
        }
    }
}

struct KeyboardShortcutBinding: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let togglePanel = Self(keyCode: UInt32(kVK_ANSI_G), modifiers: UInt32(controlKey | optionKey))
    static let markAllRead = Self(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(controlKey | optionKey))
    static let allowedModifiers = UInt32(cmdKey | controlKey | optionKey | shiftKey)

    var isValid: Bool {
        Self.keyNames[keyCode] != nil && modifiers & UInt32(cmdKey | controlKey | optionKey) != 0
            && modifiers & ~Self.allowedModifiers == 0
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(event: NSEvent) {
        keyCode = UInt32(event.keyCode)
        let flags = event.modifierFlags
        modifiers = (flags.contains(.command) ? UInt32(cmdKey) : 0)
            | (flags.contains(.control) ? UInt32(controlKey) : 0)
            | (flags.contains(.option) ? UInt32(optionKey) : 0)
            | (flags.contains(.shift) ? UInt32(shiftKey) : 0)
    }

    var displayName: String {
        [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")]
            .filter { modifiers & UInt32($0.0) != 0 }.map(\.1).joined()
            + (Self.keyNames[keyCode] ?? "?")
    }

    // Physical ANSI key names keep the stored virtual key code unambiguous.
    static let keyNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
        46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`", 51: "Delete",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        109: "F10", 111: "F12", 118: "F4", 120: "F2", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
}

@MainActor
protocol HotKeyRegistering: AnyObject {
    var onPress: ((ShortcutAction) -> Void)? { get set }
    func register(_ binding: KeyboardShortcutBinding, for action: ShortcutAction) throws
    func unregister(_ action: ShortcutAction)
    func stop()
}

@MainActor
final class CarbonHotKeyRegistrar: HotKeyRegistering {
    var onPress: ((ShortcutAction) -> Void)?
    private var references: [ShortcutAction: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?
    private var pressed: Set<ShortcutAction> = []
    private static let signature: OSType = 0x47544659

    private func installHandler() throws {
        guard handler == nil else { return }
        var types = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                     EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            return MainActor.assumeIsolated {
                let registrar = Unmanaged<CarbonHotKeyRegistrar>.fromOpaque(context).takeUnretainedValue()
                var id = EventHotKeyID()
                guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                        nil, MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr,
                      id.signature == CarbonHotKeyRegistrar.signature,
                      let action = ShortcutAction(rawValue: id.id),
                      registrar.references[action] != nil else { return OSStatus(eventNotHandledErr) }
                if GetEventKind(event) == UInt32(kEventHotKeyReleased) {
                    registrar.pressed.remove(action)
                } else if registrar.pressed.insert(action).inserted {
                    registrar.onPress?(action)
                }
                return noErr
            }
        }, types.count, &types, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { throw ShortcutError.registration(status) }
    }

    func register(_ binding: KeyboardShortcutBinding, for action: ShortcutAction) throws {
        try installHandler()
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(binding.keyCode, binding.modifiers,
                                        EventHotKeyID(signature: Self.signature, id: action.rawValue),
                                        GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &reference)
        guard status == noErr, let reference else { throw ShortcutError.registration(status) }
        references[action] = reference
    }

    func unregister(_ action: ShortcutAction) {
        if let reference = references.removeValue(forKey: action) { UnregisterEventHotKey(reference) }
        pressed.remove(action)
    }

    func stop() {
        for action in ShortcutAction.allCases { unregister(action) }
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }
}

enum ShortcutError: LocalizedError {
    case registration(OSStatus)
    case duplicate
    case invalid
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .registration(let status): "快捷键无法注册，可能已被其他应用占用（\(status)）。请更换组合键。"
        case .duplicate: "两个动作不能使用相同的快捷键。"
        case .invalid: "不支持该按键，请使用包含 Command、Control 或 Option 的组合键。"
        case .saveFailed: "快捷键保存失败，请检查配置目录的写入权限。"
        }
    }
}

@MainActor @Observable
final class GlobalShortcuts {
    private(set) var bindings: [ShortcutAction: KeyboardShortcutBinding] = [:]
    private(set) var errors: [ShortcutAction: String] = [:]
    private(set) var recording: ShortcutAction?
    private let registrar: any HotKeyRegistering
    private let save: ([ShortcutAction: KeyboardShortcutBinding]) throws -> Void
    private var monitor: Any?

    init(registrar: any HotKeyRegistering,
         save: @escaping ([ShortcutAction: KeyboardShortcutBinding]) throws -> Void,
         perform: @escaping (ShortcutAction) -> Void) {
        self.registrar = registrar
        self.save = save
        registrar.onPress = perform
    }

    func start(config: AppConfig) {
        bindings = [:]
        bindings[.togglePanel] = config.togglePanelShortcut
        bindings[.markAllRead] = config.markAllReadShortcut
        resume()
    }

    private func resume() {
        for action in ShortcutAction.allCases { registrar.unregister(action) }
        for action in ShortcutAction.allCases {
            errors[action] = nil
            guard let binding = bindings[action] else { continue }
            do {
                try registrar.register(binding, for: action)
                errors[action] = nil
            } catch { errors[action] = error.localizedDescription }
        }
    }

    func update(_ action: ShortcutAction, to binding: KeyboardShortcutBinding?) {
        cancelRecording()
        if let binding {
            guard binding.isValid else { errors[action] = ShortcutError.invalid.localizedDescription; return }
            guard !bindings.contains(where: { $0.key != action && $0.value == binding }) else {
                errors[action] = ShortcutError.duplicate.localizedDescription
                return
            }
        }
        let previous = bindings[action]
        registrar.unregister(action)
        do {
            if let binding { try registrar.register(binding, for: action) }
            var updated = bindings
            updated[action] = binding
            do { try save(updated) }
            catch { throw ShortcutError.saveFailed }
            bindings = updated
            errors[action] = nil
        } catch {
            let failure = error.localizedDescription
            registrar.unregister(action)
            if let previous {
                do { try registrar.register(previous, for: action) }
                catch { errors[action] = failure + " 原快捷键恢复失败：" + error.localizedDescription; return }
            }
            errors[action] = failure
        }
    }

    func beginRecording(_ action: ShortcutAction) {
        cancelRecording()
        recording = action
        for action in ShortcutAction.allCases { registrar.unregister(action) }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let consumed = MainActor.assumeIsolated {
                guard let self, let action = self.recording else { return false }
                if event.keyCode == UInt16(kVK_Escape) { self.cancelRecording(); return true }
                guard !event.isARepeat else { return true }
                let binding = KeyboardShortcutBinding(event: event)
                guard binding.isValid else {
                    self.errors[action] = ShortcutError.invalid.localizedDescription
                    return true
                }
                self.update(action, to: binding)
                return true
            }
            return consumed ? nil : event
        }
    }

    func cancelRecording() {
        guard recording != nil else { return }
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = nil
        resume()
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = nil
        registrar.stop()
    }
}
