# Latest handoff

## Manager

- manager_id: `extension-installer-project-manager`
- repository: `lvlaksim1/extension-installer`
- manager-state branch: `main`
- product branch: `main`

## Verified baseline

- ExtensionInstaller v3.0.2 is preserved at `src/ExtensionInstaller.cmd`.
- Functional audit: `docs/V3.0.2_FUNCTIONAL_AUDIT.md`.
- Release contract v1: `docs/EXTENSION_RELEASE_CONTRACT.md`.
- New release engine: `src/ReleaseInstaller.ps1`.
- Current validated release-engine commit: `691d71fb524e6d0acc7a7fe7c7b01a4d7b4c5aa4`.
- Windows PowerShell 5.1 validation passed; no workflow artifacts are created.

## Owner-approved architecture

- installer and extensions live in separate repositories;
- each extension owns its signing key as a GitHub secret;
- normal installation/update must not require a persistent RSA private key on the owner's PC;
- signed CRX distributables belong in GitHub Releases;
- unnecessary Actions artifacts must not accumulate;
- stable extension IDs must be preserved.

## Migration state

The new engine can resolve and verify signed releases and owns the new registration/update/rollback/uninstall path without private keys. The old GUI still invokes the v3.0.2 local ZIP/RSA path. Do not delete the legacy signing path until the release engine is connected to the GUI and a real extension release passes an end-to-end Yandex Browser test.

## Active commitments

- EI-PM-002: migrate installer architecture to signed-release consumption.
- EI-PM-003: preserve security and storage invariants.
- EI-PM-004: prepare Network Recorder as the first ecosystem integration.

## Resume point

Integrate the validated release engine into the GUI, then create/onboard Network Recorder as the first signed-release producer.


## Installable packaging

- Inno Setup source: `installer/ExtensionInstaller.iss`.
- Build script: `installer/Build-Installer.ps1`.
- Hidden launcher: `src/ExtensionInstaller.vbs`.
- Fixed AppId: `79735245-B74E-5117-B1EF-A58BDC270FC7`.
- Current verified preview: `3.0.2-preview.3`.
- Release tag: `installer-preview-3`.
- Setup asset: `ExtensionInstaller_Setup_v3.0.2-preview.3.exe`.
- SHA-256: `e69d4db6dc0ac55124e46dbd301d13ffb0504d8bb1b14d3955586c56073e37bd`.
- Windows CI verified install -> reinstall in place -> payload -> uninstall.
- No Actions artifacts are retained.

## Canonical extension naming

The first extension is named `Network Recorder`.


## Uninstall data behavior

- Interactive uninstall asks whether to delete `%LOCALAPPDATA%\ExtensionInstaller`.
- Choosing No preserves settings/logs; choosing Yes deletes the working-data folder.
- Silent uninstall preserves data by default.
- Verified preview: `3.0.2-preview.4`, release tag `installer-preview-4`.
- SHA-256: `72b8938252d02520d3c35c3b1cd397d9d04f9a7346ef03cc03f96c5aa4144b9c`.


## Network Recorder repository

- repository: `lvlaksim1/network-recorder`
- visibility: public
- created via: `lvlaksim1/repo-factory` Issue #82
- factory profile: `infrastructure` (agentless)
- Context Capsule / Project Manager: not installed by owner decision
- standard Telegram secrets: not installed
- current governance: coordinated by `extension-installer-project-manager`
- next onboarding step: import the retained stable v1.6.0 source, then configure GitHub-side signing without changing the existing Extension ID.


## Network Recorder baseline import

- repository: `lvlaksim1/network-recorder`
- retained archive SHA-256: `eeb0cdfdf6323c96c6aea777ad9aed889522dc9de13e467b8f447723612e1db3`
- factory import commit: `db1993a63c08beb1a7b7353f1bfe49419d6bafde`
- exact files imported: `background.js`, `content.js`, `manifest.json`, `offscreen.html`, `offscreen.js`
- byte-for-byte verification: all five Git blob SHA-1 values match the retained ZIP
- canonical name/version: `Network Recorder` / `1.6.0`
- stable Extension ID derived from the manifest public key: `paolfcaakecapidipfcfbbhgkpcmgcip`
- private key status: not committed; next step is GitHub secret onboarding and signed release workflow
