# Vieja

Minimal Velja clone: macOS menu-bar app that registers as the default browser and routes http/https URLs to a real browser by regex rules. Personal use, AppKit only, no Xcode project.

## Layout

```
Package.swift                      SwiftPM, macOS 14+, two targets + tests
Info.plist                         LSUIElement, CFBundleURLTypes http/https
Makefile                           build / app / run / install / test
Sources/ViejaCore/Config.swift     Codable config, ~/.config/vieja/config.json
Sources/ViejaCore/Router.swift     pure: stripTracking(), resolve() -> Target
Sources/Vieja/main.swift           AppDelegate: URL handler, status item menu
Sources/Vieja/Browsers.swift       discover browsers via NSWorkspace, open URL in bundle id
Sources/Vieja/Prompt.swift         NSPanel picker, 1-9 keys, Esc, Cmd+C
Tests/ViejaCoreTests/              XCTest for Router only
```

`ViejaCore` has no AppKit import so it is testable with `swift test`. Keep UI/NSWorkspace code in `Sources/Vieja`.

## Commands

```
make test       swift test
make run        build release, assemble build/Vieja.app, ad-hoc sign, lsregister, relaunch
make install    same, but into /Applications
```

Smoke test without changing the system default browser:

```
open -a "$PWD/build/Vieja.app" "https://example.com/?utm_source=x"
```

Logs: `NSLog("vieja: ...")`, read with `/usr/bin/log stream --predicate 'process == "Vieja"'`.

## Config

`~/.config/vieja/config.json`, re-read on every URL (no watcher). Written with a template on first run. Menu bar browser switch writes it back (pretty, sorted keys).

```json
{
  "defaultBrowser": "<bundle id> | prompt",
  "alternativeBrowser": "<bundle id> | prompt",   // used when Option is held
  "hiddenBrowsers": ["<bundle id>"],
  "extraTrackingParams": ["<query param>"],
  "rules": [{ "match": "<regex on full URL, case-insensitive>", "browser": "<bundle id> | prompt" }]
}
```

Rules are checked in order, first match wins. Browser profiles that ship as their own `.app` (e.g. Orion `~/Applications/Orion/Orion Profiles/*/*.app`) appear automatically as separate browsers with their own bundle id. No profile-specific code.

## Conventions

- Ponytail mode: shortest working diff, stdlib/AppKit first, no new dependencies, no abstractions with one implementation.
- Mark deliberate shortcuts with `// ponytail:` naming the ceiling and upgrade path.
- Non-trivial logic in `ViejaCore` gets one XCTest. UI code is verified by `make run` + a smoke `open -a`.
- Do not add: settings UI, source-app rules, short URL expansion, Chrome `--profile-directory`, custom URL scheme, history/log window. Add only when a concrete misroute demands it.
- Commit only when asked.
