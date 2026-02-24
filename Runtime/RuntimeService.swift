import Foundation

final class RuntimeService: @unchecked Sendable {
    static let currentRuntimeTagDefaultsKey = "currentRuntimeTag"
    static let remoteConfigFileName = "d2r-config.json"

    private let config: AppConfig
    private let logger: AppLogger
    private let processRunner: ProcessRunner
    private let releaseClient: GitHubReleaseClient
    private let session: URLSession

    init(
        config: AppConfig,
        logger: AppLogger,
        processRunner: ProcessRunner,
        releaseClient: GitHubReleaseClient = GitHubReleaseClient(),
        session: URLSession = .shared
    ) {
        self.config = config
        self.logger = logger
        self.processRunner = processRunner
        self.releaseClient = releaseClient
        self.session = session
    }

    func fetchLatestRelease() async throws -> GitHubRelease {
        let release = try await releaseClient.latestRelease(owner: config.runtimeRepoOwner, repo: config.runtimeRepoName)
        await logger.log(.info, "Latest runtime release: \(release.tagName)")
        return release
    }

    func installOrUpdateLatestRuntime(progress: @escaping @Sendable (Double) -> Void) async throws -> String {
        try AppPaths.ensureBaseDirectories()
        progress(0.01)

        let release = try await fetchLatestRelease()
        let assets = try release.selectedRuntimeAssets(
            archiveName: config.runtimeAssetName,
            checksumName: config.runtimeSHAAssetName,
            remoteConfigName: config.runtimeRemoteConfigName
        )

        let runtimeTag = normalizedTag(from: release.tagName)
        await logger.log(.info, "Preparing runtime release \(release.tagName)")

        let archiveDestination = AppPaths.downloadsDirectory
            .appendingPathComponent("\(runtimeTag)-\(assets.archive.name)", isDirectory: false)
        let checksumDestination = AppPaths.downloadsDirectory
            .appendingPathComponent("\(runtimeTag)-\(assets.checksum.name)", isDirectory: false)

        progress(0.05)
        try await downloadAsset(
            assets.checksum,
            to: checksumDestination,
            progressRange: 0.05...0.15,
            progress: progress
        )
        try await downloadAsset(
            assets.archive,
            to: archiveDestination,
            progressRange: 0.15...0.75,
            progress: progress
        )

        let checksumText = try String(contentsOf: checksumDestination, encoding: .utf8)
        guard let expectedChecksum = SHA256Verifier.parseChecksum(checksumText) else {
            throw AppError.operationFailed("Could not parse checksum file \(checksumDestination.lastPathComponent)")
        }

        progress(0.78)
        let checksumMatches = try SHA256Verifier.verify(fileURL: archiveDestination, expectedChecksum: expectedChecksum)
        guard checksumMatches else {
            throw AppError.operationFailed("SHA256 mismatch for \(archiveDestination.lastPathComponent)")
        }

        await logger.log(.info, "Checksum verified for \(archiveDestination.lastPathComponent)")

        let fileManager = FileManager.default
        let stagingRoot = AppPaths.runtimeDirectory
            .appendingPathComponent(".staging-\(runtimeTag)-\(UUID().uuidString)", isDirectory: true)
        let unpackDirectory = stagingRoot.appendingPathComponent("unpacked", isDirectory: true)
        try fileManager.createDirectory(at: unpackDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingRoot) }

        progress(0.80)
        try await unpackArchive(archiveURL: archiveDestination, destinationDirectory: unpackDirectory)

        let resolvedRoot = try resolveRuntimeRoot(in: unpackDirectory)
        let destinationRoot = AppPaths.runtimeDirectory.appendingPathComponent(runtimeTag, isDirectory: true)
        if fileManager.fileExists(atPath: destinationRoot.path) {
            try fileManager.removeItem(at: destinationRoot)
        }
        try fileManager.moveItem(at: resolvedRoot, to: destinationRoot)

        progress(0.92)
        let manifest = try validateRuntime(at: destinationRoot)
        await logger.log(.info, "Validated runtime binaries at \(manifest.runtimeRoot.path)")

        if let remoteAsset = assets.remoteConfig {
            let remoteConfigURL = destinationRoot.appendingPathComponent(Self.remoteConfigFileName, isDirectory: false)
            try await downloadAsset(
                remoteAsset,
                to: remoteConfigURL,
                progressRange: 0.92...0.98,
                progress: progress
            )
            _ = try? loadRemoteConfig(at: remoteConfigURL)
            await logger.log(.info, "Downloaded remote config \(remoteAsset.name)")
        }

