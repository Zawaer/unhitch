import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let bluetooth = BluetoothManager()
    private let clamshell = ClamshellMonitor()
    private let power = PowerMonitor()
    private var model: AppModel!
    private var menuBar: MenuBarController!
    private var settings: SettingsWindowController!

    /// True while the lid is shut (or the machine is asleep) and we are actively
    /// refusing to let watched devices hold a connection.
    private var isSuppressing = false

    /// Devices we dropped ourselves, so "reconnect on lid open" only reconnects
    /// what we took away rather than dialling out to every paired headset.
    private var disconnectedByUs: Set<String> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.registerDefaults()

        model = AppModel(bluetooth: bluetooth)
        model.onSettingsChanged = { [weak self] in self?.reevaluate() }
        model.onDisconnectRequested = { [weak self] in self?.disconnectWatched(blocking: false) }
        model.onMenuBarVisibilityChanged = { [weak self] visible in self?.menuBar.setVisible(visible) }

        settings = SettingsWindowController(model: model)
        menuBar = MenuBarController(model: model)
        menuBar.onOpenSettings = { [weak self] in self?.settings.show() }
        menuBar.setVisible(model.showsMenuBarIcon)

        bluetooth.onDeviceConnected = { [weak self] device in self?.deviceConnected(device) }
        bluetooth.onDeviceDisconnected = { [weak self] in self?.menuBar.refreshIfVisible() }
        bluetooth.shouldStayDisconnected = { [weak self] _ in self?.isSuppressing ?? false }
        bluetooth.startWatching()

        clamshell.onChange = { [weak self] isClosed in self?.lidStateChanged(isClosed) }
        clamshell.start()

        power.onWillSleep = { [weak self] in self?.systemWillSleep() }
        power.onDidWake = { [weak self] in self?.systemDidWake() }
        power.start()

        model.hasClamshell = clamshell.hasClamshell
        model.refreshDevices()
        Log.event("started; lid \(clamshell.isClosed ? "closed" : "open"), watching \(Preferences.watchedDevices.count) device(s)")

        // Picking a device is the only setup step there is, so on first launch put
        // the window in front rather than leaving a silent icon to be discovered.
        if !Preferences.hasLaunchedBefore {
            Preferences.hasLaunchedBefore = true

            // An app that only works while it is running, installed deliberately for
            // that purpose, should not quietly stop working after the next restart.
            // Opt in by default; the toggle to undo it is right there in the window.
            if !LaunchAtLogin.isEnabled { LaunchAtLogin.toggle() }
            model.syncLaunchAtLogin()

            settings.show()
        }
    }

    /// Reopening from the Applications folder brings the window back. This is the
    /// way in when the menu bar icon is switched off.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settings.show()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        bluetooth.stopWatching()
        clamshell.stop()
        power.stop()
    }

    // MARK: - Triggers

    private func lidStateChanged(_ isClosed: Bool) {
        Log.event("lid \(isClosed ? "closed" : "opened")")
        guard model.isEnabled, model.disconnectOnLidClose else { return }
        if isClosed {
            beginSuppressing(blocking: false)
        } else {
            endSuppressing()
        }
    }

    private func systemWillSleep() {
        Log.event("system will sleep")
        guard model.isEnabled, model.disconnectOnSystemSleep else { return }
        // Blocking, because after this returns the machine stops running our timers.
        beginSuppressing(blocking: true)
    }

    private func systemDidWake() {
        clamshell.refresh()
        // A machine woken with the lid still shut (external display, Power Nap) is
        // still a machine that should not be holding the headset.
        guard !clamshell.isClosed || !model.disconnectOnLidClose else { return }
        endSuppressing()
    }

    /// Something connected. If it is on the list and we are in a suppressing state,
    /// hang up on it. This is what catches earbuds pulled out of their case an hour
    /// after the lid was closed.
    private func deviceConnected(_ device: PairedDevice) {
        menuBar.refreshIfVisible()
        guard model.isEnabled,
              model.isWatched(device.address),
              isSuppressing || (clamshell.isClosed && model.disconnectOnLidClose)
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

        guard model.reconnectOnLidOpen, !toReconnect.isEmpty else { return }
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
        for address in model.watched where bluetooth.isConnected(address) {
            disconnectedByUs.insert(address)
            let dropped = bluetooth.disconnect(address, blocking: blocking)
            // On the awake path a false result only means the teardown is under way
            // and will be verified later; on the sleep path it means we gave up.
            let outcome = dropped ? "done" : (blocking ? "FAILED, still connected" : "requested")
            Log.event("disconnect \(bluetooth.name(for: address)): \(outcome)")
        }
        menuBar.refreshIfVisible()
    }

    /// Re-apply the current settings immediately, so a change in either UI takes
    /// effect without waiting for the next lid event.
    private func reevaluate() {
        guard model.isEnabled else {
            isSuppressing = false
            disconnectedByUs.removeAll()
            return
        }

        let shouldSuppress = clamshell.isClosed && model.disconnectOnLidClose
        if shouldSuppress && !isSuppressing {
            beginSuppressing(blocking: false)
        } else if !shouldSuppress && isSuppressing {
            // Covers turning the lid trigger off while sitting in clamshell mode.
            endSuppressing()
        }
    }
}
