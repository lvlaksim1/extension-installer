# Next actions

1. Test install/uninstall preview 3.0.2-preview.4 manually on the owner's Windows environment, including the interactive working-data deletion prompt.
2. Integrate `src/ReleaseInstaller.ps1` into the user-facing ExtensionInstaller path while preserving the v3.0.2 baseline for rollback/reference.
3. Replace the GUI's local folder/ZIP discovery with catalog-driven extension selection and GitHub Release status/version display.
4. Route Install/Update through: catalog -> latest stable GitHub Release -> descriptor -> SHA/CRX3 identity/signature verification -> installer-owned CRX storage -> Yandex registration.
5. Route Uninstall through the new release-state ownership checks and remove legacy wording about preserving local RSA keys.
6. Onboard the retained stable Network Recorder v1.6.0 source into `lvlaksim1/network-recorder`, configure its signing secret, publish v1.6.0 as the first signed Release, and add its pinned Extension ID to `catalog/extensions.json`.
7. Perform an end-to-end Yandex Browser extension install/update test before removing legacy local signing code or designating any stable ExtensionInstaller release.
