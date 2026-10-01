# Manager beliefs

## B1 — repository and authority

The active repository is `lvlaksim1/extension-installer`; both product and manager-state authority are `main`.

- source: verified repository
- authority: verified-repository

## B2 — clean product invariant

ExtensionInstaller now has one supported product path: catalog -> signed GitHub Release -> descriptor/SHA/CRX3 identity verification -> installer-owned local CRX/state -> Yandex Browser registration.

The current product must not reintroduce local extension-source folder selection, local ZIP build/signing or local private-key handling.

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

## B9 — installable application

ExtensionInstaller uses a fixed Inno Setup AppId and per-user path `%LOCALAPPDATA%\Programs\ExtensionInstaller`. Upgrades replace the existing installation in place.

- source: verified repository + Windows CI
- authority: verified-repository + verified-ci

## B10 — obsolete installed code cleanup

The current setup explicitly deletes an obsolete `ExtensionInstaller.cmd` from an older installation. Windows CI simulated that stale file and verified its removal during in-place upgrade.

- source: Windows CI run 36935180820
- authority: verified-ci

## B11 — uninstall data policy

Interactive uninstall asks whether to remove `%LOCALAPPDATA%\ExtensionInstaller`. Declining preserves application data; confirming removes it. Silent uninstall preserves it unless the explicit CI/service cleanup switch is used.

- source: owner directive + verified Windows CI
- authority: owner-directive + verified-ci

## B12 — current verified preview

The current verified clean installer preview is `4.0.0-preview.11`, tag `installer-preview-11`, SHA-256 `32ad90c6951304c3a5698f8915de6fc69d21165dc77875625bf230cce77888e6`.

- source: GitHub Release + successful Windows CI run 36935180820
- authority: verified-ci + verified-repository
