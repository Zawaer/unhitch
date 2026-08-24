import Foundation
import IOBluetooth

struct PairedDevice {
    let name: String
    let address: String       // lowercased "xx-xx-xx-xx-xx-xx"
    let isConnected: Bool
    let isAudio: Bool
}

/// Thin wrapper over IOBluetooth.
///
/// Everything here operates on individual device *links*. The Bluetooth radio is
/// never powered down, which is the whole point: Find My's offline finding network
/// keeps broadcasting while we drop one specific headset.
final class BluetoothManager: NSObject {

    /// Called when any device connects, so the app can veto it while the lid is shut.
    var onDeviceConnected: ((PairedDevice) -> Void)?
    /// Called when any device disconnects, so the menu can refresh.
    var onDeviceDisconnected: (() -> Void)?

    /// Asked before a retry, so a queued retry cannot fire after the lid reopened.
    var shouldStayDisconnected: ((String) -> Bool)?

    private var connectNotification: IOBluetoothUserNotification?

    /// How long a link takes to actually drop. Measured at roughly 2.4s on an
    /// M3 MacBook Air with an A2DP headset; 3s leaves a little headroom.
    private static let teardownTimeout: TimeInterval = 3.0

    // Major device class 0x01 = Computer, 0x02 = Phone, 0x04 = Audio/Video, 0x05 = Peripheral.
    private static let audioMajorClass: UInt32 = 0x04

    func startWatching() {
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceDidConnect(_:device:))
        )
    }

    func stopWatching() {
        connectNotification?.unregister()
        connectNotification = nil
    }

    // MARK: - Enumeration

    /// Paired devices, de-duplicated by address (IOBluetooth happily returns the
    /// same headset twice when it has both a classic and an LE record).
    func pairedDevices() -> [PairedDevice] {
        guard let raw = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return [] }

        var seen = Set<String>()
        var result: [PairedDevice] = []
        for device in raw {
            guard let address = device.addressString?.lowercased(), !address.isEmpty else { continue }
            guard seen.insert(address).inserted else { continue }
            result.append(
                PairedDevice(
                    name: device.name ?? device.nameOrAddress ?? address,
                    address: address,
                    isConnected: device.isConnected(),
                    isAudio: device.deviceClassMajor == Self.audioMajorClass
                )
            )
        }
        // Audio gear first (it's what people are here for), then alphabetical.
        return result.sorted {
            $0.isAudio == $1.isAudio
                ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                : $0.isAudio
        }
    }

    func isConnected(_ address: String) -> Bool {
        IOBluetoothDevice(addressString: address)?.isConnected() ?? false
    }

    // MARK: - Link control

    /// Drop a device's link.
    ///
    /// `closeConnection()` returns before the link is actually torn down — on real
    /// hardware the baseband takes around two seconds to let go — so success means
    /// polling until the device reports itself disconnected, not just calling the
    /// method and hoping.
    ///
    /// - Parameter blocking: when true, sleeps the calling thread until the link is
    ///   really gone. Used on the system-sleep path, where the sleep acknowledgement
    ///   is deliberately held open until this finishes; timers would never fire there
    ///   because the machine is about to stop scheduling us at all.
    @discardableResult
    func disconnect(_ address: String, blocking: Bool, attempts: Int = 2) -> Bool {
        guard let device = IOBluetoothDevice(addressString: address) else { return false }
        guard device.isConnected() else { return true }

        device.closeConnection()

        if blocking {
            let deadline = Date().addingTimeInterval(Self.teardownTimeout)
            while device.isConnected() && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.1)
            }
            if device.isConnected() && attempts > 1 {
                return disconnect(address, blocking: true, attempts: attempts - 1)
            }
            return !device.isConnected()
        }

        // Awake path: check back once the teardown should have landed, and only
        // try again if the device is still meant to be kept away.
        if attempts > 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.teardownTimeout) { [weak self] in
                guard let self, self.isConnected(address) else { return }
                guard self.shouldStayDisconnected?(address) ?? true else { return }
                self.disconnect(address, blocking: false, attempts: attempts - 1)
            }
        }
        return false
    }

    @discardableResult
    func connect(_ address: String) -> Bool {
        guard let device = IOBluetoothDevice(addressString: address) else { return false }
        guard !device.isConnected() else { return true }
        return device.openConnection() == kIOReturnSuccess
    }

    func name(for address: String) -> String {
        guard let device = IOBluetoothDevice(addressString: address) else { return address }
        return device.name ?? device.nameOrAddress ?? address
    }

    // MARK: - Notifications

    @objc private func deviceDidConnect(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        // Fires once per connection; register for this link's disconnect so the menu stays honest.
        device.register(forDisconnectNotification: self, selector: #selector(deviceDidDisconnect(_:device:)))

        guard let address = device.addressString?.lowercased() else { return }
        let paired = PairedDevice(
            name: device.name ?? device.nameOrAddress ?? address,
            address: address,
            isConnected: true,
            isAudio: device.deviceClassMajor == Self.audioMajorClass
        )
        DispatchQueue.main.async { [weak self] in
            self?.onDeviceConnected?(paired)
        }
    }

    @objc private func deviceDidDisconnect(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        notification.unregister()
        DispatchQueue.main.async { [weak self] in
            self?.onDeviceDisconnected?()
        }
    }
}
