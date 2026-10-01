# Latest handoff

Updated: 2026-10-02 01:28 MSK

## Manager

- manager_id: `extension-installer-project-manager`
- repository: `lvlaksim1/extension-installer`
- manager-state branch: `main`
- product branch: `main`

## Canonical ExtensionInstaller state

The current product is clean release-driven only.

- GUI: `src/ExtensionInstaller.ps1`
- release engine: `src/ReleaseInstaller.ps1`
- catalog: `catalog/extensions.json`
- release contract: `docs/EXTENSION_RELEASE_CONTRACT.md`
- no local extension-folder selector
- no local ZIP build/signing path
- no private RSA key handling
- old installed `ExtensionInstaller.cmd` is explicitly deleted during upgrade

Canonical flow:

`catalog -> GitHub Release -> extension-release.json -> SHA-256 + CRX3 signature + Extension ID verification -> installer-owned CRX/state -> Yandex Browser`

## Current installer preview

- version: `4.0.0-preview.11`
- tag: `installer-preview-11`
- asset: `ExtensionInstaller_Setup_v4.0.0-preview.11.exe`
- SHA-256: `32ad90c6951304c3a5698f8915de6fc69d21165dc77875625bf230cce77888e6`
- Windows CI run: `36935180820`
- verified: GUI/engine/catalog validation, live Network Recorder release resolution and CRX verification, install, simulated upgrade from stale CMD, reinstall, uninstall with data preserved, uninstall with data removed
- retained Actions artifacts: none

## Network Recorder

- repository: `lvlaksim1/network-recorder`
- manager: none; ecosystem coordination remains here
- version under test: `1.6.0`
- Extension ID: `paolfcaakecapidipfcfbbhgkpcmgcip`
- signing secret name: `RSA_PRIVATE_KEY_BASE64` (value never persisted here)
- verified prerelease: `network-recorder-v1.6.0-preview-1`
- CRX SHA-256: `3516149ea638f6ff10626c1ae974c92627e220c1e86b5c5195abdea4700c26cf`
- release assets: `Network_Recorder_v1.6.0.crx`, `extension-release.json`
- signing workflow: success
- independent ExtensionInstaller validation: success
- catalog channel: `prerelease`

## Resume point

Owner installs ExtensionInstaller `4.0.0-preview.11` over the current installation, then performs the first real Network Recorder install through the new GUI on Yandex Browser. Stable publication remains gated on real install/update verification.
