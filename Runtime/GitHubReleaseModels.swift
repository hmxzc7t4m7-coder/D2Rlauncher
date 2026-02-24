import Foundation

struct GitHubRelease: Decodable, Sendable {
    struct Asset: Decodable, Sendable {
        let name: String
        let browserDownloadURL: URL
        let size: Int

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
            case size
        }
    }

    let tagName: String
    let name: String?
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case draft
        case prerelease
        case assets
    }
}

struct RuntimeReleaseAssets: Sendable {
    let archive: GitHubRelease.Asset
    let checksum: GitHubRelease.Asset
    let remoteConfig: GitHubRelease.Asset?
}

extension GitHubRelease {
    func selectedRuntimeAssets(
        archiveName: String,
        checksumName: String,
        remoteConfigName: String
    ) throws -> RuntimeReleaseAssets {
        guard let archive = assets.first(where: { $0.name == archiveName }) else {
            throw AppError.operationFailed("Release \(tagName) is missing required asset: \(archiveName)")
        }

        guard let checksum = assets.first(where: { $0.name == checksumName }) else {
            throw AppError.operationFailed("Release \(tagName) is missing required asset: \(checksumName)")
        }

        let remoteConfig = assets.first(where: { $0.name == remoteConfigName })
        return RuntimeReleaseAssets(archive: archive, checksum: checksum, remoteConfig: remoteConfig)
    }
}
