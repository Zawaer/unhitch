import Foundation
import ServiceManagement

/// Login-item registration. Requires the app to be running from a real bundle,
/// so every call is failure-tolerant: worst case the menu item just does nothing.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    @discardableResult
    static func toggle() -> Bool {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            return true
        } catch {
            NSLog("Unhitch: could not change login item: \(error.localizedDescription)")
            return false
        }
    }
}
