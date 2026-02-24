import Foundation

struct ProcessResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

final class ProcessRunner: @unchecked Sendable {
    struct DetachedProcessHandle: Sendable {
        let pid: Int32
    }

    private final class DetachedProcessStore: @unchecked Sendable {
        private let queue = DispatchQueue(label: "D2RLauncher.ProcessRunner.DetachedStore")
        private var active: [Int32: Process] = [:]

        func retain(_ process: Process) {
            queue.sync {
                active[process.processIdentifier] = process
            }
        }

        func release(pid: Int32) {
            _ = queue.sync {
                active.removeValue(forKey: pid)
            }
        }
    }

    private final class OutputAccumulator: @unchecked Sendable {
        private let queue = DispatchQueue(label: "D2RLauncher.ProcessRunner.Accumulator")
        private var stdout = ""
        private var stderr = ""
        private var stdoutRemainder = ""
        private var stderrRemainder = ""

        func append(_ chunk: String, toErrorStream: Bool, outputHandler: ((String) -> Void)?) {
            queue.sync {
                if toErrorStream {
                    stderr.append(chunk)
                    stderrRemainder.append(chunk)
                    emitCompleteLines(from: &stderrRemainder, outputHandler: outputHandler)
                } else {
                    stdout.append(chunk)
                    stdoutRemainder.append(chunk)
                    emitCompleteLines(from: &stdoutRemainder, outputHandler: outputHandler)
                }
            }
        }

        func flush(outputHandler: ((String) -> Void)?) {
            queue.sync {
                if !stdoutRemainder.isEmpty {
                    outputHandler?(stdoutRemainder)
                    stdoutRemainder = ""
                }
                if !stderrRemainder.isEmpty {
                    outputHandler?(stderrRemainder)
                    stderrRemainder = ""
                }
            }
        }

        func snapshot() -> (stdout: String, stderr: String) {
            queue.sync { (stdout, stderr) }
        }

        private func emitCompleteLines(from remainder: inout String, outputHandler: ((String) -> Void)?) {
            let parts = remainder.components(separatedBy: .newlines)
            guard parts.count > 1 else { return }

            for line in parts.dropLast() where !line.isEmpty {
                outputHandler?(line)
            }
            remainder = parts.last ?? ""
        }
    }

    private let detachedStore = DetachedProcessStore()

    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String] = [:],
        currentDirectoryURL: URL? = nil,
        outputHandler: (@Sendable (String) -> Void)? = nil
    ) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            let accumulator = OutputAccumulator()

            do {
                process.executableURL = executableURL
                process.arguments = arguments
                process.currentDirectoryURL = currentDirectoryURL
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                var mergedEnvironment = ProcessInfo.processInfo.environment
                for (key, value) in environment {
                    mergedEnvironment[key] = value
                }
                process.environment = mergedEnvironment

                stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }
                    guard let chunk = String(data: data, encoding: .utf8) else { return }
                    accumulator.append(chunk, toErrorStream: false, outputHandler: outputHandler)
                }

                stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }
                    guard let chunk = String(data: data, encoding: .utf8) else { return }
                    accumulator.append(chunk, toErrorStream: true, outputHandler: outputHandler)
                }

                process.terminationHandler = { terminatedProcess in
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil

                    accumulator.flush(outputHandler: outputHandler)
                    let snapshot = accumulator.snapshot()
                    continuation.resume(returning: ProcessResult(
                        exitCode: terminatedProcess.terminationStatus,
                        stdout: snapshot.stdout,
                        stderr: snapshot.stderr
                    ))
                }

                try process.run()
            } catch {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: AppError.processLaunchFailed(error.localizedDescription))
            }
        }
    }

    func launchDetached(
        executableURL: URL,
        arguments: [String],
        environment: [String: String] = [:],
        currentDirectoryURL: URL? = nil
    ) throws -> DetachedProcessHandle {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        var mergedEnvironment = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            mergedEnvironment[key] = value
        }
        process.environment = mergedEnvironment

        process.terminationHandler = { [detachedStore] completed in
            detachedStore.release(pid: completed.processIdentifier)
        }

        do {
            try process.run()
            detachedStore.retain(process)
            return DetachedProcessHandle(pid: process.processIdentifier)
        } catch {
            throw AppError.processLaunchFailed(error.localizedDescription)
        }
    }
}
