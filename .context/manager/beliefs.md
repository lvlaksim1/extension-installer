# Manager beliefs

## B1 — repository and authority

The active repository is `lvlaksim1/extension-installer`; both product and manager-state authority are `main`.

- source: verified repository
- authority: verified-repository

## B2 — clean product invariant

ExtensionInstaller has one supported product path: catalog -> signed GitHub Release -> descriptor/SHA/CRX3 identity verification -> installer-owned local CRX/state -> Yandex Browser registration.

The removed legacy path must not return: no user-selected extension source directory, local ZIP discovery/build/signing, or local private-key handling.

- source: owner directive + verified repository
- authority: owner-directive + verified-repository

## B3 — ecosystem topology

ExtensionInstaller and every extension live in separate repositories. Extension repositories own their source, signing workflow and releases.

- source: owner directive
- authority: owner-directive

## B4 — signing-key policy

RSA private signing keys live only in the corresponding extension repository's GitHub secret scope and ephemeral signing runtime. ExtensionInstaller never needs the private key.

- source: owner directive + verified Network Recorder signing workflow
- authority: owner-directive + verified-ci

## B5 — release/storage policy

Distributable binaries belong in GitHub Releases, not normal Git history or retained Actions artifacts.

- source: owner directive
- authority: owner-directive

## B6 — identity/integrity policy

Catalog Extension ID is a trust anchor. Descriptor ID and CRX-derived ID must equal the catalog ID, and SHA-256 plus CRX3 signature must validate before registration.

- source: verified release engine
- authority: verified-repository + verified-ci

## B7 — Network Recorder governance

`lvlaksim1/network-recorder` is public and currently agentless. `extension-installer-project-manager` coordinates the shared extension ecosystem until the owner decides otherwise.

- source: owner directive + verified repository
- authority: owner-directive + verified-repository

## B8 — Network Recorder verified signing

Network Recorder v1.6.0 is signed in GitHub Actions with secret `RSA_PRIVATE_KEY_BASE64`. Verified prerelease `network-recorder-v1.6.0-preview-1` preserves Extension ID `paolfcaakecapidipfcfbbhgkpcmgcip` and has CRX SHA-256 `3516149ea638f6ff10626c1ae974c92627e220c1e86b5c5195abdea4700c26cf`.

- source: verified network-recorder workflow + independent ExtensionInstaller validation
- authority: verified-ci

## B9 — release asset placement

`Network_Recorder_v1.6.0.crx` and `extension-release.json` belong in the extension's GitHub Release assets. The owner does not manually copy them into ExtensionInstaller or into a local extension folder.

- source: owner clarification + verified release-driven architecture
- authority: owner-directive + verified-repository

## B10 — installable application

ExtensionInstaller uses a fixed Inno Setup AppId and per-user path `%LOCALAPPDATA%\Programs\ExtensionInstaller`. Upgrades replace the existing installation in place.

- source: verified repository + Windows CI
- authority: verified-repository + verified-ci

## B11 — obsolete installed code cleanup

The current setup explicitly deletes an obsolete `ExtensionInstaller.cmd` from an older installation. Windows CI simulated that stale file and verified its removal during in-place upgrade.

- source: Windows CI
- authority: verified-ci

## B12 — uninstall data policy

Interactive uninstall asks whether to remove `%LOCALAPPDATA%\ExtensionInstaller`. Declining preserves application data; confirming removes it. Silent uninstall preserves it unless the explicit CI/service cleanup switch is used.

- source: owner directive + verified Windows CI
- authority: owner-directive + verified-ci

## B13 — current verified preview

The current verified clean installer preview is `4.0.0-preview.24`, tag `installer-preview-24`, SHA-256 `36f28f2e2bb814b0c7cf77c45b73f0f74cb3dda105bb60a04fb0f2571652e140`.

It supersedes preview.22 as the owner-test candidate because it keeps no-restart hot registration and adds a browser-owned `browser://tune` + selected verified CRX fallback for user-removed/blocklisted or otherwise not-live-loaded external extensions.

- source: owner runtime evidence + GitHub Release + successful Windows validation/build runs `36942756644` and `36942832970`
- authority: owner-runtime-evidence + verified-ci + verified-repository

## B14 — current release gate

Repository and CI validation are green, but owner-side verification of the corrected real Yandex Browser reinstall/migration path is still pending. Stable publication remains gated on real install/update verification and explicit owner approval.

- source: verified current state + owner release authority
- authority: verified-repository + owner-directive

## B15 — browser state is not equivalent to external registry state

For externally registered Chromium/Yandex extensions, a remaining registry entry is not sufficient evidence that the extension is currently installed in the browser. The owner observed this directly after removing Network Recorder through Yandex Browser while the old ExtensionInstaller registration remained.

Current product logic separately models actual profile extension files, browser user-uninstall markers, current manager-owned registration/state, exact v3 legacy-owned registration, and foreign registration.

- source: owner runtime observation + verified implementation/CI
- authority: owner-runtime-evidence + verified-repository + verified-ci

## B16 — v3 registration is migratable owner state

The prior ExtensionInstaller stored registered CRX files under `%LOCALAPPDATA%\UniversalExtensionBuilder\projects\<extension-id>\crx`. That exact path is recognized as legacy ExtensionInstaller-owned state for migration/removal; unrelated paths remain protected as foreign.

- source: verified v3 source + current migration implementation
- authority: verified-repository

## B17 — hot external registration is required

The owner requires ExtensionInstaller install/reinstall to work without restarting Yandex Browser, matching the practical behavior of the earlier installer. Chromium/Yandex watches the external-extension registry branch while running. For an ExtensionInstaller-owned existing registration, preview.22 intentionally removes the child key, waits briefly, then recreates it with the verified CRX path/version so the live watcher observes a fresh registration. While the browser is running, ExtensionInstaller does not edit its Preferences file directly.

- source: owner directive + Chromium registry-loader behavior + verified implementation/CI
- authority: owner-directive + verified-repository + verified-ci

## B18 — user-removed external extensions need browser-owned reactivation

A user removal performed in Yandex Browser is stronger than absence of an external registry entry: the browser can remember that removal and decline a subsequent external registration. ExtensionInstaller must not silently override that browser-owned decision by editing live profile Preferences. Preview.24 therefore attempts normal hot registration first, then—when the extension was user-removed or still is not present in browser profile state—opens `browser://tune` and selects the exact verified CRX so the user can confirm installation in the running browser without restart.

- source: owner directive + owner runtime observation + browser external-extension semantics + verified implementation/CI
- authority: owner-directive + owner-runtime-evidence + verified-repository + verified-ci
