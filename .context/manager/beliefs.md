# Manager beliefs

## B1 — repository and authority

The active project repository is `lvlaksim1/extension-installer`; both product authority and manager-state authority are `main`.

- source: `.context/manifest.json`
- authority: verified-repository

## B2 — baseline

The retained local ExtensionInstaller v3.0.2 has been imported as `src/ExtensionInstaller.cmd` and is the migration baseline.

- source: owner-provided file plus verified repository import
- authority: owner-directive + verified-repository

## B3 — ecosystem topology

The owner selected separate repositories: one repository for ExtensionInstaller and a separate repository for each extension.

- source: owner directive in current project initiation
- authority: owner-directive

## B4 — signing-key policy

RSA private signing keys are not to be stored persistently on the owner's computer. Each extension's key is intended to live as a GitHub secret and be exposed only to its authorized signing workflow.

- source: owner directive
- authority: owner-directive

## B5 — release/storage policy

Build products should not accumulate in Git history or unnecessary Actions artifacts. Distributable files are intended to be placed directly in GitHub Releases.

- source: owner directive
- authority: owner-directive

## B6 — installer target responsibility

The target installer should consume already signed extension releases rather than own long-lived private signing keys or perform normal local signing.

- source: owner-approved architecture derived from B3–B5
- authority: manager-inference from owner-directive

## B7 — legacy behavior

The v3.0.2 baseline still contains local RSA-key/signing behavior. That behavior is historical baseline behavior, not the target trust architecture.

- source: verified baseline source + owner-approved target architecture
- authority: verified-repository + owner-directive


## B8 — v3.0.2 signing boundary

The v3.0.2 private-key dependency spans identity derivation, manifest-key injection, payload reconstruction and CRX3 generation; local RSA cannot be removed safely without replacing that whole input/trust path.

- source: verified audit of `src/ExtensionInstaller.cmd`
- authority: verified-repository

## B9 — release engine validation

A separate release-driven engine now performs release discovery, descriptor/SHA verification, CRX3 identity/signature verification, browser registration/update, rollback and uninstall without private-key handling. It passed Windows PowerShell 5.1 parse/C#-compile validation at commit `691d71fb524e6d0acc7a7fe7c7b01a4d7b4c5aa4`.

- source: verified repository + GitHub Actions run on Windows
- authority: verified-repository + verified-ci

## B10 — migration boundary still open

The existing GUI and normal v3.0.2 install button still invoke the legacy local ZIP/RSA path. Therefore the architectural migration is not complete and legacy signing code must not yet be deleted.

- source: verified repository
- authority: verified-repository


## B11 — canonical extension name

The first browser extension in this ecosystem is canonically named **Network Recorder**. Repository names, release metadata, catalog entries, UI text and new documentation must use `Network Recorder`.

- source: owner directive
- authority: owner-directive



## B12 — installable packaging

ExtensionInstaller has a verified per-user Inno Setup packaging path with a fixed AppId. Windows CI verified install, reinstall over the existing installation, payload presence and uninstall. Preview `3.0.2-preview.3` is published directly as a GitHub prerelease asset with SHA-256 `e69d4db6dc0ac55124e46dbd301d13ffb0504d8bb1b14d3955586c56073e37bd`.

- source: verified repository + successful Windows GitHub Actions run 36897779451
- authority: verified-repository + verified-ci


## B13 — uninstall data policy

Interactive uninstall now asks whether the owner wants to remove ExtensionInstaller working data. Program removal and user-data removal are separate decisions: declining preserves `%LOCALAPPDATA%\ExtensionInstaller`, confirming removes it. Windows CI verified both preservation and explicit-cleanup branches in preview `3.0.2-preview.4`.

- source: owner directive + verified repository + successful Windows CI
- authority: owner-directive + verified-repository + verified-ci


## B14 — Network Recorder repository governance

`lvlaksim1/network-recorder` is a public, agentless extension repository created through repo-factory. The owner explicitly chose not to install a separate Project Manager there for now. Ecosystem coordination and onboarding responsibility remain with `extension-installer-project-manager`.

- source: owner directive + verified repository
- authority: owner-directive + verified-repository
