import AppKit
import ServiceManagement
import SwiftUI
import ViejaCore

/// Settings window. Every change is saved immediately; config is re-read per URL so it is live.
enum SettingsWindow {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "Vieja Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct SettingsView: View {
    @State private var config = Config.load()
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    @State private var selectedRule: Int?
    private let browsers = Browsers.all(config: Config(), includeHidden: true)

    var body: some View {
        Form {
            Section {
                browserPicker("Default browser", $config.defaultBrowser)
                browserPicker("Option-click browser", $config.alternativeBrowser)
                Toggle("Launch at login", isOn: $loginEnabled)
                    .onChange(of: loginEnabled) { _, on in setLogin(on) }
            }

            Section("Rules — first match wins") {
                rulesTable
                rulesButtons
            }

            browsersSection
            trackingSection

            Section {
                HStack {
                    Button("Set Vieja as Default Browser") {
                        let me = Bundle.main.bundleURL
                        NSWorkspace.shared.setDefaultApplication(at: me, toOpenURLsWithScheme: "http") { _ in
                            NSWorkspace.shared.setDefaultApplication(at: me, toOpenURLsWithScheme: "https")
                        }
                    }
                    Spacer()
                    Button("Edit config.json…") { NSWorkspace.shared.open(Config.path) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 640)
        .onChange(of: config) { _, c in try? c.save() }
    }

    private struct Row: Identifiable { let id: Int }

    private var rulesTable: some View {
        Table(config.rules.indices.map(Row.init), selection: $selectedRule) {
            TableColumn("Match (regex)") { row in matchField(row.id) }
            TableColumn("Browser") { row in browserPicker("", $config.rules[row.id].browser) }
        }
        .frame(minHeight: 160)
    }

    private func matchField(_ i: Int) -> some View {
        TextField("", text: $config.rules[i].match)
            .foregroundStyle(validRegex(config.rules[i].match) ? Color.primary : Color.red)
    }

    private var rulesButtons: some View {
                HStack {
                    Button("+") { config.rules.append(Rule(match: "", browser: "prompt")); selectedRule = config.rules.count - 1 }
                    Button("−") { if let i = selectedRule { config.rules.remove(at: i); selectedRule = nil } }
                        .disabled(selectedRule == nil)
                    Button("↑") { move(-1) }.disabled(selectedRule == nil || selectedRule == 0)
                    Button("↓") { move(1) }.disabled(selectedRule == nil || selectedRule == config.rules.count - 1)
                }
    }

    private var browsersSection: some View {
            Section("Browsers shown in picker and menu") {
                ForEach(browsers, id: \.id) { b in
                    Toggle(isOn: Binding(
                        get: { !config.hiddenBrowsers.contains(b.id) },
                        set: { shown in
                            config.hiddenBrowsers.removeAll { $0 == b.id }
                            if !shown { config.hiddenBrowsers.append(b.id) }
                        })) {
                        Label { Text(b.name) } icon: { Image(nsImage: b.icon).resizable().frame(width: 16, height: 16) }
                    }
                }
            }
    }

    private var trackingSection: some View {
            Section {
                TextField("Extra tracking params (comma-separated)", text: Binding(
                    get: { config.extraTrackingParams.joined(separator: ", ") },
                    set: { config.extraTrackingParams = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }))
            }
    }

    private func browserPicker(_ label: String, _ sel: Binding<String>) -> some View {
        // ponytail: unknown ids (uninstalled browser) get their own entry so the picker doesn't clobber them
        var options: [(String, String)] = [("prompt", "Prompt")] + browsers.map { ($0.id, $0.name) }
        if !options.contains(where: { $0.0 == sel.wrappedValue }) { options.append((sel.wrappedValue, sel.wrappedValue)) }
        return Picker(label, selection: sel) {
            ForEach(options, id: \.0) { Text($0.1).tag($0.0) }
        }
    }

    private func setLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch { NSLog("vieja: login item: %@", error.localizedDescription) }
    }

    private func move(_ delta: Int) {
        guard let i = selectedRule else { return }
        config.rules.swapAt(i, i + delta)
        selectedRule = i + delta
    }

    private func validRegex(_ s: String) -> Bool { (try? NSRegularExpression(pattern: s)) != nil }
}
