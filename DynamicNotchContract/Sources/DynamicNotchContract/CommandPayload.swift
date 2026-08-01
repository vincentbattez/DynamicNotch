import Foundation

/// The script-authored contract dropped as JSON into the `commands/` folder. A Command
/// **acts** and **perishes**, opposite to a Notification (ADR-0002). The wire shape is a
/// discriminated union keyed on `action`, read first so the union is legible at a glance:
///
///     {"action": "timer.start", "endsAt": 1712345678, "label": "Fixer bug Léa"}
///
/// An unknown or absent `action` is a *malformed* drop — decoding fails, and the monitor
/// quarantines the file. New verbs (`stop`, `pause`) add a `case` without breaking the
/// contract. `endsAt` is an **absolute** epoch (seconds since 1970); expiry is a property of
/// the data, resolved app-side at ingestion (ADR-0002).
public enum CommandPayload: Equatable {
    /// Start (or replace) the Local timer, ending at the absolute instant `endsAt`. `label`
    /// is optional; a blank label is normalized to `nil` so empty ≡ absent.
    case timerStart(endsAt: Date, label: String?)

    /// The wire values of the `action` discriminant. A value outside this set is malformed.
    public enum Action: String {
        case timerStart = "timer.start"
    }

    private enum CodingKeys: String, CodingKey {
        case action, endsAt, label
    }
}

extension CommandPayload: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawAction = try container.decode(String.self, forKey: .action)
        guard let action = Action(rawValue: rawAction) else {
            throw DecodingError.dataCorruptedError(
                forKey: .action,
                in: container,
                debugDescription: "unknown action \"\(rawAction)\""
            )
        }

        switch action {
        case .timerStart:
            // `endsAt` is required epoch seconds; a missing/non-numeric value is malformed.
            let epoch = try container.decode(Double.self, forKey: .endsAt)
            let label = try container.decodeIfPresent(String.self, forKey: .label)
                .flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
            self = .timerStart(endsAt: Date(timeIntervalSince1970: epoch), label: label)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .timerStart(endsAt, label):
            try container.encode(Action.timerStart.rawValue, forKey: .action)
            try container.encode(endsAt.timeIntervalSince1970, forKey: .endsAt)
            try container.encodeIfPresent(label, forKey: .label)
        }
    }
}
