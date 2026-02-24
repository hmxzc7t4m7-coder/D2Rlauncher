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

        let selected = try release.selectedRuntimeAssets(
            archiveName: "d2r-runtime-macos.tar.gz",
            checksumName: "d2r-runtime-macos.tar.gz.sha256",
            remoteConfigName: "d2r-config.json"
        )

        XCTAssertEqual(selected.archive.name, "d2r-runtime-macos.tar.gz")
        XCTAssertEqual(selected.checksum.name, "d2r-runtime-macos.tar.gz.sha256")
        XCTAssertNil(selected.remoteConfig)
    }

    func testThrowsWhenRequiredAssetMissing() throws {
        let release = GitHubRelease(
            tagName: "v1.2.3",
            name: nil,
            draft: false,
            prerelease: false,
            assets: [
                .init(name: "d2r-runtime-macos.tar.gz", browserDownloadURL: URL(string: "https://example.com/runtime.tar.gz")!, size: 100)
            ]
        )

        XCTAssertThrowsError(
            try release.selectedRuntimeAssets(
                archiveName: "d2r-runtime-macos.tar.gz",
                checksumName: "d2r-runtime-macos.tar.gz.sha256",
                remoteConfigName: "d2r-config.json"
            )
        )
    }
}
