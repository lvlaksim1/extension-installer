# Manager plans

Current plan for active intentions EI-PM-002…004:

1. **Completed for this stage:** audit `src/ExtensionInstaller.cmd` and separate responsibilities into bootstrap, local discovery, manifest/package preparation, signing, browser registration, rollback/uninstall, browser assistance and GUI.
2. **Completed for this stage:** define release contract v1 with pinned catalog identity, `extension-release.json`, signed CRX asset and SHA-256.
3. **Completed for this stage:** implement and Windows-validate a release acquisition/verification engine that requires no private RSA key.
4. **Completed for this stage:** implement the new signed-CRX registration/update/rollback/uninstall primitives.
5. **Next:** integrate the validated engine into the user-facing installer GUI and replace local folder/ZIP selection as the primary path.
6. **Next:** create the EINV Network Recorder repository, move its retained RSA key into GitHub secret scope, publish the selected stable 1.6.0 as a signed release, and pin its existing Extension ID in the installer catalog.
7. **Gate:** verify real Yandex Browser installation/update before deleting legacy signing functions or publishing a stable installer release.
