import DynamicNotchContract
import Foundation

/// Routes an ingested `CommandPayload` to the surface it drives. Today the only verb is
/// `timer.start`; the `switch` is exhaustive so a new verb is a compile error until handled.
///
/// The router carries the conflict/replacement policy (ADR-0002) so `LocalTimerViewModel` stays
/// ignorant of provenance. Its collaborators are injected as closures/small values — no
/// `AppContainer` — so the resolution order is testable without a UI (Test 3).
@MainActor
final class CommandRouter {
    private let localTimerViewModel: LocalTimerViewModel
    private let isClockTimerActive: () -> Bool
    private let emitNotification: (NotificationPayload) -> Void
    private let now: () -> Date

    init(
        localTimerViewModel: LocalTimerViewModel,
        isClockTimerActive: @escaping () -> Bool,
        emitNotification: @escaping (NotificationPayload) -> Void,
        now: @escaping () -> Date = { Date() }
    ) {
        self.localTimerViewModel = localTimerViewModel
        self.isClockTimerActive = isClockTimerActive
        self.emitNotification = emitNotification
        self.now = now
    }

    func route(_ command: CommandPayload) {
        switch command {
        case let .timerStart(endsAt, label):
            startLocalTimer(endsAt: endsAt, label: label)
        }
    }

    /// Resolution order (ADR-0002):
    /// 1. `endsAt <= now` → no effect, no trace (the file is already deleted by the monitor).
    /// 2. Clock timer active → start nothing **and** push a `warning` Notification.
    /// 3. Local timer running → `stop()` then `start(…)` (Coalescence).
    /// 4. otherwise → `start(…)`.
    private func startLocalTimer(endsAt: Date, label: String?) {
        guard endsAt > now() else { return }

        if isClockTimerActive() {
            emitNotification(
                NotificationPayload(
                    title: "Timer command ignored",
                    summary: "A macOS Clock timer is running, so DynamicNotch left it in place.",
                    level: .warning,
                    source: "dynamicnotch.timer"
                )
            )
            return
        }

        if localTimerViewModel.state != .stopped {
            localTimerViewModel.stop()
        }
        localTimerViewModel.start(endsAt: endsAt, now: now(), label: label)
    }
}
