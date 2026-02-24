import Foundation

final class RuntimeService {
    static let currentRuntimeTagDefaultsKey = "currentRuntimeTag"

    private let config: AppConfig
    private let logger: AppLogger
    private let processRunner: ProcessRunner
    private let releaseClient: GitHubReleaseClient

    init(
        config: AppConfig,
        logger: AppLogger,
        processRunner: ProcessRunner,
        releaseClient: GitHubReleaseClient = GitHubReleaseClient()
    ) {
        self.config = config
        self.logger = logger
        self.processRunner = processRunner
        self.releaseClient = releaseClient
    }

    func fetchLatestRelease() async throws -> GitHubRelease {
        let release = try await releaseClient.latestRelease(owner: config.runtimeRepoOwner, repo: config.runtimeRepoName)
        await logger.log(.info, "Latest runtime release: \(release.tagName)")
        return release
    }

    func installOrUpdateLatestRuntime(progress: @escaping @Sendable (Double) -> Void) async throws -> String {
        _ = processRunner
        progress(0)
        let release = try await fetchLatestRelease()
        progress(1)
        UserDefaults.standard.set(release.tagName, forKey: Self.currentRuntimeTagDefaultsKey)
        return release.tagName
    }

    func currentRuntimeRoot() -> URL? {
        guard let tag = UserDefaults.standard.string(forKey: Self.currentRuntimeTagDefaultsKey) else {
            return nil
        }
        return AppPaths.runtimeDirectory.appendingPathComponent(tag, isDirectory: true)
    }

    func runtimeExecutablePaths(runtimeRoot: URL) -> (wine64: URL, wineserver: URL, wineboot: URL) {
        (
            wine64: runtimeRoot.appendingPathComponent(config.runtimePaths.wine64RelativePath, isDirectory: false),
            wineserver: runtimeRoot.appendingPathComponent(config.runtimePaths.wineserverRelativePath, isDirectory: false),
            wineboot: runtimeRoot.appendingPathComponent(config.runtimePaths.winebootRelativePath, isDirectory: false)
        )
    }

    func runtimeInstallerPath(runtimeRoot: URL) -> URL {
        runtimeRoot.appendingPathComponent(config.runtimePaths.installerRelativePath, isDirectory: false)
    }
}
