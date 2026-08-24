//
// Renders the settings window's contents straight out of SettingsView, offscreen,
// so the README figure is the real view and not a drawing of it. Sample device
// names stand in for whatever happens to be paired to the machine building it.
//
// Built and run by Tools/render-settings.sh.
//

import AppKit
import SwiftUI

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "settings.png"
let wantsDark = CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "dark"

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
// Set explicitly rather than by changing the machine's appearance, which would be a
// rude thing for a build script to do and does not reliably apply to a new process.
app.appearance = NSAppearance(named: wantsDark ? .darkAqua : .aqua)

if let icon = NSImage(contentsOfFile: "Resources/AppIcon.icns") {
    app.applicationIconImage = icon
}

// The renderer is a bare executable, not the app bundle, so it does not inherit
// the app's defaults. Register them and show the state a new user actually sees.
Preferences.registerDefaults()
Preferences.enabled = true
Preferences.disconnectOnLidClose = true
Preferences.disconnectOnSystemSleep = true
Preferences.reconnectOnWake = false
Preferences.showMenuBarIcon = true
Preferences.watchedDevices = []

let model = AppModel(bluetooth: BluetoothManager())
model.usesSampleDevices = true
model.devices = [
    PairedDevice(name: "WH-1000XM4", address: "00-00-00-00-00-01", isConnected: true, isAudio: true),
    PairedDevice(name: "Jabra Elite 8 Active", address: "00-00-00-00-00-02", isConnected: false, isAudio: true),
    PairedDevice(name: "Magic Keyboard", address: "00-00-00-00-00-03", isConnected: true, isAudio: false),
    PairedDevice(name: "Magic Trackpad", address: "00-00-00-00-00-04", isConnected: true, isAudio: false),
]
model.setWatched("00-00-00-00-00-01", true)
model.setWatched("00-00-00-00-00-02", true)

let view = NSHostingView(rootView: SettingsView(model: model))
view.frame = NSRect(x: 0, y: 0, width: 460, height: 660)

// A window is needed for the view to lay out and pick up its material background,
// but it never has to appear on screen.
let window = NSWindow(
    contentRect: view.frame,
    styleMask: [.titled, .closable],
    backing: .buffered,
    defer: false
)
window.appearance = app.appearance
view.appearance = app.appearance
window.contentView = view
window.layoutIfNeeded()

RunLoop.main.run(until: Date().addingTimeInterval(1.2))

guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
rep.size = view.bounds.size
view.cacheDisplay(in: view.bounds, to: rep)

guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
