# RuntimeSpec

This document defines the runtime bundle expected by D2RLauncher.

## Required Release Assets
- `d2r-runtime-macos.tar.gz`
- `d2r-runtime-macos.tar.gz.sha256`
- Optional `d2r-config.json`

## Expected Runtime Layout After Unpack

```
RuntimeRoot/
  bin/
    wine64
    wineserver
    wineboot
  installers/
    Battle.net-Setup.exe   (optional but preferred)
  tools/                   (optional)
  dxvk/                    (optional)
  vkd3d/                   (optional)
```

D2RLauncher validates `bin/wine64`, `bin/wineserver`, and `bin/wineboot`.

## Optional `d2r-config.json`
Supported override fields:
- `runtimePaths`
- `battleNetInstallerDownloadURL`
- `defaultD2RExecutablePath`
- `wineDebug`
- `enableDXVK`
- `enableVKD3D`
- `useVirtualDesktop`
- `virtualDesktopResolution`
- `dllOverrides`
- `windowedMode`

## Packaging Guidance
- Package runtime as `.tar.gz` with executable bits preserved.
- Include exact upstream license texts for bundled components.
- Publish source/offer compliance materials when LGPL obligations apply.

## Notes
- D2RLauncher treats runtime as external and versioned per GitHub release tag.
- Battle.net installer may be omitted; app supports in-app installer import and optional direct download URL.
