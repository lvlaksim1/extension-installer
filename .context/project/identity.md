# Project identity

- Project: ExtensionInstaller
- Repository: `lvlaksim1/extension-installer`
- Role: Windows installer/update manager for the browser-extension ecosystem.
- Initial browser target: Yandex Browser on Windows.
- Current architecture: clean catalog-driven consumption of signed extension GitHub Releases.
- Repository responsibility: installer source, GUI, release acquisition/verification logic, browser registration/update/uninstall logic, extension catalog contract, tests, documentation and installer packaging.
- Extension repositories own their own source, versioning, signing secrets and extension release assets.
- Out of scope: storing private extension signing keys or maintaining a local source/ZIP signing library on the user's PC.
