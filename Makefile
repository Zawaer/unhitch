APP        := Unhitch
BUNDLE     := dist/$(APP).app
CONFIG     := release
BIN        := .build/$(CONFIG)/$(APP)

.PHONY: all build app icon art run install uninstall zip cask log clean

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

## The icon is committed, so this only runs if it has been deleted.
Resources/AppIcon.icns:
	swift Tools/MakeIcon.swift Resources/AppIcon.icns

icon: Resources/AppIcon.icns

## Redraw the icon and the README figures from their generators.
art:
	swift Tools/MakeIcon.swift Resources/AppIcon.icns
	python3 Tools/make_diagrams.py
	sh Tools/render-settings.sh docs

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

## Point Casks/unhitch.rb at the latest published release.
cask:
	sh Tools/update-cask.sh

## What Unhitch has decided recently. Close the lid, open it, then run this.
log:
	@log show --predicate 'subsystem == "com.zawaer.unhitch"' --last 15m --style compact \
		| grep unhitch: || echo "No events in the last 15 minutes."

clean:
	rm -rf .build dist
