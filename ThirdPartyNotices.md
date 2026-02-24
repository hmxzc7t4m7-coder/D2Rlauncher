# ThirdPartyNotices

D2RLauncher is a launcher utility that orchestrates a separately distributed runtime bundle.

## Wine (LGPL)
- Wine is licensed under LGPL.
- Runtime releases that include Wine binaries must include the corresponding license text and source/offer materials required by LGPL.
- D2RLauncher keeps runtime delivery separate (GitHub release assets) so legal artifacts can be versioned with each runtime build.

## DXVK
- DXVK licensing is defined by upstream release artifacts and included license files.
- Runtime releases must ship the exact DXVK license text for the bundled version.

## VKD3D
- VKD3D and related libraries are distributed under upstream licenses (often LGPL variants).
- Runtime releases must include the exact license text for the bundled version.

## Blizzard Software
- D2RLauncher does not redistribute Diablo II: Resurrected binaries.
- Battle.net installer should be bundled only where redistribution terms permit it.
- The app supports a safer fallback path: user-provided installer import from local disk (no terminal required).
