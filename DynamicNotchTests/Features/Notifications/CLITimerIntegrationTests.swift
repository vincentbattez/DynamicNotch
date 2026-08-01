import DynamicNotchContract
import XCTest
@testable import DynamicNotch

/// Seam 2 (CLI half) + Seam 4: drives the *built* `dynamicnotch` binary for `timer start`.
/// The CLI drops into a temp `commands/` folder (via `$DYNAMICNOTCH_COMMANDS`); here we assert
/// the atomic drop shape and the argument-validation exit codes. The monitor-ingestion half of
/// the king test lives in `CommandMonitorIntegrationTests`. Mirrors `CLINotifyIntegrationTests`.
final class CLITimerIntegrationTests: XCTestCase {
    // MARK: - Seam 2: a valid drop lands atomically as one <uuid>.json

    func testUntilEpochDropsOneCommandCarryingLabel() throws {
        let commands = makeTemporaryInboxDirectory()
        defer { try? FileManager.default.removeItem(at: commands) }

        let status = try runCLI(
            ["timer", "start", "--until", "9999999999", "--label", "Fixer bug Léa"],
            commands: commands
        )
        XCTAssertEqual(status, 0)

        let dropped = eligibleJSONFiles(in: commands)
        XCTAssertEqual(dropped.count, 1)
        let name = try XCTUnwrap(dropped.first?.lastPathComponent)
        XCTAssertFalse(name.hasPrefix("."))
        XCTAssertTrue(name.hasSuffix(".json"))
        XCTAssertNotNil(UUID(uuidString: (name as NSString).deletingPathExtension))

        let decoded = try JSONDecoder().decode(
            CommandPayload.self,
            from: Data(contentsOf: try XCTUnwrap(dropped.first))
        )
        XCTAssertEqual(
            decoded,
            .timerStart(endsAt: Date(timeIntervalSince1970: 9_999_999_999), label: "Fixer bug Léa")
        )
    }

    func testDurationResolvesEndsAtInTheFutureCLISide() throws {
        let commands = makeTemporaryInboxDirectory()
        defer { try? FileManager.default.removeItem(at: commands) }

        let before = Date()
        let status = try runCLI(["timer", "start", "--duration", "1500"], commands: commands)
        XCTAssertEqual(status, 0)
        let after = Date()

        let file = try XCTUnwrap(eligibleJSONFiles(in: commands).first)
        let decoded = try JSONDecoder().decode(CommandPayload.self, from: Data(contentsOf: file))
        guard case let .timerStart(endsAt, label) = decoded else {
            return XCTFail("expected timerStart")
        }
        // Resolved CLI-side to its own now+1500, which lies between our two bookends.
        // Bounding against `after` keeps this stable however slow the process launch is.
        // The epsilon absorbs the JSON round-trip of the epoch, nothing more.
        XCTAssertGreaterThanOrEqual(endsAt.timeIntervalSince(before), 1500 - 0.001)
        XCTAssertLessThanOrEqual(endsAt.timeIntervalSince(after), 1500 + 0.001)
        XCTAssertNil(label)
    }

    func testPastUntilStillDropsBecauseAppDiscardsNotTheCLI() throws {
        let commands = makeTemporaryInboxDirectory()
        defer { try? FileManager.default.removeItem(at: commands) }

        // A `--until` already in the past is NOT a usage error: the CLI drops, the app discards.
        let status = try runCLI(["timer", "start", "--until", "100"], commands: commands)
        XCTAssertEqual(status, 0)
        XCTAssertEqual(eligibleJSONCount(in: commands), 1)
    }

    // MARK: - Seam 4: argument validation exits non-zero and drops nothing

    func testNoTimeFlagExitsNonZeroAndDropsNothing() throws {
        let commands = makeTemporaryInboxDirectory()
        defer { try? FileManager.default.removeItem(at: commands) }

        XCTAssertNotEqual(try runCLI(["timer", "start", "--label", "x"], commands: commands), 0)
        XCTAssertEqual(eligibleJSONCount(in: commands), 0)
    }

    func testBothTimeFlagsExitNonZeroAndDropNothing() throws {
        let commands = makeTemporaryInboxDirectory()
        defer { try? FileManager.default.removeItem(at: commands) }

        XCTAssertNotEqual(
            try runCLI(["timer", "start", "--until", "9999999999", "--duration", "60"], commands: commands),
            0
        )
        XCTAssertEqual(eligibleJSONCount(in: commands), 0)
    }

    func testNonPositiveDurationExitsNonZeroAndDropsNothing() throws {
        let commands = makeTemporaryInboxDirectory()
        defer { try? FileManager.default.removeItem(at: commands) }

        XCTAssertNotEqual(try runCLI(["timer", "start", "--duration", "0"], commands: commands), 0)
        XCTAssertNotEqual(try runCLI(["timer", "start", "--duration", "-5"], commands: commands), 0)
        XCTAssertEqual(eligibleJSONCount(in: commands), 0)
    }

    func testTimerStartHelpIsAvailable() throws {
        let root = try runCLICapturingStdout(["--help"])
        XCTAssertEqual(root.status, 0)
        XCTAssertTrue(root.stdout.contains("timer"))

        let start = try runCLICapturingStdout(["timer", "start", "--help"])
        XCTAssertEqual(start.status, 0)
        XCTAssertTrue(start.stdout.contains("--until"))
        XCTAssertTrue(start.stdout.contains("--duration"))
        XCTAssertTrue(start.stdout.contains("--label"))
    }
}

private extension CLITimerIntegrationTests {
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

    /// Launches the built CLI with `$DYNAMICNOTCH_COMMANDS` pointed at `commands`.
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

    func runCLICapturingStdout(_ arguments: [String]) throws -> (status: Int32, stdout: String) {
        let process = Process()
        process.executableURL = try dynamicnotchBinaryURL()
        process.arguments = arguments

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        process.standardInput = FileHandle.nullDevice

        try process.run()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
