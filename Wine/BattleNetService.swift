import Foundation

final class BattleNetService: @unchecked Sendable {
    private let config: AppConfig
    private let logger: AppLogger
    private let processRunner: ProcessRunner
    private let session: URLSession

    init(config: AppConfig, logger: AppLogger, processRunner: ProcessRunner, session: URLSession = .shared) {
        self.config = config
        self.logger = logger
        self.processRunner = processRunner
        self.session = session
    }

    func installerPath(runtimeRoot: URL) -> URL {
        runtimeRoot.appendingPathComponent(config.runtimePaths.installerRelativePath, isDirectory: false)
    }

    func hasInstaller(runtimeRoot: URL) -> Bool {
        FileManager.default.fileExists(atPath: installerPath(runtimeRoot: runtimeRoot).path)
    }

    func importBattleNetInstaller(from sourceURL: URL, runtimeRoot: URL) throws {
        let destination = installerPath(runtimeRoot: runtimeRoot)
        let directory = destination.deletingLastPathComponent()
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)
    }

    func downloadBattleNetInstaller(from sourceURL: URL, runtimeRoot: URL, progress: @escaping @Sendable (Double) -> Void) async throws {
        let destination = installerPath(runtimeRoot: runtimeRoot)
        let directory = destination.deletingLastPathComponent()
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let request = URLRequest(url: sourceURL)
        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.operationFailed("Unexpected response while downloading Battle.net installer")
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw AppError.operationFailed("Installer download failed (HTTP \(httpResponse.statusCode))")
        }

        let tempURL = destination.appendingPathExtension("part")
        if fileManager.fileExists(atPath: tempURL.path) {
            try fileManager.removeItem(at: tempURL)
        }
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        guard fileManager.createFile(atPath: tempURL.path, contents: nil) else {
            throw AppError.operationFailed("Could not create temporary installer file")
        }

        let handle = try FileHandle(forWritingTo: tempURL)
        defer { try? handle.close() }

        let expectedLength = response.expectedContentLength > 0 ? response.expectedContentLength : nil
        var receivedLength: Int64 = 0
        var chunk = Data()
        for try await byte in bytes {
            chunk.append(byte)
            receivedLength += 1
            if chunk.count >= 64 * 1024 {
                try handle.write(contentsOf: chunk)
                chunk.removeAll(keepingCapacity: true)
            }
            if let expectedLength, expectedLength > 0 {
                progress(min(1.0, Double(receivedLength) / Double(expectedLength)))
            }
        }

        if !chunk.isEmpty {
            try handle.write(contentsOf: chunk)
        }

        try fileManager.moveItem(at: tempURL, to: destination)
        progress(1.0)
    }

    func installBattleNet(runtimeRoot: URL) async throws {
        let installer = installerPath(runtimeRoot: runtimeRoot)
        guard FileManager.default.fileExists(atPath: installer.path) else {
            throw AppError.operationFailed("Battle.net installer is missing. Use Select Installer first.")
        }

        let wine64 = runtimeRoot.appendingPathComponent(config.runtimePaths.wine64RelativePath, isDirectory: false)
        try await runWineBlocking(runtimeRoot: runtimeRoot, executable: wine64, arguments: [installer.path])
    }

    func launchBattleNet(runtimeRoot: URL) async throws {
        try ensurePrefixInitialized()

        let wine64 = runtimeRoot.appendingPathComponent(config.runtimePaths.wine64RelativePath, isDirectory: false)
        let launcherPath = AppPaths.battleNetPrefix
            .appendingPathComponent("drive_c", isDirectory: true)
            .appendingPathComponent("Program Files (x86)", isDirectory: true)
            .appendingPathComponent("Battle.net", isDirectory: true)
            .appendingPathComponent("Battle.net Launcher.exe", isDirectory: false)
            .path

        guard FileManager.default.fileExists(atPath: launcherPath) else {
            throw AppError.operationFailed("Battle.net launcher not found in prefix. Install Battle.net first.")
        }

        try launchWineDetached(runtimeRoot: runtimeRoot, executable: wine64, arguments: [launcherPath])
    }

    func launchD2R(runtimeRoot: URL, d2rExecutablePath: String) async throws {
        try ensurePrefixInitialized()
        guard FileManager.default.fileExists(atPath: d2rExecutablePath) else {
            throw AppError.fileMissing(d2rExecutablePath)
        }

        let wine64 = runtimeRoot.appendingPathComponent(config.runtimePaths.wine64RelativePath, isDirectory: false)
        try launchWineDetached(runtimeRoot: runtimeRoot, executable: wine64, arguments: [d2rExecutablePath])
    }

    private func ensurePrefixInitialized() throws {
        guard PrefixService(config: config, logger: logger, processRunner: processRunner).isPrefixInitialized() else {
            throw AppError.operationFailed("Prefix is not initialized. Run Create/Repair Prefix first.")
        }
    }

    private func runWineBlocking(runtimeRoot: URL, executable: URL, arguments: [String]) async throws {
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw AppError.fileMissing(executable.path)
        }

        let env = WineEnvironment.baseEnvironment(prefixURL: AppPaths.battleNetPrefix, runtimeRoot: runtimeRoot, config: config)
        await logger.log(.info, "Launching \(executable.lastPathComponent) \(arguments.joined(separator: " "))")

        let result = try await processRunner.run(
            executableURL: executable,
            arguments: arguments,
            environment: env
        )

        for line in (result.stdout + "\n" + result.stderr).split(whereSeparator: \.isNewline) {
            await logger.log(.debug, String(line))
        }

        guard result.exitCode == 0 else {
            throw AppError.operationFailed("Wine launch failed with code \(result.exitCode)")
        }
    }

    private func launchWineDetached(runtimeRoot: URL, executable: URL, arguments: [String]) throws {
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw AppError.fileMissing(executable.path)
        }

        let env = WineEnvironment.baseEnvironment(prefixURL: AppPaths.battleNetPrefix, runtimeRoot: runtimeRoot, config: config)
        let handle = try processRunner.launchDetached(
            executableURL: executable,
            arguments: arguments,
            environment: env
        )

        let logger = self.logger
        let message = "Launched process PID \(handle.pid): \(arguments.joined(separator: " "))"
        Task { @MainActor in
            logger.log(.info, message)
        }
    }
}
