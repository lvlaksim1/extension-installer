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
