# Next actions

1. Integrate `src/ReleaseInstaller.ps1` into the user-facing ExtensionInstaller path while preserving the v3.0.2 baseline for rollback/reference.
2. Replace the GUI's local folder/ZIP discovery with catalog-driven extension selection and GitHub Release status/version display.
3. Route Install/Update through: catalog -> latest stable GitHub Release -> descriptor -> SHA/CRX3 identity/signature verification -> installer-owned CRX storage -> Yandex registration.
4. Route Uninstall through the new release-state ownership checks and remove legacy wording about preserving local RSA keys.
5. Create/onboard the EINV Network Recorder repository, configure its signing secret, publish its chosen stable 1.6.0 as the first signed Release, and add its pinned Extension ID to `catalog/extensions.json`.
6. Perform an end-to-end Yandex Browser install/update test before removing legacy local signing code or designating any stable installer release.
