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

    func isPrefixInitialized(prefixURL: URL = AppPaths.battleNetPrefix) -> Bool {
        let systemReg = prefixURL.appendingPathComponent("system.reg", isDirectory: false)
        return FileManager.default.fileExists(atPath: systemReg.path)
    }

    func createOrRepairPrefix(runtimeRoot: URL) async throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: AppPaths.battleNetPrefix, withIntermediateDirectories: true)

        let wineboot = runtimeRoot.appendingPathComponent(config.runtimePaths.winebootRelativePath, isDirectory: false)
        guard fileManager.isExecutableFile(atPath: wineboot.path) else {
            throw AppError.fileMissing(wineboot.path)
        }

        let actionLabel = isPrefixInitialized() ? "Repairing" : "Initializing"
        await logger.log(.info, "\(actionLabel) prefix at \(AppPaths.battleNetPrefix.path)")

        let env = WineEnvironment.baseEnvironment(prefixURL: AppPaths.battleNetPrefix, runtimeRoot: runtimeRoot, config: config)
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

        guard isPrefixInitialized() else {
            throw AppError.operationFailed("Prefix initialization did not create system.reg")
        }
    }
}
