# Manual Test Checklist

## Fresh Install Flow
1. Launch app on clean machine/user.
2. Click `Install / Update Runtime`.
3. Verify runtime installs and current tag updates.

## Runtime Update Flow
1. Publish a newer runtime release.
2. Click `Check Latest Release` then `Install / Update Runtime`.
3. Confirm new tag/path are active.

## Prefix Initialization
1. Click `Create / Repair Prefix`.
2. Verify prefix exists at `~/Library/Application Support/D2RLauncher/Prefixes/bnet/`.

## Battle.net Install + Launch
1. Import installer (or download if URL configured).
2. Click `Install Battle.net`.
3. Click `Launch Battle.net`.

## D2R Launch
1. Set D2R executable path in UI (or browse).
2. Click `Launch D2R`.

## Cache Clear + Relaunch
1. Run `Clear Battle.net Caches` and `Reset Blizzard Agent`.
2. Relaunch Battle.net.

## Safe Reset
1. Trigger `Safe Reset` and confirm warning.
2. Verify backup prefix folder is created and new prefix initialized.

## Diagnostics
1. Click `Export Diagnostics Zip`.
2. Verify zip appears in Logs folder and includes expected files.
