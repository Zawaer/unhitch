import Foundation
import ServiceManagement

/// Login-item registration.
///
/// `SMAppService.mainApp` needs the running bundle to be one LaunchServices knows
/// about, so registration is failure-tolerant: on a copy run from a Downloads folder
/// or a build directory it can simply refuse, and the toggle should say so rather
/// than silently lie about it.
enum LaunchAtLogin {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    @discardableResult
    static func toggle() -> Bool {
        let service = SMAppService.mainApp
        let before = service.status
        do {
            if before == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
            Log.event("login item: \(describe(before)) -> \(describe(service.status))")
            return true
        } catch {
            Log.event("login item: \(describe(before)) -> failed (\(error.localizedDescription))")
            return false
        }
    }

    private static func describe(_ status: SMAppService.Status) -> String {
        switch status {
        case .notRegistered: return "notRegistered"
        case .enabled: return "enabled"
        case .requiresApproval: return "requiresApproval"
        case .notFound: return "notFound"
        @unknown default: return "unknown"
        }
    }
}
