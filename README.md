# Vieja

A macOS menu-bar app that registers as the default browser and routes `http`/`https` links to a real browser by regex rules, or shows a picker.

Personal use. AppKit only, SwiftPM, no Xcode project, no dependencies.

## Install

Grab the latest `.dmg` from [Releases](https://github.com/lucasefe/vieja/releases) and drag Vieja to Applications. The app is ad-hoc signed, so on first launch right-click → Open (or `xattr -d com.apple.quarantine /Applications/Vieja.app`).

Or from source:

```
make install          # builds, assembles /Applications/Vieja.app, launches it
```

Then click the menu-bar icon → **Set Vieja as Default Browser**.

Other targets: `make run` (build into `build/Vieja.app` and launch), `make test`, `make clean`.

## Release

```
make release VERSION=0.2.0    # bumps Info.plist, builds dmg, tags, pushes, publishes GitHub release
```

## Usage

- Click a link anywhere → Vieja routes it by the rules below.
- Hold **Option** while clicking → uses `alternativeBrowser` instead.
- Picker: click an icon or press **1–9**. **Esc** closes, **Cmd+C** copies the URL.
- Menu bar: switch the default browser, open a URL from the clipboard, edit config.

Tracking params (`utm_*`, `fbclid`, `gclid`, … plus `extraTrackingParams`) are stripped before routing.

## Config

`~/.config/vieja/config.json`, created with a template on first run and re-read on every URL.

```json
{
  "defaultBrowser": "com.apple.Safari",
  "alternativeBrowser": "prompt",
  "hiddenBrowsers": ["org.chromium.Chromium"],
  "extraTrackingParams": ["ref"],
  "rules": [
    { "match": "github\\.com", "browser": "com.kagi.kagimacOS.158125DC-386B-4EF8-AE20-E2077DA7C533" },
    { "match": "(youtube\\.com|youtu\\.be)", "browser": "com.kagi.kagimacOS.Defaults" }
  ]
}
```

- `browser` is a bundle id or `"prompt"`.
- `match` is a case-insensitive regex tested against the full URL. Rules are checked in order; first match wins.
- Browsers are discovered via Launch Services (anything registered for `https`). Find a bundle id with `osascript -e 'id of app "Safari"'`.

## Browser profiles (Orion)

Orion ships each non-default profile as its own `.app` under `~/Applications/Orion/Orion Profiles/<id>/`, with a unique bundle id, so they show up in Vieja as separate browsers automatically.

The **Default** profile has no such app, and sending a URL to plain `Orion.app` lands in whatever profile Orion last used. To route to it deterministically, make a stub by hand:

```
SRC=~/Applications/Orion/Orion\ Profiles/<work-id>/Orion\ -\ Work.app
DST=~/Applications/Orion/Orion\ Profiles/Defaults/Orion\ -\ Personal.app
cp -R "$SRC" "$DST"
printf '#!/bin/bash\n\nexec arch -arm64 "/Applications/Orion.app/Contents/MacOS/Orion" -P Defaults\n' > "$DST/Contents/MacOS/Orion"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.kagi.kagimacOS.Defaults' -c 'Set :CFBundleName Personal' "$DST/Contents/Info.plist"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DST"
```

Then add `"com.kagi.kagimacOS"` to `hiddenBrowsers` so the ambiguous bare "Orion" entry disappears. Orion does not accept a URL on argv, so the stub must go through Launch Services; this is why Vieja has no profile-specific code.

## Debugging

```
open -a "$PWD/build/Vieja.app" "https://example.com/?utm_source=x"    # route without changing the system default
/usr/bin/log stream --predicate 'process == "Vieja"'                     # vieja: <url> -> <target>
```
