import AppKit
import Combine
import SwiftUI

/// The single source of truth shared by the menu bar and the settings window, so
/// the two views of the same settings can never drift apart.
final class AppModel: ObservableObject {

    /// Fired when a change should be applied to the Bluetooth state right away.
    var onSettingsChanged: (() -> Void)?
    var onDisconnectRequested: (() -> Void)?
    var onMenuBarVisibilityChanged: ((Bool) -> Void)?

    @Published var isEnabled: Bool { didSet { commit { Preferences.enabled = isEnabled } } }
    @Published var disconnectOnLidClose: Bool { didSet { commit { Preferences.disconnectOnLidClose = disconnectOnLidClose } } }
    @Published var disconnectOnSystemSleep: Bool { didSet { commit { Preferences.disconnectOnSystemSleep = disconnectOnSystemSleep } } }
    @Published var reconnectOnLidOpen: Bool { didSet { Preferences.reconnectOnWake = reconnectOnLidOpen } }

    @Published var showsMenuBarIcon: Bool {
        didSet {
            guard !isSyncing else { return }
            Preferences.showMenuBarIcon = showsMenuBarIcon
            onMenuBarVisibilityChanged?(showsMenuBarIcon)
        }
    }

    @Published var launchesAtLogin: Bool {
        didSet {
            guard !isSyncing else { return }
            LaunchAtLogin.toggle()
            // Registration can fail — reflect what actually happened, not what was asked.
            isSyncing = true
            launchesAtLogin = LaunchAtLogin.isEnabled
            isSyncing = false
        }
    }

    @Published var devices: [PairedDevice] = []
    @Published private(set) var watched: Set<String>
    @Published var hasClamshell = true

    private let bluetooth: BluetoothManager
    private var isSyncing = false

    init(bluetooth: BluetoothManager) {
        self.bluetooth = bluetooth
        isEnabled = Preferences.enabled
        disconnectOnLidClose = Preferences.disconnectOnLidClose
        disconnectOnSystemSleep = Preferences.disconnectOnSystemSleep
        reconnectOnLidOpen = Preferences.reconnectOnWake
        showsMenuBarIcon = Preferences.showMenuBarIcon
        launchesAtLogin = LaunchAtLogin.isEnabled
        watched = Preferences.watchedDevices
    }

    var versionSummary: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let count = watched.count
        let subject = count == 1 ? "1 device" : "\(count) devices"
        return isEnabled ? "Version \(version) · watching \(subject)" : "Version \(version) · paused"
    }

    /// Set by the figure renderer so the sample device list survives `onAppear`.
    var usesSampleDevices = false

    /// Re-read the login item state without running the toggle in `didSet`.
    func syncLaunchAtLogin() {
        isSyncing = true
        launchesAtLogin = LaunchAtLogin.isEnabled
        isSyncing = false
    }

    func refreshDevices() {
        guard !usesSampleDevices else { return }
        devices = bluetooth.pairedDevices()
    }

    func isWatched(_ address: String) -> Bool {
        watched.contains(address.lowercased())
    }

    func setWatched(_ address: String, _ isOn: Bool) {
        let key = address.lowercased()
        if isOn { watched.insert(key) } else { watched.remove(key) }
        Preferences.watchedDevices = watched
        onSettingsChanged?()
    }

    func binding(for address: String) -> Binding<Bool> {
        Binding(
            get: { [weak self] in self?.isWatched(address) ?? false },
            set: { [weak self] in self?.setWatched(address, $0) }
        )
    }

    func disconnectNow() {
        onDisconnectRequested?()
    }

    private func commit(_ apply: () -> Void) {
        guard !isSyncing else { return }
        apply()
        onSettingsChanged?()
    }
}
