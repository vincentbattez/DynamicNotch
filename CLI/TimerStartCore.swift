import Foundation
import DynamicNotchContract

/// The testable heart of `dynamicnotch timer start`: resolves the absolute end instant from
/// the mutually-exclusive `--until` / `--duration` flags and drops a `CommandPayload` into the
/// resolved `commands/` folder. Kept free of ArgumentParser so the resolution rules can be read
/// (and exercised through the binary) in one place. Mirrors `NotifyCore`.
enum TimerStartCore {
    enum UsageError: Error, CustomStringConvertible {
        case noTimeFlag
        case bothTimeFlags
        case nonPositiveDuration
        case unparsableUntil(String)

        var description: String {
            switch self {
            case .noTimeFlag:
                "Provide exactly one of --until <epoch|ISO8601> or --duration <seconds>."
            case .bothTimeFlags:
                "--until and --duration are mutually exclusive; pass exactly one."
            case .nonPositiveDuration:
                "--duration must be a positive number of seconds."
            case let .unparsableUntil(value):
                "--until must be epoch seconds or an ISO8601 instant, not \"\(value)\"."
            }
        }
    }

    /// Resolves `endsAt` from the flags, applying the XOR rule. `--duration` is added to `now`
    /// **here**, before any drop, so the emit→ingest lag never taints the result (ADR-0002).
    /// A `--until` already in the past is *not* an error — the CLI drops and the app discards.
    static func resolveEndsAt(until: String?, duration: Int?, now: Date) throws -> Date {
        switch (until, duration) {
        case (nil, nil):
            throw UsageError.noTimeFlag
        case (.some, .some):
            throw UsageError.bothTimeFlags
        case let (nil, .some(seconds)):
            guard seconds > 0 else { throw UsageError.nonPositiveDuration }
            return now.addingTimeInterval(TimeInterval(seconds))
        case let (.some(value), nil):
            guard let date = parseUntil(value) else {
                throw UsageError.unparsableUntil(value)
            }
            return date
        }
    }

    /// `--until` accepts epoch seconds (the path the Raycast script uses, kept bulletproof) or
    /// an ISO8601 instant as a convenience. Epoch is tried first.
    static func parseUntil(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if let epoch = Double(trimmed) {
            return Date(timeIntervalSince1970: epoch)
        }
        return ISO8601DateFormatter().date(from: trimmed)
    }

    /// Builds the `CommandPayload` and drops it atomically into `commands` (created if absent).
    /// Returns the URL of the placed `<uuid>.json` file.
    @discardableResult
    static func run(endsAt: Date, label: String?, commands: URL) throws -> URL {
        let normalized = label.flatMap {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0
        }
        return try AtomicInboxDrop.write(
            .timerStart(endsAt: endsAt, label: normalized),
            to: commands
        )
    }
}
