import Foundation
import IOKit

/// Reports whether the lid is shut.
///
/// This is separate from sleep on purpose. A MacBook on an external display stays
/// wide awake with the lid closed, and that is exactly when a headset silently
/// re-attaching to the laptop is most irritating.
final class ClamshellMonitor {

    /// Called on the main queue whenever the lid state changes.
    var onChange: ((_ isClosed: Bool) -> Void)?

    private(set) var isClosed: Bool = false

    private var rootDomain: io_service_t = 0
    private var notifyPort: IONotificationPortRef?
    private var notifier: io_object_t = 0
    private var pollTimer: Timer?

    /// True on machines with no lid at all (Mac mini, Studio, iMac).
    private(set) var hasClamshell: Bool = true

    func start() {
        rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard rootDomain != 0 else {
            hasClamshell = false
            return
        }

        if readClamshellState() == nil {
            hasClamshell = false
            return
        }
        isClosed = readClamshellState() ?? false

        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        if let notifyPort {
            IONotificationPortSetDispatchQueue(notifyPort, DispatchQueue.main)
            let context = Unmanaged.passUnretained(self).toOpaque()
            IOServiceAddInterestNotification(
                notifyPort,
                rootDomain,
                kIOGeneralInterest,
                { context, _, _, _ in
                    guard let context else { return }
                    let monitor = Unmanaged<ClamshellMonitor>.fromOpaque(context).takeUnretainedValue()
                    monitor.refresh()
                },
                context,
                &notifier
            )
        }

        // Safety net. The power-management interest notification is the primary
        // signal, but a cheap registry read on a coalesced timer costs nothing and
        // covers the cases where it does not arrive.
        let timer = Timer(timeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer.tolerance = 2.0
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        if notifier != 0 { IOObjectRelease(notifier); notifier = 0 }
        if let notifyPort { IONotificationPortDestroy(notifyPort) }
        notifyPort = nil
        if rootDomain != 0 { IOObjectRelease(rootDomain); rootDomain = 0 }
    }

    /// Re-read the lid state and fire `onChange` if it moved.
    func refresh() {
        guard let state = readClamshellState(), state != isClosed else { return }
        isClosed = state
        onChange?(state)
    }

    private func readClamshellState() -> Bool? {
        guard rootDomain != 0 else { return nil }
        guard let property = IORegistryEntryCreateCFProperty(
            rootDomain, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() else { return nil }
        return (property as? Bool) ?? ((property as? NSNumber)?.boolValue)
    }
}
