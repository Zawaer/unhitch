import Foundation
import IOKit
import IOKit.pwr_mgt

/// System sleep/wake notifications, via `IORegisterForSystemPower`.
///
/// We use the low-level API rather than `NSWorkspace.willSleepNotification` for one
/// reason: it lets us hold off the sleep acknowledgement until the disconnect has
/// actually landed. Acknowledging late is fine; going to sleep with the headset
/// still attached is not.
final class PowerMonitor {

    /// `IOMessage.h` defines these with a macro that Swift cannot import, so they
    /// are spelled out here. All three are `iokit_common_msg(x)`, i.e. `0xE0000000 | x`.
    private enum Message {
        static let canSystemSleep: UInt32 = 0xE000_0270
        static let systemWillSleep: UInt32 = 0xE000_0280
        static let systemHasPoweredOn: UInt32 = 0xE000_0300
    }

    /// Runs synchronously on the main queue just before the machine sleeps.
    var onWillSleep: (() -> Void)?
    /// Runs on the main queue once the machine is awake again.
    var onDidWake: (() -> Void)?

    private var rootPort: io_connect_t = 0
    private var notifyPort: IONotificationPortRef?
    private var notifier: io_object_t = 0

    func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        var port: IONotificationPortRef?

        rootPort = IORegisterForSystemPower(
            context,
            &port,
            { context, _, messageType, messageArgument in
                guard let context else { return }
                let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
                monitor.handle(messageType: messageType, argument: messageArgument)
            },
            &notifier
        )

        guard rootPort != 0, let port else { return }
        notifyPort = port
        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)
    }

    func stop() {
        guard rootPort != 0 else { return }
        if let notifyPort { IODeregisterForSystemPower(&notifier); IONotificationPortDestroy(notifyPort) }
        IOServiceClose(rootPort)
        rootPort = 0
        notifyPort = nil
    }

    private func handle(messageType: UInt32, argument: UnsafeMutableRawPointer?) {
        switch messageType {
        case Message.canSystemSleep:
            // We never want to veto sleep, only to get in front of it.
            IOAllowPowerChange(rootPort, Int(bitPattern: argument))

        case Message.systemWillSleep:
            onWillSleep?()
            IOAllowPowerChange(rootPort, Int(bitPattern: argument))

        case Message.systemHasPoweredOn:
            onDidWake?()

        default:
            break
        }
    }
}
