import XCTest
@testable import DynamicNotch

/// Unit coverage for the one testable seam of the CLI installer: `createSymlink`. The privileged
/// escalation and bundle-path resolution are process/UI glue exercised manually, but the symlink's
/// correctness and idempotency — the "ré-appui répare un symlink périmé" acceptance criterion — is
/// pinned here against a temp directory (never `/usr/local/bin`).
final class CLIToolInstallerTests: XCTestCase {
    private var workingDirectory: URL!

    override func setUpWithError() throws {
        workingDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("cli-installer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workingDirectory)
    }

    func testCreatesSymlinkPointingAtSource() throws {
        let source = workingDirectory.appendingPathComponent("bundle/dynamicnotch")
        try makeExecutable(at: source)
        let target = workingDirectory.appendingPathComponent("bin/dynamicnotch")

        try CLIToolInstaller.createSymlink(from: source, at: target)

        let destination = try FileManager.default.destinationOfSymbolicLink(atPath: target.path)
        XCTAssertEqual(destination, source.path)
    }

    func testCreatesMissingParentDirectory() throws {
        let source = workingDirectory.appendingPathComponent("dynamicnotch")
        try makeExecutable(at: source)
        // A parent that does not exist yet — mirrors an absent `/usr/local/bin`.
        let target = workingDirectory.appendingPathComponent("does/not/exist/dynamicnotch")

        try CLIToolInstaller.createSymlink(from: source, at: target)

        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
    }

    func testReRunRepairsStaleSymlink() throws {
        let target = workingDirectory.appendingPathComponent("bin/dynamicnotch")

        // First install points at an old bundle location that is then removed, leaving a broken link.
        let oldSource = workingDirectory.appendingPathComponent("old/dynamicnotch")
        try makeExecutable(at: oldSource)
        try CLIToolInstaller.createSymlink(from: oldSource, at: target)
        try FileManager.default.removeItem(at: oldSource.deletingLastPathComponent())

        // Re-running (app updated → new bundle path) must overwrite the dangling link without error.
        let newSource = workingDirectory.appendingPathComponent("new/dynamicnotch")
        try makeExecutable(at: newSource)
        try CLIToolInstaller.createSymlink(from: newSource, at: target)

        let destination = try FileManager.default.destinationOfSymbolicLink(atPath: target.path)
        XCTAssertEqual(destination, newSource.path)
    }

    func testOverwritesExistingRegularFile() throws {
        let source = workingDirectory.appendingPathComponent("dynamicnotch")
        try makeExecutable(at: source)
        let target = workingDirectory.appendingPathComponent("dynamicnotch-link")
        // A pre-existing regular file at the target must be replaced, not appended to.
        try Data("stale".utf8).write(to: target)

        try CLIToolInstaller.createSymlink(from: source, at: target)

        let destination = try FileManager.default.destinationOfSymbolicLink(atPath: target.path)
        XCTAssertEqual(destination, source.path)
    }

    // MARK: - installState classification

    func testAbsentTargetIsClassifiedAbsent() throws {
        let expected = bundleBinary(named: "DynamicNotch.app")
        let target = workingDirectory.appendingPathComponent("bin/dynamicnotch")

        XCTAssertEqual(CLIToolInstaller.installState(target: target, expectedBinary: expected), .absent)
    }

    func testSymlinkToExpectedBinaryIsInstalledCurrent() throws {
        let expected = bundleBinary(named: "DynamicNotch.app")
        try makeExecutable(at: expected)
        let target = workingDirectory.appendingPathComponent("bin/dynamicnotch")
        try CLIToolInstaller.createSymlink(from: expected, at: target)

        XCTAssertEqual(CLIToolInstaller.installState(target: target, expectedBinary: expected), .installedCurrent)
    }

    func testSymlinkToSameBinaryInOtherBundleIsInstalledOther() throws {
        let expected = bundleBinary(named: "current/DynamicNotch.app")
        try makeExecutable(at: expected)
        let other = bundleBinary(named: "moved/DynamicNotch.app")
        try makeExecutable(at: other)
        let target = workingDirectory.appendingPathComponent("bin/dynamicnotch")
        try CLIToolInstaller.createSymlink(from: other, at: target)

        XCTAssertEqual(CLIToolInstaller.installState(target: target, expectedBinary: expected), .installedOther)
    }

    func testDanglingSymlinkToOldBundleIsInstalledOther() throws {
        let expected = bundleBinary(named: "current/DynamicNotch.app")
        try makeExecutable(at: expected)
        let old = bundleBinary(named: "old/DynamicNotch.app")
        try makeExecutable(at: old)
        let target = workingDirectory.appendingPathComponent("bin/dynamicnotch")
        try CLIToolInstaller.createSymlink(from: old, at: target)
        // Remove the old bundle so the link dangles — an updated/moved app must still repair it.
        try FileManager.default.removeItem(at: workingDirectory.appendingPathComponent("old"))

        XCTAssertEqual(CLIToolInstaller.installState(target: target, expectedBinary: expected), .installedOther)
    }

    func testSymlinkOutsideDynamicNotchBundleIsForeign() throws {
        let expected = bundleBinary(named: "DynamicNotch.app")
        try makeExecutable(at: expected)
        // A Homebrew-style install: a symlink to an executable that is not inside a .app bundle.
        let foreign = workingDirectory.appendingPathComponent("homebrew/bin/dynamicnotch")
        try makeExecutable(at: foreign)
        let target = workingDirectory.appendingPathComponent("bin/dynamicnotch")
        try CLIToolInstaller.createSymlink(from: foreign, at: target)

        XCTAssertEqual(CLIToolInstaller.installState(target: target, expectedBinary: expected), .foreign)
    }

    func testRegularFileAtTargetIsForeign() throws {
        let expected = bundleBinary(named: "DynamicNotch.app")
        try makeExecutable(at: expected)
        let target = workingDirectory.appendingPathComponent("bin/dynamicnotch")
        try FileManager.default.createDirectory(
            at: target.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("#!/bin/sh\n".utf8).write(to: target)

        XCTAssertEqual(CLIToolInstaller.installState(target: target, expectedBinary: expected), .foreign)
    }

    private func bundleBinary(named bundle: String) -> URL {
        workingDirectory
            .appendingPathComponent(bundle)
            .appendingPathComponent("Contents/Helpers/dynamicnotch")
    }

    private func makeExecutable(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("#!/bin/sh\n".utf8).write(to: url)
    }
}
