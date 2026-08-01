import Foundation
import OSLog

/// Installs the `dynamicnotch` CLI (embedded in the app bundle at `Contents/Helpers/`) onto the
/// user's `PATH` by symlinking it at `/usr/local/bin/dynamicnotch`. The symlink points **into the
/// bundle**, so every app update transparently updates the CLI too.
///
/// The symlink logic (`createSymlink`) is a pure, parameterised seam so its idempotency and
/// overwrite semantics are unit-testable against a temp directory. The privilege escalation
/// (`installWithPrivileges`) is process/UI glue — a single `osascript … with administrator
/// privileges` prompt used only when `/usr/local/bin` isn't directly writable.
enum CLIToolInstaller {
    /// Where the symlink lands so `dynamicnotch` is reachable from any shell.
    static let symlinkPath = "/usr/local/bin/dynamicnotch"

    private static let logger = Logger(subsystem: "com.dynamicnotch.app", category: "CLIToolInstaller")

    /// Classification of what currently occupies the symlink target. This is the single source of
    /// truth shared by the silent launch attempt and the Settings row label — they can never
    /// diverge because both derive their decision from this one pure function.
    enum InstallState: Equatable {
        /// Nothing at the target — the automatic path creates the link; the button reads `Install`.
        case absent
        /// A symlink into the current bundle — nothing to do; the button reads `Installed`, disabled.
        case installedCurrent
        /// A symlink (possibly dangling) into *another* DynamicNotch bundle — a moved/updated/old
        /// build. The automatic path re-points it; the button reads `Repair`.
        case installedOther
        /// A regular file or a symlink that does not look like ours (Homebrew, manual copy). The
        /// automatic path never touches it; the button reads `Install` and shows a warning.
        case foreign
    }

    /// The in-bundle path segment identifying a `dynamicnotch` symlink that belongs to us: the
    /// embedded binary always lives at `…/Something.app/Contents/Helpers/dynamicnotch`.
    private static let ownedBundleSuffix = ".app/Contents/Helpers/dynamicnotch"

    /// Semantic result of an install attempt. The view maps each case to a localized message —
    /// the installer stays free of SwiftUI and localization so it can be exercised in tests.
    enum Outcome: Equatable {
        /// Symlink created directly (the target directory was writable).
        case installed
        /// Symlink created after the user approved the single administrator prompt.
        case installedWithPrivileges
        /// The embedded CLI binary was not found in the app bundle.
        case binaryMissing
        /// The administrator prompt was cancelled or refused — nothing was changed.
        case permissionDenied
        /// Any other failure, carrying the underlying message for diagnostics.
        case failed(String)
    }

    /// The embedded CLI binary inside the running app bundle. It lives under `Contents/Helpers/`
    /// (not `Contents/MacOS/`) because a case-insensitive filesystem would otherwise collide the
    /// `dynamicnotch` tool with the app's own `DynamicNotch` executable in the same directory.
    static var embeddedBinaryURL: URL {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/dynamicnotch", isDirectory: false)
    }

    /// Resolves the embedded binary, then tries a direct symlink; on any filesystem failure
    /// (typically a non-writable `/usr/local/bin` on Apple Silicon) it falls back to a single
    /// privileged prompt. Blocking — the escalation waits on the admin dialog, so call this off
    /// the main thread.
    static func install() -> Outcome {
        let source = embeddedBinaryURL
        guard FileManager.default.isExecutableFile(atPath: source.path) else {
            return .binaryMissing
        }

        let target = URL(fileURLWithPath: symlinkPath)
        do {
            try createSymlink(from: source, at: target)
            return .installed
        } catch {
            return installWithPrivileges(source: source)
        }
    }

    /// Classifies what sits at `target` relative to `expectedBinary` (the embedded CLI of the
    /// running bundle). Pure and parameterised on URLs so it is testable against a temp directory —
    /// this is the one seam the spec asks to cover. Compares the *raw* symlink destination against
    /// `expectedBinary.path` with no symlink resolution on either side, so a temp path under
    /// `/var` (→ `/private/var`) never spuriously mismatches.
    static func installState(target: URL, expectedBinary: URL) -> InstallState {
        let fileManager = FileManager.default

        guard let destination = try? fileManager.destinationOfSymbolicLink(atPath: target.path) else {
            // Not a symlink: either a regular file/dir (foreign) or genuinely absent.
            return fileManager.fileExists(atPath: target.path) ? .foreign : .absent
        }

        if destination == expectedBinary.path {
            return .installedCurrent
        }
        // Dangling links still report their stored destination, so an old/moved bundle lands here.
        return destination.contains(ownedBundleSuffix) ? .installedOther : .foreign
    }

    /// Convenience over `installState` bound to the running bundle and the real symlink target.
    static func currentInstallState() -> InstallState {
        installState(target: URL(fileURLWithPath: symlinkPath), expectedBinary: embeddedBinaryURL)
    }

    /// Silent best-effort install run at every launch. Never escalates and never destroys a
    /// `foreign` file — it creates or repairs the link only when the classification allows, and
    /// stays completely quiet otherwise (a failure leaves only a log line for diagnostics). Also
    /// self-guards against any test host: no suite must ever write to `/usr/local/bin`.
    static func installAutomaticallyIfPossible() {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        let source = embeddedBinaryURL
        guard FileManager.default.isExecutableFile(atPath: source.path) else { return }

        let target = URL(fileURLWithPath: symlinkPath)
        switch installState(target: target, expectedBinary: source) {
        case .installedCurrent, .foreign:
            return
        case .absent, .installedOther:
            do {
                try createSymlink(from: source, at: target)
            } catch {
                logger.error("Silent CLI install failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Testable core: (re)create a symlink at `target` pointing to `source`, overwriting any
    /// existing entry — a regular file or a stale/broken symlink from an earlier install. Creates
    /// the parent directory if absent. Throws if the parent can't be created or written to, which
    /// is exactly the signal `install()` uses to escalate.
    static func createSymlink(from source: URL, at target: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: target.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // `fileExists` follows symlinks, so a dangling one reports absent; remove unconditionally
        // and ignore "no such file" so re-runs stay idempotent.
        try? fileManager.removeItem(at: target)
        try fileManager.createSymbolicLink(at: target, withDestinationURL: source)
    }

    /// Runs one `osascript … with administrator privileges` that does `mkdir -p` + `ln -sf` in a
    /// single elevated shell call — one password prompt total. The bundle path is passed via
    /// `argv` and shell-escaped with AppleScript's `quoted form of`, never interpolated into the
    /// script string (bundle paths can contain spaces). A cancelled prompt (`-128`) surfaces as
    /// `.permissionDenied`, distinct from a genuine failure.
    private static func installWithPrivileges(source: URL) -> Outcome {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e", "on run argv",
            "-e", "do shell script \"/bin/mkdir -p /usr/local/bin && /bin/ln -sf \" "
                + "& quoted form of (item 1 of argv) & \" \(symlinkPath)\" "
                + "with administrator privileges",
            "-e", "end run",
            "--", source.path
        ]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        do {
            try process.run()
        } catch {
            return .failed(error.localizedDescription)
        }

        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            return .installedWithPrivileges
        }

        let message = String(decoding: errorData, as: UTF8.self)
        if message.contains("-128") || message.localizedCaseInsensitiveContains("cancel") {
            return .permissionDenied
        }
        return .failed(message.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
