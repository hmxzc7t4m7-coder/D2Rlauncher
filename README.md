# D2RLauncher

D2RLauncher is a macOS SwiftUI utility app for launching Diablo II: Resurrected via Battle.net on Apple Silicon using a separately distributed Wine runtime bundle.

## Goals
- No Terminal required for end users.
- One-click runtime install/update from GitHub Releases.
- One-click prefix create/repair.
- One-click Battle.net install/launch and D2R launch.
- In-app repair toolkit and diagnostics zip export.

## System Requirements
- macOS 15+
- Apple Silicon (M-series)
- Xcode 26.x (current repo settings)

## Configure Before Shipping
Edit these values:

1. GitHub runtime repo owner/name:
- File: `Core/AppConfig.swift`
- Fields: `runtimeRepoOwner`, `runtimeRepoName`

2. Bundle identifier:
- File: `D2RLauncher.xcodeproj/project.pbxproj`
- Replace `com.example.D2RLauncher` and `com.example.D2RLauncherTests`

3. Optional Battle.net installer direct URL:
- File: `Core/AppConfig.swift`
- Field: `battleNetInstallerDownloadURL`
- Leave `nil` for safer default (user imports installer file in-app)

## Runtime Release Setup (GitHub)
App expects latest release from:

`https://api.github.com/repos/hmxzc7t4m7-coder/D2Rlauncher/releases/latest`

Each release must include:
- `d2r-runtime-macos.tar.gz`
- `d2r-runtime-macos.tar.gz.sha256`
- Optional: `d2r-config.json`

Runtime install pipeline:
- Download assets to `~/Library/Application Support/D2RLauncher/Downloads/`
- Verify SHA256
- Unpack into `~/Library/Application Support/D2RLauncher/Runtime/<tag>/`
- Validate required binaries (`wine64`, `wineserver`, `wineboot`)
- Persist current runtime tag in `UserDefaults`

## End-User Storage Paths
- App root: `~/Library/Application Support/D2RLauncher/`
- Runtime: `~/Library/Application Support/D2RLauncher/Runtime/`
- Prefix: `~/Library/Application Support/D2RLauncher/Prefixes/bnet/`
- Downloads: `~/Library/Application Support/D2RLauncher/Downloads/`
- Logs + diagnostics zips: `~/Library/Application Support/D2RLauncher/Logs/`

## Diagnostics
Use `Export Diagnostics Zip` in-app. It produces a zip in the Logs folder and reveals it in Finder.

Archive contains:
- `info.txt`
- `runtime_manifest.txt`
- `prefix_tree.txt` (capped)
- `recent_app_log.txt`
- `wineserver_status.txt`

## Legal Notes
- The app does not redistribute Diablo II: Resurrected binaries.
- Runtime distribution must include license compliance artifacts for Wine/DXVK/VKD3D.
- See `ThirdPartyNotices.md` and `RuntimeSpec.md`.
