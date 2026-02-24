import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var isBusy = false
    @Published var statusBanner: String = "Ready"
    @Published var runtimeTag: String?
    @Published var currentRuntimePath: String = "Not installed"
    @Published var prefixPath: String = AppPaths.battleNetPrefix.path
    @Published var d2rExecutablePath: String = AppPaths.defaultD2RExecutablePath()
    @Published var showingSettingsSheet = false
    @Published var showingLicensesSheet = false
    @Published var showSafeResetConfirmation = false
    @Published var config: AppConfig = .defaultConfig()
    @Published var lastErrorMessage: String?

    let logger = AppLogger()

    let taskCoordinator = TaskCoordinator()
    let processRunner = ProcessRunner()

    private lazy var runtimeService = RuntimeService(config: config, logger: logger, processRunner: processRunner)
    private lazy var prefixService = PrefixService(config: config, logger: logger, processRunner: processRunner)
    private lazy var battleNetService = BattleNetService(config: config, logger: logger, processRunner: processRunner)
    private lazy var repairService = RepairService(config: config, logger: logger, processRunner: processRunner)
    private lazy var diagnosticsExporter = DiagnosticsExporter(config: config, logger: logger, processRunner: processRunner)

    func bootstrap() async {
        do {
            try AppPaths.ensureBaseDirectories()
            runtimeTag = UserDefaults.standard.string(forKey: RuntimeService.currentRuntimeTagDefaultsKey)
            if let tag = runtimeTag {
                currentRuntimePath = AppPaths.runtimeDirectory.appendingPathComponent(tag, isDirectory: true).path
            }
            logger.log(.info, "Initialized app directories in \(AppPaths.appSupportRoot.path)")
            await refreshDerivedPaths()
        } catch {
            await fail(error)
        }
    }

    func refreshDerivedPaths() async {
        d2rExecutablePath = config.defaultD2RExecutablePath
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

    func launchBattleNet() {
        runAction("Launch Battle.net") {
            guard let runtimeRoot = self.runtimeService.currentRuntimeRoot() else {
                throw AppError.runtimeNotInstalled
            }
            try await self.battleNetService.launchBattleNet(runtimeRoot: runtimeRoot)
        }
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
        config = .defaultConfig()
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
