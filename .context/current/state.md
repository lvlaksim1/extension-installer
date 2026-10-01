# Current state

- Repository `lvlaksim1/extension-installer` was created through `lvlaksim1/repo-factory`.
- Visibility: public.
- Factory profile: `project-manager`; Project Manager v2 context capsule installed.
- Durable manager identity: `extension-installer-project-manager`.
- Manager-state authority: `main`; product authority: `main`.
- Standard Telegram secrets: skipped.
- The retained `ExtensionInstaller_v3.0.2.cmd` remains preserved as `src/ExtensionInstaller.cmd`.
- Original retained file SHA-256 before import: `100193a70aa77f0a06fb76d84a4deb28c6447ad930a6fb36e1a2159600a0375a`.
- v3.0.2 functional audit is recorded in `docs/V3.0.2_FUNCTIONAL_AUDIT.md`.
- Signed-extension release contract v1 is recorded in `docs/EXTENSION_RELEASE_CONTRACT.md`.
- Catalog skeleton exists at `catalog/extensions.json`; it is intentionally empty until an extension repository is onboarded.
- New release-driven engine exists at `src/ReleaseInstaller.ps1`.
- The new engine contains no local private-key creation/import/signing path. It resolves a public GitHub latest Release, downloads `extension-release.json` and the signed CRX, verifies SHA-256, parses CRX3, derives Extension ID from the embedded public key, verifies the RSA/SHA-256 CRX3 proof, and rejects identity mismatch against the pinned catalog entry.
- The new engine also implements installer-owned signed-CRX storage, Yandex Browser registry registration/update, rollback, state persistence and uninstall without any private key.
- Windows PowerShell 5.1 validation passed on commit `691d71fb524e6d0acc7a7fe7c7b01a4d7b4c5aa4`; the validation compiles the CRX3 inspector and checks the release engine/catalog. No Actions artifacts are produced.
- A WinPS 5.1 UTF-8/BOM incompatibility and one code-generation replacement bug were found during validation and fixed before this state was recorded.
- The legacy GUI in `src/ExtensionInstaller.cmd` still uses the local ZIP/RSA path. It has not yet been switched to the release-driven engine, so the migration is intentionally incomplete.
- Repository hygiene excludes RSA/key material, ZIP/CRX outputs, logs and local settings.
- Active manager commitments: EI-PM-002, EI-PM-003, EI-PM-004.


- Installable Windows packaging is implemented with Inno Setup.
- Fixed installer AppId: `79735245-B74E-5117-B1EF-A58BDC270FC7`; repeated/newer installers use the same installed application identity and path.
- Default install scope is per-user, no admin rights required, under `%LOCALAPPDATA%\Programs\ExtensionInstaller`.
- The installed launcher runs the existing CMD UI without a visible console window.
- Preview `3.0.2-preview.3` was built and published as GitHub prerelease `installer-preview-3`.
- Windows CI smoke test passed: silent install, second install over the existing fixed-AppId installation, payload verification, and silent uninstall.
- Setup SHA-256: `e69d4db6dc0ac55124e46dbd301d13ffb0504d8bb1b14d3955586c56073e37bd`.
- No GitHub Actions artifact is retained; the setup EXE is published directly as a Release asset.
- Canonical extension name for the first ecosystem integration is `Network Recorder`.

- Uninstall data policy is implemented: interactive uninstall asks whether to delete `%LOCALAPPDATA%\ExtensionInstaller`; declining preserves it, confirming removes it.
- Silent uninstall preserves working data by default; CI has an explicit cleanup switch only for exercising the full-delete path.
- Preview `3.0.2-preview.4` passed Windows smoke tests for both uninstall branches and is published as prerelease `installer-preview-4`.
- Preview 3.0.2-preview.4 SHA-256: `72b8938252d02520d3c35c3b1cd397d9d04f9a7346ef03cc03f96c5aa4144b9c`.

- Public extension repository `lvlaksim1/network-recorder` was created through `lvlaksim1/repo-factory` using the agentless `infrastructure` profile.
- Network Recorder currently has no Project Manager / Context Capsule. Ecosystem coordination remains with `extension-installer-project-manager`.
- The Network Recorder repository has repository-level signing/release policy documented and a `.gitignore` that excludes RSA/private-key material and CRX/ZIP build outputs.

- Network Recorder v1.6.0 source was imported byte-for-byte into `lvlaksim1/network-recorder/src` through `repo-factory`.
- Authoritative retained source archive SHA-256: `eeb0cdfdf6323c96c6aea777ad9aed889522dc9de13e467b8f447723612e1db3`.
- Factory import commit: `db1993a63c08beb1a7b7353f1bfe49419d6bafde`; README follow-up commit: `5dd717080a60b06747cc266553f9e880745d8c79`.
- Git blob hashes for all five imported files were compared against the retained ZIP and matched byte-for-byte.
- Imported manifest confirms canonical name `Network Recorder`, version `1.6.0`, and the existing public key derives Extension ID `paolfcaakecapidipfcfbbhgkpcmgcip`.
- No private signing key is committed to `network-recorder`.

- Network Recorder GitHub signing is operational using repository secret `RSA_PRIVATE_KEY_BASE64` (secret value is not stored in context).
- Signed prerelease `network-recorder-v1.6.0-preview-1` was built on GitHub Actions from v1.6.0 source.
- The signing key preserved Extension ID `paolfcaakecapidipfcfbbhgkpcmgcip`.
- Published CRX SHA-256: `3516149ea638f6ff10626c1ae974c92627e220c1e86b5c5195abdea4700c26cf`.
- Release assets: `Network_Recorder_v1.6.0.crx` and `extension-release.json`.
- ExtensionInstaller independently validated the published prerelease: descriptor, SHA-256, CRX3 signature and embedded Extension ID all passed.
- Neither signing nor validation workflow retained GitHub Actions artifacts.
