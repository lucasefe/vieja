import AppKit
import ServiceManagement
import SwiftUI
import ViejaCore

/// Settings window with toolbar tabs. Every change is saved immediately; config is re-read per URL so it is live.
///
///   General  — app: launch at login, system default browser, tracking params, config file
///   Browsers — default / option-click browser, and which browsers are shown
///   Rules    — regex → browser table
enum SettingsWindow {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let tabs = NSTabViewController()
            tabs.tabStyle = .toolbar
            tabs.canPropagateSelectedChildViewControllerTitle = false
            tabs.addTabViewItem(tab("General", symbol: "gearshape", view: GeneralView()))
            tabs.addTabViewItem(tab("Browsers", symbol: "globe", view: BrowsersView()))
            tabs.addTabViewItem(tab("Rules", symbol: "arrow.triangle.branch", view: RulesView()))
            let w = NSWindow(contentViewController: tabs)
            w.title = "Vieja Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private static func tab<V: View>(_ label: String, symbol: String, view: V) -> NSTabViewItem {
        let host = NSHostingController(rootView: view)
        host.sizingOptions = .preferredContentSize // lets the tab controller resize the window per tab
        let item = NSTabViewItem(viewController: host)
        item.label = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        return item
    }
}

// ponytail: one shared model so hiding a browser in one tab updates pickers in the others
private final class Model: ObservableObject {
    static let shared = Model()
    @Published var config = Config.load() { didSet { try? config.save() } }
    let browsers = Browsers.all(config: Config(), includeHidden: true)
    var visible: [Browser] { browsers.filter { !config.hiddenBrowsers.contains($0.id) } }
}

private let pageWidth = 560.0

// ponytail: rows are separate small structs on purpose; one big Form body blows the main-thread stack on macOS 26 SwiftUI

private struct Help: View {
    let text: String
    var body: some View { Text(text).foregroundStyle(.secondary).font(.callout) }
}

/// Picker of visible browsers + Prompt. An id not in the list (hidden or uninstalled) gets its own entry so it is not clobbered.
private struct BrowserPicker: View {
    let label: String
    let browsers: [Browser]
    @Binding var selection: String

    var body: some View {
        var options: [(String, String)] = [("prompt", "Prompt")] + browsers.map { ($0.id, $0.name) }
        if !options.contains(where: { $0.0 == selection }) { options.append((selection, selection)) }
        return Picker(label, selection: $selection) {
            ForEach(options, id: \.0) { Text($0.1).tag($0.0) }
        }
    }
}

// MARK: - General

private struct GeneralView: View {
    var body: some View {
        Form {
            LoginRow()
            DefaultBrowserRow()
            TrackingRow()
            ConfigFileRow()
        }
        .formStyle(.columns)
        .toggleStyle(.checkbox)
        .padding(20)
        .frame(width: pageWidth)
    }
}

private struct LoginRow: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled
    var body: some View {
        LabeledContent("Startup:") {
            Toggle("Launch Vieja at login", isOn: $enabled)
                .onChange(of: enabled) { _, on in
                    do {
                        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch { NSLog("vieja: login item: %@", error.localizedDescription) }
                }
        }
    }
}

private struct DefaultBrowserRow: View {
    @State private var isDefault = false
    var body: some View {
        LabeledContent("Links:") {
            HStack {
                Text(isDefault ? "Vieja is the default browser" : "Vieja is not the default browser").foregroundStyle(.secondary)
                Spacer()
                Button("Set as Default…") { setDefault() }.disabled(isDefault)
            }
        }
        .onAppear { isDefault = check() }
    }

    private func check() -> Bool {
        NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!) == Bundle.main.bundleURL
    }

    private func setDefault() {
        let me = Bundle.main.bundleURL
        NSWorkspace.shared.setDefaultApplication(at: me, toOpenURLsWithScheme: "http") { _ in
            NSWorkspace.shared.setDefaultApplication(at: me, toOpenURLsWithScheme: "https") { _ in
                DispatchQueue.main.async { isDefault = check() }
            }
        }
    }
}

