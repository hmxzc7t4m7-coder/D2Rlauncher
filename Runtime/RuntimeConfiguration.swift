import Foundation

struct RuntimeConfiguration: Sendable {
    let owner: String
    let repo: String
    let runtimeArchiveName: String
    let checksumName: String
    let remoteConfigName: String
    let pathConfig: RuntimePathConfig

    init(appConfig: AppConfig) {
        self.owner = appConfig.runtimeRepoOwner
        self.repo = appConfig.runtimeRepoName
        self.runtimeArchiveName = appConfig.runtimeAssetName
        self.checksumName = appConfig.runtimeSHAAssetName
        self.remoteConfigName = appConfig.runtimeRemoteConfigName
        self.pathConfig = appConfig.runtimePaths
    }

    var latestReleaseEndpoint: URL {
        URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
    }
}
