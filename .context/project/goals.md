# Project goals

1. Preserve the known working ExtensionInstaller v3.0.2 baseline.
2. Evolve the installer from local ZIP + local RSA signing toward installation of already signed extension releases.
3. Keep each browser extension in a separate repository with independent versioning and releases.
4. Preserve stable extension IDs across migrations.
5. Keep RSA private keys out of local persistent storage and out of Git history; signing is intended to run in GitHub Actions using repository/environment secrets.
6. Avoid unnecessary GitHub Actions artifacts and large binary files in repository history.
