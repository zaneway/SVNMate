import Foundation

struct SVNCommandOutputLine: Sendable {
    enum Stream: Sendable {
        case stdout
        case stderr
    }

    let stream: Stream
    let text: String
}

struct SVNCommandResult {
    let executablePath: String
    let arguments: [String]
    let stdout: String
    let stderr: String
    let exitCode: Int32

    var commandDescription: String {
        ([executablePath] + arguments).map(Self.quote).joined(separator: " ")
    }

    private static func quote(_ value: String) -> String {
        if value.contains(" ") {
            return "\"\(value)\""
        }
        return value
    }
}

actor SVNCommandRunner {
    private let defaultTimeout: TimeInterval

    init(timeout: TimeInterval = 30) {
        self.defaultTimeout = timeout
    }

    func run(
        executableURL: URL,
        arguments: [String],
        currentDirectory: String? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> SVNCommandResult {
        try await execute(
            executableURL: executableURL,
            arguments: arguments,
            currentDirectory: currentDirectory,
            timeout: timeout,
            outputHandler: nil
        )
    }

    func run(
        executableURL: URL,
        arguments: [String],
        currentDirectory: String? = nil,
        timeout: TimeInterval? = nil,
        outputHandler: (@Sendable (SVNCommandOutputLine) -> Void)?
    ) async throws -> SVNCommandResult {
        try await execute(
            executableURL: executableURL,
            arguments: arguments,
            currentDirectory: currentDirectory,
            timeout: timeout,
            outputHandler: outputHandler
        )
    }

    private func execute(
        executableURL: URL,
        arguments: [String],
        currentDirectory: String?,
        timeout: TimeInterval?,
        outputHandler: (@Sendable (SVNCommandOutputLine) -> Void)?
    ) async throws -> SVNCommandResult {
        let state = CommandExecutionState()
        let collector = StreamingOutputCollector(outputHandler: outputHandler)
        let effectiveTimeout = timeout ?? defaultTimeout
        let command = SVNCommandResult(
            executablePath: executableURL.path,
            arguments: arguments,
            stdout: "",
            stderr: "",
            exitCode: 0
        ).commandDescription

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                state.store(continuation: continuation)

                DispatchQueue.global(qos: .userInitiated).async {
                    let process = Process()
                    process.executableURL = executableURL
                    process.arguments = arguments

                    if let currentDirectory {
                        process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
                    }

                    let stdoutPipe = Pipe()
                    let stderrPipe = Pipe()
                    let stdinPipe = Pipe()
                    stdinPipe.fileHandleForWriting.closeFile()
                    process.standardInput = stdinPipe
                    process.standardOutput = stdoutPipe
                    process.standardError = stderrPipe

                    state.store(process: process)
                    collector.attach(
                        stdout: stdoutPipe.fileHandleForReading,
                        stderr: stderrPipe.fileHandleForReading
                    )

                    do {
                        try process.run()
                    } catch {
                        collector.detach(
                            stdout: stdoutPipe.fileHandleForReading,
                            stderr: stderrPipe.fileHandleForReading
                        )
                        state.finish(
                            with: .failure(
                                SVNError(
                                    message: "Failed to launch svn command.",
                                    command: command,
                                    output: error.localizedDescription
                                )
                            )
                        )
                        return
                    }

                    let timeoutTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
                    timeoutTimer.schedule(deadline: .now() + effectiveTimeout)
                    timeoutTimer.setEventHandler {
                        state.terminate()
                        state.finish(
                            with: .failure(
                                SVNError(
                                    message: "SVN command timed out after \(Int(effectiveTimeout)) seconds.",
                                    command: command
                                )
                            )
                        )
                        timeoutTimer.cancel()
                    }

                    timeoutTimer.resume()
                    process.waitUntilExit()
                    timeoutTimer.cancel()

                    collector.detach(
                        stdout: stdoutPipe.fileHandleForReading,
                        stderr: stderrPipe.fileHandleForReading
                    )
                    collector.drainRemaining(
                        stdout: stdoutPipe.fileHandleForReading,
                        stderr: stderrPipe.fileHandleForReading
                    )

                    let output = collector.finalize()
                    let result = SVNCommandResult(
                        executablePath: executableURL.path,
                        arguments: arguments,
                        stdout: output.stdout,
                        stderr: output.stderr,
                        exitCode: process.terminationStatus
                    )

                    guard result.exitCode == 0 else {
                        let errorOutput = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? result.stdout : result.stderr
                        state.finish(
                            with: .failure(
                                SVNError(
                                    message: "SVN command failed.",
                                    command: result.commandDescription,
                                    output: errorOutput
                                )
                            )
                        )
                        return
                    }

                    state.finish(with: .success(result))
                }
            }
        } onCancel: {
            state.terminate()
            state.finish(
                with: .failure(
                    SVNError(
                        message: "SVN command was cancelled.",
                        command: command
                    )
                )
            )
        }
    }
}

