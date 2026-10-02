# Latest handoff

Updated: 2026-10-02 04:42 MSK

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
- preview.33 proved real install/uninstall now works, but owner testing found two residual defects: active same-version `Переустановить` unnecessarily entered live reset and timed out with 3 active profiles / 0 blockers; successful install left ExtensionInstaller and its success dialog behind the browser.
- preview.35 keeps live reset only for genuine blocked/missing-active-profile recovery, uses v3-style in-place registration for active same-version reinstall, and restores ExtensionInstaller to foreground before showing an owned modal result dialog.

## Current installer preview

- version: `4.0.0-preview.37`
- tag: `installer-preview-37`
- asset: `ExtensionInstaller_Setup_v4.0.0-preview.37.exe`
- SHA-256: `55094465f755ec1e7b7e9ad41b5a66a5ce8c6449de274425c6e6339e323eacfe`
- release-engine validation run: `36951995805` — success
- build run: `36952046332` — success
- retained Actions artifacts: none
- preview.37 fixes Windows PowerShell 5.1 top-level GitHub releases-array enumeration. With multiple prereleases present, preview.35 could merge assets from several releases and falsely report duplicate `extension-release.json` assets. preview.37 scopes assets to the selected latest prerelease only.

## Network Recorder

- repository: `lvlaksim1/network-recorder`
- manager: none; ecosystem coordination remains here
- historical baseline: `1.6.0`
- current development version: `1.7.0`
- Extension ID: `paolfcaakecapidipfcfbbhgkpcmgcip`
- signing secret name: `RSA_PRIVATE_KEY_BASE64` (value never persisted here)
- current verified prerelease: `network-recorder-v1.7.0-preview-7`
- CRX SHA-256: `3db553fc93c12ba4fb6a5e2ce415f7c69e352d502b7b8fed5ed02fc952333bef`
- build/sign/release run: `36951295240` — success
- catalog channel: `prerelease`
- v1.7.0 default capture: API bodies + textual page resources enabled; binary bodies, file/blob bytes, deep diagnostics and Chromium Tracing disabled
- v1.7.0 ZIP: selective DEFLATE, payload deduplication and per-category `archiveSizeBreakdown` in `session-manifest.json`

## Resume point

Owner installs preview.37 over preview.35, presses `Проверить`, verifies Network Recorder 1.7.0 resolves without the duplicate-asset error, updates it, then repeats the ~10-second size test with default lightweight options.

Stable publication remains gated on real install/update verification and explicit owner approval.
