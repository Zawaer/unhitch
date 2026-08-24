import AppKit

/// The menu bar half of the UI. Optional — see `Preferences.showMenuBarIcon` — and
/// deliberately not the only way to reach anything.
final class MenuBarController: NSObject, NSMenuDelegate {

    var onOpenSettings: (() -> Void)?

    private let model: AppModel
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var isMenuOpen = false

    init(model: AppModel) {
        self.model = model
        super.init()
        menu.delegate = self
    }

    /// Adding and removing the status item is how the icon is hidden; there is no
    /// "invisible" state for an `NSStatusItem` worth faking.
    func setVisible(_ visible: Bool) {
        if visible {
            guard statusItem == nil else { return }
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.menu = menu
            statusItem = item
            updateIcon()
        } else {
            guard let item = statusItem else { return }
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    /// Keeps the icon honest always, and the menu honest only while it is on screen.
    func refreshIfVisible() {
        updateIcon()
        guard isMenuOpen else { return }
        rebuild()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        model.refreshDevices()
        rebuild()
    }

    func menuWillOpen(_ menu: NSMenu) { isMenuOpen = true }
    func menuDidClose(_ menu: NSMenu) { isMenuOpen = false }

    // MARK: - Icon

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let name = model.isEnabled ? "laptopcomputer" : "laptopcomputer.slash"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Unhitch")
            ?? NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "Unhitch")
        image?.isTemplate = true
        button.image = image
        button.appearsDisabled = !model.isEnabled
        button.toolTip = model.versionSummary
    }

    // MARK: - Menu

    private func rebuild() {
        menu.removeAllItems()

        add(title: model.isEnabled ? "Unhitch is on" : "Unhitch is paused",
            action: #selector(toggleEnabled),
            state: model.isEnabled ? .on : .off)

        menu.addItem(.separator())
        addCaption("Devices to let go of")

        if model.devices.isEmpty {
            addCaption("No paired Bluetooth devices")
        } else {
            for device in model.devices {
                let item = NSMenuItem(title: device.name, action: #selector(toggleDevice(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = device.address
                item.state = model.isWatched(device.address) ? .on : .off
                if device.isConnected {
                    item.attributedTitle = Self.title(device.name, suffix: "connected")
                }
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        menu.addItem(triggersItem())

        let disconnect = add(title: "Disconnect Now", action: #selector(disconnectNow))
        disconnect.isEnabled = !model.watched.isEmpty && model.isEnabled

        add(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")

        menu.addItem(.separator())
        add(title: "Quit Unhitch", action: #selector(quit), keyEquivalent: "q")
    }

    /// The triggers live in a submenu so the menu stays short without making the
    /// settings window the only place they can be changed.
    private func triggersItem() -> NSMenuItem {
        let submenu = NSMenu()
        let parent = NSMenuItem(title: "Let go when", action: nil, keyEquivalent: "")

        func option(_ title: String, _ isOn: Bool, _ action: Selector) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.state = isOn ? .on : .off
            submenu.addItem(item)
        }

        if model.hasClamshell {
            option("The lid closes", model.disconnectOnLidClose, #selector(toggleLidClose))
        }
        option("The Mac sleeps", model.disconnectOnSystemSleep, #selector(toggleSystemSleep))
        submenu.addItem(.separator())
        option("Reconnect when the lid opens", model.reconnectOnLidOpen, #selector(toggleReconnect))

        parent.submenu = submenu
        return parent
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

    private func addCaption(_ title: String) {
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

    @objc private func toggleEnabled() { model.isEnabled.toggle(); updateIcon() }
    @objc private func toggleLidClose() { model.disconnectOnLidClose.toggle() }
    @objc private func toggleSystemSleep() { model.disconnectOnSystemSleep.toggle() }
    @objc private func toggleReconnect() { model.reconnectOnLidOpen.toggle() }
    @objc private func disconnectNow() { model.disconnectNow() }
    @objc private func openSettings() { onOpenSettings?() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func toggleDevice(_ sender: NSMenuItem) {
        guard let address = sender.representedObject as? String else { return }
        model.setWatched(address, !model.isWatched(address))
        updateIcon()
    }
}
