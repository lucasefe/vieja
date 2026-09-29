import Foundation

public struct Rule: Codable, Equatable {
    public var match: String   // regex, tested against the full URL string
    public var browser: String // bundle id, or "prompt"
    public init(match: String, browser: String) { self.match = match; self.browser = browser }
}

public struct Config: Codable, Equatable {
    public var defaultBrowser: String = "com.apple.Safari"
    public var alternativeBrowser: String = "prompt"
    public var hiddenBrowsers: [String] = []
    public var extraTrackingParams: [String] = []
    public var rules: [Rule] = []

    public init() {}

    public static let path = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/vieja/config.json")

    public static func load() -> Config {
        if let data = try? Data(contentsOf: path),
           let cfg = try? JSONDecoder().decode(Config.self, from: data) {
            return cfg
        }
        let cfg = Config()
        try? cfg.save() // first run: write a template the user can edit
        return cfg
    }

    public func save() throws {
        try FileManager.default.createDirectory(
            at: Self.path.deletingLastPathComponent(), withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try enc.encode(self).write(to: Self.path)
    }
}
