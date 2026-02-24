import SwiftUI

struct SettingsSheetView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Remote Defaults") {
                    Text(viewModel.remoteConfigStatus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("GitHub Runtime Repo") {
                    TextField("Owner", text: $viewModel.config.runtimeRepoOwner)
                    TextField("Repo", text: $viewModel.config.runtimeRepoName)
                    TextField("Runtime archive asset", text: $viewModel.config.runtimeAssetName)
                    TextField("SHA256 asset", text: $viewModel.config.runtimeSHAAssetName)
                    TextField("Remote config asset", text: $viewModel.config.runtimeRemoteConfigName)
                }

                Section("Battle.net / D2R") {
                    TextField("Default D2R executable path", text: $viewModel.config.defaultD2RExecutablePath)
                        .font(.system(.body, design: .monospaced))
                    TextField("Battle.net installer URL (optional)", text: Binding(
                        get: { viewModel.config.battleNetInstallerDownloadURL ?? "" },
                        set: { viewModel.config.battleNetInstallerDownloadURL = $0.isEmpty ? nil : $0 }
                    ))
                }

                Section("Compatibility") {
                    TextField("WINEDEBUG", text: $viewModel.config.wineDebug)
                    Toggle("Enable DXVK", isOn: $viewModel.config.enableDXVK)
                    Toggle("Enable VKD3D", isOn: $viewModel.config.enableVKD3D)
                    Toggle("Use virtual desktop", isOn: $viewModel.config.useVirtualDesktop)
                    TextField("Virtual desktop resolution", text: $viewModel.config.virtualDesktopResolution)
                    Toggle("Prefer windowed mode", isOn: $viewModel.config.windowedMode)
                    TextField("DLL overrides (e.g. d3d11=n,b;dxgi=n)", text: dllOverrideBinding)
                }

                Section("Runtime Relative Paths") {
                    TextField("wine64 path", text: $viewModel.config.runtimePaths.wine64RelativePath)
                    TextField("wineserver path", text: $viewModel.config.runtimePaths.wineserverRelativePath)
                    TextField("wineboot path", text: $viewModel.config.runtimePaths.winebootRelativePath)
                    TextField("Battle.net installer path", text: $viewModel.config.runtimePaths.installerRelativePath)
                }
            }
            .navigationTitle("Advanced Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel.showingSettingsSheet = false
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Reset to Defaults") {
                        viewModel.resetConfigToDefaults()
                    }
                }
            }
        }
    }

    private var dllOverrideBinding: Binding<String> {
        Binding(
            get: {
                viewModel.config.dllOverrides
                    .map { "\($0.key)=\($0.value)" }
                    .sorted()
                    .joined(separator: ";")
            },
            set: { newValue in
                viewModel.config.dllOverrides = parseDLLOverrides(newValue)
            }
        )
    }

    private func parseDLLOverrides(_ rawValue: String) -> [String: String] {
        let entries = rawValue.split(separator: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var overrides: [String: String] = [:]

        for entry in entries where !entry.isEmpty {
            let parts = entry.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { continue }
            overrides[parts[0]] = parts[1]
        }

        return overrides
    }
}
