import DynamicNotchContract
import Foundation

/// Abstraction over the commands-folder watcher so wiring can swap in an inert double for UI
/// tests. Mirrors `NotificationInboxMonitoring`, but hands back a `CommandPayload` per drop.
protocol CommandMonitoring: AnyObject {
    var onCommand: ((CommandPayload) -> Void)? { get set }

    func startMonitoring()
    func stopMonitoring()
}
