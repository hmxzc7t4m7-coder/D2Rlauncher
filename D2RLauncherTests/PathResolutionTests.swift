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
}
