APP        := Clamshell
BUNDLE     := dist/$(APP).app
CONFIG     := release
BIN        := .build/$(CONFIG)/$(APP)

.PHONY: all build app icon run install uninstall zip clean

all: app

build:
	swift build -c $(CONFIG)

## Assemble a real .app bundle. SwiftPM only emits a bare executable, and a menu
## bar app needs Info.plist (LSUIElement) plus a bundle identifier for login items.
app: build icon
	rm -rf "$(BUNDLE)"
	mkdir -p "$(BUNDLE)/Contents/MacOS" "$(BUNDLE)/Contents/Resources"
	cp "$(BIN)" "$(BUNDLE)/Contents/MacOS/$(APP)"
	cp Resources/Info.plist "$(BUNDLE)/Contents/Info.plist"
	cp Resources/AppIcon.icns "$(BUNDLE)/Contents/Resources/AppIcon.icns"
	printf 'APPL????' > "$(BUNDLE)/Contents/PkgInfo"
	codesign --force --deep --sign - "$(BUNDLE)"
	@echo "Built $(BUNDLE)"

Resources/AppIcon.icns:
	swift Tools/MakeIcon.swift Resources/AppIcon.icns

icon: Resources/AppIcon.icns

run: app
	pkill -x $(APP) || true
	open "$(BUNDLE)"

install: app
	pkill -x $(APP) || true
	rm -rf "/Applications/$(APP).app"
	cp -R "$(BUNDLE)" /Applications/
	open "/Applications/$(APP).app"
	@echo "Installed to /Applications/$(APP).app"

uninstall:
	pkill -x $(APP) || true
	rm -rf "/Applications/$(APP).app"

zip: app
	cd dist && zip -qry "$(APP).zip" "$(APP).app"
	@echo "Packaged dist/$(APP).zip"

clean:
	rm -rf .build dist Resources/AppIcon.icns
