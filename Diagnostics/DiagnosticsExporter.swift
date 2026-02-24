import AppKit
import Darwin
import Foundation

final class DiagnosticsExporter: @unchecked Sendable {
    private let config: AppConfig
    private let logger: AppLogger
    private let processRunner: ProcessRunner

    init(config: AppConfig, logger: AppLogger, processRunner: ProcessRunner) {
        self.config = config
        self.logger = logger
        self.processRunner = processRunner
    }

    func exportDiagnostics(
        runtimeRoot: URL,
        runtimeTag: String?,
        d2rExecutablePath: String,
        recentLogText: String
    ) async throws -> URL {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let tempDir = AppPaths.logsDirectory.appendingPathComponent("diagnostics-\(timestamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let infoText = """
        Date: \(Date())
        App version: \(appVersionString)
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Architecture: \(ProcessInfo.processInfo.machineHardwareName)
        Runtime tag: \(runtimeTag ?? "none")
        Runtime root: \(runtimeRoot.path)
        Prefix: \(AppPaths.battleNetPrefix.path)
        D2R executable: \(d2rExecutablePath)
        DXVK enabled: \(config.enableDXVK)
        VKD3D enabled: \(config.enableVKD3D)
        WINEDEBUG: \(config.wineDebug)
        """

        try infoText.write(to: tempDir.appendingPathComponent("info.txt"), atomically: true, encoding: .utf8)
        try recentLogText.write(to: tempDir.appendingPathComponent("recent_app_log.txt"), atomically: true, encoding: .utf8)

        let runtimeManifest = try await runtimeManifestText(runtimeRoot: runtimeRoot)
        try runtimeManifest.write(to: tempDir.appendingPathComponent("runtime_manifest.txt"), atomically: true, encoding: .utf8)

        let prefixTree = try prefixTreeListing(maxEntries: 2_000)
        try prefixTree.write(to: tempDir.appendingPathComponent("prefix_tree.txt"), atomically: true, encoding: .utf8)

        let wineserverStatus = try await wineserverStatusOutput(runtimeRoot: runtimeRoot)
        try wineserverStatus.write(to: tempDir.appendingPathComponent("wineserver_status.txt"), atomically: true, encoding: .utf8)

        let zipURL = AppPaths.logsDirectory.appendingPathComponent("diagnostics-\(timestamp).zip", isDirectory: false)
        try await zipDirectory(sourceDirectory: tempDir, destinationZipURL: zipURL)

        NSWorkspace.shared.activateFileViewerSelecting([zipURL])
        await logger.log(.info, "Diagnostics zip created at \(zipURL.path)")

        return zipURL
    }

    private var appVersionString: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        return "\(shortVersion) (\(buildNumber))"
    }

    private func prefixTreeListing(maxEntries: Int) throws -> String {
        var count = 0
        var lines: [String] = []
        let root = AppPaths.battleNetPrefix

        guard FileManager.default.fileExists(atPath: root.path) else {
            return "Prefix does not exist at \(root.path)"
        }

        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let item = enumerator?.nextObject() as? URL {
            lines.append(item.path.replacingOccurrences(of: root.path + "/", with: ""))
            count += 1
            if count >= maxEntries {
                lines.append("...output truncated at \(maxEntries) entries...")
                break
            }
        }

        return lines.joined(separator: "\n")
    }

    private func wineserverStatusOutput(runtimeRoot: URL) async throws -> String {
        let wineserver = runtimeRoot.appendingPathComponent(config.runtimePaths.wineserverRelativePath, isDirectory: false)
        guard FileManager.default.isExecutableFile(atPath: wineserver.path) else {
            return "wineserver not found at \(wineserver.path)"
        }

        let env = WineEnvironment.baseEnvironment(prefixURL: AppPaths.battleNetPrefix, runtimeRoot: runtimeRoot, config: config)
        let result = try await processRunner.run(executableURL: wineserver, arguments: ["-v"], environment: env)
        return "Exit code: \(result.exitCode)\nstdout:\n\(result.stdout)\nstderr:\n\(result.stderr)"
    }

    private func runtimeManifestText(runtimeRoot: URL) async throws -> String {
        let wine64 = runtimeRoot.appendingPathComponent(config.runtimePaths.wine64RelativePath, isDirectory: false)
        let wineserver = runtimeRoot.appendingPathComponent(config.runtimePaths.wineserverRelativePath, isDirectory: false)
        let wineboot = runtimeRoot.appendingPathComponent(config.runtimePaths.winebootRelativePath, isDirectory: false)
        let installer = runtimeRoot.appendingPathComponent(config.runtimePaths.installerRelativePath, isDirectory: false)
        let env = WineEnvironment.baseEnvironment(prefixURL: AppPaths.battleNetPrefix, runtimeRoot: runtimeRoot, config: config)

        let wine64Version = try await commandSummaryIfExecutable(
            executable: wine64,
            arguments: ["--version"],
            environment: env
        )
        let wineserverVersion = try await commandSummaryIfExecutable(
            executable: wineserver,
            arguments: ["-v"],
            environment: env
        )

        return [
            "runtime_root=\(runtimeRoot.path)",
            "wine64=\(wine64.path)",
            "wine64_version=\(wine64Version)",
            "wineserver=\(wineserver.path)",
            "wineserver_version=\(wineserverVersion)",
            "wineboot=\(wineboot.path)",
            "installer=\(installer.path)",
            "installer_exists=\(FileManager.default.fileExists(atPath: installer.path))",
        ].joined(separator: "\n")
    }

    private func commandSummaryIfExecutable(
        executable: URL,
        arguments: [String],
        environment: [String: String]
    ) async throws -> String {
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            return "not executable"
        }

        let result = try await processRunner.run(
            executableURL: executable,
            arguments: arguments,
            environment: environment
        )

        let output = (result.stdout + "\n" + result.stderr)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " | ")
        return "exit=\(result.exitCode); output=\(output)"
    }

    private func zipDirectory(sourceDirectory: URL, destinationZipURL: URL) async throws {
        if FileManager.default.fileExists(atPath: destinationZipURL.path) {
            try FileManager.default.removeItem(at: destinationZipURL)
        }

        let result = try await processRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/ditto"),
            arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", sourceDirectory.path, destinationZipURL.path]
        )

        guard result.exitCode == 0 else {
            throw AppError.operationFailed("Failed to zip diagnostics: \(result.stderr)")
        }
    }
}

private extension ProcessInfo {
    var machineHardwareName: String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }
}
