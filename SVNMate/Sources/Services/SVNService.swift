import Foundation

final class SVNService {
    private let binaryResolver: SVNBinaryResolver
    private let commandRunner: SVNCommandRunner
    private let xmlParser: SVNXMLParser
    private let diskScanner: WorkingCopyDiskScanner
    private let snapshotAssembler: WorkingCopySnapshotAssembler
    private let settingsStore: SettingsStore

    init(
        binaryResolver: SVNBinaryResolver = SVNBinaryResolver(),
        commandRunner: SVNCommandRunner = SVNCommandRunner(),
        xmlParser: SVNXMLParser = SVNXMLParser(),
        diskScanner: WorkingCopyDiskScanner = WorkingCopyDiskScanner(),
        snapshotAssembler: WorkingCopySnapshotAssembler = WorkingCopySnapshotAssembler(),
        settingsStore: SettingsStore = SettingsStore()
    ) {
        self.binaryResolver = binaryResolver
        self.commandRunner = commandRunner
        self.xmlParser = xmlParser
        self.diskScanner = diskScanner
        self.snapshotAssembler = snapshotAssembler
        self.settingsStore = settingsStore
    }

    func info(at path: String) async throws -> SVNInfo {
        let result = try await execute(["info", "--xml"], at: path, timeout: timeout(for: .defaultOperation))
        return try xmlParser.parseInfo(result.stdout)
    }

    func treeConflictDetail(at repositoryPath: String, path: String) async throws -> SVNTreeConflictDetail? {
        let result = try await execute(
            ["info", "--xml", path],
            at: repositoryPath,
            timeout: timeout(for: .defaultOperation)
        )
        return try xmlParser.parseTreeConflictDetail(result.stdout)
    }

    func workingCopySnapshot(at path: String) async throws -> WorkingCopySnapshot {
        let result = try await execute(
            ["status", "--xml", "--depth", "infinity", "--no-ignore"],
            at: path,
            timeout: timeout(for: .defaultOperation)
        )
        let statusIndex = try xmlParser.parseStatus(result.stdout, basePath: path)
        let rootEntries = try diskScanner.scanDirectory(at: path)
        let rootNodes = snapshotAssembler.makeNodes(
            from: rootEntries,
            statusIndex: statusIndex,
            childrenLoaded: false
        )

        return WorkingCopySnapshot(
            rootNodes: rootNodes,
            issues: statusIndex.issues,
            statusIndex: statusIndex
        )
    }

    func loadDirectory(at repositoryPath: String, relativePath: String, statusIndex: WorkingCopyStatusIndex) throws -> [FileNode] {
        let entries = try diskScanner.scanDirectory(at: repositoryPath, relativePath: relativePath)
        return snapshotAssembler.makeNodes(
            from: entries,
            statusIndex: statusIndex,
            childrenLoaded: false
        )
    }

    func update(at path: String, revision: String? = nil) async throws -> String {
        var arguments = ["update", "--non-interactive"]
        if let revision, !revision.isEmpty {
            arguments.append(contentsOf: ["-r", revision])
        }

        return try await execute(arguments, at: path, timeout: timeout(for: .networkOperation)).stdout
    }

    func commit(at path: String, message: String, files: [String] = []) async throws -> String {
        var arguments = ["commit", "--non-interactive", "-m", message]
        arguments.append(contentsOf: files)
        return try await execute(arguments, at: path, timeout: timeout(for: .networkOperation)).stdout
    }

    func add(at path: String, files: [String]) async throws -> String {
        guard !files.isEmpty else {
            return ""
        }

        var arguments = ["add", "--non-interactive", "--force", "--parents"]
        arguments.append(contentsOf: files)
        return try await execute(arguments, at: path, timeout: timeout(for: .defaultOperation)).stdout
    }

    func checkout(
        url: String,
        to path: String,
        outputHandler: (@Sendable (SVNCommandOutputLine) -> Void)? = nil
    ) async throws -> String {
        try await execute(
            ["checkout", "--non-interactive", url, path],
            timeout: timeout(for: .checkoutOperation),
            outputHandler: outputHandler
        ).stdout
    }

    func diff(at path: String, file: String? = nil) async throws -> String {
        var arguments = ["diff"]
        if let file, !file.isEmpty {
            arguments.append(file)
        }

        return try await execute(arguments, at: path, timeout: timeout(for: .defaultOperation)).stdout
    }

    func log(at path: String, limit: Int = 10) async throws -> String {
        try await execute(["log", "--non-interactive", "-l", "\(limit)"], at: path, timeout: timeout(for: .logOperation)).stdout
    }

    func cleanup(at path: String) async throws -> String {
        try await execute(["cleanup"], at: path, timeout: timeout(for: .defaultOperation)).stdout
    }

    func resolve(at path: String, file: String, option: String = "working") async throws -> String {
        try await execute(["resolve", "--accept", option, file], at: path, timeout: timeout(for: .defaultOperation)).stdout
    }

    private func execute(
        _ arguments: [String],
        at path: String? = nil,
        timeout: TimeInterval? = nil,
        outputHandler: (@Sendable (SVNCommandOutputLine) -> Void)? = nil
    ) async throws -> SVNCommandResult {
        let executableURL = try binaryResolver.resolve()
        if let outputHandler {
            return try await commandRunner.run(
                executableURL: executableURL,
                arguments: arguments,
                currentDirectory: path,
                timeout: timeout,
                outputHandler: outputHandler
            )
        }

        return try await commandRunner.run(
            executableURL: executableURL,
            arguments: arguments,
            currentDirectory: path,
            timeout: timeout
        )
    }

    private func timeout(for key: AppTimeoutKey) -> TimeInterval {
        let settings = settingsStore.load()
        return TimeInterval(settings.timeouts.value(for: key))
    }
}
