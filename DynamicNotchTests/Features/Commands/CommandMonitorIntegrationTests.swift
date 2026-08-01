import DynamicNotchContract
import XCTest
@testable import DynamicNotch

/// Seam 2 (the king test) + monitor policy: drives the real `CommandMonitor` over a temp
/// `commands/` folder. The king case runs the *built* `dynamicnotch` binary end-to-end — the
/// exact production path a script exercises. Mirrors `NotificationInboxMonitorIntegrationTests`.
final class CommandMonitorIntegrationTests: XCTestCase {
    func testValidCommandDropIsIngestedThenFileDeleted() {
        let commands = makeTemporaryInboxDirectory()
        defer { try? FileManager.default.removeItem(at: commands) }

        let monitor = CommandMonitor(commandsDirectory: commands, retryDelay: 0)
        let ingested = expectation(description: "ingests dropped command")
        let box = CommandBox()
        monitor.onCommand = { command in
            box.value = command
            ingested.fulfill()
        }
        monitor.startMonitoring()

        atomicDrop(
            ["action": "timer.start", "endsAt": 9_999_999_999, "label": "Fixer bug Léa"],
            named: "\(UUID().uuidString).json",
            in: commands
        )

        wait(for: [ingested], timeout: 10.0)
        monitor.stopMonitoring()

        XCTAssertEqual(
            box.value,
            .timerStart(endsAt: Date(timeIntervalSince1970: 9_999_999_999), label: "Fixer bug Léa")
        )
        XCTAssertEqual(eligibleJSONCount(in: commands), 0)
    }

    func testMalformedJSONIsQuarantinedInRejectedAfterRetry() async {
        let commands = makeTemporaryInboxDirectory()
        defer { try? FileManager.default.removeItem(at: commands) }

        let monitor = CommandMonitor(commandsDirectory: commands, retryDelay: 0)
        let receivedCount = UncheckedCounter()
        monitor.onCommand = { _ in receivedCount.increment() }
        monitor.startMonitoring()

        atomicDropRaw("{ not json at all ", named: "bad.json", in: commands)

        await assertEventually(timeout: 10.0) { rejectedFileCount(in: commands) == 1 }
        monitor.stopMonitoring()

        XCTAssertEqual(receivedCount.value, 0)
        XCTAssertEqual(eligibleJSONCount(in: commands), 0)
    }

    func testUnknownActionIsQuarantined() async {
        let commands = makeTemporaryInboxDirectory()
        defer { try? FileManager.default.removeItem(at: commands) }

        let monitor = CommandMonitor(commandsDirectory: commands, retryDelay: 0)
        let receivedCount = UncheckedCounter()
        monitor.onCommand = { _ in receivedCount.increment() }
        monitor.startMonitoring()

        // Valid JSON, but an action the contract does not know: malformed, not surfaced.
        atomicDrop(
            ["action": "timer.blastoff", "endsAt": 9_999_999_999],
            named: "unknown.json",
            in: commands
        )

        await assertEventually(timeout: 10.0) { rejectedFileCount(in: commands) == 1 }
        monitor.stopMonitoring()

        XCTAssertEqual(receivedCount.value, 0)
        XCTAssertEqual(eligibleJSONCount(in: commands), 0)
    }

    /// King test: the CLI drops via `$DYNAMICNOTCH_COMMANDS`, the real monitor ingests it, and
    /// the command the script authored surfaces via `onCommand`.
    func testCLIDropThenRealMonitorIngestsIt() throws {
        let commands = makeTemporaryInboxDirectory()
        defer { try? FileManager.default.removeItem(at: commands) }

        let status = try runCLI(
            ["timer", "start", "--until", "9999999999", "--label", "Léa"],
            commands: commands
        )
        XCTAssertEqual(status, 0)

        let monitor = CommandMonitor(commandsDirectory: commands, retryDelay: 0)
        let ingested = expectation(description: "monitor ingests the CLI drop")
        let box = CommandBox()
        monitor.onCommand = { command in
            box.value = command
            ingested.fulfill()
        }
        monitor.startMonitoring()
        wait(for: [ingested], timeout: 10.0)
        monitor.stopMonitoring()

        XCTAssertEqual(
            box.value,
            .timerStart(endsAt: Date(timeIntervalSince1970: 9_999_999_999), label: "Léa")
        )
        XCTAssertEqual(eligibleJSONCount(in: commands), 0)
    }
}

private extension CommandMonitorIntegrationTests {
    func dynamicnotchBinaryURL() throws -> URL {
        if let override = ProcessInfo.processInfo.environment["DYNAMICNOTCH_CLI_BIN"],
           !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        let binary = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("dynamicnotch", isDirectory: false)
        try XCTSkipUnless(
            FileManager.default.isExecutableFile(atPath: binary.path),
            "dynamicnotch binary not found at \(binary.path)"
        )
        return binary
    }

    @discardableResult
    func runCLI(_ arguments: [String], commands: URL) throws -> Int32 {
        let process = Process()
        process.executableURL = try dynamicnotchBinaryURL()
        process.arguments = arguments

        var environment = ProcessInfo.processInfo.environment
        environment["DYNAMICNOTCH_COMMANDS"] = commands.path
        process.environment = environment

        process.standardOutput = Pipe()
        process.standardError = Pipe()
        process.standardInput = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}

/// Thread-safe holder — `onCommand` fires on the monitor's queue while the test thread reads it.
private final class CommandBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: CommandPayload?

    var value: CommandPayload? {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); defer { lock.unlock() }; stored = newValue }
    }
}
