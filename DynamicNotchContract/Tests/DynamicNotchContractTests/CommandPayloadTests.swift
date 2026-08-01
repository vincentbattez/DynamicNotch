import Foundation
import Testing
@testable import DynamicNotchContract

// Seam 1 — pure logic of the shared Command contract, no Xcode, no signing.

@Suite("CommandPayload Codable")
struct CommandPayloadCodableTests {
    @Test("round-trips a timer.start with an absolute endsAt and a label")
    func roundTripWithLabel() throws {
        let payload = CommandPayload.timerStart(
            endsAt: Date(timeIntervalSince1970: 1_712_345_678),
            label: "Fixer bug Léa"
        )

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(CommandPayload.self, from: data)

        #expect(decoded == payload)
    }

    @Test("round-trips a timer.start with no label, restoring nil")
    func roundTripNoLabel() throws {
        let payload = CommandPayload.timerStart(
            endsAt: Date(timeIntervalSince1970: 1_712_345_678),
            label: nil
        )

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(CommandPayload.self, from: data)

        #expect(decoded == payload)
        guard case let .timerStart(_, label) = decoded else {
            Issue.record("expected timerStart")
            return
        }
        #expect(label == nil)
    }

    @Test("puts action first with the wire value timer.start")
    func encodesActionWireValue() throws {
        let payload = CommandPayload.timerStart(
            endsAt: Date(timeIntervalSince1970: 1_712_345_678),
            label: "L"
        )

        let data = try JSONEncoder().encode(payload)
        let object = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(object["action"] as? String == "timer.start")
        #expect(object["endsAt"] as? Double == 1_712_345_678)
        #expect(object["label"] as? String == "L")
    }

    @Test("decodes a hand-authored timer.start from epoch seconds")
    func decodesHandAuthored() throws {
        let json = Data(#"{"action":"timer.start","endsAt":1712345678,"label":"Pomodoro"}"#.utf8)

        let decoded = try JSONDecoder().decode(CommandPayload.self, from: json)

        #expect(decoded == .timerStart(
            endsAt: Date(timeIntervalSince1970: 1_712_345_678),
            label: "Pomodoro"
        ))
    }

    @Test("normalizes a blank label to nil (empty ≡ absent)")
    func blankLabelBecomesNil() throws {
        let json = Data(#"{"action":"timer.start","endsAt":1712345678,"label":"   "}"#.utf8)

        let decoded = try JSONDecoder().decode(CommandPayload.self, from: json)

        guard case let .timerStart(_, label) = decoded else {
            Issue.record("expected timerStart")
            return
        }
        #expect(label == nil)
    }

    @Test("an unknown action is rejected as malformed")
    func unknownActionThrows() {
        let json = Data(#"{"action":"timer.blastoff","endsAt":1712345678}"#.utf8)

        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(CommandPayload.self, from: json)
        }
    }

    @Test("an absent action is rejected as malformed")
    func absentActionThrows() {
        let json = Data(#"{"endsAt":1712345678}"#.utf8)

        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(CommandPayload.self, from: json)
        }
    }

    @Test("a timer.start missing endsAt is rejected as malformed")
    func missingEndsAtThrows() {
        let json = Data(#"{"action":"timer.start","label":"x"}"#.utf8)

        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(CommandPayload.self, from: json)
        }
    }
}

@Suite("CommandFolder path derivation")
struct CommandFolderTests {
    @Test("defaultURL points at Application Support/DynamicNotch/commands, sibling of inbox")
    func defaultPath() {
        let url = CommandFolder.defaultURL
        #expect(url.lastPathComponent == "commands")
        #expect(url.deletingLastPathComponent().lastPathComponent == "DynamicNotch")
        // Sibling of the inbox: same parent directory.
        #expect(
            url.deletingLastPathComponent()
                == NotificationInbox.defaultURL.deletingLastPathComponent()
        )
    }

    @Test("resolvedURL honors $DYNAMICNOTCH_COMMANDS when set")
    func resolvedHonorsEnv() {
        let override = "/tmp/dynamicnotch-test-commands-\(UUID().uuidString)"
        setenv("DYNAMICNOTCH_COMMANDS", override, 1)
        defer { unsetenv("DYNAMICNOTCH_COMMANDS") }

        #expect(CommandFolder.resolvedURL.path == override)
    }

    @Test("resolvedURL falls back to defaultURL when env is unset")
    func resolvedFallsBack() {
        unsetenv("DYNAMICNOTCH_COMMANDS")
        #expect(CommandFolder.resolvedURL == CommandFolder.defaultURL)
    }
}
