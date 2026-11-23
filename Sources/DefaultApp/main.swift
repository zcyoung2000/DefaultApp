import AppKit

let appDelegate = AppDelegate()

@main
struct DefaultApp {
    static func main() {
        let app = NSApplication.shared
        app.delegate = appDelegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 固定 Aqua，避免继承父进程外观导致首帧闪色。
        NSApp.appearance = NSAppearance(named: .aqua)
        windowController = MainWindowController()
        windowController?.show()
        NSApp.activate(ignoringOtherApps: true)

    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
