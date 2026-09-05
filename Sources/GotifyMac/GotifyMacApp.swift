import AppKit

@main
enum GotifyMacApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = MenuBarController(model: AppModel(initialConfig: AppConfig.load()))
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }
}
