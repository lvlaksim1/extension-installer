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
