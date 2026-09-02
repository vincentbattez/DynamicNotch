import XCTest
@testable import DynamicNotch

@MainActor
final class LockScreenManagerIntegrationTests: XCTestCase {
    // Scratch domain: these tests run app-hosted, so writing to .standard would leak into the real app prefs.
    private var scratchSuiteName: String!
    private var scratchDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        scratchSuiteName = "DynamicNotchTests.\(UUID().uuidString)"
        scratchDefaults = UserDefaults(suiteName: scratchSuiteName)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: scratchSuiteName)
        scratchDefaults = nil
        scratchSuiteName = nil
        super.tearDown()
    }

    func testLockAndUnlockTransitionsPlayExpectedSounds() async {
        let service = FakeLockScreenMonitoringService()
        let soundPlayer = FakeLockScreenSoundPlayer()
        let manager = LockScreenManager(
            service: service,
            soundPlayer: soundPlayer,
            defaults: scratchDefaults,
            unlockCollapseDelay: 0.05,
            idleResetDelay: 0.05
        )

        manager.startMonitoring()

        service.publish(isLocked: true)
        service.publish(isLocked: true)
        service.publish(isLocked: false)
        service.publish(isLocked: false)

        await assertEventually(timeout: 0.2) {
            await MainActor.run {
                soundPlayer.playedSounds == [.lock, .unlock] &&
                !manager.isLocked &&
                !manager.isLockIdle
            }
        }

        await assertEventually(timeout: 0.2) {
            await MainActor.run {
                manager.isLockIdle && manager.event == .stopped
            }
        }
    }

    func testLockAndUnlockTransitionsDoNotPlaySoundsWhenDisabled() async {
        scratchDefaults.set(false, forKey: LockScreenSettings.soundKey)

        let service = FakeLockScreenMonitoringService()
        let soundPlayer = FakeLockScreenSoundPlayer()
        let manager = LockScreenManager(
            service: service,
            soundPlayer: soundPlayer,
            defaults: scratchDefaults,
            unlockCollapseDelay: 0.05,
            idleResetDelay: 0.05
        )

        manager.startMonitoring()

        service.publish(isLocked: true)
        service.publish(isLocked: false)

        await assertEventually(timeout: 0.2) {
            await MainActor.run {
                soundPlayer.playedSounds.isEmpty &&
                !manager.isLocked &&
                !manager.isLockIdle
            }
        }

        await assertEventually(timeout: 0.2) {
            await MainActor.run {
                manager.isLockIdle && manager.event == .stopped
            }
        }
    }
}
