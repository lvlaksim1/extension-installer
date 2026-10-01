# Manager goals

1. Maintain ExtensionInstaller as a clean release-driven installer/update manager with no user-facing legacy folder/ZIP/RSA workflow.
2. Keep each browser extension in its own repository with independent source, versioning, signing workflow and GitHub Releases.
3. Maintain a stable machine-readable release contract between ExtensionInstaller and extension repositories.
4. Preserve extension identity by pinning and verifying Extension IDs across signing and update migrations.
5. Keep private signing keys out of Git and out of the owner's persistent ExtensionInstaller installation.
6. Make install/update/uninstall behavior diagnosable, integrity-checked and rollback-safe where practical.
7. Keep repository and CI storage lean: source in Git, distributables in Releases, no unnecessary retained artifacts.
8. Coordinate agentless extension repositories from `extension-installer-project-manager` until the owner explicitly assigns separate managers.
9. Maintain durable project state so another runtime can resume the same manager role without relying on chat history.
