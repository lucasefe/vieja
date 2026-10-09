import AppKit
import ServiceManagement
import SwiftUI
import ViejaCore

/// Settings window: toolbar tabs (General, Rules). Every change is saved immediately; config is re-read per URL.
enum SettingsWindow {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let tabs = NSTabViewController()
            tabs.tabStyle = .toolbar
            tabs.canPropagateSelectedChildViewControllerTitle = false
            tabs.addTabViewItem(tab("General", symbol: "gearshape", view: GeneralView()))
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

private final class Model: ObservableObject {
    @Published var config = Config.load() { didSet { try? config.save() } }
    let browsers = Browsers.all(config: Config(), includeHidden: true)
}

/// Picker of installed browsers + Prompt. Unknown ids (uninstalled browser) get their own entry so they are not clobbered.
private func browserPicker(_ label: String, browsers: [Browser], _ sel: Binding<String>) -> some View {
    var options: [(String, String)] = [("prompt", "Prompt")] + browsers.map { ($0.id, $0.name) }
    if !options.contains(where: { $0.0 == sel.wrappedValue }) { options.append((sel.wrappedValue, sel.wrappedValue)) }
    return Picker(label, selection: sel) {
        ForEach(options, id: \.0) { Text($0.1).tag($0.0) }
    }
    .fixedSize()
}

private struct GeneralView: View {
    @StateObject private var m = Model()
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            browserPicker("Default browser:", browsers: m.browsers, $m.config.defaultBrowser)
            browserPicker("Option-click:", browsers: m.browsers, $m.config.alternativeBrowser)

            LabeledContent("General:") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Launch Vieja at login", isOn: $loginEnabled)
                        .onChange(of: loginEnabled) { _, on in setLogin(on) }
                    HStack {
                        Text("Vieja handles http/https links").foregroundStyle(.secondary)
                        Spacer()
                        Button("Set as Default Browser…") { makeSystemDefault() }
                    }
                }
            }

            LabeledContent("Browsers:") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(m.browsers, id: \.id) { b in
                        Toggle(isOn: shown(b.id)) {
                            Label { Text(b.name) } icon: { Image(nsImage: b.icon).resizable().frame(width: 16, height: 16) }
                        }
                    }
                    Text("Unchecked browsers are hidden from the picker.").foregroundStyle(.secondary).font(.callout)
                }
            }

            LabeledContent("Tracking params:") {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("", text: Binding(
                        get: { m.config.extraTrackingParams.joined(separator: ", ") },
                        set: { m.config.extraTrackingParams = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }))
                    Text("Stripped from URLs, in addition to utm_* and common ad ids. Comma-separated.")
                        .foregroundStyle(.secondary).font(.callout).fixedSize(horizontal: false, vertical: true)
                }
            }

            LabeledContent("Config file:") {
                HStack {
                    Text(Config.path.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Edit…") { NSWorkspace.shared.open(Config.path) }
                }
            }
        }
        .formStyle(.columns)
        .toggleStyle(.checkbox)
        .padding(20)
        .frame(width: 560)
    }

    private func shown(_ id: String) -> Binding<Bool> {
        Binding(get: { !m.config.hiddenBrowsers.contains(id) },
                set: { on in
                    m.config.hiddenBrowsers.removeAll { $0 == id }
                    if !on { m.config.hiddenBrowsers.append(id) }
                })
    }

    private func setLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch { NSLog("vieja: login item: %@", error.localizedDescription) }
    }

    private func makeSystemDefault() {
        let me = Bundle.main.bundleURL
        NSWorkspace.shared.setDefaultApplication(at: me, toOpenURLsWithScheme: "http") { _ in
            NSWorkspace.shared.setDefaultApplication(at: me, toOpenURLsWithScheme: "https")
        }
    }
}

private struct RulesView: View {
    @StateObject private var m = Model()
    @State private var selected: Int?
    private struct Row: Identifiable { let id: Int }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Table(m.config.rules.indices.map(Row.init), selection: $selected) {
                TableColumn("Match (regex)") { row in matchField(row.id) }
                TableColumn("Open in") { row in browserPicker("", browsers: m.browsers, $m.config.rules[row.id].browser).labelsHidden().frame(maxWidth: .infinity, alignment: .leading) }
            }
            .frame(height: 260)
            HStack {
                Button("+") { m.config.rules.append(Rule(match: "", browser: "prompt")); selected = m.config.rules.count - 1 }
                Button("−") { if let i = selected { m.config.rules.remove(at: i); selected = nil } }.disabled(selected == nil)
                Button("↑") { move(-1) }.disabled(selected == nil || selected == 0)
                Button("↓") { move(1) }.disabled(selected == nil || selected == m.config.rules.count - 1)
                Spacer()
            }
            Text("Case-insensitive regex tested against the full URL. Rules are checked top to bottom; first match wins. Unmatched links go to the default browser.")
                .foregroundStyle(.secondary).font(.callout)
        }
        .padding(20)
        .frame(width: 560)
    }

    private func matchField(_ i: Int) -> some View {
        TextField("", text: $m.config.rules[i].match)
            .foregroundStyle((try? NSRegularExpression(pattern: m.config.rules[i].match)) == nil ? Color.red : Color.primary)
    }

    private func move(_ delta: Int) {
        guard let i = selected else { return }
        m.config.rules.swapAt(i, i + delta)
        selected = i + delta
    }
}
