APP     = build/Vieja.app
BIN     = .build/release/Vieja
INSTALL = /Applications/Vieja.app
DMG     = build/Vieja-$(VERSION).dmg

.PHONY: build app run install test clean release

build:
	swift build -c release

build/AppIcon.icns: scripts/icon.swift
	mkdir -p build && swift scripts/icon.swift build/AppIcon.png
	rm -rf build/AppIcon.iconset && mkdir build/AppIcon.iconset
	for s in 16 32 128 256 512; do \
	  sips -z $$s $$s build/AppIcon.png --out build/AppIcon.iconset/icon_$${s}x$${s}.png >/dev/null; \
	  sips -z $$((s*2)) $$((s*2)) build/AppIcon.png --out build/AppIcon.iconset/icon_$${s}x$${s}@2x.png >/dev/null; \
	done
	iconutil -c icns build/AppIcon.iconset -o $@

app: build build/AppIcon.icns
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp $(BIN) $(APP)/Contents/MacOS/Vieja
	cp build/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	cp Info.plist $(APP)/Contents/Info.plist
	codesign --force --sign - $(APP)
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f $(APP)

run: app
	pkill -x Vieja || true
	open $(APP)

install: app
	pkill -x Vieja || true
	rm -rf $(INSTALL)
	cp -R $(APP) $(INSTALL)
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f $(INSTALL)
	open $(INSTALL)

test:
	swift test

clean:
	rm -rf build .build

# make release VERSION=x.y.z — bump versions, build dmg, tag, publish GitHub release
release:
	@test -n "$(VERSION)" || (echo "usage: make release VERSION=x.y.z" && exit 1)
	@test -z "$$(git status --porcelain)" || (echo "working tree dirty" && exit 1)
	plutil -replace CFBundleShortVersionString -string $(VERSION) Info.plist
	plutil -replace CFBundleVersion -string $$(( $$(plutil -extract CFBundleVersion raw Info.plist) + 1 )) Info.plist
	$(MAKE) app
	hdiutil create -volname Vieja -srcfolder $(APP) -ov -format UDZO $(DMG)
	git commit -am "release v$(VERSION)"
	git tag v$(VERSION)
	git push && git push origin v$(VERSION)
	gh release create v$(VERSION) $(DMG) --title "v$(VERSION)" --generate-notes
