import Foundation

/// UserDefaults-backed settings. Deliberately tiny: this app has one job.
enum Preferences {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let enabled = "enabled"
        static let watchedDevices = "watchedDevices"
        static let onLidClose = "disconnectOnLidClose"
        static let onSystemSleep = "disconnectOnSystemSleep"
        static let reconnectOnWake = "reconnectOnWake"
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let showMenuBarIcon = "showMenuBarIcon"
    }

    static func registerDefaults() {
        defaults.register(defaults: [
            Key.enabled: true,
            Key.watchedDevices: [String](),
            Key.onLidClose: true,
            Key.onSystemSleep: true,
            Key.reconnectOnWake: false,
            Key.hasLaunchedBefore: false,
            Key.showMenuBarIcon: true,
        ])
    }

    static var enabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    /// Bluetooth addresses (lowercased, dash-separated) the user wants dropped.
    static var watchedDevices: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.watchedDevices) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: Key.watchedDevices) }
    }

    static var disconnectOnLidClose: Bool {
        get { defaults.bool(forKey: Key.onLidClose) }
        set { defaults.set(newValue, forKey: Key.onLidClose) }
    }

    static var disconnectOnSystemSleep: Bool {
        get { defaults.bool(forKey: Key.onSystemSleep) }
        set { defaults.set(newValue, forKey: Key.onSystemSleep) }
    }

    static var reconnectOnWake: Bool {
        get { defaults.bool(forKey: Key.reconnectOnWake) }
        set { defaults.set(newValue, forKey: Key.reconnectOnWake) }
    }

    /// The menu bar icon is opt-out. Some people keep a deliberately empty menu bar
    /// and would rather this ran invisibly, reachable by reopening the app.
    static var showMenuBarIcon: Bool {
        get { defaults.bool(forKey: Key.showMenuBarIcon) }
        set { defaults.set(newValue, forKey: Key.showMenuBarIcon) }
    }

    /// Used once, to open the menu on first launch. Picking a device is the only
    /// setup step there is, so it should not be something you have to go looking for.
    static var hasLaunchedBefore: Bool {
        get { defaults.bool(forKey: Key.hasLaunchedBefore) }
        set { defaults.set(newValue, forKey: Key.hasLaunchedBefore) }
    }

    static func isWatched(_ address: String) -> Bool {
        watchedDevices.contains(address.lowercased())
    }

    static func toggleWatched(_ address: String) {
        let key = address.lowercased()
        var set = watchedDevices
        if set.contains(key) { set.remove(key) } else { set.insert(key) }
        watchedDevices = set
    }
}
