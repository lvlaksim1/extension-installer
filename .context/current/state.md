# Current state

Updated: 2026-10-02 01:28 MSK

- Repository: `lvlaksim1/extension-installer`.
- Visibility: public.
- Product branch: `main`.
- Manager-state branch: `main`.
- Durable manager: `extension-installer-project-manager`.
- ExtensionInstaller is now a clean release-driven application. The current product tree contains no local extension-folder/ZIP workflow and no local RSA signing workflow.
- User-facing GUI: `src/ExtensionInstaller.ps1`.
- Release acquisition/verification engine: `src/ReleaseInstaller.ps1`.
- Launcher: `src/ExtensionInstaller.vbs`.
- Extension catalog: `catalog/extensions.json`.
- Release contract: `docs/EXTENSION_RELEASE_CONTRACT.md`.
- The catalog currently contains Network Recorder only.
- Network Recorder repository: `lvlaksim1/network-recorder`.
- Network Recorder Extension ID is pinned as `paolfcaakecapidipfcfbbhgkpcmgcip`.
- Current integration channel is `prerelease`; the GUI needs no change when the catalog later switches to `stable`.
- Network Recorder v1.6.0 signing is performed in its own GitHub Actions workflow using repository secret `RSA_PRIVATE_KEY_BASE64`; the secret value is never stored in this context.
- Verified Network Recorder prerelease: `network-recorder-v1.6.0-preview-1`.
- Verified Network Recorder CRX SHA-256: `3516149ea638f6ff10626c1ae974c92627e220c1e86b5c5195abdea4700c26cf`.
- ExtensionInstaller verifies release descriptor metadata, SHA-256, CRX3 RSA/SHA-256 signature and Extension ID before registration.
- Managed extension state/CRX files live under `%LOCALAPPDATA%\ExtensionInstaller\extensions\<extension-id>`.
- Logs live under `%LOCALAPPDATA%\ExtensionInstaller\logs`.
- Yandex Browser registration is owned by the release engine and protected by ownership/rollback checks.
- Windows installer uses fixed AppId `79735245-B74E-5117-B1EF-A58BDC270FC7` and installs per-user under `%LOCALAPPDATA%\Programs\ExtensionInstaller`.
- Upgrade explicitly removes obsolete `ExtensionInstaller.cmd` from an older installation.
- Interactive uninstall asks whether to remove `%LOCALAPPDATA%\ExtensionInstaller`; declining preserves data, confirming removes it.
- Current verified installer preview: `4.0.0-preview.11`.
- Release tag: `installer-preview-11`.
- Setup asset: `ExtensionInstaller_Setup_v4.0.0-preview.11.exe`.
- Setup SHA-256: `32ad90c6951304c3a5698f8915de6fc69d21165dc77875625bf230cce77888e6`.
- Windows CI run `36935180820` passed clean GUI/catalog/release validation, real Network Recorder prerelease resolution and CRX verification, install, simulated upgrade cleanup of obsolete CMD, reinstall, both uninstall data-policy paths and direct prerelease publication.
- No GitHub Actions artifacts were retained.
- Stable ExtensionInstaller publication has not been designated. Real owner-side Yandex Browser installation is the next gate.
