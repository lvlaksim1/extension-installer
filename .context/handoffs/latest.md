# Latest handoff

## Manager

- manager_id: `extension-installer-project-manager`
- repository: `lvlaksim1/extension-installer`
- manager-state branch: `main`
- product branch: `main`

## Verified baseline

- ExtensionInstaller v3.0.2 is imported at `src/ExtensionInstaller.cmd`.
- The repository is public and was created via `lvlaksim1/repo-factory`.
- Project Manager v2 Core commit: `7aa1e697504e686b02a4d7f1539a157214d5e692`.
- No signing private key is committed to the repository.

## Owner-approved architecture

- installer and extensions live in separate repositories;
- each extension owns its signing key as a GitHub secret;
- normal installation/update must not require a persistent RSA private key on the owner's PC;
- signed CRX distributables belong in GitHub Releases;
- unnecessary Actions artifacts must not accumulate;
- stable extension IDs must be preserved.

## Active commitments

- EI-PM-002: migrate installer architecture to signed-release consumption.
- EI-PM-003: preserve security and storage invariants.
- EI-PM-004: prepare EINV Network Recorder as the first ecosystem integration.

## Resume point

Audit `src/ExtensionInstaller.cmd` by responsibility, then define the installer-to-extension release contract before modifying the installation path.
