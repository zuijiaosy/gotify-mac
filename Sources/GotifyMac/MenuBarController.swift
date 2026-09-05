import AppKit
import SwiftUI
import Observation

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate, NSWindowDelegate {
    private let model: AppModel
    let item: NSStatusItem
    let popover = NSPopover()
    private(set) var settingsWindow: NSWindow?
    private var shortcuts: GlobalShortcuts!
    private var stopped = false

    init(model: AppModel, registrar: any HotKeyRegistering = CarbonHotKeyRegistrar()) {
        self.model = model
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        shortcuts = GlobalShortcuts(registrar: registrar, save: { [model] bindings in
            try model.saveShortcuts(bindings)
        }, perform: { [weak self] action in
            guard let self else { return }
            switch action {
            case .togglePanel: self.togglePanel()
            case .markAllRead: self.model.markAllRead()
            }
        })
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        item.button?.toolTip = "Gotify Mac"
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: PanelView(
            model: model,
            showSettings: { [weak self] in self?.showSettings() },
            resize: { [weak self] expanded in self?.resizePanel(expanded: expanded) }
        ))
        resizePanel(expanded: false)
        observeUnread()
        // Load bindings synchronously so they work before the first panel opening.
        shortcuts.start(config: model.config)
        installMainMenu()
    }

    private func installMainMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        let settings = appMenu.addItem(withTitle: "设置…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 Gotify Mac", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem()
        menu.addItem(editItem)
        let editMenu = NSMenu(title: "编辑")
        editItem.submenu = editMenu
        for (title, selector, key) in [("撤销", "undo:", "z"), ("重做", "redo:", "Z"),
                                       ("剪切", "cut:", "x"), ("复制", "copy:", "c"),
                                       ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: NSSelectorFromString(selector), keyEquivalent: key)
        }
        NSApp.mainMenu = menu
    }

    private func observeUnread() {
        guard !stopped else { return }
        withObservationTracking {
            let image = NSImage(systemSymbolName: model.hasUnread ? "bell.badge" : "bell",
                                accessibilityDescription: "Gotify Mac")
            image?.isTemplate = true
            item.button?.image = image
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeUnread() }
        }
    }

    @objc func togglePanel() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = item.button {
            model.selectedMessageID = nil
            resizePanel(expanded: false)
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func resizePanel(expanded: Bool) {
        popover.contentSize = NSSize(width: expanded ? 641 : 360, height: 480)
    }

    func popoverDidClose(_ notification: Notification) {
        model.selectedMessageID = nil
        resizePanel(expanded: false)
    }

    @objc func showSettings() {
        popover.performClose(nil)
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 420),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Gotify Mac 设置"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentViewController = NSHostingController(rootView: SettingsView(model: model, shortcuts: shortcuts))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func windowDidResignKey(_ notification: Notification) { shortcuts.cancelRecording() }
    func windowWillClose(_ notification: Notification) { shortcuts.cancelRecording() }

    func stop() {
        stopped = true
        shortcuts.stop()
        popover.performClose(nil)
        settingsWindow?.close()
        NSStatusBar.system.removeStatusItem(item)
    }
}
