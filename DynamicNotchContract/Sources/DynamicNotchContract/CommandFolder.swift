import Foundation

/// Single source of truth for *where* Command drops live — a sibling of the inbox, never the
/// inbox itself (ADR-0002). Both the app (ingesting) and the CLI (dropping) resolve the
/// directory here so they can never disagree.
public enum CommandFolder {
    /// `~/Library/Application Support/DynamicNotch/commands` — the canonical location, sibling
    /// of `NotificationInbox.defaultURL`.
    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DynamicNotch", isDirectory: true)
            .appendingPathComponent("commands", isDirectory: true)
    }

    /// `$DYNAMICNOTCH_COMMANDS` when set to a non-empty path (tests + power-users), otherwise
    /// `defaultURL`. Calqued on `NotificationInbox.resolvedURL` / `$DYNAMICNOTCH_INBOX`.
    public static var resolvedURL: URL {
        if let override = ProcessInfo.processInfo.environment["DYNAMICNOTCH_COMMANDS"],
           !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return defaultURL
    }
}
