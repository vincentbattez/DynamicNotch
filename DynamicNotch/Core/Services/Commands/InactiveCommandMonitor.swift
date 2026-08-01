import DynamicNotchContract
import Foundation

/// No-op command monitor for UI tests / previews, mirroring `InactiveNotificationInboxMonitor`.
final class InactiveCommandMonitor: CommandMonitoring {
    var onCommand: ((CommandPayload) -> Void)?

    func startMonitoring() {}
    func stopMonitoring() {}
}
