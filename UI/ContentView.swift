import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 12) {
            StatusBannerView(
                isBusy: viewModel.isBusy,
                message: viewModel.lastErrorMessage ?? viewModel.statusBanner,
                isError: viewModel.lastErrorMessage != nil
            )

            ScrollView {
                VStack(spacing: 16) {
                    runtimeSection
                    prefixSection
                    battleNetSection
                    repairSection
                    diagnosticsSection
                    logsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
        }
        .padding(.top, 12)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Settings") {
                    viewModel.showingSettingsSheet = true
                }
            }
            ToolbarItem(placement: .automatic) {
                Button("About / Licenses") {
                    viewModel.showingLicensesSheet = true
                }
            }
        }
        .sheet(isPresented: $viewModel.showingSettingsSheet) {
            SettingsSheetView(viewModel: viewModel)
                .frame(minWidth: 600, minHeight: 520)
        }
        .sheet(isPresented: $viewModel.showingLicensesSheet) {
            AboutLicensesView()
                .frame(minWidth: 760, minHeight: 600)
        }
        .confirmationDialog(
            "Safe Reset will back up and rebuild your prefix. Continue?",
            isPresented: $viewModel.showSafeResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Run Safe Reset", role: .destructive) {
                viewModel.performSafeReset()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Battle.net and game files inside the prefix may need repairs afterward.")
        }
    }

    private var runtimeSection: some View {
        SectionBox(title: "Runtime") {
            LabeledContent("Current tag", value: viewModel.runtimeTag ?? "Not installed")
            LabeledContent("Runtime path", value: viewModel.currentRuntimePath)

            HStack {
                Button("Check Latest Release") { viewModel.checkForRuntimeUpdate() }
                Button("Install / Update Runtime") { viewModel.installOrUpdateRuntime() }
            }
        }
    }

    private var prefixSection: some View {
        SectionBox(title: "Prefix") {
            LabeledContent("Prefix path", value: viewModel.prefixPath)
            Button("Create / Repair Prefix") { viewModel.createOrRepairPrefix() }
        }
    }

    private var battleNetSection: some View {
        SectionBox(title: "Battle.net / D2R") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("D2R executable path", text: $viewModel.d2rExecutablePath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Button("Browse…") { viewModel.chooseD2RExecutable() }
                }

                HStack {
                    Button("Install Battle.net") { viewModel.installBattleNet() }
                    Button("Select Installer…") { viewModel.chooseBattleNetInstaller() }
                    if viewModel.config.battleNetInstallerDownloadURL != nil {
                        Button("Download Installer") { viewModel.downloadBattleNetInstaller() }
                    }
                }

                HStack {
                    Button("Launch Battle.net") { viewModel.launchBattleNet() }
                    Button("Launch D2R") { viewModel.launchD2R() }
                }
            }
        }
    }

    private var repairSection: some View {
        SectionBox(title: "Repair") {
            HStack {
                Button("Kill All Wine Processes") { viewModel.killAllWineProcesses() }
                Button("Clear Battle.net Caches") { viewModel.clearBattleNetCaches() }
                Button("Reset Blizzard Agent") { viewModel.resetBlizzardAgent() }
                Button("Safe Reset") { viewModel.showSafeResetConfirmation = true }
            }
        }
    }

    private var diagnosticsSection: some View {
        SectionBox(title: "Diagnostics") {
            Button("Export Diagnostics Zip") { viewModel.exportDiagnostics() }
        }
    }

    private var logsSection: some View {
        SectionBox(title: "Logs") {
            LogsView(logger: viewModel.logger)
        }
    }
}

private struct SectionBox<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
