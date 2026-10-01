# extension-installer

Windows installer and updater for locally managed Chromium-based browser extensions, currently focused on Yandex Browser.

## Baseline

The repository starts from the retained local **ExtensionInstaller v3.0.2** baseline.

- canonical working source: `src/ExtensionInstaller.cmd`
- original retained file SHA-256 before import: `100193a70aa77f0a06fb76d84a4deb28c6447ad930a6fb36e1a2159600a0375a`
- baseline behavior: discovers extension ZIP packages, manages stable extension IDs via RSA signing keys, builds CRX3 packages and registers them in Yandex Browser.

The imported baseline is the starting point. Its local-key behavior is legacy behavior to be migrated, not the target architecture.

## Target ecosystem

Each extension lives in its own repository. Extension repositories own their source, versioning, release process and signing secret. Private RSA signing material must be stored in GitHub Actions secrets and must never be committed to Git.

The installer repository contains only the installer/update manager. The target installer downloads already signed CRX releases and verifies their metadata/checksums before installation.

## Repository policy

- No RSA private keys in Git.
- No ZIP/CRX build products in repository history.
- Release binaries belong in GitHub Releases, not Actions artifacts or normal commits.
- Temporary CI outputs must not be retained unless required for a release.
- Extension source code belongs in the corresponding extension repository, not here.

## Current phase

1. Preserve and document the v3.0.2 baseline.
2. Separate signing/build responsibilities from local installation.
3. Define the extension catalog/release contract.
4. Adapt ExtensionInstaller to consume signed releases.
5. Migrate existing extensions one by one without changing stable extension IDs.