private struct TrackingRow: View {
    @ObservedObject private var m = Model.shared
    var body: some View {
        LabeledContent("Tracking params:") {
            VStack(alignment: .leading, spacing: 4) {
                TextField("", text: Binding(
                    get: { m.config.extraTrackingParams.joined(separator: ", ") },
                    set: { m.config.extraTrackingParams = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }))
                Help(text: "Extra query params to strip, comma-separated. utm_* and common ad ids are always stripped.")
            }
        }
    }
}

private struct ConfigFileRow: View {
    var body: some View {
        LabeledContent("Config file:") {
            HStack {
                Text(Config.path.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                Spacer()
                Button("Edit…") { NSWorkspace.shared.open(Config.path) }
            }
        }
    }
}

// MARK: - Browsers

private struct BrowsersView: View {
    @ObservedObject private var m = Model.shared

    var body: some View {
        Form {
            BrowserPicker(label: "Open links in:", browsers: m.visible, selection: $m.config.defaultBrowser).fixedSize()
            BrowserPicker(label: "With ⌥ held:", browsers: m.visible, selection: $m.config.alternativeBrowser).fixedSize()
            LabeledContent("") {
                Help(text: "The first is used when no rule matches; option-click a link to use the second. “Prompt” shows the picker.")
            }
            ShownBrowsersRow()
        }
        .formStyle(.columns)
        .toggleStyle(.checkbox)
        .padding(20)
        .frame(width: pageWidth)
    }
}

private struct ShownBrowsersRow: View {
    @ObservedObject private var m = Model.shared
    var body: some View {
        LabeledContent("Show:") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(m.browsers, id: \.id) { b in
                    Toggle(isOn: shown(b.id)) {
                        Label { Text(b.name) } icon: { Image(nsImage: b.icon).resizable().frame(width: 18, height: 18) }
                    }
                }
                Help(text: "Unchecked browsers are hidden from the picker and the menus above.")
            }
        }
    }

    private func shown(_ id: String) -> Binding<Bool> {
        Binding(get: { !m.config.hiddenBrowsers.contains(id) },
                set: { on in
                    m.config.hiddenBrowsers.removeAll { $0 == id }
                    if !on { m.config.hiddenBrowsers.append(id) }
                })
    }
}

// MARK: - Rules

private struct RulesView: View {
    @ObservedObject private var m = Model.shared
    @State private var selected: Int?
    private struct Row: Identifiable { let id: Int }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Table(m.config.rules.indices.map(Row.init), selection: $selected) {
                TableColumn("Match (regex)") { row in MatchField(m: m, index: row.id) }
                TableColumn("Open in") { row in
                    BrowserPicker(label: "", browsers: m.visible, selection: $m.config.rules[row.id].browser)
                        .labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(height: 260)
            HStack {
                Button("+") { m.config.rules.append(Rule(match: "", browser: "prompt")); selected = m.config.rules.count - 1 }
                Button("−") { if let i = selected { m.config.rules.remove(at: i); selected = nil } }.disabled(selected == nil)
                Button("↑") { move(-1) }.disabled(selected == nil || selected == 0)
                Button("↓") { move(1) }.disabled(selected == nil || selected == m.config.rules.count - 1)
                Spacer()
            }
            Help(text: "Case-insensitive regex tested against the full URL. Checked top to bottom; first match wins. Unmatched links use the default from the Browsers tab.")
        }
        .padding(20)
        .frame(width: pageWidth)
    }

    private func move(_ delta: Int) {
        guard let i = selected else { return }
        m.config.rules.swapAt(i, i + delta)
        selected = i + delta
    }
}

private struct MatchField: View {
    @ObservedObject var m: Model
    let index: Int
    var body: some View {
        TextField("", text: $m.config.rules[index].match)
            .foregroundStyle((try? NSRegularExpression(pattern: m.config.rules[index].match)) == nil ? Color.red : Color.primary)
    }
}
