APP     = build/Vieja.app
BIN     = .build/release/Vieja
INSTALL = /Applications/Vieja.app

.PHONY: build app run install test clean

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
