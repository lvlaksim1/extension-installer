# Project architecture

## Ecosystem boundary

`extension-installer` is the consumer-side installer/update manager.

Each browser extension is an independent producer repository with its own source, version history, signing secret, release workflow and GitHub Releases.

## Canonical flow

```text
extension repository
    source
      |
      v
GitHub Actions signing job
    + repository secret
      |
      v
signed CRX + extension-release.json
      |
      v
GitHub Release
      |
      v
ExtensionInstaller catalog
      |
      v
download -> descriptor/SHA verification -> CRX3 signature/ID verification
      |
      v
installer-owned local CRX/state -> Yandex Browser registration
```

## User-facing product

The application has one supported workflow: catalog-driven signed releases.

There is no user-selected extension source directory, local ZIP discovery/build path or local private-key signing path.

## Trust boundaries

- Private signing keys remain in extension-repository GitHub secret scope and ephemeral signing runners.
- ExtensionInstaller receives public release material only.
- Catalog `extension_id` is a trust anchor.
- Descriptor ID, CRX-derived ID and catalog ID must all match.
- CRX SHA-256 and CRX3 signature must validate before browser registration.
- Installer ownership state prevents silent takeover of a foreign registration.

## Storage policy

- source/configuration/documentation: Git;
- distributable installer and extension binaries: GitHub Releases;
- private keys: GitHub secrets only;
- managed local CRX/state: `%LOCALAPPDATA%\ExtensionInstaller\extensions`;
- temporary downloads/build outputs: ephemeral;
- retained GitHub Actions artifacts: avoided.
