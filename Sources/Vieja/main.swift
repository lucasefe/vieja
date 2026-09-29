import AppKit
import ViejaCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = Config.load() // writes a template on first run
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "Vieja")
        statusItem.menu = NSMenu()
        statusItem.menu?.delegate = self
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

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let config = Config.load()
        for b in Browsers.all(config: config) {
            let item = NSMenuItem(title: b.name, action: #selector(setDefault(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = b.id
            item.image = b.icon
            item.image?.size = NSSize(width: 16, height: 16)
            item.state = b.id == config.defaultBrowser ? .on : .off
            menu.addItem(item)
        }
        let prompt = NSMenuItem(title: "Prompt", action: #selector(setDefault(_:)), keyEquivalent: "")
        prompt.target = self
        prompt.representedObject = "prompt"
        prompt.state = config.defaultBrowser == "prompt" ? .on : .off
        menu.addItem(prompt)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Open URL from Clipboard", action: #selector(openClipboard), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Edit Config…", action: #selector(editConfig), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Set Vieja as Default Browser", action: #selector(makeSystemDefault), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Vieja", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc private func setDefault(_ sender: NSMenuItem) {
        var config = Config.load()
        config.defaultBrowser = sender.representedObject as! String
        try? config.save()
    }

    @objc private func openClipboard() {
        guard let s = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: s), url.scheme?.hasPrefix("http") == true else { NSSound.beep(); return }
        handle(url, optionHeld: NSEvent.modifierFlags.contains(.option))
    }

    @objc private func editConfig() {
        _ = Config.load()
        NSWorkspace.shared.open(Config.path)
    }

    @objc private func makeSystemDefault() {
        let me = Bundle.main.bundleURL
        NSWorkspace.shared.setDefaultApplication(at: me, toOpenURLsWithScheme: "http") { _ in
            NSWorkspace.shared.setDefaultApplication(at: me, toOpenURLsWithScheme: "https")
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
