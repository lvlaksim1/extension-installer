# ExtensionInstaller

Windows application for installing, updating and removing approved Chromium-based browser extensions, currently focused on Yandex Browser.

## Product model

ExtensionInstaller has one installation path only:

`catalog/extensions.json` → selected extension repository → signed GitHub Release → `extension-release.json` → CRX3 verification → installer-owned local CRX → Yandex Browser registration.

There is no local extension-source folder, no ZIP selector, no local extension build step and no private RSA key on the user's computer.

## Trust model

Each catalog entry pins:

- extension slug and display name;
- GitHub repository;
- expected Extension ID;
- release channel.

Before installation or update, ExtensionInstaller verifies:

1. release descriptor schema and metadata;
2. descriptor Extension ID against the pinned catalog ID;
3. CRX SHA-256;
4. CRX3 RSA/SHA-256 signature;
5. Extension ID derived from the CRX public key.

Only a CRX that passes all checks may be registered.

## Current catalog

- **Network Recorder**
  - repository: `lvlaksim1/network-recorder`
  - Extension ID: `paolfcaakecapidipfcfbbhgkpcmgcip`
  - current integration channel: `prerelease`

The prerelease channel is temporary for end-to-end installation testing. Switching a catalog entry to `stable` requires no GUI changes.

## Local layout

Program files:

`%LOCALAPPDATA%\Programs\ExtensionInstaller`

Application data:

`%LOCALAPPDATA%\ExtensionInstaller`

Managed extension CRX/state:

`%LOCALAPPDATA%\ExtensionInstaller\extensions\<extension-id>`

Logs:

`%LOCALAPPDATA%\ExtensionInstaller\logs`

## Windows installation

The application is packaged with Inno Setup as a per-user installer.

- fixed AppId for in-place updates;
- no administrator rights required by default;
- Start Menu shortcut;
- optional desktop shortcut;
- setup EXE is published directly in GitHub Releases;
- no GitHub Actions artifacts are retained for distribution.

During interactive uninstall, Windows asks whether application data should also be removed. Declining preserves settings, extension state and logs; confirming removes `%LOCALAPPDATA%\ExtensionInstaller`.

## Extension release ownership

Extension repositories own their source, signing workflow and release assets. Private signing keys live only in GitHub secret scope. ExtensionInstaller never receives or stores those keys.

See `docs/EXTENSION_RELEASE_CONTRACT.md` for the release contract.
