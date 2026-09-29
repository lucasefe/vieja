import AppKit

/// Floating browser picker. Click an icon or press 1-9. Esc closes. Cmd+C copies the URL.
final class Prompt: NSPanel, NSWindowDelegate {
    private static var current: Prompt?
    private let url: URL
    private let browsers: [Browser]

    static func show(_ url: URL, browsers: [Browser]) {
        current?.close()
        let p = Prompt(url: url, browsers: browsers)
        current = p
        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
    }

    private init(url: URL, browsers: [Browser]) {
        self.url = url
        self.browsers = browsers
        super.init(contentRect: .zero, styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        level = .floating
        delegate = self

        let buttons = browsers.prefix(9).enumerated().map { i, b -> NSButton in
            let btn = NSButton(title: "\(i + 1)  \(b.name)", image: b.icon, target: self, action: #selector(pick(_:)))
            btn.tag = i
            btn.isBordered = false
            btn.imagePosition = .imageAbove
            btn.imageScaling = .scaleProportionallyUpOrDown
            btn.image?.size = NSSize(width: 64, height: 64)
            btn.font = .systemFont(ofSize: 11)
            btn.keyEquivalent = "\(i + 1)"
            btn.keyEquivalentModifierMask = []
            btn.widthAnchor.constraint(equalToConstant: 96).isActive = true
            return btn
        }
        let row = NSStackView(views: buttons)
        row.spacing = 4

        let label = NSTextField(labelWithString: url.host ?? url.absoluteString)
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 11)
        label.lineBreakMode = .byTruncatingMiddle
        label.alignment = .center

        let col = NSStackView(views: [row, label])
        col.orientation = .vertical
        col.spacing = 8
        col.edgeInsets = NSEdgeInsets(top: 24, left: 16, bottom: 12, right: 16)
        contentView = col
        setContentSize(col.fittingSize)

        // center on the screen that has the mouse
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let f = screen?.visibleFrame {
            setFrameOrigin(NSPoint(x: f.midX - frame.width / 2, y: f.midY - frame.height / 2))
        }
    }

    override var canBecomeKey: Bool { true }

    @objc private func pick(_ sender: NSButton) {
        Browsers.open(url, in: browsers[sender.tag].id)
        close()
    }

    override func cancelOperation(_ sender: Any?) { close() }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "c" {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.absoluteString, forType: .string)
            close()
        } else {
            super.keyDown(with: event)
        }
    }

    func windowDidResignKey(_ notification: Notification) { close() }
    override func close() { super.close(); if Prompt.current === self { Prompt.current = nil } }
}
