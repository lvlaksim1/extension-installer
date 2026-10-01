# Current state

- Repository `lvlaksim1/extension-installer` was created through `lvlaksim1/repo-factory`.
- Visibility: public.
- Factory profile: `project-manager`; Project Manager v2 context capsule installed.
- Standard Telegram secrets: skipped.
- The retained `ExtensionInstaller_v3.0.2.cmd` has been imported as `src/ExtensionInstaller.cmd`.
- Original retained file SHA-256 before import: `100193a70aa77f0a06fb76d84a4deb28c6447ad930a6fb36e1a2159600a0375a`.
- Pre-import scan found references to `RSA_PRIVATE_KEY.txt` as an external file, but no embedded RSA private key or obvious token/password material.
- Repository hygiene excludes RSA/key material, ZIP/CRX outputs, logs and local settings.
- Target architecture: separate extension repositories, signing keys stored only as GitHub Actions secrets, signed CRX files published in Releases, installer consumes signed releases.
