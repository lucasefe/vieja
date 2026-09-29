import XCTest
@testable import ViejaCore

final class RouterTests: XCTestCase {
    func testStripTracking() {
        let u = URL(string: "https://foo.com/a?x=1&utm_source=z&fbclid=abc&custom=2")!
        XCTAssertEqual(Router.stripTracking(u).absoluteString, "https://foo.com/a?x=1&custom=2")
        XCTAssertEqual(Router.stripTracking(u, extra: ["custom"]).absoluteString, "https://foo.com/a?x=1")
        let clean = URL(string: "https://foo.com/a?utm_x=1")!
        XCTAssertEqual(Router.stripTracking(clean).absoluteString, "https://foo.com/a")
        let none = URL(string: "https://foo.com/a")!
        XCTAssertEqual(Router.stripTracking(none), none)
    }

    func testResolve() {
        var cfg = Config()
        cfg.defaultBrowser = "default"
        cfg.alternativeBrowser = "prompt"
        cfg.rules = [
            Rule(match: "meet\\.google\\.com", browser: "chrome"),
            Rule(match: "slack\\.com", browser: "prompt"),
        ]
        let meet = URL(string: "https://MEET.google.com/abc")!
        XCTAssertEqual(Router.resolve(meet, optionHeld: false, config: cfg), .app("chrome"))
        XCTAssertEqual(Router.resolve(meet, optionHeld: true, config: cfg), .prompt)
        XCTAssertEqual(Router.resolve(URL(string: "https://x.slack.com")!, optionHeld: false, config: cfg), .prompt)
        XCTAssertEqual(Router.resolve(URL(string: "https://other.com")!, optionHeld: false, config: cfg), .app("default"))
    }
}
