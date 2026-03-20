import Foundation

final class SVNService {
    private enum Timeouts {
        static let defaultOperation: TimeInterval = 30
        static let networkOperation: TimeInterval = 300
        static let checkoutOperation: TimeInterval = 1_800
        static let logOperation: TimeInterval = 120
    }

    private let binaryResolver: SVNBinaryResolver
    private let commandRunner: SVNCommandRunner
    private let xmlParser: SVNXMLParser
    private let diskScanner: WorkingCopyDiskScanner
    private let snapshotAssembler: WorkingCopySnapshotAssembler

    init(
        binaryResolver: SVNBinaryResolver = SVNBinaryResolver(),
        commandRunner: SVNCommandRunner = SVNCommandRunner(),
        xmlParser: SVNXMLParser = SVNXMLParser(),
        diskScanner: WorkingCopyDiskScanner = WorkingCopyDiskScanner(),
        snapshotAssembler: WorkingCopySnapshotAssembler = WorkingCopySnapshotAssembler()
    ) {
        self.binaryResolver = binaryResolver
        self.commandRunner = commandRunner
        self.xmlParser = xmlParser
        self.diskScanner = diskScanner
        self.snapshotAssembler = snapshotAssembler
    }

    func info(at path: String) async throws -> SVNInfo {
        let result = try await execute(["info", "--xml"], at: path, timeout: Timeouts.defaultOperation)
        return try xmlParser.parseInfo(result.stdout)
    }

    func treeConflictDetail(at repositoryPath: String, path: String) async throws -> SVNTreeConflictDetail? {
        let result = try await execute(
            ["info", "--xml", path],
            at: repositoryPath,
            timeout: Timeouts.defaultOperation
        )
        return try xmlParser.parseTreeConflictDetail(result.stdout)
    }

    func workingCopySnapshot(at path: String) async throws -> WorkingCopySnapshot {
        let result = try await execute(
            ["status", "--xml", "--depth", "infinity", "--no-ignore"],
            at: path,
            timeout: Timeouts.defaultOperation
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

        return try await execute(arguments, at: path, timeout: Timeouts.networkOperation).stdout
    }

    func commit(at path: String, message: String, files: [String] = []) async throws -> String {
        var arguments = ["commit", "--non-interactive", "-m", message]
        arguments.append(contentsOf: files)
        return try await execute(arguments, at: path, timeout: Timeouts.networkOperation).stdout
    }

    func add(at path: String, files: [String]) async throws -> String {
        guard !files.isEmpty else {
            return ""
        }

        var arguments = ["add", "--non-interactive", "--force", "--parents"]
        arguments.append(contentsOf: files)
        return try await execute(arguments, at: path, timeout: Timeouts.defaultOperation).stdout
    }

    func checkout(
        url: String,
        to path: String,
        outputHandler: (@Sendable (SVNCommandOutputLine) -> Void)? = nil
    ) async throws -> String {
        try await execute(
            ["checkout", "--non-interactive", url, path],
            timeout: Timeouts.checkoutOperation,
            outputHandler: outputHandler
        ).stdout
    }

    func diff(at path: String, file: String? = nil) async throws -> String {
        var arguments = ["diff"]
        if let file, !file.isEmpty {
            arguments.append(file)
        }

        return try await execute(arguments, at: path, timeout: Timeouts.defaultOperation).stdout
    }

    func log(at path: String, limit: Int = 10) async throws -> String {
        try await execute(["log", "--non-interactive", "-l", "\(limit)"], at: path, timeout: Timeouts.logOperation).stdout
    }

    func cleanup(at path: String) async throws -> String {
        try await execute(["cleanup"], at: path, timeout: Timeouts.defaultOperation).stdout
    }

    func resolve(at path: String, file: String, option: String = "working") async throws -> String {
        try await execute(["resolve", "--accept", option, file], at: path, timeout: Timeouts.defaultOperation).stdout
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
}
