import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let bluetooth = BluetoothManager()
    private let clamshell = ClamshellMonitor()
    private let power = PowerMonitor()
    private var menuBar: MenuBarController!

    /// True while the lid is shut (or the machine is asleep) and we are actively
    /// refusing to let watched devices hold a connection.
    private var isSuppressing = false

    /// Devices we dropped ourselves, so "reconnect on lid open" only reconnects
    /// what we took away rather than dialling out to every paired headset.
    private var disconnectedByUs: Set<String> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.registerDefaults()

        menuBar = MenuBarController(bluetooth: bluetooth)
        menuBar.onStateChanged = { [weak self] in self?.reevaluate() }
        menuBar.onDisconnectNow = { [weak self] in self?.disconnectWatched(blocking: false) }
        menuBar.install()

        bluetooth.onDeviceConnected = { [weak self] device in self?.deviceConnected(device) }
        bluetooth.shouldStayDisconnected = { [weak self] _ in self?.isSuppressing ?? false }
        bluetooth.onDeviceDisconnected = { [weak self] in self?.menuBar.refreshIfVisible() }
        bluetooth.startWatching()

        clamshell.onChange = { [weak self] isClosed in self?.lidStateChanged(isClosed) }
        clamshell.start()

        power.onWillSleep = { [weak self] in self?.systemWillSleep() }
        power.onDidWake = { [weak self] in self?.systemDidWake() }
        power.start()

        menuBar.hasClamshell = clamshell.hasClamshell
        Log.event("started; lid \(clamshell.isClosed ? "closed" : "open"), watching \(Preferences.watchedDevices.count) device(s)")
    }

    func applicationWillTerminate(_ notification: Notification) {
        bluetooth.stopWatching()
        clamshell.stop()
        power.stop()
    }

    // MARK: - Triggers

    private func lidStateChanged(_ isClosed: Bool) {
        Log.event("lid \(isClosed ? "closed" : "opened")")
        guard Preferences.enabled, Preferences.disconnectOnLidClose else { return }
        if isClosed {
            beginSuppressing(blocking: false)
        } else {
            endSuppressing()
        }
    }

    private func systemWillSleep() {
        Log.event("system will sleep")
        guard Preferences.enabled, Preferences.disconnectOnSystemSleep else { return }
        // Blocking, because after this returns the machine stops running our timers.
        beginSuppressing(blocking: true)
    }

    private func systemDidWake() {
        clamshell.refresh()
        // A machine woken with the lid still shut (external display, Power Nap) is
        // still a machine that should not be holding the headset.
        guard !clamshell.isClosed || !Preferences.disconnectOnLidClose else { return }
        endSuppressing()
    }

    /// Something connected. If it is on the list and we are in a suppressing state,
    /// hang up on it. This is what catches earbuds pulled out of their case an hour
    /// after the lid was closed.
    private func deviceConnected(_ device: PairedDevice) {
        menuBar.refreshIfVisible()
        guard Preferences.enabled,
              Preferences.isWatched(device.address),
              isSuppressing || (clamshell.isClosed && Preferences.disconnectOnLidClose)
        else { return }

        Log.event("\(device.name) connected while suppressed; dropping it")
        disconnectedByUs.insert(device.address)
        bluetooth.disconnect(device.address, blocking: false)
    }

    // MARK: - Suppression

    private func beginSuppressing(blocking: Bool) {
        isSuppressing = true
        disconnectWatched(blocking: blocking)
    }

    private func endSuppressing() {
        guard isSuppressing else { return }
        isSuppressing = false

        let toReconnect = disconnectedByUs
        disconnectedByUs.removeAll()

        guard Preferences.reconnectOnWake, !toReconnect.isEmpty else { return }
        // The Bluetooth stack needs a beat after wake before it will honour an
        // outbound connection request.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, !self.isSuppressing else { return }
            for address in toReconnect {
                Log.event("reconnecting \(self.bluetooth.name(for: address))")
                self.bluetooth.connect(address)
            }
        }
    }

    private func disconnectWatched(blocking: Bool) {
        for address in Preferences.watchedDevices where bluetooth.isConnected(address) {
            disconnectedByUs.insert(address)
            let dropped = bluetooth.disconnect(address, blocking: blocking)
            Log.event("disconnect \(bluetooth.name(for: address)): \(dropped ? "done" : "pending")")
        }
        menuBar.refreshIfVisible()
    }

    /// Re-apply the current settings immediately, so a change in the menu takes
    /// effect without waiting for the next lid event.
    private func reevaluate() {
        guard Preferences.enabled else {
            isSuppressing = false
            disconnectedByUs.removeAll()
            return
        }

        let shouldSuppress = clamshell.isClosed && Preferences.disconnectOnLidClose
        if shouldSuppress && !isSuppressing {
            beginSuppressing(blocking: false)
        } else if !shouldSuppress && isSuppressing {
            // Covers turning the lid trigger off while sitting in clamshell mode.
            endSuppressing()
        }
    }
}
