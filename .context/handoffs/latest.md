# Latest handoff

Updated: 2026-10-02 02:50 MSK

## Manager

- manager_id: `extension-installer-project-manager`
- repository: `lvlaksim1/extension-installer`
- manager-state branch: `main`
- product branch: `main`

## Owner decisions now canonical

- Remove legacy ExtensionInstaller functionality completely; do not restore a legacy compatibility UI/path.
- Extension repositories remain separate from ExtensionInstaller.
- Network Recorder currently has no separate manager; `extension-installer-project-manager` coordinates the extension ecosystem.
- Private extension signing keys live only in GitHub secret scope.
- Release CRX + `extension-release.json` live in the extension's GitHub Release; the user does not place them manually.
- Stable release publication remains owner-controlled.
- User-facing ExtensionInstaller updates are delivered as one setup EXE, not ZIP/CMD bundles.

## Canonical ExtensionInstaller state

The product remains clean release-driven only:

`catalog -> GitHub Release -> extension-release.json -> SHA-256 + CRX3 signature + Extension ID verification -> installer-owned CRX/state -> Yandex Browser`

The owner installed preview.11 and confirmed that it sees the Network Recorder GitHub release. A real migration defect was then observed: after removing the previously installed extension in Yandex Browser, preview.11 still showed version 1.6.0 and classified the remaining registration as foreign.

Root cause and correction:
- v3.x registrations point to `%LOCALAPPDATA%\UniversalExtensionBuilder\projects\<id>\crx`;
- v4 managed registrations point to `%LOCALAPPDATA%\ExtensionInstaller\extensions\<id>\crx`;
- browser UI removal may leave the external registry entry and set `extensions.external_uninstalls`;
- registry presence is therefore not accepted as proof of actual installation;
- v4 now detects actual profile extension files and the browser user-uninstall marker separately;
- the exact v3-owned path is accepted as migratable ExtensionInstaller state, while unrelated registrations remain protected;
- preview.24 does not require a browser restart: while Yandex is running, ExtensionInstaller first performs a two-phase remove/recreate of its owned registry subkey. If the extension was previously removed through the browser or is still not present in browser profile state after the hot attempt, ExtensionInstaller opens `browser://tune` and selects the verified managed CRX in Explorer for normal user-confirmed installation. Preferences are not edited behind a running browser.

## Current installer preview

- version: `4.0.0-preview.24`
- tag: `installer-preview-24`
- asset: `ExtensionInstaller_Setup_v4.0.0-preview.24.exe`
- SHA-256: `36f28f2e2bb814b0c7cf77c45b73f0f74cb3dda105bb60a04fb0f2571652e140`
- validation run: `36942756644` — success
- build run: `36942832970` — success
- retained Actions artifacts: none

## Network Recorder

- repository: `lvlaksim1/network-recorder`
- manager: none; ecosystem coordination remains here
- source baseline: `1.6.0`
- Extension ID: `paolfcaakecapidipfcfbbhgkpcmgcip`
- signing secret name: `RSA_PRIVATE_KEY_BASE64` (value never persisted here)
- verified prerelease: `network-recorder-v1.6.0-preview-1`
- CRX SHA-256: `3516149ea638f6ff10626c1ae974c92627e220c1e86b5c5195abdea4700c26cf`
- catalog channel: `prerelease`

## Resume point

Owner installs ExtensionInstaller `4.0.0-preview.24` while keeping Yandex Browser open, runs install/reinstall/apply for Network Recorder, and verifies either immediate hot load or the automatic `browser://tune` + selected-CRX fallback, with no browser restart.

Stable publication remains gated on real install/update verification and explicit owner approval.
