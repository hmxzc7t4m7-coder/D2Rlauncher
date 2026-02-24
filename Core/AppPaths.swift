import Foundation

struct AppPaths {
    static let appSupportRoot: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        return base.appendingPathComponent("D2RLauncher", isDirectory: true)
    }()

    static let downloadsDirectory = appSupportRoot.appendingPathComponent("Downloads", isDirectory: true)
    static let runtimeDirectory = appSupportRoot.appendingPathComponent("Runtime", isDirectory: true)
    static let prefixesDirectory = appSupportRoot.appendingPathComponent("Prefixes", isDirectory: true)
    static let logsDirectory = appSupportRoot.appendingPathComponent("Logs", isDirectory: true)

    static let battleNetPrefix = prefixesDirectory.appendingPathComponent("bnet", isDirectory: true)

    static func defaultD2RExecutablePath(prefix: URL = AppPaths.battleNetPrefix) -> String {
        let path = prefix
            .appendingPathComponent("drive_c", isDirectory: true)
            .appendingPathComponent("Program Files (x86)", isDirectory: true)
            .appendingPathComponent("Diablo II Resurrected", isDirectory: true)
            .appendingPathComponent("D2R.exe", isDirectory: false)
            .path
        return path
    }

    static func ensureBaseDirectories() throws {
        let fileManager = FileManager.default
        for directory in [appSupportRoot, downloadsDirectory, runtimeDirectory, prefixesDirectory, logsDirectory] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
