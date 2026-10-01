# Next actions

1. Configure the existing Network Recorder RSA private key in GitHub secret scope for `lvlaksim1/network-recorder` without committing or persisting it in repository state.
2. Add the GitHub-side CRX signing/release workflow and verify that it produces Extension ID `paolfcaakecapidipfcfbbhgkpcmgcip`.
3. Publish the first signed Network Recorder v1.6.0 release with `extension-release.json`, signed CRX and SHA-256 metadata, without retained Actions artifacts.
4. Add Network Recorder to `extension-installer/catalog/extensions.json`.
5. Integrate `src/ReleaseInstaller.ps1` into the ExtensionInstaller GUI and replace the legacy local ZIP/RSA path.
6. Perform a real Yandex Browser install/update test through ExtensionInstaller before removing legacy signing code or designating a stable ExtensionInstaller release.
