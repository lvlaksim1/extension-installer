# Project architecture

## Ecosystem boundary

`extension-installer` is the consumer-side installer/update manager.

Each browser extension is an independent producer repository with its own:

- source tree;
- version history;
- signing secret;
- CI/release workflow;
- GitHub Releases.

## Target release flow

```text
extension repository
    source
      |
      v
GitHub Actions release job
    + repository/environment RSA secret
      |
      v
signed CRX + integrity metadata
      |
      v
GitHub Release
      |
      v
ExtensionInstaller
    discover -> validate -> download -> verify -> register/update
      |
      v
Yandex Browser
```

## Trust boundaries

- RSA private key remains inside GitHub secret scope and ephemeral release execution.
- ExtensionInstaller receives only public release material.
- Installer verifies expected repository/extension identity and integrity metadata before installation.
- Existing extension ID continuity is a migration invariant.

## Legacy boundary

`src/ExtensionInstaller.cmd` v3.0.2 includes local packaging/signing responsibilities. Those are retained as baseline behavior while the release-driven path is designed and verified.

## Storage policy

- source/configuration/documentation: Git;
- distributable installer/extension binaries: GitHub Releases;
- private keys: GitHub secrets;
- temporary build files: ephemeral job/runtime storage;
- GitHub Actions artifacts: avoided unless a concrete workflow requires retention.
