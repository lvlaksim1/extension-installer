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

The extension previously referred to as `EINV Network Recorder` is now canonically named **Network Recorder**. New repository names, release metadata, catalog entries, UI text and documentation must use only `Network Recorder`, except where historical evidence must preserve an old literal filename or label.

- source: owner directive
- authority: owner-directive
