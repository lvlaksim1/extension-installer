# Latest handoff

Updated: 2026-10-02 03:22 MSK

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
- preview.24 added no-restart install fallback, but owner testing found that ExtensionInstaller-driven uninstall could erase its own active state before Yandex removed the profile entry, causing a false foreign classification.
- preview.26 added durable `ownership.json` and browser-only recovery, but owner testing then proved its “installed” state could still be false: Network Recorder was absent from the real Yandex extensions UI.
- re-audit of the canonical v3.0.2 `ExtensionInstaller.cmd` showed that the old working install path NEVER deleted/recreated the registry child key. It updated only `path` and `version` in place. v3 also provided a user32 foreground bridge and `browser://tune/` confirmation workflow.
- preview.31 restores that exact non-destructive registry behavior, keeps the newer ownership safeguards, ports the v3 foreground activation bridge, and refuses to treat stale browser-profile presence as proof of successful live load in recovery/same-value cases.

## Current installer preview

- version: `4.0.0-preview.31`
- tag: `installer-preview-31`
- asset: `ExtensionInstaller_Setup_v4.0.0-preview.31.exe`
- SHA-256: `7a77f01e7c1484f9794737a67cf77d23f75f688f0dd831c8b408fb0d0e802c04`
- validation run: `36945415272` — success
- build run: `36945552459` — success
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

Owner installs ExtensionInstaller `4.0.0-preview.31` over preview.26 with Yandex Browser open and verifies ACTUAL browser appearance after reinstall, not just installer status. Then test uninstall -> check -> reinstall in the same browser session.

Stable publication remains gated on real install/update verification and explicit owner approval.
