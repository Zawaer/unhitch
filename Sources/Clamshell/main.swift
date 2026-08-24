import AppKit

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
// Menu bar only: no Dock icon, no app switcher entry.
application.setActivationPolicy(.accessory)
application.run()
