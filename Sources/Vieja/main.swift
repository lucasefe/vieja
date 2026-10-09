import AppKit
import ViejaCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = Config.load() // writes a template on first run
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "Vieja")
        let menu = NSMenu()
        menu.addItem(withTitle: "Open URL from Clipboard", action: #selector(openClipboard), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Vieja", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        if ProcessInfo.processInfo.environment["VIEJA_SETTINGS"] != nil { SettingsWindow.show() } // dev: open settings on launch
    }

    // MARK: URL handling

    func application(_ application: NSApplication, open urls: [URL]) {
        let optionHeld = NSEvent.modifierFlags.contains(.option)
        for url in urls { handle(url, optionHeld: optionHeld) }
    }

    private func handle(_ raw: URL, optionHeld: Bool) {
        let config = Config.load()
        let url = Router.stripTracking(raw, extra: config.extraTrackingParams)
        let target = Router.resolve(url, optionHeld: optionHeld, config: config)
        NSLog("vieja: %@ -> %@ (option=%d)", url.absoluteString, String(describing: target), optionHeld ? 1 : 0)
        switch target {
        case .app(let id):
            if !Browsers.open(url, in: id) { Prompt.show(url, browsers: Browsers.all(config: config)) }
        case .prompt:
            Prompt.show(url, browsers: Browsers.all(config: config))
        }
    }

    // MARK: Menu

    @objc private func openClipboard() {
        guard let s = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: s), url.scheme?.hasPrefix("http") == true else { NSSound.beep(); return }
        handle(url, optionHeld: NSEvent.modifierFlags.contains(.option))
    }

    @objc private func showSettings() { SettingsWindow.show() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
