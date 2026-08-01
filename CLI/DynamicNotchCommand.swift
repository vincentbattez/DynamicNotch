import ArgumentParser
import Foundation
import DynamicNotchContract

/// `dynamicnotch` — a thin CLI over the DynamicNotch file-drop contracts. It builds valid
/// payloads and drops them atomically, so scripts never hand-roll JSON escaping or the
/// temp-file `rename` dance.
@main
struct DynamicNotchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dynamicnotch",
        abstract: "Drive DynamicNotch from any process.",
        subcommands: [Notify.self, Timer.self]
    )
}

/// `dynamicnotch timer …` — Command drops that pilot the Local timer. `start` today; `stop` /
/// `pause` can join later without breaking the contract.
struct Timer: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Control the DynamicNotch Local timer.",
        subcommands: [Start.self]
    )

    struct Start: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Start (or replace) the Local timer via a command drop."
        )

        @Option(name: .long, help: "Absolute end instant: epoch seconds or ISO8601. XOR --duration.")
        var until: String?

        @Option(name: .long, help: "Whole seconds from now until the timer ends. XOR --until.")
        var duration: Int?

        @Option(name: .long, help: "Optional name shown under the countdown on the notch.")
        var label: String?

        func run() throws {
            do {
                let endsAt = try TimerStartCore.resolveEndsAt(
                    until: until,
                    duration: duration,
                    now: Date()
                )
                try TimerStartCore.run(
                    endsAt: endsAt,
                    label: label,
                    commands: CommandFolder.resolvedURL
                )
            } catch let error as TimerStartCore.UsageError {
                // Surface flag misuse as an ArgumentParser usage error (exit ≠ 0).
                throw ValidationError(error.description)
            }
        }
    }
}

/// Strict `--level` parsing: an unknown value yields `nil`, which argument-parser turns into
/// an immediate usage error (exit ≠ 0) — never a silent downgrade to `.info`.
extension NotificationLevel: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        self.init(rawValue: argument)
    }

    public static var allValueStrings: [String] { allCases.map(\.rawValue) }
}

struct Notify: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Drop a notification into the DynamicNotch inbox."
    )

    @Option(name: .long, help: "Short title.")
    var title: String

    @Option(name: .long, help: "Body text. Required via this flag OR piped on stdin.")
    var summary: String?

    @Option(name: .long, help: "Severity: info | success | warning | error.")
    var level: NotificationLevel = .info

    @Option(name: .long, help: "Coalescing key / subtitle.")
    var source: String?

    @Option(name: .long, help: "SF Symbol name (app-side fallback if invalid).")
    var icon: String?

    func run() throws {
        try NotifyCore.run(
            title: title,
            summary: try resolveSummary(),
            level: level,
            source: source,
            icon: icon,
            inbox: NotificationInbox.resolvedURL
        )
    }

    /// `--summary` wins; otherwise the whole of stdin is the summary. stdin is only consumed
    /// when it is piped/redirected — a TTY is treated as "no summary" so an interactive
    /// invocation errors immediately instead of blocking on `readDataToEndOfFile()`.
    private func resolveSummary() throws -> String {
        if let summary { return summary }

        if isatty(FileHandle.standardInput.fileDescriptor) == 0 {
            let data = FileHandle.standardInput.readDataToEndOfFile()
            let piped = String(decoding: data, as: UTF8.self)
            if !piped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return piped
            }
        }

        throw ValidationError("Provide --summary or pipe the body on stdin.")
    }
}