private final class CommandExecutionState: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var continuation: CheckedContinuation<SVNCommandResult, Error>?
    private var hasFinished = false

    func store(process: Process) {
        lock.lock()
        self.process = process
        lock.unlock()
    }

    func store(continuation: CheckedContinuation<SVNCommandResult, Error>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    func terminate() {
        lock.lock()
        let process = self.process
        lock.unlock()

        if process?.isRunning == true {
            process?.terminate()
        }
    }

    func finish(with result: Result<SVNCommandResult, Error>) {
        lock.lock()
        guard !hasFinished else {
            lock.unlock()
            return
        }

        hasFinished = true
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()

        continuation?.resume(with: result)
    }
}

private final class StreamingOutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let outputHandler: (@Sendable (SVNCommandOutputLine) -> Void)?
    private var stdoutData = Data()
    private var stderrData = Data()
    private var stdoutLineBuffer = Data()
    private var stderrLineBuffer = Data()
    private var didFinalize = false

    init(outputHandler: (@Sendable (SVNCommandOutputLine) -> Void)?) {
        self.outputHandler = outputHandler
    }

    func attach(stdout: FileHandle, stderr: FileHandle) {
        stdout.readabilityHandler = { [weak self] handle in
            self?.consume(handle.availableData, stream: .stdout)
        }

        stderr.readabilityHandler = { [weak self] handle in
            self?.consume(handle.availableData, stream: .stderr)
        }
    }

    func detach(stdout: FileHandle, stderr: FileHandle) {
        stdout.readabilityHandler = nil
        stderr.readabilityHandler = nil
    }

    func drainRemaining(stdout: FileHandle, stderr: FileHandle) {
        consume(stdout.readDataToEndOfFile(), stream: .stdout)
        consume(stderr.readDataToEndOfFile(), stream: .stderr)
    }

    func finalize() -> (stdout: String, stderr: String) {
        let emittedLines: [SVNCommandOutputLine]
        let stdout: String
        let stderr: String

        lock.lock()
        guard !didFinalize else {
            let existingStdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let existingStderr = String(data: stderrData, encoding: .utf8) ?? ""
            lock.unlock()
            return (existingStdout, existingStderr)
        }

        didFinalize = true

        var bufferedLines = extractCompletedLines(from: &stdoutLineBuffer, stream: .stdout)
        bufferedLines.append(contentsOf: extractCompletedLines(from: &stderrLineBuffer, stream: .stderr))

        if !stdoutLineBuffer.isEmpty {
            bufferedLines.append(makeLine(from: stdoutLineBuffer, stream: .stdout))
            stdoutLineBuffer.removeAll(keepingCapacity: false)
        }

        if !stderrLineBuffer.isEmpty {
            bufferedLines.append(makeLine(from: stderrLineBuffer, stream: .stderr))
            stderrLineBuffer.removeAll(keepingCapacity: false)
        }

        emittedLines = bufferedLines.filter { !$0.text.isEmpty }
        stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        stderr = String(data: stderrData, encoding: .utf8) ?? ""
        lock.unlock()

        emit(lines: emittedLines)
        return (stdout, stderr)
    }

    private func consume(_ data: Data, stream: SVNCommandOutputLine.Stream) {
        guard !data.isEmpty else {
            return
        }

        let emittedLines: [SVNCommandOutputLine]

        lock.lock()
        if didFinalize {
            lock.unlock()
            return
        }

        switch stream {
        case .stdout:
            stdoutData.append(data)
            stdoutLineBuffer.append(data)
            emittedLines = extractCompletedLines(from: &stdoutLineBuffer, stream: .stdout)
        case .stderr:
            stderrData.append(data)
            stderrLineBuffer.append(data)
            emittedLines = extractCompletedLines(from: &stderrLineBuffer, stream: .stderr)
        }
        lock.unlock()

        emit(lines: emittedLines)
    }

    private func extractCompletedLines(
        from buffer: inout Data,
        stream: SVNCommandOutputLine.Stream
    ) -> [SVNCommandOutputLine] {
        var lines: [SVNCommandOutputLine] = []

        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer.prefix(upTo: newlineIndex)
            buffer.removeSubrange(...newlineIndex)
            lines.append(makeLine(from: Data(lineData), stream: stream))
        }

        return lines.filter { !$0.text.isEmpty }
    }

    private func makeLine(from data: Data, stream: SVNCommandOutputLine.Stream) -> SVNCommandOutputLine {
        let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .newlines) ?? ""
        return SVNCommandOutputLine(stream: stream, text: text)
    }

    private func emit(lines: [SVNCommandOutputLine]) {
        guard let outputHandler else {
            return
        }

        for line in lines {
            outputHandler(line)
        }
    }
}
