import AppKit
import ViejaCore

struct Browser {
    let id: String
    let url: URL
    var name: String { FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "") }
    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }
}

enum Browsers {
    static func all(config: Config, includeHidden: Bool = false) -> [Browser] {
        let me = Bundle.main.bundleIdentifier
        let hidden = includeHidden ? [] : Set(config.hiddenBrowsers)
        var seen = Set<String>()
        return NSWorkspace.shared.urlsForApplications(toOpen: URL(string: "https://example.com")!)
            .compactMap { u -> Browser? in
                guard let id = Bundle(url: u)?.bundleIdentifier, id != me, !hidden.contains(id),
                      seen.insert(id).inserted else { return nil }
                return Browser(id: id, url: u)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Opens `url` in the app with `bundleID`. Returns false if the app is not installed.
    @discardableResult
    static func open(_ url: URL, in bundleID: String) -> Bool {
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return false }
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration()) { _, err in
            if let err { NSLog("vieja: open failed: %@", err.localizedDescription) }
        }
        return true
    }
}
