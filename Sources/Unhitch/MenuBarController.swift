import AppKit

final class MenuBarController: NSObject, NSMenuDelegate {

    var onStateChanged: (() -> Void)?
    var onDisconnectNow: (() -> Void)?
    var hasClamshell: Bool = true

    private let bluetooth: BluetoothManager
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var isMenuOpen = false

    static let repositoryURL = URL(string: "https://github.com/Zawaer/unhitch")!

    init(bluetooth: BluetoothManager) {
        self.bluetooth = bluetooth
        super.init()
    }

    func install() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()

        guard !Preferences.hasLaunchedBefore else { return }
        Preferences.hasLaunchedBefore = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.statusItem.button?.performClick(nil)
        }
    }

    /// Keeps the icon honest always, and the menu honest only while it is on screen.
    /// Rebuilding a closed menu is wasted work; rebuilding an open one is the point.
    func refreshIfVisible() {
        updateIcon()
        guard isMenuOpen else { return }
        rebuild()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild()
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
    }

    // MARK: - Icon

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let symbol = Preferences.enabled ? "laptopcomputer" : "laptopcomputer.slash"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Unhitch")
            ?? NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "Unhitch")
        image?.isTemplate = true
        button.image = image
        button.appearsDisabled = !Preferences.enabled
        button.toolTip = Preferences.enabled
            ? "Unhitch is watching \(Preferences.watchedDevices.count) device(s)"
            : "Unhitch is paused"
    }

    // MARK: - Menu

    private func rebuild() {
        menu.removeAllItems()

        add(title: Preferences.enabled ? "Unhitch is on" : "Unhitch is paused",
            action: #selector(toggleEnabled),
            state: Preferences.enabled ? .on : .off)

        menu.addItem(.separator())
        addHeader("Disconnect these when the lid closes")

        let devices = bluetooth.pairedDevices()
        if devices.isEmpty {
            addHeader("No paired Bluetooth devices")
        } else {
            for device in devices {
                let item = NSMenuItem(
                    title: device.name,
                    action: #selector(toggleDevice(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = device.address
                item.state = Preferences.isWatched(device.address) ? .on : .off
                if device.isConnected {
                    item.attributedTitle = Self.title(device.name, suffix: "connected")
                }
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        if hasClamshell {
            add(title: "Trigger on lid close",
                action: #selector(toggleLidClose),
                state: Preferences.disconnectOnLidClose ? .on : .off)
        }
        add(title: "Trigger on sleep",
            action: #selector(toggleSystemSleep),
            state: Preferences.disconnectOnSystemSleep ? .on : .off)
        add(title: "Reconnect when the lid opens",
            action: #selector(toggleReconnect),
            state: Preferences.reconnectOnWake ? .on : .off)

        menu.addItem(.separator())

        let disconnectNow = add(title: "Disconnect selected now", action: #selector(disconnectNow))
        disconnectNow.isEnabled = !Preferences.watchedDevices.isEmpty

        if LaunchAtLogin.isAvailable {
            add(title: "Launch at login",
                action: #selector(toggleLaunchAtLogin),
                state: LaunchAtLogin.isEnabled ? .on : .off)
        }

        menu.addItem(.separator())
        addHeader("Bluetooth stays on — Find My is unaffected")
        add(title: "About Unhitch", action: #selector(openRepository))
        add(title: "Quit Unhitch", action: #selector(quit), keyEquivalent: "q")
    }

    @discardableResult
    private func add(title: String, action: Selector, state: NSControl.StateValue = .off, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.state = state
        menu.addItem(item)
        return item
    }

    /// A menu title with a dimmed trailing note. `NSMenuItemBadge` would be nicer
    /// but it is macOS 14+, and there is no reason to drop Ventura over a label.
    private static func title(_ text: String, suffix: String) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: text,
            attributes: [.font: NSFont.menuFont(ofSize: 0)]
        )
        result.append(NSAttributedString(
            string: "  \(suffix)",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        ))
        return result
    }

    private func addHeader(_ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
        menu.addItem(item)
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        Preferences.enabled.toggle()
        updateIcon()
        onStateChanged?()
    }

    @objc private func toggleDevice(_ sender: NSMenuItem) {
        guard let address = sender.representedObject as? String else { return }
        Preferences.toggleWatched(address)
        updateIcon()
        onStateChanged?()
    }

    @objc private func toggleLidClose() {
        Preferences.disconnectOnLidClose.toggle()
        onStateChanged?()
    }

    @objc private func toggleSystemSleep() {
        Preferences.disconnectOnSystemSleep.toggle()
        onStateChanged?()
    }

    @objc private func toggleReconnect() {
        Preferences.reconnectOnWake.toggle()
    }

    @objc private func disconnectNow() {
        onDisconnectNow?()
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.toggle()
    }

    @objc private func openRepository() {
        NSWorkspace.shared.open(Self.repositoryURL)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
