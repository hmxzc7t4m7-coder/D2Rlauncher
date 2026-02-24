import Foundation

final class RepairService {
    private let config: AppConfig
    private let logger: AppLogger
    private let processRunner: ProcessRunner

    init(config: AppConfig, logger: AppLogger, processRunner: ProcessRunner) {
        self.config = config
        self.logger = logger
        self.processRunner = processRunner
    }

    func killAllWineProcesses(runtimeRoot: URL) async throws {
        let wineserver = runtimeRoot.appendingPathComponent(config.runtimePaths.wineserverRelativePath, isDirectory: false)
        guard FileManager.default.isExecutableFile(atPath: wineserver.path) else {
            throw AppError.fileMissing(wineserver.path)
        }

        let env = WineEnvironment.baseEnvironment(prefixURL: AppPaths.battleNetPrefix, runtimeRoot: runtimeRoot, config: config)
        let result = try await processRunner.run(executableURL: wineserver, arguments: ["-k"], environment: env)
        guard result.exitCode == 0 else {
            throw AppError.operationFailed("wineserver -k failed with code \(result.exitCode)")
        }

        await logger.log(.info, "All Wine processes requested to terminate.")
    }

    func clearBattleNetCaches() async throws {
        let paths = [
            AppPaths.battleNetPrefix
                .appendingPathComponent("drive_c/users/crossover/AppData/Roaming/Battle.net"),
            AppPaths.battleNetPrefix
                .appendingPathComponent("drive_c/users/crossover/AppData/Local/Battle.net"),
            AppPaths.battleNetPrefix
                .appendingPathComponent("drive_c/ProgramData/Battle.net")
        ]

        for path in paths where FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
            await logger.log(.info, "Removed cache folder: \(path.path)")
        }
    }

    func resetBlizzardAgent() async throws {
        let paths = [
            AppPaths.battleNetPrefix
                .appendingPathComponent("drive_c/ProgramData/Battle.net/Agent"),
            AppPaths.battleNetPrefix
                .appendingPathComponent("drive_c/users/crossover/AppData/ProgramData/Battle.net/Agent")
        ]

        for path in paths where FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
            await logger.log(.info, "Removed Blizzard Agent folder: \(path.path)")
        }
    }

    func safeReset(runtimeRoot: URL, launchAfterReset: Bool) async throws {
        let fileManager = FileManager.default
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backup = AppPaths.prefixesDirectory.appendingPathComponent("bnet-backup-\(timestamp)", isDirectory: true)

        if fileManager.fileExists(atPath: AppPaths.battleNetPrefix.path) {
            try fileManager.copyItem(at: AppPaths.battleNetPrefix, to: backup)
            try fileManager.removeItem(at: AppPaths.battleNetPrefix)
            await logger.log(.warning, "Backed up old prefix to \(backup.path)")
        }

        let prefixService = PrefixService(config: config, logger: logger, processRunner: processRunner)
        try await prefixService.createOrRepairPrefix(runtimeRoot: runtimeRoot)

        if launchAfterReset {
            let battleNetService = BattleNetService(config: config, logger: logger, processRunner: processRunner)
            try await battleNetService.launchBattleNet(runtimeRoot: runtimeRoot)
        }
    }
}
