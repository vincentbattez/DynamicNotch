import Dispatch
import DynamicNotchContract
import Foundation
import OSLog

/// Watches the `commands/` folder for `*.json` drops, parses each into a `CommandPayload`,
/// hands it off via `onCommand`, then removes the file. Malformed drops are retried once
/// (guarding against non-atomic writers) and, if still unparseable, quarantined in
/// `rejected/`. Decalques `NotificationInboxMonitor`; the folder and retry delay are injected
/// for testability. Expiry (`endsAt <= now`) is a routing decision, not the monitor's job — it
/// ingests every well-formed command and lets `CommandRouter` discard stale ones.
final class CommandMonitor: CommandMonitoring {
    var onCommand: ((CommandPayload) -> Void)?

    private let commandsDirectory: URL
    private let retryDelay: TimeInterval
    private let fileManager: FileManager
    private let queue = DispatchQueue(
        label: "com.dynamicnotch.commands.monitor",
        qos: .utility
    )
    private let logger = Logger(subsystem: "com.dynamicnotch", category: "Commands")

    private var directorySource: DispatchSourceFileSystemObject?
    private var isMonitoring = false
    private var processingPaths: Set<String> = []

    init(
        commandsDirectory: URL,
        retryDelay: TimeInterval = 0.2,
        fileManager: FileManager = .default
    ) {
        self.commandsDirectory = commandsDirectory
        self.retryDelay = retryDelay
        self.fileManager = fileManager
    }

    deinit {
        directorySource?.cancel()
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        queue.async { [weak self] in
            guard let self else { return }
            self.ensureDirectoryExists()
            // Arm the watcher *before* scanning so a drop landing during startup is either seen
            // by the scan or latched by the (already resumed) source — never missed.
            self.installDirectoryWatcher()
            self.scan()
        }
    }

    func stopMonitoring() {
        guard isMonitoring || directorySource != nil else { return }
        isMonitoring = false

        directorySource?.cancel()
        directorySource = nil

        queue.async { [weak self] in
            self?.processingPaths.removeAll()
        }
    }
}

private extension CommandMonitor {
    var rejectedDirectory: URL {
        commandsDirectory.appendingPathComponent("rejected", isDirectory: true)
    }

    func ensureDirectoryExists() {
        try? fileManager.createDirectory(
            at: commandsDirectory,
            withIntermediateDirectories: true
        )
    }

    func installDirectoryWatcher() {
        guard directorySource == nil else { return }

        let descriptor = open(commandsDirectory.path, O_EVTONLY)
        guard descriptor != -1 else {
            logger.debug("Commands directory is not available for watching")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.scan()
        }
        source.setCancelHandler {
            close(descriptor)
        }

        directorySource = source
        source.resume()
    }

    func scan() {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: commandsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for url in urls where isEligible(url) {
            process(url)
        }
    }

    func isEligible(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "json" && !url.lastPathComponent.hasPrefix(".")
    }

    func process(_ url: URL) {
        let path = url.standardizedFileURL.path
        guard processingPaths.insert(path).inserted else { return }

        if let command = parseCommand(at: url) {
            ingest(command, from: url)
            processingPaths.remove(path)
        } else {
            // Retry once after a short delay: a non-atomic writer may still be mid-write.
            queue.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
                guard let self else { return }

                if let command = self.parseCommand(at: url) {
                    self.ingest(command, from: url)
                } else {
                    self.reject(url)
                }
                self.processingPaths.remove(path)
            }
        }
    }

    func parseCommand(at url: URL) -> CommandPayload? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CommandPayload.self, from: data)
    }

    func ingest(_ command: CommandPayload, from url: URL) {
        onCommand?(command)
        try? fileManager.removeItem(at: url)
    }

    func reject(_ url: URL) {
        try? fileManager.createDirectory(
            at: rejectedDirectory,
            withIntermediateDirectories: true
        )

        var destination = rejectedDirectory.appendingPathComponent(url.lastPathComponent)
        if fileManager.fileExists(atPath: destination.path) {
            destination = rejectedDirectory.appendingPathComponent(
                "\(UUID().uuidString)-\(url.lastPathComponent)"
            )
        }

        do {
            try fileManager.moveItem(at: url, to: destination)
            logger.error("Quarantined malformed command file: \(url.lastPathComponent, privacy: .public)")
        } catch {
            // If the move fails (e.g. the file vanished), drop it rather than crash.
            try? fileManager.removeItem(at: url)
        }
    }
}
