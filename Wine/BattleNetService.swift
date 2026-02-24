import Foundation

final class BattleNetService {
    private let config: AppConfig
    private let logger: AppLogger
    private let processRunner: ProcessRunner

    init(config: AppConfig, logger: AppLogger, processRunner: ProcessRunner) {
        self.config = config
        self.logger = logger
        self.processRunner = processRunner
    }

    func installBattleNet(runtimeRoot: URL) async throws {
        let installerPath = runtimeRoot.appendingPathComponent(config.runtimePaths.installerRelativePath, isDirectory: false)
        guard FileManager.default.fileExists(atPath: installerPath.path) else {
            throw AppError.fileMissing(installerPath.path)
        }

        let wine64 = runtimeRoot.appendingPathComponent(config.runtimePaths.wine64RelativePath, isDirectory: false)
        try await runWine(runtimeRoot: runtimeRoot, executable: wine64, arguments: [installerPath.path])
    }

    func launchBattleNet(runtimeRoot: URL) async throws {
        guard PrefixService(config: config, logger: logger, processRunner: processRunner).isPrefixInitialized() else {
            throw AppError.operationFailed("Prefix is not initialized. Run Create/Repair Prefix first.")
        }

        let wine64 = runtimeRoot.appendingPathComponent(config.runtimePaths.wine64RelativePath, isDirectory: false)
        let launcherPath = AppPaths.battleNetPrefix
            .appendingPathComponent("drive_c", isDirectory: true)
            .appendingPathComponent("Program Files (x86)", isDirectory: true)
            .appendingPathComponent("Battle.net", isDirectory: true)
            .appendingPathComponent("Battle.net Launcher.exe", isDirectory: false)
            .path

        try await runWine(runtimeRoot: runtimeRoot, executable: wine64, arguments: [launcherPath])
    }

    func launchD2R(runtimeRoot: URL, d2rExecutablePath: String) async throws {
        guard PrefixService(config: config, logger: logger, processRunner: processRunner).isPrefixInitialized() else {
            throw AppError.operationFailed("Prefix is not initialized. Run Create/Repair Prefix first.")
        }

        let wine64 = runtimeRoot.appendingPathComponent(config.runtimePaths.wine64RelativePath, isDirectory: false)
        try await runWine(runtimeRoot: runtimeRoot, executable: wine64, arguments: [d2rExecutablePath])
    }

    private func runWine(runtimeRoot: URL, executable: URL, arguments: [String]) async throws {
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw AppError.fileMissing(executable.path)
        }

        let env = WineEnvironment.baseEnvironment(prefixURL: AppPaths.battleNetPrefix, runtimeRoot: runtimeRoot, config: config)
        await logger.log(.info, "Launching \(executable.lastPathComponent) \(arguments.joined(separator: " "))")

        let result = try await processRunner.run(
            executableURL: executable,
            arguments: arguments,
            environment: env,
            outputHandler: { line in
                Task { @MainActor in
                    self.logger.log(.debug, line)
                }
            }
        )

        guard result.exitCode == 0 else {
            throw AppError.operationFailed("Wine launch failed with code \(result.exitCode)")
        }
    }
}
