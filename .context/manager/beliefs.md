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

The current verified clean installer preview is `4.0.0-preview.33`, tag `installer-preview-33`, SHA-256 `f8d4275762e3ff264f5e20e39b34dc47f346de62581374a068ace7f2fa0d5a46`.

It supersedes preview.31 because it preserves canonical v3.0.2 registration for normal changes and adds an acknowledged live reset for blocked or same-value reinstall, plus explicit Chromium state=2 detection.

- source: owner runtime evidence + verified v3 source + GitHub Release + successful Windows validation/build runs `36946218482` and `36946267122`
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

## B17 — v3.0.2 in-place registration is canonical

The canonical working ExtensionInstaller v3.0.2 source does not delete/recreate an existing Yandex external-extension registry child key during install or update. It executes `New-Item -Force` for the same key and overwrites only `path` and `version`. Deleting that key as an install-time “pulse” was introduced later in v4 and is not part of the proven v3 behavior.

The v3 CRX3 signing algorithm, manifest public-key identity and current GitHub-signed Network Recorder package are compatible; the material behavioral difference was registry handling. v3 also contains a `user32.dll` bridge to foreground the already-running Yandex Browser.

- source: verified v3.0.2 source + owner runtime evidence + preview.31 implementation/CI
- authority: verified-repository + owner-runtime-evidence + verified-ci

## B18 — user-removed external extensions need browser-owned reactivation

A user removal performed in Yandex Browser is stronger than absence of an external registry entry: the browser can remember that removal and decline a subsequent external registration. ExtensionInstaller must not silently override that browser-owned decision by editing live profile Preferences. Preview.24 therefore attempts normal hot registration first, then—when the extension was user-removed or still is not present in browser profile state—opens `browser://tune` and selects the exact verified CRX so the user can confirm installation in the running browser without restart.

- source: owner directive + owner runtime observation + browser external-extension semantics + verified implementation/CI
- authority: owner-directive + owner-runtime-evidence + verified-repository + verified-ci

## B19 — profile-only same-ID state is not a foreign external registration

Owner testing of preview.24 showed that ExtensionInstaller-driven uninstall can remove its registry/state immediately while a running Yandex Browser still retains the extension entry in profile state. Classifying that exact state as “foreign” destroys the reinstall path.

Current rule: a trusted catalog Extension ID found only in browser profile state, with no external registry registration and no active installer state, is modeled as `BrowserOnly`, not as a foreign external registration. Install/connect remains allowed. Future ExtensionInstaller-driven uninstalls persist `ownership.json` before deleting active CRX/state so the UI can explicitly report “removed by ExtensionInstaller” during browser-state lag.

- source: owner runtime observation + preview.26 implementation/CI
- authority: owner-runtime-evidence + verified-repository + verified-ci

## B20 — installer status is not proof of live browser presence

Owner testing of preview.26 showed “Установлено” in ExtensionInstaller while Network Recorder was absent from Yandex Browser's extensions UI. Therefore browser-profile `extensions.settings` residue cannot be treated as sufficient evidence of a live loaded extension during a running-browser recovery/reinstall.

For recovery or same-value reinstall, preview.31 forces the browser-owned confirmation path instead of claiming success solely from profile-state presence.

- source: owner runtime observation + preview.31 implementation
- authority: owner-runtime-evidence + verified-repository

## B21 — blocked reinstall requires browser acknowledgement, not a fixed delay

Chromium's Windows external registry loader watches the HKCU extensions key live. When an external extension has been explicitly removed, persisted state can represent `EXTERNAL_EXTENSION_UNINSTALLED` (state value 2) and/or `extensions.external_uninstalls`. Rewriting the same registry values does not prove that the browser accepted the extension.

Preview.33 keeps v3.0.2 in-place writes for normal install/update. For blocked or same-value reinstall, it removes only the owned registration, waits for Yandex to clear its old profile/uninstall state, re-registers the verified CRX, and waits for a non-uninstalled profile state before claiming live success.

- source: Chromium source + owner runtime observation + preview.33 implementation/CI
- authority: upstream-source + owner-runtime-evidence + verified-ci