        progress(0.99)
        UserDefaults.standard.set(release.tagName, forKey: Self.currentRuntimeTagDefaultsKey)
        UserDefaults.standard.set(manifest.runtimeRoot.path, forKey: "currentRuntimeRootPath")
        progress(1.0)
        await logger.log(.info, "Runtime \(release.tagName) installed to \(destinationRoot.path)")
        return release.tagName
    }

    func currentRuntimeRoot() -> URL? {
        guard let tag = UserDefaults.standard.string(forKey: Self.currentRuntimeTagDefaultsKey) else {
            return nil
        }
        let runtimeRoot = AppPaths.runtimeDirectory.appendingPathComponent(tag, isDirectory: true)
        return FileManager.default.fileExists(atPath: runtimeRoot.path) ? runtimeRoot : nil
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

    func loadRemoteConfig(at remoteConfigURL: URL) throws -> RuntimeRemoteConfig {
        let data = try Data(contentsOf: remoteConfigURL)
        return try JSONDecoder().decode(RuntimeRemoteConfig.self, from: data)
    }

    func validateRuntime(at runtimeRoot: URL) throws -> RuntimeValidationManifest {
        let paths = runtimeExecutablePaths(runtimeRoot: runtimeRoot)
        let installer = runtimeInstallerPath(runtimeRoot: runtimeRoot)

        try ensureExecutableExists(paths.wine64)
        try ensureExecutableExists(paths.wineserver)
        try ensureExecutableExists(paths.wineboot)

        return RuntimeValidationManifest(
            runtimeRoot: runtimeRoot,
            wine64: paths.wine64,
            wineserver: paths.wineserver,
            wineboot: paths.wineboot,
            installer: installer
        )
    }

    private func normalizedTag(from rawTag: String) -> String {
        rawTag.replacingOccurrences(of: "/", with: "-")
    }

    private func ensureExecutableExists(_ url: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            throw AppError.fileMissing(url.path)
        }

        var permissions = (try? fileManager.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?.intValue ?? 0o644
        if permissions & 0o111 == 0 {
            permissions |= 0o755
            try fileManager.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path)
        }
    }

    private func downloadAsset(
        _ asset: GitHubRelease.Asset,
        to destination: URL,
        progressRange: ClosedRange<Double>,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        await logger.log(.info, "Downloading \(asset.name)")

        try await downloadFile(
            from: asset.browserDownloadURL,
            to: destination,
            progress: { fraction in
                let mapped = progressRange.lowerBound + (progressRange.upperBound - progressRange.lowerBound) * fraction
                progress(mapped)
            }
        )
    }

    private func downloadFile(
        from sourceURL: URL,
        to destinationURL: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let tempURL = destinationURL.appendingPathExtension("part")
        if fileManager.fileExists(atPath: tempURL.path) {
            try fileManager.removeItem(at: tempURL)
        }
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        guard fileManager.createFile(atPath: tempURL.path, contents: nil) else {
            throw AppError.operationFailed("Could not create temporary download file at \(tempURL.path)")
        }

        let request = URLRequest(url: sourceURL)
        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.operationFailed("Unexpected response while downloading \(sourceURL.absoluteString)")
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw AppError.operationFailed("Download failed (HTTP \(httpResponse.statusCode)) for \(sourceURL.absoluteString)")
        }

        let expectedLength = response.expectedContentLength > 0 ? response.expectedContentLength : nil
        var receivedLength: Int64 = 0
        var chunk = Data()
        let handle = try FileHandle(forWritingTo: tempURL)
        defer {
            try? handle.close()
        }

        for try await byte in bytes {
            chunk.append(byte)
            receivedLength += 1

            if chunk.count >= 64 * 1024 {
                try handle.write(contentsOf: chunk)
                chunk.removeAll(keepingCapacity: true)
            }

            if let expectedLength, expectedLength > 0 {
                progress(min(1.0, Double(receivedLength) / Double(expectedLength)))
            }
        }

        if !chunk.isEmpty {
            try handle.write(contentsOf: chunk)
        }

        try fileManager.moveItem(at: tempURL, to: destinationURL)
        progress(1.0)
    }

    private func unpackArchive(archiveURL: URL, destinationDirectory: URL) async throws {
        let lower = archiveURL.lastPathComponent.lowercased()

        if lower.hasSuffix(".zip") {
            let result = try await processRunner.run(
                executableURL: URL(fileURLWithPath: "/usr/bin/ditto"),
                arguments: ["-x", "-k", archiveURL.path, destinationDirectory.path]
            )
            guard result.exitCode == 0 else {
                throw AppError.operationFailed("Failed to unpack zip with ditto: \(result.stderr)")
            }
            return
        }

        if lower.hasSuffix(".tar.gz") || lower.hasSuffix(".tgz") {
            let result = try await processRunner.run(
                executableURL: URL(fileURLWithPath: "/usr/bin/tar"),
                arguments: ["-xzf", archiveURL.path, "-C", destinationDirectory.path]
            )
            guard result.exitCode == 0 else {
                throw AppError.operationFailed("Failed to unpack tar.gz: \(result.stderr)")
            }
            return
        }

        throw AppError.operationFailed("Unsupported runtime archive format: \(archiveURL.lastPathComponent)")
    }

    private func resolveRuntimeRoot(in unpackDirectory: URL) throws -> URL {
        if hasRequiredRuntimeFiles(in: unpackDirectory) {
            return unpackDirectory
        }

        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(
            at: unpackDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        while let candidate = enumerator?.nextObject() as? URL {
            let isDirectory = (try? candidate.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDirectory else { continue }

            if hasRequiredRuntimeFiles(in: candidate) {
                return candidate
            }
        }

        throw AppError.operationFailed("Unpacked runtime is missing required Wine binaries")
    }

    private func hasRequiredRuntimeFiles(in candidateRoot: URL) -> Bool {
        let wine64 = candidateRoot.appendingPathComponent(config.runtimePaths.wine64RelativePath, isDirectory: false)
        let wineserver = candidateRoot.appendingPathComponent(config.runtimePaths.wineserverRelativePath, isDirectory: false)
        let wineboot = candidateRoot.appendingPathComponent(config.runtimePaths.winebootRelativePath, isDirectory: false)
        let fileManager = FileManager.default

        return fileManager.fileExists(atPath: wine64.path)
            && fileManager.fileExists(atPath: wineserver.path)
            && fileManager.fileExists(atPath: wineboot.path)
    }
}
