import Cocoa

enum MenuBarApp {
    @MainActor
    static func run() {
        // GUI stdout is usually a pipe (open, launchd, drives); line-buffer it so
        // the log is not lost when the app is killed rather than exited.
        setvbuf(stdout, nil, _IOLBF, 0)

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = MenuBarAppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class MenuBarAppDelegate: NSObject, NSApplicationDelegate {
    private var preferences = Preferences.load()
    private lazy var controller = NotchController(preferences: preferences)
    private let monitor = WallpaperMonitor()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        LoginItem.registerOnFirstRun(&preferences)
        buildMenu()

        monitor.onObservedChange = { [weak controller] id, ref in
            controller?.observed(ref, on: id)
        }
        monitor.onDisplaysChanged = { [weak controller] in
            controller?.displaysChanged()
        }
        // Converge before the monitor's first poll, so the launch apply is the
        // only write and the poll just records the baseline. A poll-driven
        // reconcile racing the launch reconcile can re-apply against a stale
        // desktopImageURL read.
        controller.reconcileAll()
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    private func buildMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        item.button?.image = statusIcon()

        let row = NotchRow(frame: .zero)
        row.setIntent(controller.intent)
        row.onToggle = { [weak controller] intent in
            controller?.toggle(to: intent)
        }

        let rowItem = NSMenuItem()
        rowItem.view = row

        let exitItem = NSMenuItem(title: "Exit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        exitItem.target = NSApplication.shared

        let menu = NSMenu()
        menu.addItem(rowItem)
        menu.addItem(.separator())
        menu.addItem(exitItem)
        item.menu = menu
    }

    private func statusIcon() -> NSImage {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png"), let icon = NSImage(contentsOf: url) {
            // The icon carries its own transparent margins, so go larger than the
            // usual 16pt to keep the visible artwork at a normal status-icon size.
            icon.size = NSSize(width: 20, height: 20)
            NSApp.applicationIconImage = icon
            return icon
        }
        if #available(macOS 11, *), let symbol = NSImage(systemSymbolName: "menubar.arrow.up.rectangle", accessibilityDescription: "Notch") {
            return symbol
        }
        return Self.drawnFallbackIcon()
    }

    private static func drawnFallbackIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        NSColor.black.setFill()
        NSBezierPath(roundedRect: NSRect(x: 2, y: 12, width: 14, height: 4), xRadius: 1, yRadius: 1).fill()
        NSBezierPath(roundedRect: NSRect(x: 5, y: 3, width: 8, height: 7), xRadius: 1, yRadius: 1).fill()
        image.unlockFocus()
        return image
    }
}
