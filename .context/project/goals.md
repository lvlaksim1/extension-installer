# Project goals

1. Provide a clean Windows GUI for installing, updating and removing approved browser extensions from signed GitHub Releases.
2. Keep each extension in a separate repository with independent source, versioning, signing and releases.
3. Preserve extension identity by pinning and verifying stable Extension IDs.
4. Keep RSA private keys out of the owner's persistent local installation and out of Git history.
5. Verify release metadata, SHA-256, CRX3 signature and Extension ID before registration.
6. Make ExtensionInstaller itself installable/updatable in place with one setup EXE.
7. Avoid unnecessary GitHub Actions artifacts and binary files in normal Git history.
8. Keep the extension ecosystem coordinated by `extension-installer-project-manager` until the owner assigns separate managers.
