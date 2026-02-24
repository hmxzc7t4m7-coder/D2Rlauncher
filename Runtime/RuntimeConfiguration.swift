import Foundation

struct RuntimeRemoteConfig: Codable, Sendable {
    var runtimePaths: RuntimePathConfig?
    var battleNetInstallerDownloadURL: String?
    var defaultD2RExecutablePath: String?
    var wineDebug: String?
    var enableDXVK: Bool?
    var enableVKD3D: Bool?
    var useVirtualDesktop: Bool?
    var virtualDesktopResolution: String?
    var dllOverrides: [String: String]?
    var windowedMode: Bool?
}

struct RuntimeValidationManifest: Sendable {
    let runtimeRoot: URL
    let wine64: URL
    let wineserver: URL
    let wineboot: URL
    let installer: URL
}

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
