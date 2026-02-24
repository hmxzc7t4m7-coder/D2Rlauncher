import XCTest
@testable import D2RLauncher

final class PathResolutionTests: XCTestCase {
    func testDefaultD2RPathEndsWithExecutable() throws {
        let path = AppPaths.defaultD2RExecutablePath(prefix: URL(fileURLWithPath: "/tmp/prefix", isDirectory: true))
        XCTAssertTrue(path.hasSuffix("/drive_c/Program Files (x86)/Diablo II Resurrected/D2R.exe"))
    }

    func testRuntimeConfigurationEndpointContainsOwnerAndRepo() throws {
        var config = AppConfig.defaultConfig()
        config.runtimeRepoOwner = "owner"
        config.runtimeRepoName = "repo"
        let endpoint = RuntimeConfiguration(appConfig: config).latestReleaseEndpoint.absoluteString
        XCTAssertEqual(endpoint, "https://api.github.com/repos/owner/repo/releases/latest")
    }

    func testRuntimeRelativePathsResolveAgainstRuntimeRoot() throws {
        let config = AppConfig.defaultConfig()
        let runtimeRoot = URL(fileURLWithPath: "/tmp/runtime", isDirectory: true)
        let wine64Path = runtimeRoot.appendingPathComponent(config.runtimePaths.wine64RelativePath).path
        let wineserverPath = runtimeRoot.appendingPathComponent(config.runtimePaths.wineserverRelativePath).path
        let winebootPath = runtimeRoot.appendingPathComponent(config.runtimePaths.winebootRelativePath).path

        XCTAssertTrue(wine64Path.hasSuffix("/tmp/runtime/bin/wine64"))
        XCTAssertTrue(wineserverPath.hasSuffix("/tmp/runtime/bin/wineserver"))
        XCTAssertTrue(winebootPath.hasSuffix("/tmp/runtime/bin/wineboot"))
    }
}
