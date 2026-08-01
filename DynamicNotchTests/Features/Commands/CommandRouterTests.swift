import DynamicNotchContract
import XCTest
@testable import DynamicNotch

/// Seam 3: the `CommandRouter` resolution order, exercised without any UI or `AppContainer`.
/// Collaborators are plain closures, so each rule is asserted in isolation.
@MainActor
final class CommandRouterTests: XCTestCase {
    private let fixedNow = Date(timeIntervalSince1970: 1_000_000)

    private func makeRouter(
        localTimer: LocalTimerViewModel,
        clockActive: Bool,
        emitted: EmittedBox
    ) -> CommandRouter {
        CommandRouter(
            localTimerViewModel: localTimer,
            isClockTimerActive: { clockActive },
            emitNotification: { emitted.append($0) },
            now: { self.fixedNow }
        )
    }

    func testNominalStartRunsTheLocalTimerWithLabelAndEmitsNothing() {
        let localTimer = LocalTimerViewModel()
        let emitted = EmittedBox()
        let router = makeRouter(localTimer: localTimer, clockActive: false, emitted: emitted)

        router.route(.timerStart(endsAt: fixedNow.addingTimeInterval(600), label: "Fixer bug Léa"))

        XCTAssertEqual(localTimer.state, .running)
        XCTAssertEqual(localTimer.label, "Fixer bug Léa")
        XCTAssertTrue(emitted.values.isEmpty)
    }

    func testExpiredEndsAtIsANoOpWithNoTimerAndNoNotification() {
        let localTimer = LocalTimerViewModel()
        let emitted = EmittedBox()
        let router = makeRouter(localTimer: localTimer, clockActive: false, emitted: emitted)

        // endsAt == now, i.e. not in the future: discarded without effect or trace.
        router.route(.timerStart(endsAt: fixedNow, label: "too late"))

        XCTAssertEqual(localTimer.state, .stopped)
        XCTAssertNil(localTimer.label)
        XCTAssertTrue(emitted.values.isEmpty)
    }

    func testARunningLocalTimerIsReplacedByANewCommand() {
        let localTimer = LocalTimerViewModel()
        let emitted = EmittedBox()
        let router = makeRouter(localTimer: localTimer, clockActive: false, emitted: emitted)

        router.route(.timerStart(endsAt: fixedNow.addingTimeInterval(600), label: "First"))
        XCTAssertEqual(localTimer.label, "First")

        router.route(.timerStart(endsAt: fixedNow.addingTimeInterval(1200), label: "Second"))

        XCTAssertEqual(localTimer.state, .running)
        XCTAssertEqual(localTimer.label, "Second")
        XCTAssertTrue(emitted.values.isEmpty)
    }

    func testActiveClockTimerBlocksStartAndEmitsAWarning() {
        let localTimer = LocalTimerViewModel()
        let emitted = EmittedBox()
        let router = makeRouter(localTimer: localTimer, clockActive: true, emitted: emitted)

        router.route(.timerStart(endsAt: fixedNow.addingTimeInterval(600), label: "Blocked"))

        XCTAssertEqual(localTimer.state, .stopped)
        XCTAssertEqual(emitted.values.count, 1)
        XCTAssertEqual(emitted.values.first?.level, .warning)
    }
}

private final class EmittedBox {
    private(set) var values: [NotificationPayload] = []
    func append(_ payload: NotificationPayload) { values.append(payload) }
}
