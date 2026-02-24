import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppViewModel: ObservableObject {
    private enum DefaultsKey {
        static let d2rExecutablePath = "d2rExecutablePath"
        static let configOverride = "configOverride"
    }

    @Published var isBusy = false
    @Published var statusBanner: String = "Ready"
    @Published var runtimeTag: String?
    @Published var currentRuntimePath: String = "Not installed"
    @Published var prefixPath: String = AppPaths.battleNetPrefix.path
    @Published var d2rExecutablePath: String = AppPaths.defaultD2RExecutablePath() {
        didSet {
            UserDefaults.standard.set(d2rExecutablePath, forKey: DefaultsKey.d2rExecutablePath)
        }
    }
    @Published var showingSettingsSheet = false
    @Published var showingLicensesSheet = false
    @Published var showSafeResetConfirmation = false
    @Published var config: AppConfig = .defaultConfig() {
        didSet {
            persistConfigOverrideIfNeeded()
        }
    }
    @Published var remoteConfigStatus: String = "Built-in defaults"
    @Published var lastErrorMessage: String?

    let logger = AppLogger()

    let taskCoordinator = TaskCoordinator()
    let processRunner = ProcessRunner()

    private var effectiveDefaultConfig = AppConfig.defaultConfig()
    private var isApplyingManagedConfig = false

    private var runtimeService: RuntimeService {
        RuntimeService(config: config, logger: logger, processRunner: processRunner)
    }

    private var prefixService: PrefixService {
        PrefixService(config: config, logger: logger, processRunner: processRunner)
    }

    private var battleNetService: BattleNetService {
        BattleNetService(config: config, logger: logger, processRunner: processRunner)
    }

    private var repairService: RepairService {
        RepairService(config: config, logger: logger, processRunner: processRunner)
    }

    private var diagnosticsExporter: DiagnosticsExporter {
        DiagnosticsExporter(config: config, logger: logger, processRunner: processRunner)
    }

    func bootstrap() async {
        do {
            try AppPaths.ensureBaseDirectories()
            runtimeTag = UserDefaults.standard.string(forKey: RuntimeService.currentRuntimeTagDefaultsKey)
            if let tag = runtimeTag {
                currentRuntimePath = AppPaths.runtimeDirectory.appendingPathComponent(tag, isDirectory: true).path
            }

            loadEffectiveDefaultsForCurrentRuntime()
            applyPersistedConfigOrDefaults()
            logger.log(.info, "Initialized app directories in \(AppPaths.appSupportRoot.path)")
            await refreshDerivedPaths()
        } catch {
            await fail(error)
        }
    }

    func refreshDerivedPaths() async {
        if let persisted = UserDefaults.standard.string(forKey: DefaultsKey.d2rExecutablePath), !persisted.isEmpty {
            d2rExecutablePath = persisted
        } else {
            d2rExecutablePath = config.defaultD2RExecutablePath
        }
    }

    func runAction(_ name: String, operation: @escaping @MainActor () async throws -> Void) {
        Task { @MainActor in
            do {
                try await taskCoordinator.runExclusive(named: name) {
                    self.isBusy = true
                    self.lastErrorMessage = nil
                    self.statusBanner = name
                    defer {
                        self.isBusy = false
                        self.statusBanner = "Ready"
                    }
                    self.logger.log(.info, "Starting: \(name)")
                    try await operation()
                    self.logger.log(.info, "Completed: \(name)")
                }
            } catch {
                await fail(error)
            }
        }
    }

    func checkForRuntimeUpdate() {
        runAction("Checking Runtime Release") {
            _ = try await self.runtimeService.fetchLatestRelease()
        }
    }

    func installOrUpdateRuntime() {
        runAction("Install/Update Runtime") {
            let tag = try await self.runtimeService.installOrUpdateLatestRuntime(progress: { progress in
                Task { @MainActor in
                    self.statusBanner = "Installing runtime \(Int(progress * 100))%"
                }
            })
            self.runtimeTag = tag
            self.currentRuntimePath = AppPaths.runtimeDirectory.appendingPathComponent(tag, isDirectory: true).path
            self.loadEffectiveDefaultsForCurrentRuntime()

            if !self.hasPersistedConfigOverride {
                self.applyManagedConfig(self.effectiveDefaultConfig)
            }
        }
    }

    func createOrRepairPrefix() {
        runAction("Create/Repair Prefix") {
            guard let runtimeRoot = self.runtimeService.currentRuntimeRoot() else {
                throw AppError.runtimeNotInstalled
            }
            try await self.prefixService.createOrRepairPrefix(runtimeRoot: runtimeRoot)
        }
    }

    func installBattleNet() {
        runAction("Install Battle.net") {
            guard let runtimeRoot = self.runtimeService.currentRuntimeRoot() else {
                throw AppError.runtimeNotInstalled
            }
            try await self.battleNetService.installBattleNet(runtimeRoot: runtimeRoot)
        }
    }

    func chooseBattleNetInstaller() {
        guard let runtimeRoot = runtimeService.currentRuntimeRoot() else {
            lastErrorMessage = AppError.runtimeNotInstalled.errorDescription
            return
        }

        let panel = NSOpenPanel()
        panel.title = "Select Battle.net Installer"
        panel.prompt = "Use Installer"
        panel.allowedContentTypes = [.data]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let sourceURL = panel.url else {
            return
        }

        runAction("Import Battle.net Installer") {
            try self.battleNetService.importBattleNetInstaller(from: sourceURL, runtimeRoot: runtimeRoot)
            self.logger.log(.info, "Imported installer to runtime \(runtimeRoot.lastPathComponent)")
        }
    }

    func downloadBattleNetInstaller() {
        guard let runtimeRoot = runtimeService.currentRuntimeRoot() else {
            lastErrorMessage = AppError.runtimeNotInstalled.errorDescription
            return
        }
        guard
            let rawURL = config.battleNetInstallerDownloadURL,
            let sourceURL = URL(string: rawURL)
        else {
            lastErrorMessage = "No Battle.net installer URL configured."
            return
        }

        runAction("Download Battle.net Installer") {
            try await self.battleNetService.downloadBattleNetInstaller(
                from: sourceURL,
                runtimeRoot: runtimeRoot,
                progress: { fraction in
                    Task { @MainActor in
                        self.statusBanner = "Downloading installer \(Int(fraction * 100))%"
                    }
                }
            )
            self.logger.log(.info, "Downloaded Battle.net installer from \(sourceURL.absoluteString)")
        }
    }

    func launchBattleNet() {
        runAction("Launch Battle.net") {
            guard let runtimeRoot = self.runtimeService.currentRuntimeRoot() else {
                throw AppError.runtimeNotInstalled
            }
            try await self.battleNetService.launchBattleNet(runtimeRoot: runtimeRoot)
        }
    }

    func chooseD2RExecutable() {
        let panel = NSOpenPanel()
        panel.title = "Select D2R.exe"
        panel.prompt = "Use Executable"
        panel.allowedContentTypes = [.data]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        d2rExecutablePath = selectedURL.path
        logger.log(.info, "Selected D2R executable: \(selectedURL.path)")
    }

    func launchD2R() {
        runAction("Launch Diablo II: Resurrected") {
            guard let runtimeRoot = self.runtimeService.currentRuntimeRoot() else {
                throw AppError.runtimeNotInstalled
            }
            try await self.battleNetService.launchD2R(runtimeRoot: runtimeRoot, d2rExecutablePath: self.d2rExecutablePath)
        }
    }

    func killAllWineProcesses() {
        runAction("Kill Wine Processes") {
            guard let runtimeRoot = self.runtimeService.currentRuntimeRoot() else {
                throw AppError.runtimeNotInstalled
            }
            try await self.repairService.killAllWineProcesses(runtimeRoot: runtimeRoot)
        }
    }

    func clearBattleNetCaches() {
        runAction("Clear Battle.net Caches") {
            try await self.repairService.clearBattleNetCaches()
        }
    }

    func resetBlizzardAgent() {
        runAction("Reset Blizzard Agent") {
            try await self.repairService.resetBlizzardAgent()
        }
    }

    func performSafeReset() {
        runAction("Safe Reset") {
            guard let runtimeRoot = self.runtimeService.currentRuntimeRoot() else {
                throw AppError.runtimeNotInstalled
            }
            try await self.repairService.safeReset(runtimeRoot: runtimeRoot, launchAfterReset: true)
        }
    }

    func exportDiagnostics() {
        runAction("Export Diagnostics") {
            guard let runtimeRoot = self.runtimeService.currentRuntimeRoot() else {
                throw AppError.runtimeNotInstalled
            }
            let diagnosticsURL = try await self.diagnosticsExporter.exportDiagnostics(
                runtimeRoot: runtimeRoot,
                runtimeTag: self.runtimeTag,
                d2rExecutablePath: self.d2rExecutablePath,
                recentLogText: self.logger.recentLines(limit: 500)
            )
            self.logger.log(.info, "Diagnostics exported to \(diagnosticsURL.path)")
        }
    }

    func resetConfigToDefaults() {
        UserDefaults.standard.removeObject(forKey: DefaultsKey.configOverride)
        applyManagedConfig(effectiveDefaultConfig)
        d2rExecutablePath = config.defaultD2RExecutablePath
    }

    private var hasPersistedConfigOverride: Bool {
        UserDefaults.standard.data(forKey: DefaultsKey.configOverride) != nil
    }

    private func applyManagedConfig(_ newConfig: AppConfig) {
        isApplyingManagedConfig = true
        config = newConfig
        isApplyingManagedConfig = false
    }

    private func applyPersistedConfigOrDefaults() {
        if
            let data = UserDefaults.standard.data(forKey: DefaultsKey.configOverride),
            let savedConfig = try? JSONDecoder().decode(AppConfig.self, from: data)
        {
            let (repairedConfig, didRepair) = repairedPersistedConfigIfNeeded(savedConfig)
            applyManagedConfig(repairedConfig)
            if didRepair {
                persistConfigOverrideIfNeeded()
                logger.log(.warning, "Repaired legacy placeholder GitHub repo settings in saved configuration.")
            }
        } else {
            applyManagedConfig(effectiveDefaultConfig)
        }
    }

    private func persistConfigOverrideIfNeeded() {
        guard !isApplyingManagedConfig else { return }
        guard let data = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(data, forKey: DefaultsKey.configOverride)
    }

    private func loadEffectiveDefaultsForCurrentRuntime() {
        let base = AppConfig.defaultConfig()
        guard
            let tag = runtimeTag,
            let url = remoteConfigURL(forTag: tag)
        else {
            effectiveDefaultConfig = base
            remoteConfigStatus = "Built-in defaults (no remote config)"
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let remote = try JSONDecoder().decode(RuntimeRemoteConfig.self, from: data)
            effectiveDefaultConfig = mergeRemoteConfig(remote, into: base)
            remoteConfigStatus = "Remote config loaded from \(url.lastPathComponent) (\(tag))"
        } catch {
            effectiveDefaultConfig = base
            remoteConfigStatus = "Remote config invalid, using built-in defaults"
            logger.log(.warning, "Failed to load remote config: \(error.localizedDescription)")
        }
    }

    private func remoteConfigURL(forTag tag: String) -> URL? {
        let runtimeRoot = AppPaths.runtimeDirectory.appendingPathComponent(tag, isDirectory: true)
        let configURL = runtimeRoot.appendingPathComponent(RuntimeService.remoteConfigFileName, isDirectory: false)
        return FileManager.default.fileExists(atPath: configURL.path) ? configURL : nil
    }

    private func mergeRemoteConfig(_ remote: RuntimeRemoteConfig, into base: AppConfig) -> AppConfig {
        var merged = base
        if let runtimePaths = remote.runtimePaths { merged.runtimePaths = runtimePaths }
        if let installerURL = remote.battleNetInstallerDownloadURL { merged.battleNetInstallerDownloadURL = installerURL }
        if let d2rPath = remote.defaultD2RExecutablePath { merged.defaultD2RExecutablePath = d2rPath }
        if let wineDebug = remote.wineDebug { merged.wineDebug = wineDebug }
        if let enableDXVK = remote.enableDXVK { merged.enableDXVK = enableDXVK }
        if let enableVKD3D = remote.enableVKD3D { merged.enableVKD3D = enableVKD3D }
        if let useVirtualDesktop = remote.useVirtualDesktop { merged.useVirtualDesktop = useVirtualDesktop }
        if let virtualDesktopResolution = remote.virtualDesktopResolution { merged.virtualDesktopResolution = virtualDesktopResolution }
        if let dllOverrides = remote.dllOverrides { merged.dllOverrides = dllOverrides }
        if let windowedMode = remote.windowedMode { merged.windowedMode = windowedMode }
        return merged
    }

    private func repairedPersistedConfigIfNeeded(_ persisted: AppConfig) -> (AppConfig, Bool) {
        var repaired = persisted
        var didRepair = false

        let owner = persisted.runtimeRepoOwner.trimmingCharacters(in: .whitespacesAndNewlines)
        if owner.isEmpty || owner == "YOUR_GH_OWNER" {
            repaired.runtimeRepoOwner = effectiveDefaultConfig.runtimeRepoOwner
            didRepair = true
        }

        let repo = persisted.runtimeRepoName.trimmingCharacters(in: .whitespacesAndNewlines)
        if repo.isEmpty || repo == "YOUR_GH_REPO" {
            repaired.runtimeRepoName = effectiveDefaultConfig.runtimeRepoName
            didRepair = true
        }

        return (repaired, didRepair)
    }

    private func fail(_ error: Error) async {
        let description: String
        if let localizedError = error as? LocalizedError, let detail = localizedError.errorDescription {
            description = detail
        } else {
            description = error.localizedDescription
        }

        isBusy = false
        statusBanner = "Error"
        lastErrorMessage = description
        logger.log(.error, description)
    }
}
