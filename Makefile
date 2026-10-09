APP     = build/Vieja.app
BIN     = .build/release/Vieja
INSTALL = /Applications/Vieja.app
DMG     = build/Vieja-$(VERSION).dmg

.PHONY: build app run install test clean release

build:
	swift build -c release

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp $(BIN) $(APP)/Contents/MacOS/Vieja
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
	git push --follow-tags
	gh release create v$(VERSION) $(DMG) --title "v$(VERSION)" --generate-notes
