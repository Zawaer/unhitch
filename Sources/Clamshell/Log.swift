import Foundation
import os

/// Diagnostics for a background app with no window to show them in.
///
///     log stream --predicate 'subsystem == "com.zawaer.clamshell"'
enum Log {
    private static let logger = Logger(subsystem: "com.zawaer.clamshell", category: "clamshell")

    static func event(_ message: String) {
        logger.notice("\(message, privacy: .public)")
    }
}
