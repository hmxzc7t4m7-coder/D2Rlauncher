import Foundation

final class PrefixService {
    private let config: AppConfig
    private let logger: AppLogger
    private let processRunner: ProcessRunner

    init(config: AppConfig, logger: AppLogger, processRunner: ProcessRunner) {
        self.config = config
        self.logger = logger
        self.processRunner = processRunner
    }

    func createOrRepairPrefix(runtimeRoot: URL) async throws {
        try FileManager.default.createDirectory(at: AppPaths.battleNetPrefix, withIntermediateDirectories: true)

        let wineboot = runtimeRoot.appendingPathComponent(config.runtimePaths.winebootRelativePath, isDirectory: false)
        guard FileManager.default.isExecutableFile(atPath: wineboot.path) else {
            throw AppError.fileMissing(wineboot.path)
        }

        await logger.log(.info, "Running wineboot for prefix at \(AppPaths.battleNetPrefix.path)")

        let env = WineEnvironment.baseEnvironment(prefixURL: AppPaths.battleNetPrefix, config: config)
        let result = try await processRunner.run(
            executableURL: wineboot,
            arguments: ["-u"],
            environment: env,
            outputHandler: { line in
                Task { @MainActor in
                    self.logger.log(.debug, line)
                }
            }
        )

        guard result.exitCode == 0 else {
            throw AppError.operationFailed("wineboot failed with code \(result.exitCode)")
        }
    }
}
