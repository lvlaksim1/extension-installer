# Manager goals

1. Preserve ExtensionInstaller v3.0.2 as a known migration baseline while keeping the repository free of secrets.
2. Convert ExtensionInstaller into a reliable installer/update manager for independently released browser extensions.
3. Establish a stable machine-readable contract between the installer and extension repositories/releases.
4. Remove the need for persistent local RSA signing keys without changing existing extension IDs.
5. Make installation and update behavior diagnosable, reversible where practical, and safe for Yandex Browser.
6. Keep repository and CI storage lean: source in Git, distributables in Releases, no unnecessary retained artifacts.
7. Maintain durable project state so another runtime can resume the same manager role without relying on chat history.
