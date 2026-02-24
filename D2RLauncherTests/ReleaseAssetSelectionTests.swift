import XCTest
@testable import D2RLauncher

final class ReleaseAssetSelectionTests: XCTestCase {
    func testFindsRequiredAssetsByName() throws {
        let release = GitHubRelease(
            tagName: "v1.2.3",
            name: "Runtime v1.2.3",
            draft: false,
            prerelease: false,
            assets: [
                .init(name: "d2r-runtime-macos.tar.gz", browserDownloadURL: URL(string: "https://example.com/runtime.tar.gz")!, size: 100),
                .init(name: "d2r-runtime-macos.tar.gz.sha256", browserDownloadURL: URL(string: "https://example.com/runtime.sha256")!, size: 12)
            ]
        )

        let archive = release.assets.first { $0.name == "d2r-runtime-macos.tar.gz" }
        let checksum = release.assets.first { $0.name == "d2r-runtime-macos.tar.gz.sha256" }

        XCTAssertNotNil(archive)
        XCTAssertNotNil(checksum)
    }
}
