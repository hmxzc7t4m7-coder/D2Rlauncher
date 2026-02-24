import Foundation

struct RuntimePathConfig: Codable, Sendable {
    var wine64RelativePath: String
    var wineserverRelativePath: String
    var winebootRelativePath: String
    var installerRelativePath: String

    static let `default` = RuntimePathConfig(
        wine64RelativePath: "bin/wine64",
        wineserverRelativePath: "bin/wineserver",
        winebootRelativePath: "bin/wineboot",
        installerRelativePath: "installers/Battle.net-Setup.exe"
    )
}

struct AppConfig: Codable, Sendable {
    var runtimeRepoOwner: String
    var runtimeRepoName: String

    var runtimeAssetName: String
    var runtimeSHAAssetName: String
    var runtimeRemoteConfigName: String

    var defaultD2RExecutablePath: String
    var battleNetInstallerDownloadURL: String?

    var wineDebug: String
    var enableDXVK: Bool
    var enableVKD3D: Bool
    var useVirtualDesktop: Bool
    var virtualDesktopResolution: String
    var dllOverrides: [String: String]
    var windowedMode: Bool

    var runtimePaths: RuntimePathConfig

    static func defaultConfig() -> AppConfig {
        AppConfig(
            runtimeRepoOwner: "hmxzc7t4m7-coder",
            runtimeRepoName: "D2Rlauncher",
            runtimeAssetName: "d2r-runtime-macos.tar.gz",
            runtimeSHAAssetName: "d2r-runtime-macos.tar.gz.sha256",
            runtimeRemoteConfigName: "d2r-config.json",
            defaultD2RExecutablePath: AppPaths.defaultD2RExecutablePath(),
            battleNetInstallerDownloadURL: nil,
            wineDebug: "-all",
            enableDXVK: true,
            enableVKD3D: true,
            useVirtualDesktop: false,
            virtualDesktopResolution: "1920x1080",
            dllOverrides: [:],
            windowedMode: false,
            runtimePaths: .default
        )
    }
}
