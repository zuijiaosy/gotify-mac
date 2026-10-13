import AppKit
import Carbon
import SwiftUI

@main enum ShortcutUISmoke {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = SmokeDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor private final class SmokeRegistrar: HotKeyRegistering {
    var onPress: ((ShortcutAction) -> Void)?
    var active: [ShortcutAction: KeyboardShortcutBinding] = [:]
    func register(_ binding: KeyboardShortcutBinding, for action: ShortcutAction) throws { active[action] = binding }
    func unregister(_ action: ShortcutAction) { active[action] = nil }
    func stop() { active = [:] }
}

@MainActor private final class SmokeDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            do {
                try await checkFlow()
                try checkCarbonEvents()
                print("PASS: native panel, settings, recording and background mark-all-read")
                print("Accessibility permission for physical-key automation: \(AXIsProcessTrusted())")
                exit(0)
            } catch {
                print("FAIL: \(error.localizedDescription)")
                exit(1)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw NSError(domain: "ShortcutUISmoke", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    private func settle() async throws { try await Task.sleep(for: .milliseconds(250)) }

    private func checkFlow() async throws {
        // The reading panel must stay opaque white even when the app uses dark appearance.
        NSApp.appearance = NSAppearance(named: .darkAqua)
        defer { NSApp.appearance = nil }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configURL = directory.appendingPathComponent("config.json")
        var store = MessageStore()
        _ = store.insert(GotifyMessage(id: 12, appid: 1, title: "快捷键验收消息", message: "用于验证面板展开与收起。", priority: 5, date: Date()))
        for messageID in 1..<12 {
            _ = store.insert(GotifyMessage(id: messageID, appid: 1, title: "历史验收消息 \(messageID)",
                                          message: "用于验证关闭后重新打开时回到最新消息。", priority: 1, date: Date()))
        }
        let model = AppModel(autoStart: false, initialStore: store, configURL: configURL)
        let registrar = SmokeRegistrar()
        let controller = MenuBarController(model: model, registrar: registrar)
        defer { controller.stop() }
        try await settle()

        registrar.onPress?(.togglePanel)
        try await settle()
        try check(controller.popover.isShown, "Panel did not open")
        try check(controller.popover.contentSize.width == 360, "Incorrect single-column width")
        try snapshot(controller.popover.contentViewController!.view, name: "panel-single")
        try await scrollToOlderMessages(controller)
        registrar.onPress?(.togglePanel)
        try await settle()
        try check(!controller.popover.isShown, "Shortcut did not hide panel")
        controller.item.button?.performClick(nil)
        try await settle()
        try check(controller.popover.isShown, "Mouse did not reopen panel")
        let mouseReopenedList = try messageScrollView(controller)
        try check(abs(distanceFromTop(mouseReopenedList)) < 1, "Mouse reopening did not show the newest message")
        model.selectedMessageID = 12
        try await settle()
        try check(controller.popover.contentSize.width == 641, "Incorrect expanded width")
        try snapshot(controller.popover.contentViewController!.view, name: "panel-expanded")
        try await scrollToOlderMessages(controller)

        controller.item.button?.performClick(nil)
        try await settle()
        try check(!controller.popover.isShown, "Mouse did not hide panel")
        try check(model.selectedMessageID == nil, "Selection was not reset")
        registrar.onPress?(.markAllRead)
        try check(!model.hasUnread, "Mark-all-read did not clear unread state")
        try check(!controller.popover.isShown, "Mark-all-read unexpectedly opened panel")
        try check(AppConfig.load(from: configURL).lastReadMessageID == 12, "Watermark was not persisted")
        registrar.onPress?(.togglePanel)
        try await settle()
        try check(controller.popover.contentSize.width == 360, "Reopened panel did not reset its width")
        let shortcutReopenedList = try messageScrollView(controller)
        try check(abs(distanceFromTop(shortcutReopenedList)) < 1, "Shortcut reopening did not show the newest message")
        controller.showSettings()
        NSApp.appearance = nil
        try await settle()
        try check(!controller.popover.isShown, "Settings did not close panel")
        try check(controller.settingsWindow?.isVisible == true, "Settings window did not open")
        try check(controller.settingsWindow!.toolbar?.items.isEmpty == false, "Settings tabs are missing")
        try snapshot(controller.settingsWindow!.contentView!.superview!, name: "settings-server")

        let shortcuts = GlobalShortcuts(registrar: registrar, save: { _ in }, perform: { _ in })
        shortcuts.start(config: .default)
        let window = controller.settingsWindow!
        window.contentViewController = NSHostingController(rootView: GeneralSettingsTab(shortcuts: shortcuts).frame(width: 440, height: 420))
        try await settle()
        try snapshot(window.contentView!, name: "settings-shortcuts")
        shortcuts.beginRecording(.togglePanel)
        try check(registrar.active.isEmpty, "Recording did not suspend hotkeys")
        shortcuts.cancelRecording()
        try check(registrar.active.count == 2, "Cancellation did not restore hotkeys")
        shortcuts.stop()
    }

    private func messageScrollView(_ controller: MenuBarController) throws -> NSScrollView {
        func scrollViews(in view: NSView) -> [NSScrollView] {
            let current = (view as? NSScrollView).map { [$0] } ?? []
            return current + view.subviews.flatMap { scrollViews(in: $0) }
        }
        let rootView = controller.popover.contentViewController!.view
        rootView.layoutSubtreeIfNeeded()
        guard let scrollView = scrollViews(in: rootView).min(by: {
            $0.convert($0.bounds, to: rootView).minX < $1.convert($1.bounds, to: rootView).minX
        }), scrollView.documentView != nil else {
            throw NSError(domain: "ShortcutUISmoke", code: 5,
                          userInfo: [NSLocalizedDescriptionKey: "Message list scroll view was not found"])
        }
        return scrollView
    }

    private func distanceFromTop(_ scrollView: NSScrollView) -> CGFloat {
        let documentView = scrollView.documentView!
        let visibleRect = scrollView.documentVisibleRect
        return documentView.isFlipped
            ? visibleRect.minY - documentView.bounds.minY
            : documentView.bounds.maxY - visibleRect.maxY
    }

    private func scrollToOlderMessages(_ controller: MenuBarController) async throws {
        let scrollView = try messageScrollView(controller)
        let documentView = scrollView.documentView!
        let clipView = scrollView.contentView
        let olderOrigin = documentView.isFlipped
            ? documentView.frame.maxY - clipView.bounds.height
            : documentView.frame.minY
        clipView.scroll(to: NSPoint(x: clipView.bounds.minX, y: olderOrigin))
        scrollView.reflectScrolledClipView(clipView)
        try await settle()
        try check(distanceFromTop(scrollView) > 1, "Message list did not scroll to older messages")
    }

    private func checkCarbonEvents() throws {
        let registrar = CarbonHotKeyRegistrar()
        defer { registrar.stop() }
        let binding = KeyboardShortcutBinding(keyCode: UInt32(kVK_F12), modifiers: KeyboardShortcutBinding.allowedModifiers)
        try registrar.register(binding, for: .togglePanel)
        var presses = 0
        registrar.onPress = { _ in presses += 1 }
        // Exercise the actual Carbon callback without synthesizing system keyboard input.
        for kind in [kEventHotKeyPressed, kEventHotKeyPressed, kEventHotKeyReleased, kEventHotKeyPressed] {
            var event: EventRef?
            try check(CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kind), 0, 0, &event) == noErr,
                      "Cannot create Carbon test event")
            guard let event else { throw ShortcutError.registration(-1) }
            defer { ReleaseEvent(event) }
            var id = EventHotKeyID(signature: 0x47544659, id: ShortcutAction.togglePanel.rawValue)
            try check(SetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                        MemoryLayout<EventHotKeyID>.size, &id) == noErr, "Cannot set Carbon event ID")
            try check(SendEventToEventTarget(event, GetApplicationEventTarget()) == noErr, "Carbon callback did not handle event")
        }
        try check(presses == 2, "Held key was dispatched more than once")
        registrar.stop()
        // Successful re-registration proves the old system registration was released.
        try registrar.register(binding, for: .togglePanel)
        print("PASS: Carbon registration, callback dispatch, repeat suppression and release")
    }

    private func snapshot(_ view: NSView, name: String) throws {
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw NSError(domain: "ShortcutUISmoke", code: 2)
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        if name.hasPrefix("panel-") {
            guard let pixel = bitmap.colorAt(x: 4, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.deviceRGB) else {
                throw NSError(domain: "ShortcutUISmoke", code: 4)
            }
            try check(pixel.alphaComponent > 0.99 && pixel.redComponent > 0.99
                      && pixel.greenComponent > 0.99 && pixel.blueComponent > 0.99,
                      "Panel background must be opaque white before screenshot compositing")
        }
        // Flatten transparent hosting-view pixels onto the native window background.
        let image = NSImage(size: view.bounds.size)
        image.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        view.bounds.fill()
        let foreground = NSImage(size: view.bounds.size)
        foreground.addRepresentation(bitmap)
        foreground.draw(in: view.bounds, from: .zero, operation: .sourceOver, fraction: 1)
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let data = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "ShortcutUISmoke", code: 3)
        }
        let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("build/shortcut-ui")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try data.write(to: output.appendingPathComponent("\(name).png"))
    }
}
