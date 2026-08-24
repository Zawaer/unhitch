#!/bin/sh
# Renders docs/settings-{light,dark}.png from the real SettingsView.
set -e
out="${1:-docs}"
build=$(mktemp -d)
# swiftc only permits top-level code in a file called main.swift.
cp Tools/RenderSettings.swift "$build/main.swift"
swiftc -o "$build/render" \
    $(ls Sources/Unhitch/*.swift | grep -v 'main.swift') \
    "$build/main.swift" \
    -framework AppKit -framework SwiftUI -framework IOBluetooth -framework IOKit \
    -framework ServiceManagement
for theme in light dark; do
    "$build/render" "$out/settings-$theme.png" "$theme"
done
rm -rf "$build"
